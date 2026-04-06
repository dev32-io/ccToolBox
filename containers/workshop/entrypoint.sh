#!/bin/bash
# Runs as root. Sets up security boundaries, then drops to node user.

# --- Workspace isolation: poc cannot write to /workspace ---
# Volume is mounted at runtime, so permissions must be set here.
chown node:node /workspace
chmod 755 /workspace
# Recursively restrict workspace subdirs (research files) to node-only write.
# poc can still read (needed to reference prompt.md etc).
find /workspace -mindepth 1 -maxdepth 1 ! -name poc -exec chown -R node:node {} + 2>/dev/null || true
find /workspace -mindepth 1 -maxdepth 1 ! -name poc -exec chmod -R o-w {} + 2>/dev/null || true

# --- PoC sandbox: /workspace/poc/ owned by poc, node cannot write ---
# Forces Claude Code to use "sudo -u poc" for all PoC operations.
# node can still read results (755), but cannot write or bypass the sandbox.
mkdir -p /workspace/poc
chown poc:poc /workspace/poc
chmod 755 /workspace/poc

# --- Auth isolation: restrict ~/.claude from poc user ---
# .claude is mounted directly; restrict permissions so poc cannot read credentials.
chmod 700 /home/node/.claude

# If called with a non-claude command (e.g., "tail -f /dev/null" for keep-alive),
# pass through directly. Otherwise, run Claude Code.
if [[ "${1:-}" == "tail" || "${1:-}" == "bash" || "${1:-}" == "sh" ]]; then
    exec gosu node "$@"
else
    exec gosu node claude --dangerously-skip-permissions "$@"
fi
