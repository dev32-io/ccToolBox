# Offline Research Container

Sandboxed Claude Code environment for web research and GitHub exploration. No sensitive host data is mounted — only settings for quality of life.

## Build

```bash
docker build -t offline-research containers/offline-research/
```

## Run

```bash
./containers/offline-research/launch.sh [workspace_dir]
```

Defaults to `~/research` as workspace. The launcher creates a persistent named container (`research-sandbox`) — auth and installed plugins survive between sessions.

## First Run

1. `claude login` (one-time)
2. Install plugins you need (e.g. ralph-loop)
3. Use Claude normally with `--dangerously-skip-permissions`

## Resume

```bash
./containers/offline-research/launch.sh
```

Resumes the existing container — no re-login or plugin install needed.

## Fresh Start

```bash
docker rm research-sandbox
./containers/offline-research/launch.sh
```

## Notes

- Auth and plugins persist inside the named container
- `/workspace` is mounted to your host (`~/research` by default)
- Nothing from host `~/.claude` is mounted — fully isolated
- To start fresh: `docker rm research-sandbox` then relaunch
