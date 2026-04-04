# Containers

Two Docker-based containers running Claude Code in sandboxed environments for offline research tasks.

## offline-research

Sandboxed Claude Code environment for web research and GitHub exploration.

- **Base image:** node:20-slim
- **Included tools:** git, curl, jq, python3, ripgrep, build-essential, tree, sqlite3, gh (GitHub CLI), Claude Code
- **Used by:** `/research-probe` skill from the [offline-research](../plugins/offline-research/README.md) plugin

### Usage

```bash
# First run: build image, create container, drop into shell for claude login
./containers/offline-research/launch.sh setup

# Run research loop with auto-resume
./containers/offline-research/launch.sh run <topic-path> [max-iterations]

# Open container shell
./containers/offline-research/launch.sh shell
```

### First run

1. `launch.sh setup` builds the image and creates the container
2. Inside the container, run `claude login` to authenticate
3. Install plugins you need (e.g. ralph-loop)

### Runner (run-research.sh)

Auto-resume loop that runs Claude Code iteratively:

- Parses `progress.md` for queue status (current task, next task, completed count)
- Handles rate limiting -- probes hourly during research window, prompts for manual resume outside
- Live TUI: iteration count, elapsed time, queue progress, current/next task, output tail

---

## arch-tool

Sandboxed Claude Code environment for architecture exploration with PoC capabilities. Everything offline-research has, plus extra tooling for building and running proof-of-concept code.

- **Base image:** node:20-slim
- **Additional tools:** Bun, Rust toolchain, Go, TypeScript/tsx/pnpm, Chromium + Playwright, cmake, pkg-config, libssl-dev, protobuf-compiler, networking tools (net-tools, dnsutils, iputils-ping), redis-tools
- **Used by:** `/arch-forge` skill from the [offline-research](../plugins/offline-research/README.md) plugin

### Security: poc user sandbox

A sandboxed `poc` user handles all PoC code execution:

- Claude runs as `node`, delegates to `poc` via `sudo -u poc`
- The `poc` user cannot escalate back to `node`
- All PoC code must be written and executed as the `poc` user
- `/workspace/poc/` is owned by `poc` -- Claude cannot write there directly

### Usage

```bash
# First run: build image, create container, login
./containers/arch-tool/launch.sh setup

# Run architecture exploration loop with auto-resume
./containers/arch-tool/launch.sh run <topic-path> [max-iterations]

# Open container shell
./containers/arch-tool/launch.sh shell
```

### Runner (run-arch.sh)

Same auto-resume loop as the research runner, adapted for architecture exploration. Same TUI, rate limiting, and schedule awareness.

---

## Configuration

Both containers support `.env` files in their respective directories.

| Variable | Default | Description |
|----------|---------|-------------|
| `RESEARCH_HOURS` | `23:00-07:00` | Active research window |
| `TZ` | `America/Vancouver` | Container timezone |
| `CONTAINER_NAME` | `research-sandbox` / `arch-sandbox` | Docker container name |
| `CLAUDE_CODE_RESEARCH_TOOL` | (required) | Path to Claude Code config home |

## Common notes

- Both containers use named Docker containers that persist between sessions -- auth survives restarts.
- Both runners show a live TUI with iteration count, elapsed time, queue progress, and output tail.
- Rate limiting: probes hourly during research window, prompts for manual resume outside.
- Fresh start: `docker rm <container-name>` then relaunch.
