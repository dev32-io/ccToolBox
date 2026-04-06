# Containers

Unified Docker-based workshop running Claude Code in sandboxed environments for offline research, architecture exploration, and codebase refactoring.

## Workshop

All skills share a single `workshop/` directory with per-profile Dockerfiles and runner scripts, selected via the `--container` flag.

### Profiles

| Profile | Dockerfile | Used by | Description |
|---------|-----------|---------|-------------|
| `research` | `research.Dockerfile` | `/research-probe` | Lightweight — web research and analysis |
| `arch` | `arch.Dockerfile` | `/arch-forge` | Heavy — architecture exploration with PoC sandbox |
| `refactor` | `refactor.Dockerfile` | `/refactor-probe` | Heavy — codebase refactoring with PoC sandbox |

### Usage

```bash
# First run: build image, create container, drop into shell for claude login
./containers/workshop/launch.sh setup --container=research

# Run with auto-resume
./containers/workshop/launch.sh run --container=research <topic-path> [max-iterations]

# Open container shell
./containers/workshop/launch.sh shell --container=research
```

Replace `research` with `arch` or `refactor` as needed.

### First run

1. `launch.sh setup --container=<profile>` builds the image and creates the container
2. Inside the container, run `claude login` to authenticate
3. Install plugins you need (e.g. ralph-loop)

### Research profile

- **Base image:** node:20-slim
- **Tools:** git, curl, jq, python3, ripgrep, build-essential, tree, sqlite3, gh, Claude Code
- **No resource limits** — lightweight research workload

### Arch and Refactor profiles

Both use the same heavy Dockerfile with PoC capabilities:

- **Additional tools:** Bun, Rust toolchain, Go, TypeScript/tsx/pnpm, Chromium + Playwright, cmake, pkg-config, libssl-dev, protobuf-compiler, networking tools, redis-tools
- **Resource limits:** `--memory=4g --cpus=4 --pids-limit=200`

#### Security: poc user sandbox

A sandboxed `poc` user handles all PoC code execution:

- Claude runs as `node`, delegates to `poc` via `sudo -u poc`
- The `poc` user cannot escalate back to `node`
- All PoC code must be written and executed as the `poc` user
- `/workspace/poc/` is owned by `poc` — Claude cannot write there directly

### Runners

Each profile has its own runner script:

| Runner | Profile | Extra features |
|--------|---------|---------------|
| `run-research.sh` | research | Standard auto-resume |
| `run-arch-forge.sh` | arch | Standard auto-resume |
| `run-refactor.sh` | refactor | Permission error logging, macOS notifications |

All runners share:
- Live TUI: iteration count, elapsed time, queue progress, current/next task, output tail
- Rate limiting with broad subagent detection (`429`, `too many requests`, `quota exceeded`, etc.)
- Schedule-aware probing during research window, manual resume outside

---

## Configuration

Workshop supports a `.env` file in `containers/workshop/`.

| Variable | Default | Description |
|----------|---------|-------------|
| `RESEARCH_HOURS` | `23:00-07:00` | Active research window |
| `TZ` | `America/Vancouver` | Container timezone |
| `CONTAINER_NAME` | `workshop-<profile>-sandbox` | Docker container name (auto-set per profile) |
| `CLAUDE_CODE_RESEARCH_TOOL` | (required) | Path to Claude Code config home |

## Common notes

- Named Docker containers persist between sessions — auth survives restarts.
- Fresh start: `docker rm <container-name>` then relaunch.
