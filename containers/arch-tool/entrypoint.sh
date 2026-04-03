#!/bin/bash
# Symlink ~/.claude to the mounted .private/.claude so Claude Code finds its config.
# .private/ is 700 owned by node (set in Dockerfile), so the poc user cannot traverse
# it and therefore cannot follow this symlink to read auth tokens.
ln -sf /home/node/.private/.claude /home/node/.claude
ln -sf /home/node/.private/.claude.json /home/node/.claude.json
exec claude --dangerously-skip-permissions "$@"
