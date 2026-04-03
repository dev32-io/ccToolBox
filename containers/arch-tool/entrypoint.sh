#!/bin/bash
# Lock down .claude/ so only the node user (Claude Code) can read it.
# The poc user used for PoC code execution cannot access auth tokens.
chmod 700 /home/node/.claude 2>/dev/null || true
exec claude --dangerously-skip-permissions "$@"
