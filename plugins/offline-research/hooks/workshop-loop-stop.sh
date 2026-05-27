#!/bin/bash
# workshop-loop-stop.sh — Stop hook for the offline-research workshop-loop.
# Reads transcript for [workshop-loop-active|done] markers, derives loop state
# from <probe-dir>/progress.md, and either releases (exit 0) or blocks
# (emits {"decision":"block","reason":...} JSON to stdout).

set -uo pipefail

HOOK_INPUT=$(cat)
TRANSCRIPT=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
[[ -f "$TRANSCRIPT" ]] || exit 0

# Find most recent marker (active or done) in assistant text blocks
LAST_MARKER=$(grep '"role":"assistant"' "$TRANSCRIPT" 2>/dev/null | tail -n 200 | \
  jq -rs 'map(.message.content[]? | select(.type=="text") | .text) | join("\n")' 2>/dev/null | \
  grep -oE '\[workshop-loop-(active|done)\] probe_dir=\S+' | tail -n 1)

[[ -z "$LAST_MARKER" ]] && exit 0
# Done marker most recent → post-run chat → fast release
echo "$LAST_MARKER" | grep -q 'workshop-loop-done' && exit 0

# Active marker — extract probe_dir
PROBE_DIR=$(echo "$LAST_MARKER" | sed 's/.*probe_dir=//')
PROGRESS="$PROBE_DIR/progress.md"
[[ -f "$PROGRESS" ]] || exit 0   # probe-dir vanished or never set up

# Derive state from progress.md
MAX_ITER=$(grep -m1 '^max_iter:' "$PROGRESS" | sed 's/max_iter: *//' | tr -d '[:space:]')
[[ -z "$MAX_ITER" ]] && MAX_ITER=999
ITER=$(grep -c '^- \[x\]' "$PROGRESS" 2>/dev/null || true); ITER=${ITER:-0}
PENDING=$(grep -c '^- \[ \]' "$PROGRESS" 2>/dev/null || true); PENDING=${PENDING:-0}
ACTIVE_ROWS=$(grep -c '| ACTIVE |' "$PROGRESS" 2>/dev/null || true); ACTIVE_ROWS=${ACTIVE_ROWS:-0}

# Last assistant text for promise check
LAST_TEXT=$(grep '"role":"assistant"' "$TRANSCRIPT" 2>/dev/null | tail -n 50 | \
  jq -rs 'map(.message.content[]? | select(.type=="text") | .text) | last // ""' 2>/dev/null || echo "")
PROMISE=$(echo "$LAST_TEXT" | perl -0777 -ne 'print $1 if /<promise>\s*(RUN COMPLETE)\s*<\/promise>/s' 2>/dev/null || echo "")

# Termination tests (any one releases)
if [[ "$PROMISE" == "RUN COMPLETE" ]]; then
    echo "✅ workshop-loop: RUN COMPLETE (iter $ITER)" >&2
    exit 0
fi
if [[ $PENDING -eq 0 && $ACTIVE_ROWS -eq 0 ]]; then
    echo "✅ workshop-loop: all CONCLUDED, queue empty (iter $ITER)" >&2
    exit 0
fi
if [[ $ITER -ge $MAX_ITER ]]; then
    echo "🛑 workshop-loop: max_iter $MAX_ITER reached" >&2
    exit 0
fi

# Continue — re-feed minimal pointer
REFEED="Read $PROBE_DIR/progress.md. Find the first unchecked task. Dispatch the matching agent per the dispatch table in the workshop-loop command body. After the agent returns, Edit the task line in progress.md from \`[ ]\` to \`[x]\`. If the task was Score: or Critique & Score:, also dispatch expansion-planner with the scorer's return. Then stop."

jq -n --arg p "$REFEED" --arg msg "workshop-loop iter $ITER/$MAX_ITER ($PENDING pending, $ACTIVE_ROWS active)" \
  '{decision:"block", reason:$p, systemMessage:$msg}'

exit 0
