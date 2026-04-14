#!/bin/bash
# If called with a non-opencode command (e.g., "tail -f /dev/null" for keep-alive),
# pass through directly. Otherwise, run OpenCode.
if [[ "${1:-}" == "tail" || "${1:-}" == "bash" || "${1:-}" == "sh" ]]; then
    exec "$@"
else
    exec opencode "$@"
fi
