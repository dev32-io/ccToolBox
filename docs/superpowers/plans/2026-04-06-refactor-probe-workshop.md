# Refactor Probe + Workshop Container Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the refactor-probe skill to the offline-research plugin and consolidate both container directories into a single `containers/workshop/` with per-profile Dockerfiles, unified launch script, and rate-limit-fixed runner scripts.

**Architecture:** Workshop container uses a `--container=research|arch|refactor` flag to route to profile-specific Dockerfiles, entrypoints, and runner scripts. Refactor-probe skill is faithfully adapted from the source work-environment version, replacing local bash runner references with container execution. All runner scripts get the broad rate-limit detection fix.

**Tech Stack:** Bash, Docker, Markdown (skill/template files)

**Spec:** `docs/superpowers/specs/2026-04-06-refactor-probe-workshop-design.md`

---

## Task 1: Create workshop directory structure

**Files:**
- Create: `containers/workshop/dockerfiles/` (directory)
- Create: `containers/workshop/.env.example`

- [ ] **Step 1: Create workshop directory tree**

```bash
mkdir -p containers/workshop/dockerfiles containers/workshop/testing
```

- [ ] **Step 2: Create .env.example**

Create `containers/workshop/.env.example`:

```
# Workshop runner config — copy to .env and customize
RESEARCH_HOURS="23:00-07:00"
TZ="America/Vancouver"
# Container names are set automatically per profile.
# Override here only if you need custom names.
# CONTAINER_NAME="workshop-research-sandbox"
```

- [ ] **Step 3: Commit**

```bash
git add containers/workshop/
git commit -m "chore(workshop): scaffold directory structure"
```

---

## Task 2: Move and adapt Dockerfiles

**Files:**
- Create: `containers/workshop/dockerfiles/research.Dockerfile`
- Create: `containers/workshop/dockerfiles/arch.Dockerfile`
- Create: `containers/workshop/dockerfiles/refactor.Dockerfile`

- [ ] **Step 1: Create research.Dockerfile**

Copy `containers/offline-research/Dockerfile` to `containers/workshop/dockerfiles/research.Dockerfile`. The only change: the `COPY entrypoint.sh` line must reference the parent directory since Dockerfiles are in a subdirectory — but we'll handle this via docker build context (build context is `containers/workshop/`, so COPY paths are relative to that).

Change the COPY line from:
```dockerfile
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
```
to:
```dockerfile
COPY entrypoint-light.sh /usr/local/bin/entrypoint.sh
```

This is because the lightweight entrypoint is being renamed to `entrypoint-light.sh` in the workshop.

- [ ] **Step 2: Create arch.Dockerfile**

Copy `containers/arch-tool/Dockerfile` to `containers/workshop/dockerfiles/arch.Dockerfile`. Change the COPY line from:
```dockerfile
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
```
to:
```dockerfile
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
```

No path change needed — the build context will be `containers/workshop/`.

- [ ] **Step 3: Create refactor.Dockerfile**

Copy `containers/workshop/dockerfiles/arch.Dockerfile` to `containers/workshop/dockerfiles/refactor.Dockerfile`. They start identical — both need PoC runtimes and the `poc` user sandbox.

- [ ] **Step 4: Commit**

```bash
git add containers/workshop/dockerfiles/
git commit -m "feat(workshop): add per-profile Dockerfiles"
```

---

## Task 3: Move entrypoints

**Files:**
- Create: `containers/workshop/entrypoint.sh`
- Create: `containers/workshop/entrypoint-light.sh`

- [ ] **Step 1: Copy heavy entrypoint**

Copy `containers/arch-tool/entrypoint.sh` to `containers/workshop/entrypoint.sh` unchanged. This is the full entrypoint with poc user setup, workspace permissions, and gosu drop.

- [ ] **Step 2: Copy light entrypoint**

Copy `containers/offline-research/entrypoint.sh` to `containers/workshop/entrypoint-light.sh` unchanged. This is the simple passthrough.

- [ ] **Step 3: Commit**

```bash
git add containers/workshop/entrypoint.sh containers/workshop/entrypoint-light.sh
git commit -m "feat(workshop): add entrypoint scripts"
```

---

## Task 4: Create unified launch.sh

**Files:**
- Create: `containers/workshop/launch.sh`

- [ ] **Step 1: Write launch.sh**

Create `containers/workshop/launch.sh`. This is adapted from `containers/arch-tool/launch.sh` with the `--container` required flag added. Key changes from the original:

1. Parse `--container=research|arch|refactor` from args
2. Route to the correct Dockerfile, image name, container name, and runner script
3. Build with `-f dockerfiles/<profile>.Dockerfile .` (context is workshop dir)
4. Arch and refactor get `--memory=4g --cpus=4 --pids-limit=200`; research does not
5. Title/banner uses profile name

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .env if present
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

# Defaults
TZ="${TZ:-America/Vancouver}"

# Colors
DIM='\033[2m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'
FRAMES=('   ' '.  ' '.. ' '...')

# ─── Profile routing ───

PROFILE=""
IMAGE_NAME=""
CONTAINER_NAME=""
RUNNER_SCRIPT=""
RESOURCE_LIMITS=""

parse_container_flag() {
    local found=""
    local remaining=()
    for arg in "$@"; do
        case "$arg" in
            --container=*)
                found="${arg#--container=}"
                ;;
            *)
                remaining+=("$arg")
                ;;
        esac
    done

    if [[ -z "$found" ]]; then
        printf "  ${RED}Error: --container flag is required${RESET}\n"
        printf "  Usage: launch.sh <command> --container=research|arch|refactor [args]\n"
        exit 1
    fi

    PROFILE="$found"
    case "$PROFILE" in
        research)
            IMAGE_NAME="workshop-research"
            CONTAINER_NAME="${CONTAINER_NAME:-workshop-research-sandbox}"
            RUNNER_SCRIPT="$SCRIPT_DIR/run-research.sh"
            RESOURCE_LIMITS=""
            ;;
        arch)
            IMAGE_NAME="workshop-arch"
            CONTAINER_NAME="${CONTAINER_NAME:-workshop-arch-sandbox}"
            RUNNER_SCRIPT="$SCRIPT_DIR/run-arch-forge.sh"
            RESOURCE_LIMITS="--memory=4g --cpus=4 --pids-limit=200"
            ;;
        refactor)
            IMAGE_NAME="workshop-refactor"
            CONTAINER_NAME="${CONTAINER_NAME:-workshop-refactor-sandbox}"
            RUNNER_SCRIPT="$SCRIPT_DIR/run-refactor.sh"
            RESOURCE_LIMITS="--memory=4g --cpus=4 --pids-limit=200"
            ;;
        *)
            printf "  ${RED}Unknown container profile: %s${RESET}\n" "$PROFILE"
            printf "  Valid profiles: research, arch, refactor\n"
            exit 1
            ;;
    esac

    # Return remaining args
    REMAINING_ARGS=("${remaining[@]}")
}

# ─── Helpers ───

spin() {
    local msg="$1" pid="$2" i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${DIM}${FRAMES[$((i % 4))]}${RESET} %s" "$msg"
        i=$((i + 1))
        sleep 0.3
    done
    wait "$pid"
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        printf "\r  ${GREEN}ok${RESET}  %s\n" "$msg"
    else
        printf "\r  ${RED}!!${RESET}  %s\n" "$msg"
    fi
    return $exit_code
}

log_ok()   { printf "  ${GREEN}ok${RESET}  %b\n" "$1"; }
log_err()  { printf "  ${RED}!!${RESET}  %b\n" "$1"; }
log_warn() { printf "  ${YELLOW}--${RESET}  %b\n" "$1"; }
log_dim()  { printf "  ${DIM}%b${RESET}\n" "$1"; }

build_image() {
    local dockerfile="$SCRIPT_DIR/dockerfiles/${PROFILE}.Dockerfile"
    local build_log="/tmp/${IMAGE_NAME}-build-$$.log"
    docker build -q -t "$IMAGE_NAME" -f "$dockerfile" "$SCRIPT_DIR" >"$build_log" 2>&1 &
    if ! spin "Building image ($PROFILE)" $!; then
        cat "$build_log" >&2
        rm -f "$build_log"
        exit 1
    fi
    rm -f "$build_log"
}

ensure_container() {
    local CONTAINER_HOME="${CLAUDE_CODE_RESEARCH_TOOL:?CLAUDE_CODE_RESEARCH_TOOL is not set}"
    local CLAUDE_PATH="${CONTAINER_HOME}/.claude"

    # Always recreate from latest image — state lives on mounted volumes
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
    fi

    mkdir -p "$WORKSPACE" "$CLAUDE_PATH"

    local claude_json="${CONTAINER_HOME}/.claude.json"
    [ -f "$claude_json" ] || echo '{"hasCompletedOnboarding":true,"installMethod":"native"}' > "$claude_json"

    docker run -d \
        --name "$CONTAINER_NAME" \
        ${RESOURCE_LIMITS} \
        -v "$WORKSPACE:/workspace" \
        -v "${CLAUDE_PATH}:/home/node/.claude:rw" \
        -v "${CONTAINER_HOME}/.claude.json:/home/node/.claude.json:rw" \
        -e "TZ=${TZ}" \
        ${GH_TOKEN:+-e GH_TOKEN="$GH_TOKEN"} \
        "$IMAGE_NAME" \
        tail -f /dev/null >/dev/null

    log_ok "Created container ${DIM}${CONTAINER_NAME}${RESET}"
}

# ─── Commands ───

WORKSPACE="${HOME}/offline-research"

cmd_setup() {
    printf "\n${BOLD}${CYAN}  workshop setup (%s)${RESET}\n\n" "$PROFILE"
    build_image
    ensure_container
    echo
    log_dim "Dropping into container shell. Run 'claude login' to authenticate."
    echo
    docker exec -it --user node "$CONTAINER_NAME" bash
}

cmd_run() {
    local topic_path="${1:?Usage: launch.sh run --container=<profile> <topic-path> [max-iterations]}"
    local max_iter="${2:-75}"

    topic_path="$(cd "$topic_path" && pwd)"

    printf "\n${BOLD}${CYAN}  workshop run (%s)${RESET}\n\n" "$PROFILE"
    build_image
    WORKSPACE="$topic_path"
    ensure_container
    echo
    exec "$RUNNER_SCRIPT" "$max_iter"
}

cmd_shell() {
    printf "\n${BOLD}${CYAN}  workshop shell (%s)${RESET}\n\n" "$PROFILE"
    ensure_container
    echo
    docker exec -it --user node "$CONTAINER_NAME" bash
}

cmd_help() {
    printf "\n${BOLD}${CYAN}  workshop${RESET}\n\n"
    printf "  ${BOLD}Usage:${RESET} launch.sh <command> --container=<profile> [args]\n\n"
    printf "  ${BOLD}Profiles:${RESET}\n"
    printf "    research     Lightweight — web research and analysis\n"
    printf "    arch         Heavy — architecture exploration with PoC sandbox\n"
    printf "    refactor     Heavy — codebase refactoring with PoC sandbox\n"
    printf "\n"
    printf "  ${BOLD}Commands:${RESET}\n"
    printf "    setup --container=<profile>                          Create container and login\n"
    printf "    run   --container=<profile> <topic-path> [max-iter]  Start exploration with auto-resume\n"
    printf "    shell --container=<profile>                          Open container shell\n"
    echo
}

# ─── Main ───

CMD="${1:-help}"
shift || true

if [[ "$CMD" == "help" ]]; then
    cmd_help
    exit 0
fi

parse_container_flag "$@"

case "$CMD" in
    setup) cmd_setup ;;
    run)   cmd_run "${REMAINING_ARGS[@]}" ;;
    shell) cmd_shell ;;
    *)     cmd_help ;;
esac
```

- [ ] **Step 2: Make executable**

```bash
chmod +x containers/workshop/launch.sh
```

- [ ] **Step 3: Commit**

```bash
git add containers/workshop/launch.sh
git commit -m "feat(workshop): unified launch.sh with --container flag"
```

---

## Task 5: Create runner scripts with rate-limit fix

**Files:**
- Create: `containers/workshop/run-research.sh`
- Create: `containers/workshop/run-arch-forge.sh`
- Create: `containers/workshop/run-refactor.sh`

All three runners share the same structure. The key changes from the originals:

1. **Rate-limit fix** — add the broad regex pattern to `check_rate_limit()` in all three
2. **Container name** — read from `CONTAINER_NAME` env (set by launch.sh or .env)
3. **Banner text** — unique per runner

- [ ] **Step 1: Create run-research.sh**

Copy `containers/offline-research/run-research.sh` to `containers/workshop/run-research.sh`. Apply these changes:

1. Change default `CONTAINER_NAME` from `research-sandbox` to `workshop-research-sandbox`
2. Add the broad rate-limit pattern to `check_rate_limit()`:

Replace:
```bash
check_rate_limit() {
    [[ $LAST_EXIT -ne 0 ]] && return 0
    grep -q 'rate_limit' "$LAST_OUTPUT" 2>/dev/null && return 0
    return 1
}
```

With:
```bash
check_rate_limit() {
    [[ $LAST_EXIT -ne 0 ]] && return 0
    grep -q 'rate_limit' "$LAST_OUTPUT" 2>/dev/null && return 0
    # Catches subagent limit errors that surface with different messages
    grep -qiE 'rate.?limit|too many requests|429|quota exceeded|capacity|overloaded|resource_exhausted' "$LAST_OUTPUT" 2>/dev/null && return 0
    return 1
}
```

- [ ] **Step 2: Create run-arch-forge.sh**

Copy `containers/arch-tool/run-arch.sh` to `containers/workshop/run-arch-forge.sh`. Apply these changes:

1. Change default `CONTAINER_NAME` from `arch-sandbox` to `workshop-arch-sandbox`
2. Change banner from `arch-runner` to `arch-forge-runner`
3. Change completion message from `Exploration complete` to `Exploration complete`
4. Apply the same `check_rate_limit()` fix as step 1
5. Change tmp file names from `arch-runner-output` to `arch-forge-runner-output` and `arch-probe-output` to `arch-forge-probe-output`

- [ ] **Step 3: Create run-refactor.sh**

Copy `containers/workshop/run-arch-forge.sh` to `containers/workshop/run-refactor.sh`. Apply these changes:

1. Change default `CONTAINER_NAME` from `workshop-arch-sandbox` to `workshop-refactor-sandbox`
2. Change banner from `arch-forge-runner` to `refactor-runner`
3. Change tmp file names from `arch-forge-runner-output` to `refactor-runner-output` and `arch-forge-probe-output` to `refactor-probe-output`
4. Add permission error detection (from source `run-refactor-probe.sh`). After `check_completed` and `check_rate_limit`, add:

```bash
check_permission_errors() {
    local perms
    perms=$(grep -iE 'permission|not allowed|denied|requires approval|tool.*blocked' \
        "$LAST_OUTPUT" 2>/dev/null || true)
    if [[ -n "$perms" ]]; then
        local ts
        ts=$(date '+%Y-%m-%d %H:%M:%S')
        echo "--- [$ts] iteration $iter ---" >> "/tmp/refactor-permission-errors-$$.log"
        echo "$perms" >> "/tmp/refactor-permission-errors-$$.log"
        echo "" >> "/tmp/refactor-permission-errors-$$.log"
        printf "  ${YELLOW}Permission issue detected — see log${RESET}\n"
    fi
}
```

And call `check_permission_errors` in the main loop after `run_iteration`, before `check_completed`.

5. Add macOS notification on completion (from source):

After the completion message in the main loop:
```bash
osascript -e 'display notification "Exploration complete!" with title "refactor-runner"' 2>/dev/null || true
```

- [ ] **Step 4: Make all runners executable**

```bash
chmod +x containers/workshop/run-research.sh containers/workshop/run-arch-forge.sh containers/workshop/run-refactor.sh
```

- [ ] **Step 5: Commit**

```bash
git add containers/workshop/run-research.sh containers/workshop/run-arch-forge.sh containers/workshop/run-refactor.sh
git commit -m "feat(workshop): runner scripts with subagent rate-limit fix"
```

---

## Task 6: Create refactor-probe SKILL.md

**Files:**
- Create: `plugins/offline-research/skills/refactor-probe/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

Create `plugins/offline-research/skills/refactor-probe/SKILL.md`. This is faithfully adapted from the source at `/Users/kevinye/Development/offline-research/skills/refactor-probe/SKILL.md` with these changes only:

1. **Frontmatter**: add `allowed-tools` matching the source
2. **Step 5 run instructions**: Replace the local `run-refactor-probe.sh` instructions with container-based execution. Instead of copying a runner script and disabling skills, present three run options matching the sibling skills' pattern:

Replace the entire "Present setup and run instructions" section with:

```markdown
**Present three run options (without showing commands yet):**

Derive `<folder-name>` from the last path segment of the user's chosen directory.

> **How do you want to run this refactor exploration?**
> 1. In the workshop container with auto-resume (Recommended)
> 2. In the workshop container (manual)
> 3. Locally

After the user picks, print only the selected command:

- **Auto-resume command** (option 1):
  ```
  ./containers/workshop/launch.sh run --container=refactor <host-path> <TOPIC_COUNT * 10 + 15>
  ```

- **Manual container command** (option 2):
  ```
  /ralph-loop:ralph-loop "Do NOT invoke any skills or use the Skill tool. Read /workspace/prompt.md for context. Read /workspace/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop." --max-iterations <TOPIC_COUNT * 10 + 15> --completion-promise "TASK DONE"
  ```

- **Local command** (option 3):
  ```
  /ralph-loop:ralph-loop "Do NOT invoke any skills or use the Skill tool. Read <local-path>/prompt.md for context. Read <local-path>/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop." --max-iterations <TOPIC_COUNT * 10 + 15> --completion-promise "TASK DONE"
  ```

Replace `<host-path>` and `<local-path>` with the user's chosen directory path.

Then ask:

> Copy to clipboard? (y/n)

If yes, copy the selected command to clipboard via `printf '%s' '<command>' | pbcopy`.
```

3. **Output location**: Change default from `.refactor-probe/YYYY-MM-DD-short-title/` to offer the same three options as siblings:

```markdown
> Where should I write the seed files?
> 1. `~/offline-research/YYYY-MM-DD-short-title/`
> 2. `<git-root>/offline-research/YYYY-MM-DD-short-title/` (or `./YYYY-MM-DD-short-title/` if not in a git repo)
> 3. Type a custom path
```

Everything else — the 5-phase flow, Tone section, Intake, Quick Survey, Critical Assessment + Refinement, Rubric Co-Design (4a-4d), template reading, placeholder filling, max-iterations formula — is copied verbatim from the source.

- [ ] **Step 2: Verify skill file structure**

```bash
ls plugins/offline-research/skills/refactor-probe/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add -f plugins/offline-research/skills/refactor-probe/
git commit -m "feat(offline-research): add refactor-probe skill"
```

---

## Task 7: Create refactor-probe template files

**Files:**
- Create: `plugins/offline-research/templates/refactor-probe/prompt.md`
- Create: `plugins/offline-research/templates/refactor-probe/progress.md`
- Create: `plugins/offline-research/templates/refactor-probe/expansion-loop.md`
- Create: `plugins/offline-research/templates/refactor-probe/scoring-rubric-template.md`

- [ ] **Step 1: Create prompt.md**

Copy from source `/Users/kevinye/Development/offline-research/templates/refactor-probe/prompt.md` with these changes:

1. The workspace structure section uses `/workspace/` paths since it runs in a container. But the `[PROBE_DIR]` placeholder already handles this — the skill fills it with the correct path. No change needed.

2. Add the `Do NOT invoke any skills or use the Skill tool.` line at the top (already present in source — keep it).

Copy verbatim from source.

- [ ] **Step 2: Create progress.md**

Copy from source `/Users/kevinye/Development/offline-research/templates/refactor-probe/progress.md` verbatim.

- [ ] **Step 3: Create expansion-loop.md**

Copy from source `/Users/kevinye/Development/offline-research/templates/refactor-probe/expansion-loop.md` verbatim. The `[PROBE_DIR]` and `[DIMENSION_HINTS]` placeholders are filled by the skill.

- [ ] **Step 4: Create scoring-rubric-template.md**

Copy from source `/Users/kevinye/Development/offline-research/templates/refactor-probe/scoring-rubric-template.md` verbatim.

- [ ] **Step 5: Commit**

```bash
git add -f plugins/offline-research/templates/refactor-probe/
git commit -m "feat(offline-research): add refactor-probe template files"
```

---

## Task 8: Update sibling skills' run commands

**Files:**
- Modify: `plugins/offline-research/skills/research-probe/SKILL.md:112-138`
- Modify: `plugins/offline-research/skills/arch-forge/SKILL.md:124-150`

- [ ] **Step 1: Update research-probe SKILL.md**

In `plugins/offline-research/skills/research-probe/SKILL.md`, update the three run options:

Replace:
```
- **Auto-resume command** (option 1):
  ```
  ./containers/offline-research/launch.sh run <host-path> <TOPIC_COUNT * 8 + 10>
  ```
```

With:
```
- **Auto-resume command** (option 1):
  ```
  ./containers/workshop/launch.sh run --container=research <host-path> <TOPIC_COUNT * 8 + 10>
  ```
```

Also update the option text from "In the offline research container" to "In the workshop container (research profile)".

- [ ] **Step 2: Update arch-forge SKILL.md**

In `plugins/offline-research/skills/arch-forge/SKILL.md`, update the three run options:

Replace:
```
- **Auto-resume command** (option 1):
  ```
  ./containers/arch-tool/launch.sh run <host-path> <DECISION_COUNT * 10 + 15>
  ```
```

With:
```
- **Auto-resume command** (option 1):
  ```
  ./containers/workshop/launch.sh run --container=arch <host-path> <DECISION_COUNT * 10 + 15>
  ```
```

Also update the option text from "In the arch-tool container" to "In the workshop container (arch profile)".

- [ ] **Step 3: Commit**

```bash
git add -f plugins/offline-research/skills/research-probe/SKILL.md plugins/offline-research/skills/arch-forge/SKILL.md
git commit -m "fix(offline-research): update skill run commands to use workshop container"
```

---

## Task 9: Remove old container directories

**Files:**
- Delete: `containers/offline-research/` (entire directory)
- Delete: `containers/arch-tool/` (entire directory)

- [ ] **Step 1: Remove old directories**

```bash
git rm -r containers/offline-research/ containers/arch-tool/
```

- [ ] **Step 2: Verify no dangling references**

```bash
grep -r 'containers/offline-research\|containers/arch-tool' plugins/ containers/ --include='*.md' --include='*.sh' --include='*.json'
```

Expected: no matches. If any found, fix them before committing.

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: remove old container directories (migrated to workshop)"
```

---

## Task 10: Update manifests, README, and CHANGELOG

**Files:**
- Modify: `plugins/offline-research/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugins/offline-research/README.md`
- Modify: `plugins/offline-research/CHANGELOG.md`

- [ ] **Step 1: Bump plugin.json version**

In `plugins/offline-research/.claude-plugin/plugin.json`, change:
```json
"version": "2.3.2"
```
to:
```json
"version": "2.4.0"
```

Also update the description:
```json
"description": "Tools for structured offline research, architecture exploration, and codebase refactoring"
```

- [ ] **Step 2: Bump marketplace.json version**

In `.claude-plugin/marketplace.json`, update the offline-research entry:
```json
"version": "2.4.0"
```
and:
```json
"description": "Tools for structured offline research, architecture exploration, and codebase refactoring"
```

- [ ] **Step 3: Update README.md**

In `plugins/offline-research/README.md`:

1. Update version from `2.3.2` to `2.4.0`
2. Add a `/refactor-probe` section after the `/arch-forge` section:

```markdown
---

### /refactor-probe

Explores codebase tech debt and refactoring ideas through collaborative rubric co-design and autonomous loop exploration with PoC building.

**Trigger:** `/refactor-probe`, "refactor-probe this codebase", "launch a refactor probe"

**Flow:**

1. Dump your refactoring idea (freeform text)
2. Skill scans the codebase and surveys the landscape
3. Critical assessment with real code references, then guided refinement
4. Rubric co-design — you define 3-7 custom scoring dimensions with expansion hint tags
5. Generates 4 seed files (`prompt.md`, `progress.md`, `expansion-loop.md`, `scoring-rubric.md`) to your chosen directory
6. Gives you the run command for the workshop container

**How it differs from siblings:**

- User-designed custom rubric (3-7 dimensions with custom anchors)
- Dimension hint tags drive expansion: BUILD, INVESTIGATE, RETHINK, REFOCUS
- Codebase-aware — scans real code during intake and grounds suggestions in actual patterns
- PoCs replicate the real problem at small scale in isolated sketch projects

**Max iterations:** `topics * 10 + 15`
```

3. Update the Containers table:

```markdown
## Containers

All skills share the unified workshop container:

| Skill | Profile | Purpose |
|-------|---------|---------|
| /research-probe | `--container=research` | Web research and analysis |
| /arch-forge | `--container=arch` | Architecture exploration with PoC sandbox |
| /refactor-probe | `--container=refactor` | Codebase refactoring with PoC sandbox |

See [containers/workshop/](../../containers/workshop/) for setup and configuration.
```

- [ ] **Step 4: Update CHANGELOG.md**

Add at the top of the changelog, after the `# Changelog` header:

```markdown
## 2.4.0

### Added

- `/refactor-probe` skill with rubric co-design, dimension-aware expansion, and PoC building
- Refactor-probe templates (prompt, progress, expansion-loop, scoring-rubric-template)
- Unified `containers/workshop/` with per-profile Dockerfiles (`--container=research|arch|refactor`)

### Changed

- Consolidated `containers/offline-research/` and `containers/arch-tool/` into `containers/workshop/`
- `launch.sh` now requires `--container` flag to select profile
- Renamed `run-arch.sh` to `run-arch-forge.sh`
- Updated research-probe and arch-forge run commands to use workshop container

### Fixed

- Subagent rate-limit detection — all runners now use broad regex patterns to catch `429`, `too many requests`, `quota exceeded`, etc. (backported from source refactor-probe runner)
```

- [ ] **Step 5: Commit**

```bash
git add -f plugins/offline-research/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/offline-research/README.md plugins/offline-research/CHANGELOG.md
git commit -m "feat(offline-research): bump to 2.4.0 — add refactor-probe, workshop container"
```

---

## Task 11: Verify everything works together

- [ ] **Step 1: Verify file structure**

```bash
find containers/workshop/ -type f | sort
find plugins/offline-research/ -type f | sort
```

Expected workshop structure:
```
containers/workshop/.env.example
containers/workshop/dockerfiles/arch.Dockerfile
containers/workshop/dockerfiles/refactor.Dockerfile
containers/workshop/dockerfiles/research.Dockerfile
containers/workshop/entrypoint-light.sh
containers/workshop/entrypoint.sh
containers/workshop/launch.sh
containers/workshop/run-arch-forge.sh
containers/workshop/run-refactor.sh
containers/workshop/run-research.sh
```

Expected plugin structure includes:
```
plugins/offline-research/skills/refactor-probe/SKILL.md
plugins/offline-research/templates/refactor-probe/expansion-loop.md
plugins/offline-research/templates/refactor-probe/progress.md
plugins/offline-research/templates/refactor-probe/prompt.md
plugins/offline-research/templates/refactor-probe/scoring-rubric-template.md
```

- [ ] **Step 2: Verify old directories are gone**

```bash
ls containers/offline-research/ 2>&1 || echo "GOOD: offline-research removed"
ls containers/arch-tool/ 2>&1 || echo "GOOD: arch-tool removed"
```

- [ ] **Step 3: Verify no dangling references**

```bash
grep -rn 'containers/offline-research\|containers/arch-tool\|run-arch\.sh\b' plugins/ containers/ .claude-plugin/ --include='*.md' --include='*.sh' --include='*.json' || echo "GOOD: no dangling references"
```

- [ ] **Step 4: Verify version sync**

```bash
grep '"version"' plugins/offline-research/.claude-plugin/plugin.json .claude-plugin/marketplace.json
```

Both should show `"2.4.0"`.

- [ ] **Step 5: Verify rate-limit fix in all runners**

```bash
grep -l 'too many requests' containers/workshop/run-*.sh
```

Expected: all three runner files listed.

- [ ] **Step 6: Verify launch.sh is executable and parses --container**

```bash
containers/workshop/launch.sh help
containers/workshop/launch.sh run 2>&1 | head -1
```

Expected: help shows all three profiles; run without `--container` shows error.
