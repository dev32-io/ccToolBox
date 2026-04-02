# Research Tool Container

Sandboxed Claude Code environment for web research and GitHub exploration. No sensitive host data is mounted — only settings for quality of life.

## Build

```bash
docker build -t claude-research containers/research-tool/
```

## Run

```bash
docker run --rm -it \
  -v ~/research:/workspace \
  -v ~/.claude/settings.json:/home/node/.claude/settings.json:ro \
  -v ~/.claude/settings.local.json:/home/node/.claude/settings.local.json:ro \
  -v ~/.claude/themes:/home/node/.claude/themes:ro \
  -v ~/.claude/scripts:/home/node/.claude/scripts:ro \
  -v ~/.claude/plugins:/home/node/.claude/plugins:ro \
  claude-research
```

## Inside the container

```bash
claude login
claude --dangerously-skip-permissions
```

## Notes

- Container is ephemeral (`--rm`) — nothing persists except `/workspace` (mounted to `~/research`)
- Auth is session-scoped — you must `claude login` each time
- Host `~/.claude` memories, history, and project config are never mounted
- Adjust the mount list as needed — the five mounts above cover settings, themes, scripts, and plugins
