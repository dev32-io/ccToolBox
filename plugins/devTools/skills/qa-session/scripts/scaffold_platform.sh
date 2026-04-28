#!/usr/bin/env bash
# scaffold_platform.sh — first-run scaffold for a new qa/<platform>/ tree.
#
# Copies the skill's `templates/` into qa/<platform>/, renaming `*.tmpl`
# to drop the suffix. Creates findings/{bugs/,issues.md} skeleton, an
# empty index.json, and writes a .gitignore entry for sessions/ and
# .playwright/profiles/ if the platform's parent project has a .gitignore.
#
# Usage: scaffold_platform.sh <platform>
# Exit:  0 on success; 2 on bad args / missing skill dir; 3 if platform
#        already exists (refuse to overwrite).
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: scaffold_platform.sh <platform>" >&2
  exit 2
fi

PLATFORM="$1"
case "$PLATFORM" in
  *[/\\]*|"") echo "scaffold_platform.sh: invalid platform name: $PLATFORM" >&2; exit 2 ;;
esac

# CLAUDE_SKILL_DIR is set by the harness when the skill is active. When
# someone runs this script directly (e.g. testing), derive it from the
# script's own path.
SKILL_DIR="${CLAUDE_SKILL_DIR:-}"
if [[ -z "$SKILL_DIR" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SKILL_DIR="$(dirname "$SCRIPT_DIR")"
fi

TEMPLATES_DIR="$SKILL_DIR/templates"
[[ -d "$TEMPLATES_DIR" ]] || { echo "scaffold_platform.sh: templates dir missing at $TEMPLATES_DIR" >&2; exit 2; }

command -v git >/dev/null || { echo "scaffold_platform.sh: git is required" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "scaffold_platform.sh: not a git repo" >&2; exit 2; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

PLATFORM_DIR="qa/$PLATFORM"
if [[ -e "$PLATFORM_DIR/config.yml" ]]; then
  echo "scaffold_platform.sh: $PLATFORM_DIR/config.yml already exists; refusing to overwrite" >&2
  exit 3
fi

mkdir -p "$PLATFORM_DIR/charters" "$PLATFORM_DIR/findings/bugs" "$PLATFORM_DIR/sessions"

# Copy templates; strip .tmpl suffix in destination.
copy_template() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || return 0
  if [[ -e "$dst" ]]; then
    echo "  skipped (exists): $dst" >&2
    return 0
  fi
  cp "$src" "$dst"
  echo "  wrote: $dst"
}

copy_template "$TEMPLATES_DIR/config.yml.tmpl"   "$PLATFORM_DIR/config.yml"
copy_template "$TEMPLATES_DIR/recon.sh.tmpl"     "$PLATFORM_DIR/recon.sh"
copy_template "$TEMPLATES_DIR/oracles.md.tmpl"   "$PLATFORM_DIR/oracles.md"
copy_template "$TEMPLATES_DIR/charters/login.md.tmpl"  "$PLATFORM_DIR/charters/login.md"
copy_template "$TEMPLATES_DIR/charters/smoke.md.tmpl"  "$PLATFORM_DIR/charters/smoke.md"

# Make recon.sh executable if it landed.
[[ -f "$PLATFORM_DIR/recon.sh" ]] && chmod +x "$PLATFORM_DIR/recon.sh"

# Empty issues.md and index.json skeletons.
if [[ ! -f "$PLATFORM_DIR/findings/issues.md" ]]; then
  cat > "$PLATFORM_DIR/findings/issues.md" <<EOF
# Issues — $PLATFORM

The "weird, not sure yet" pile from qa-session runs. Each entry is
appended by the Reporter's PROOF debrief; recurring entries get a
"(seen again [date])" line appended in place. Promote to a confirmed
bug by writing a JSON file in \`findings/bugs/\`; demote / delete by
hand if no longer relevant.

EOF
  echo "  wrote: $PLATFORM_DIR/findings/issues.md"
fi

if [[ ! -f "$PLATFORM_DIR/index.json" ]]; then
  cat > "$PLATFORM_DIR/index.json" <<'EOF'
{
  "version": 1,
  "generated_at": null,
  "open_count": 0,
  "by_area": {},
  "recurring": [],
  "recent_first_seen": [],
  "issue_count": 0
}
EOF
  echo "  wrote: $PLATFORM_DIR/index.json"
fi

# Update .gitignore if present at repo root. Idempotent.
GITIGNORE="$REPO_ROOT/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
  needs_block=false
  grep -qE "^qa/\*/sessions/" "$GITIGNORE" 2>/dev/null || needs_block=true
  grep -qE "^qa/\*/.playwright/" "$GITIGNORE" 2>/dev/null || needs_block=true
  if [[ "$needs_block" == "true" ]]; then
    {
      echo ""
      echo "# qa-session per-run artifacts (committed: bugs/, issues.md, index.json, charters/, config.yml, oracles.md, recon.sh)"
      echo "qa/*/sessions/"
      echo "qa/*/.playwright/"
    } >> "$GITIGNORE"
    echo "  appended .gitignore entries for qa/*/sessions/ and qa/*/.playwright/"
  fi
fi

cat <<EOF

Scaffold complete: $PLATFORM_DIR/

Next steps:
  1. Edit $PLATFORM_DIR/config.yml — set base_url and stack.setup commands.
  2. Edit $PLATFORM_DIR/recon.sh — adapt route discovery to your router framework.
  3. Edit $PLATFORM_DIR/charters/login.md — describe your login UI steps.
  4. Optionally add more charters under $PLATFORM_DIR/charters/.
  5. Re-run the qa-session skill (or /qa-session $PLATFORM).
EOF
