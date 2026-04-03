#!/bin/bash
# Runs as root. Sets up security boundaries, then drops to node user.

# --- PoC sandbox: /workspace/poc/ owned by poc, node cannot write ---
# Forces Claude Code to use "sudo -u poc" for all PoC operations.
# node can still read results (755), but cannot write or bypass the sandbox.
mkdir -p /workspace/poc
chown poc:poc /workspace/poc
chmod 755 /workspace/poc

# --- Auth isolation: symlink ~/.claude through .private/ ---
# .private/ is 700 owned by node (set in Dockerfile).
# poc user cannot traverse .private/, so following this symlink fails.
ln -sf /home/node/.private/.claude /home/node/.claude
ln -sf /home/node/.private/.claude.json /home/node/.claude.json
chown -h node:node /home/node/.claude /home/node/.claude.json

# Drop to node user and start Claude Code
exec gosu node claude --dangerously-skip-permissions "$@"
