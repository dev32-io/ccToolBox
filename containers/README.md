# Containers

Docker-based sandbox running interactive Claude Code or OpenCode for PoC validation during workshop-loop research runs.

> v3.0.0: the host-side `run` subcommand was retired (host `claude -p` is moving to a separate billing pool on 2026-06-15). The container now serves only as an optional sandbox for `/workshop-loop` runs that need to execute generated PoC code against an isolated environment. Day-to-day use of the offline-research plugin no longer requires Docker — `/workshop-loop` runs in your normal interactive Claude Code session.

## Workshop

Per-profile Dockerfiles, selected via `--container`. Agent selection via `--agent` (defaults to `claude`).

### Profiles

| Profile | Dockerfile (Claude) | Dockerfile (OpenCode) | Used by | Description |
|---------|---------------------|----------------------|---------|-------------|
| `research` | `research-claude.Dockerfile` | `research-opencode.Dockerfile` | `/research-probe` | Lightweight — web research and analysis |
| `arch` | `arch-claude.Dockerfile` | `arch-opencode.Dockerfile` | `/arch-forge` | Heavy — architecture exploration with PoC sandbox |
| `refactor` | `refactor-claude.Dockerfile` | `refactor-opencode.Dockerfile` | `/refactor-probe` | Heavy — codebase refactoring with PoC sandbox |

### Usage

```bash
# First run (Claude): build image, create container, drop into shell for claude login
./containers/workshop/launch.sh setup --container=research

# First run (OpenCode): build image, create container, drop into shell for opencode login
export OPENCODE_AUTH_DIR="$HOME/.config/opencode"
./containers/workshop/launch.sh setup --container=research --agent=opencode

# Build the image without entering a shell
./containers/workshop/launch.sh build --container=research

# Drop into an interactive container shell (probe-dir mounts at /workspace)
./containers/workshop/launch.sh shell --container=research /path/to/probe-dir
# inside container:
claude
# in Claude Code:
/workshop-loop /workspace
```

Replace `research` with `arch` or `refactor` as needed. Add `--agent=opencode` to use OpenCode instead of Claude.

When `shell` is used with a probe-dir, the container starts with `WORKSHOP_CONTAINER=1` exported, which `poc-builder` reads to decide whether code execution is allowed (SANDBOXED mode vs HOST mode).

### First run

**Claude Code:**
1. `launch.sh setup --container=<profile>` builds the image and creates the container.
2. Inside the container, run `claude login` to authenticate.

**OpenCode:**
1. Set `OPENCODE_AUTH_DIR` environment variable pointing to your OpenCode config directory.
2. `launch.sh setup --container=<profile> --agent=opencode` builds the image and creates the container.
3. Inside the container, run `opencode login` or configure API keys via environment variables.

### Research profile

- **Base image:** node:20-slim
- **Tools:** git, curl, jq, python3, ripgrep, build-essential, tree, sqlite3, gh, Claude Code
- **No resource limits** — lightweight research workload

### Arch and Refactor profiles

Both use a heavier image with PoC capabilities:

- **Additional tools:** Bun, Rust toolchain, Go, TypeScript/tsx/pnpm, Chromium + Playwright, cmake, pkg-config, libssl-dev, protobuf-compiler, networking tools, redis-tools
- **Resource limits:** `--memory=4g --cpus=4 --pids-limit=200`

#### Security: poc user sandbox

A sandboxed `poc` user handles all PoC code execution:

- Claude runs as `node`, delegates to `poc` via `sudo -u poc`.
- The `poc` user cannot escalate back to `node`.
- All PoC code must be written and executed as the `poc` user.
- `/workspace/poc/` is owned by `poc` — Claude cannot write there directly.

---

## Agent Selection

The workshop supports two AI agents:

| Flag | Agent | Auth Environment Variable |
|------|-------|--------------------------|
| (default) or `--agent=claude` | Claude Code | `CLAUDE_CODE_RESEARCH_TOOL` |
| `--agent=opencode` | OpenCode | `OPENCODE_AUTH_DIR` |

### Setting up agents

**Claude Code:**
```bash
export CLAUDE_CODE_RESEARCH_TOOL="$HOME/.claude"
```

**OpenCode:**
```bash
export OPENCODE_AUTH_DIR="$HOME/.config/opencode"
```

---

## Configuration

Workshop supports a `.env` file in `containers/workshop/`.

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/Vancouver` | Container timezone |
| `CONTAINER_NAME` | `workshop-<profile>-sandbox` | Docker container name (auto-set per profile) |
| `CLAUDE_CODE_RESEARCH_TOOL` | (required for Claude) | Path to Claude Code config home |
| `OPENCODE_AUTH_DIR` | (required for OpenCode) | Path to OpenCode auth/config directory |

## Common notes

- Named Docker containers persist between sessions — auth survives restarts.
- Fresh start: `docker rm <container-name>` then relaunch.
- `WORKSHOP_CONTAINER=1` is set automatically when you use `launch.sh shell`; `poc-builder` reads this to unlock full Bash execution.
