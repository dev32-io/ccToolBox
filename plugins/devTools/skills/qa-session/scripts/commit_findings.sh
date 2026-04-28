#!/usr/bin/env bash
# commit_findings.sh — apply a Reporter's output to the platform's
# findings corpus. Idempotent within a single session id.
#
# Reads the reporter-output.json (schema described in SKILL.md Step 8)
# and:
#   - writes each new bug as findings/bugs/<id>.json (collision-resolved)
#   - applies bug_recurrences in place (bumps recurrence_count, etc.)
#   - appends new issues to findings/issues.md as a date-stamped section
#   - applies issue_recurrences as inline "(seen again …)" lines
#   - regenerates index.json from the current bug corpus + issues file
#   - renders sessions/<id>/session-sheet.md from a template
#
# Usage: commit_findings.sh <platform> <session_id> <reporter_output_json>
# Exit:  0 on success; 2 on bad args / missing inputs.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: commit_findings.sh <platform> <session_id> <reporter_output_json>" >&2
  exit 2
fi

PLATFORM="$1"
SESSION_ID="$2"
REPORTER_JSON="$3"

case "$PLATFORM" in
  *[/\\]*|"") echo "commit_findings.sh: invalid platform name" >&2; exit 2 ;;
esac

[[ -f "$REPORTER_JSON" ]] || { echo "commit_findings.sh: reporter output not found: $REPORTER_JSON" >&2; exit 2; }

command -v jq >/dev/null  || { echo "commit_findings.sh: jq is required" >&2; exit 2; }
command -v git >/dev/null || { echo "commit_findings.sh: git is required" >&2; exit 2; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

PLATFORM_DIR="qa/$PLATFORM"
BUGS_DIR="$PLATFORM_DIR/findings/bugs"
ISSUES_PATH="$PLATFORM_DIR/findings/issues.md"
INDEX_PATH="$PLATFORM_DIR/index.json"
SESSION_DIR="$PLATFORM_DIR/sessions/$SESSION_ID"
SHEET_PATH="$SESSION_DIR/session-sheet.md"

mkdir -p "$BUGS_DIR" "$SESSION_DIR"
[[ -f "$ISSUES_PATH" ]] || touch "$ISSUES_PATH"

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
TODAY="$(date -u +%Y-%m-%d)"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Counters for the summary.
BUGS_NEW=0
BUGS_RECURRING=0
ISSUES_NEW=0
ISSUES_RECURRING=0

# ---------------------------------------------------------------------------
# Step A: write new bug JSONs.
# ---------------------------------------------------------------------------
BUG_COUNT="$(jq '.bugs | length' "$REPORTER_JSON")"
for ((i=0; i<BUG_COUNT; i++)); do
  BUG_JSON="$(jq -c ".bugs[$i]" "$REPORTER_JSON")"
  ID_HINT="$(echo "$BUG_JSON" | jq -r '.id_hint')"

  # Collision resolution: if a file with this id already exists in
  # bugs/, append a 2-char suffix until we find a free name. Idempotent
  # within a single session: same fingerprint → same content → no churn.
  ID="$ID_HINT"
  SUFFIX_N=0
  while [[ -e "$BUGS_DIR/$ID.json" ]]; do
    EXISTING_FP="$(jq -r '.fingerprint' "$BUGS_DIR/$ID.json" 2>/dev/null || echo "")"
    NEW_FP="$(echo "$BUG_JSON" | jq -r '.fingerprint')"
    if [[ "$EXISTING_FP" == "$NEW_FP" ]]; then
      # Same finding, already on disk — treat as recurrence by content.
      break
    fi
    SUFFIX_N=$((SUFFIX_N + 1))
    ID="${ID_HINT}-$(printf '%02d' "$SUFFIX_N")"
  done

  if [[ -e "$BUGS_DIR/$ID.json" ]]; then
    # Same fingerprint, same id — bump recurrence_count instead of overwriting.
    EXISTING="$(cat "$BUGS_DIR/$ID.json")"
    UPDATED="$(echo "$EXISTING" | jq \
      --arg ts "$NOW_ISO" \
      --arg branch "$BRANCH" \
      --arg session "$SESSION_ID" \
      '
      .recurrence_count = ((.recurrence_count // 1) + 1)
      | .consecutive_misses = 0
      | .last_seen = { ts: $ts, branch: $branch, session_id: $session }
      | .branches_seen = ((.branches_seen // []) + [$branch] | unique)
      ')"
    echo "$UPDATED" > "$BUGS_DIR/$ID.json"
    BUGS_RECURRING=$((BUGS_RECURRING + 1))
    continue
  fi

  # New bug — assemble the canonical record.
  ENRICHED="$(echo "$BUG_JSON" | jq \
    --arg id "$ID" \
    --arg ts "$NOW_ISO" \
    --arg branch "$BRANCH" \
    --arg session "$SESSION_ID" \
    '
    {
      id: $id,
      fingerprint: .fingerprint,
      title: .title,
      area: .area,
      target: .target,
      oracle: .oracle,
      severity: .severity,
      priority: .priority,
      status: "open",
      first_seen: { ts: $ts, branch: $branch, session_id: $session },
      last_seen:  { ts: $ts, branch: $branch, session_id: $session },
      recurrence_count: 1,
      consecutive_misses: 0,
      branches_seen: [$branch],
      evidence: .evidence,
      repro_steps: .repro_steps,
      expected: .expected,
      actual: .actual,
      rimgea: .rimgea,
      notes: [],
      linked_pr: null
    }')"
  echo "$ENRICHED" | jq '.' > "$BUGS_DIR/$ID.json"
  BUGS_NEW=$((BUGS_NEW + 1))
done

# ---------------------------------------------------------------------------
# Step B: apply bug_recurrences explicitly emitted by the Reporter.
# ---------------------------------------------------------------------------
REC_COUNT="$(jq '.bug_recurrences | length' "$REPORTER_JSON")"
for ((i=0; i<REC_COUNT; i++)); do
  REC="$(jq -c ".bug_recurrences[$i]" "$REPORTER_JSON")"
  EXISTING_ID="$(echo "$REC" | jq -r '.existing_id')"
  TARGET_FILE="$BUGS_DIR/$EXISTING_ID.json"
  if [[ ! -f "$TARGET_FILE" ]]; then
    # Reporter referenced a bug id that doesn't exist on disk — log warning, skip.
    echo "warning: bug_recurrence references missing id: $EXISTING_ID" >&2
    continue
  fi
  EXISTING="$(cat "$TARGET_FILE")"
  UPDATED="$(echo "$EXISTING" | jq \
    --arg ts "$NOW_ISO" \
    --arg branch "$BRANCH" \
    --arg session "$SESSION_ID" \
    '
    .recurrence_count = ((.recurrence_count // 1) + 1)
    | .consecutive_misses = 0
    | .last_seen = { ts: $ts, branch: $branch, session_id: $session }
    | .branches_seen = ((.branches_seen // []) + [$branch] | unique)
    ')"
  echo "$UPDATED" > "$TARGET_FILE"
  BUGS_RECURRING=$((BUGS_RECURRING + 1))
done

# ---------------------------------------------------------------------------
# Step C: append new issues to issues.md as a date-stamped section.
# ---------------------------------------------------------------------------
ISSUE_COUNT="$(jq '.issues | length' "$REPORTER_JSON")"
if [[ "$ISSUE_COUNT" -gt 0 ]]; then
  {
    echo ""
    echo "## $TODAY — session $SESSION_ID"
    echo ""
    for ((i=0; i<ISSUE_COUNT; i++)); do
      ISSUE="$(jq -c ".issues[$i]" "$REPORTER_JSON")"
      TITLE="$(echo "$ISSUE" | jq -r '.title')"
      AREA="$(echo "$ISSUE"  | jq -r '.area // "uncategorized"')"
      KIND="$(echo "$ISSUE"  | jq -r '.kind // "other"')"
      OPEN_Q="$(echo "$ISSUE" | jq -r '.evidence.open_question // ""')"
      EXCERPT="$(echo "$ISSUE" | jq -r '.evidence.session_log_excerpt // ""')"

      echo "### [$AREA] $TITLE"
      echo ""
      echo "- **kind:** \`$KIND\`"
      [[ -n "$OPEN_Q" ]] && echo "- **open question:** $OPEN_Q"
      if [[ -n "$EXCERPT" ]]; then
        echo "- **excerpt:**"
        echo ""
        echo "  > $(echo "$EXCERPT" | head -c 400 | tr '\n' ' ')"
      fi

      # Inline screenshots if any.
      SHOT_COUNT="$(echo "$ISSUE" | jq '.evidence.screenshots // [] | length')"
      for ((s=0; s<SHOT_COUNT; s++)); do
        SHOT="$(echo "$ISSUE" | jq -r ".evidence.screenshots[$s]")"
        echo "- ![screenshot]($SHOT)"
      done
      echo ""
      ISSUES_NEW=$((ISSUES_NEW + 1))
    done
  } >> "$ISSUES_PATH"
fi

# ---------------------------------------------------------------------------
# Step D: apply issue_recurrences as inline "(seen again …)" lines.
# We do a simple grep for the title_match string and append one line below
# the matched heading. If no match, fall through to a "stray recurrence"
# section so nothing is silently dropped.
# ---------------------------------------------------------------------------
IREC_COUNT="$(jq '.issue_recurrences | length' "$REPORTER_JSON")"
STRAY=()
for ((i=0; i<IREC_COUNT; i++)); do
  TM="$(jq -r ".issue_recurrences[$i].title_match" "$REPORTER_JSON")"
  if grep -qF "$TM" "$ISSUES_PATH" 2>/dev/null; then
    # Append a recurrence line after the FIRST matching heading.
    awk -v tm="$TM" -v note="- _seen again $TODAY (session $SESSION_ID)_" '
      BEGIN { appended = 0 }
      {
        print
        if (!appended && index($0, tm) > 0) {
          print ""
          print note
          appended = 1
        }
      }
    ' "$ISSUES_PATH" > "$ISSUES_PATH.tmp" && mv "$ISSUES_PATH.tmp" "$ISSUES_PATH"
    ISSUES_RECURRING=$((ISSUES_RECURRING + 1))
  else
    STRAY+=("$TM")
  fi
done

if [[ "${#STRAY[@]}" -gt 0 ]]; then
  {
    echo ""
    echo "## $TODAY — session $SESSION_ID — stray recurrences"
    echo ""
    echo "Reporter flagged these as recurrences but no matching prior entry was found:"
    echo ""
    for s in "${STRAY[@]}"; do
      echo "- $s"
    done
  } >> "$ISSUES_PATH"
fi

# ---------------------------------------------------------------------------
# Step E: bump consecutive_misses on bugs that did NOT recur this run, and
# auto-close stale ones.
# Fingerprints we saw this run = (new bug fingerprints) ∪ (recurrence target ids).
# ---------------------------------------------------------------------------
SEEN_FPS_FILE="$(mktemp)"
jq -r '.bugs[].fingerprint' "$REPORTER_JSON" > "$SEEN_FPS_FILE"
jq -r '.bug_recurrences[].existing_id' "$REPORTER_JSON" > "$SEEN_FPS_FILE.ids"

# Read auto_close_after_misses from config.yml (default 3).
AUTO_CLOSE_N=3
CONFIG_PATH="$PLATFORM_DIR/config.yml"
if [[ -f "$CONFIG_PATH" ]]; then
  CFG_VAL="$(awk '/^[[:space:]]*auto_close_after_misses:/ {print $2; exit}' "$CONFIG_PATH" | tr -d '"')"
  [[ "$CFG_VAL" =~ ^[0-9]+$ ]] && AUTO_CLOSE_N="$CFG_VAL"
fi

for f in "$BUGS_DIR"/*.json; do
  [[ -f "$f" ]] || continue
  ID="$(basename "$f" .json)"
  FP="$(jq -r '.fingerprint' "$f")"
  STATUS="$(jq -r '.status' "$f")"
  [[ "$STATUS" != "open" ]] && continue

  # Did we see this bug this run?
  if grep -qFx "$FP" "$SEEN_FPS_FILE" 2>/dev/null; then continue; fi
  if grep -qFx "$ID" "$SEEN_FPS_FILE.ids" 2>/dev/null; then continue; fi

  UPDATED="$(jq \
    --argjson n "$AUTO_CLOSE_N" \
    '
    .consecutive_misses = ((.consecutive_misses // 0) + 1)
    | if .consecutive_misses >= $n then .status = "auto-closed-stale" else . end
    ' "$f")"
  echo "$UPDATED" > "$f"
done

rm -f "$SEEN_FPS_FILE" "$SEEN_FPS_FILE.ids"

# ---------------------------------------------------------------------------
# Step F: regenerate index.json from the current bug corpus + issues file.
# ---------------------------------------------------------------------------
TMP_BUGS="$(mktemp)"
{
  echo "["
  first=true
  for f in "$BUGS_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    if $first; then first=false; else echo ","; fi
    cat "$f"
  done
  echo "]"
} > "$TMP_BUGS"

ISSUE_LINES="$(grep -c '^### ' "$ISSUES_PATH" 2>/dev/null || echo 0)"

jq \
  --arg gen "$NOW_ISO" \
  --argjson issue_count "$ISSUE_LINES" \
  '
  {
    version: 1,
    generated_at: $gen,
    open_count: (map(select(.status == "open")) | length),
    by_area: (
      map(select(.status == "open"))
      | group_by(.area)
      | map({key: (.[0].area // "uncategorized"), value: length})
      | from_entries
    ),
    recurring: (
      map(select(.status == "open" and (.recurrence_count // 1) >= 2))
      | sort_by(-(.recurrence_count // 1))
      | .[0:20]
      | map({id, area, recurrence_count, last_seen})
    ),
    recent_first_seen: (
      sort_by(.first_seen.ts // "") | reverse | .[0:10]
      | map({id, area, ts: (.first_seen.ts // null)})
    ),
    issue_count: $issue_count
  }
  ' "$TMP_BUGS" > "$INDEX_PATH"

rm -f "$TMP_BUGS"

# ---------------------------------------------------------------------------
# Step G: render session-sheet.md.
# ---------------------------------------------------------------------------
PROOF_PAST="$(jq -r '.proof_debrief.past // ""' "$REPORTER_JSON")"
PROOF_RESULTS="$(jq -r '.proof_debrief.results // ""' "$REPORTER_JSON")"
PROOF_OUTLOOK="$(jq -r '.proof_debrief.outlook // ""' "$REPORTER_JSON")"
PROOF_OBSTACLES="$(jq -r '.proof_debrief.obstacles // ""' "$REPORTER_JSON")"
PROOF_FEELINGS="$(jq -r '.proof_debrief.feelings // ""' "$REPORTER_JSON")"

CHARTERS_RUN="$(jq -r '.summary.charters_run // 0' "$REPORTER_JSON")"
CHARTERS_DONE="$(jq -r '.summary.charters_complete // 0' "$REPORTER_JSON")"
LOG_LINES="$(jq -r '.summary.session_log_lines // 0' "$REPORTER_JSON")"
OPEN_QS="$(jq -r '.summary.open_questions // 0' "$REPORTER_JSON")"
SHOT_TOTAL="$(jq -r '.summary.screenshots // 0' "$REPORTER_JSON")"

cat > "$SHEET_PATH" <<EOF
# Session sheet — $SESSION_ID

**Platform:** $PLATFORM
**Branch:** $BRANCH
**Generated:** $NOW_ISO

## Summary

- Charters: $CHARTERS_DONE / $CHARTERS_RUN complete
- Session-log lines: $LOG_LINES
- Open questions (\`?\` lines): $OPEN_QS
- Screenshots: $SHOT_TOTAL
- New bugs: $BUGS_NEW
- Recurring bugs: $BUGS_RECURRING
- New issues: $ISSUES_NEW
- Recurring issues: $ISSUES_RECURRING

## PROOF debrief

### Past
$PROOF_PAST

### Results
$PROOF_RESULTS

### Outlook
$PROOF_OUTLOOK

### Obstacles
$PROOF_OBSTACLES

### Feelings
$PROOF_FEELINGS

## Handoff

### Needs human
$(jq -r '.handoff.needs_human[]? // empty | "- " + .' "$REPORTER_JSON")

### Ready for fixer
$(jq -r '.handoff.needs_fixer_agent[]? // empty | "- " + .' "$REPORTER_JSON")
EOF

# ---------------------------------------------------------------------------
# Step H: emit a one-paragraph summary to stdout.
# ---------------------------------------------------------------------------
cat <<EOF
Findings written:
  bugs:    +$BUGS_NEW new, +$BUGS_RECURRING recurring  (corpus: $(ls -1 "$BUGS_DIR" 2>/dev/null | wc -l | tr -d ' ') total files)
  issues:  +$ISSUES_NEW new, +$ISSUES_RECURRING recurring
  index:   regenerated → $INDEX_PATH
  sheet:   $SHEET_PATH
EOF
