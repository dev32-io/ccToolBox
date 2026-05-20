# Research Runner — Schedule-Aware Auto-Resume

## Overview

A host-side bash script that `docker exec`s into the research container for each iteration, showing the full Claude Code TUI. Handles rate limits with schedule-aware auto-resume: retries automatically during allowed hours, prompts for manual "continue" outside them.

## How It Works

The script runs on the host (not inside the container). Each iteration:
1. `docker exec -it` into the container, runs Claude with the research prompt
2. User sees the full Claude Code TUI (statusline, streaming output, everything)
3. When Claude finishes, the script checks: done? rate-limited? normal iteration?
4. Loops accordingly

### Rate Limit Handling

```
Rate limit detected
  ↓
Inside RESEARCH_HOURS?
├── Yes → sleep 1hr, probe "say hi", if OK → resume, else sleep again
└── No → print status, wait for user to type "continue"
```

**Probe:** `docker exec claude -p "say hi" --output-format json --max-turns 1`. If it responds without rate-limiting, the limit has reset. Fixed 1-hour interval.

## Config

`.env` file in the container directory (git-ignored), with `.env.example` committed:

```bash
RESEARCH_HOURS="23:00-07:00"
TZ="America/Vancouver"
CONTAINER_NAME="research-sandbox"
```

Defaults baked in the script — `.env` only needed for overrides.

## Script Structure

`containers/offline-research/run-research.sh`:

```
main()              — arg parsing, load .env, run loop
run_iteration()     — docker exec claude with prompt, capture exit
check_completed()   — grep for <promise>TASK DONE</promise>
check_rate_limit()  — detect rate limit from exit code/output
probe_limit()       — cheap "say hi" to test if limit reset
in_schedule()       — check if current time is within RESEARCH_HOURS
wait_for_reset()    — 1hr probe loop (in-window) or prompt user (out-of-window)
print_status()      — current iteration, workspace path, waiting state
```

## launch.sh Subcommands

Updated `containers/offline-research/launch.sh`:

- `./launch.sh setup` — create persistent named container, drop into bash for login
- `./launch.sh run <workspace-path> [max-iterations]` — start the research runner
- `./launch.sh shell` — attach to container for manual work

`setup` creates the container with:
- Volume mount: `~/offline-research:/workspace`
- Mounted `.claude` dir for auth persistence
- `TZ` env var from `.env` or default
- Named container (not `--rm`)

`run` invokes `run-research.sh` with the workspace path and max-iterations.

`shell` is just `docker exec -it $CONTAINER_NAME bash`.

## Dockerfile Changes

Add timezone default:
```dockerfile
ENV TZ=America/Vancouver
```

Pass through from docker run: `-e TZ="${TZ:-America/Vancouver}"`.

## Research-Probe Skill Update

Update SKILL.md to present three run options:

> **How do you want to run this research?**
> 1. In the offline research container with auto-resume (Recommended)
> 2. In the offline research container (manual)
> 3. Locally

**Option 1** outputs:
```
./containers/offline-research/run-research.sh /workspace/<folder-name> <TOPIC_COUNT * 8 + 10>
```

**Option 2** outputs the existing ralph-loop command for manual container use.

**Option 3** stays the same (local ralph-loop).

## Files Changed

1. **`containers/offline-research/run-research.sh`** — NEW. Host-side runner script with schedule-aware auto-resume.
2. **`containers/offline-research/.env.example`** — NEW. Default config values.
3. **`containers/offline-research/launch.sh`** — Rewrite with setup/run/shell subcommands, persistent container.
4. **`containers/offline-research/Dockerfile`** — Add `ENV TZ=America/Vancouver`.
5. **`plugins/offline-research/skills/research-probe/SKILL.md`** — Add third run option (auto-resume script).
6. **`plugins/offline-research/.claude-plugin/plugin.json`** — Bump version +0.1.0 (2.1.0 → 2.2.0).
7. **`.claude-plugin/marketplace.json`** — Bump offline-research version to match.
