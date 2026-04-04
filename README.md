# ccToolBox

A personal Claude Code plugin marketplace.

## Setup

### 1. Add the marketplace

```bash
claude plugins marketplace add github:dev32-io/ccToolBox
```

This registers ccToolBox as a plugin source. You only need to do this once per machine.

### 2. Install a plugin

```bash
claude plugins install daily-briefing@ccToolBox
```

### 3. Verify

```bash
claude plugins list
```

### Updating

```bash
claude plugins marketplace update ccToolBox
claude plugins update daily-briefing@ccToolBox
```

### Uninstalling

```bash
# Remove a plugin
claude plugins uninstall daily-briefing@ccToolBox

# Remove the marketplace entirely
claude plugins marketplace remove ccToolBox
```

## Available Plugins

| Plugin | Version | Description |
|--------|---------|-------------|
| [daily-briefing](plugins/daily-briefing/README.md) | 1.5.1 | Vintage broadsheet daily briefing with 12 sources, TTS audio, and dark/light mode |
| [offline-research](plugins/offline-research/README.md) | 2.3.2 | Structured offline research and architecture exploration via container-based loops |

## Containers

Sandboxed Docker environments for running offline research and architecture exploration. See [containers/README.md](containers/README.md).

## Adding Plugins

See [CLAUDE.md](CLAUDE.md) for the plugin directory template and conventions.

## License

MIT
