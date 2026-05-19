# ccToolBox

A personal Claude Code plugin marketplace.

## Pairs with agentic-dev-harness

[`agentic-dev-harness`](https://github.com/dev32-io/agentic-dev-harness) provides the rules, hooks, and scripts substrate the skills here consume. Install both together:

```sh
sh agentic-dev-harness/install.sh --target . --platforms web,bun
claude plugins install dev32-io/ccToolBox/devTools
```

`frustration-check` (under `devTools`) is highlighted there as the headline skill — the rarest piece in the public AI-tooling market for maximizing AI-as-collaborator.

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
| [daily-briefing](plugins/daily-briefing/README.md) | 2.3.2 | Vintage broadsheet daily briefing with 12 sources, TTS audio, and dark/light mode |
| [offline-research](plugins/offline-research/README.md) | 2.4.2 | Structured offline research and architecture exploration via container-based loops |
| [devTools](plugins/devTools/README.md) | 1.4.1 | Developer productivity skills: branch retros, testing-knowledge recall, and frustration-check intervention |

## Containers

Sandboxed Docker environments for running offline research and architecture exploration. See [containers/README.md](containers/README.md).

## Adding Plugins

See [CLAUDE.md](CLAUDE.md) for the plugin directory template and conventions.

## License

MIT
