#!/bin/bash
# If called with a non-claude command (e.g., "tail -f /dev/null" for keep-alive),
# pass through directly. Otherwise, run Claude Code.
if [[ "${1:-}" == "tail" || "${1:-}" == "bash" || "${1:-}" == "sh" ]]; then
    exec "$@"
else
    exec claude --dangerously-skip-permissions "$@"
fi
