#!/bin/bash
# Test: template files have expected placeholders and no stale ones
set -euo pipefail

TEMPLATES="$(cd "$(dirname "$0")/../../.." && pwd)/plugins/offline-research/templates"

# prompt.md should have [TOPIC] and [TOPICS]
grep -q '\[TOPIC\]' "$TEMPLATES/prompt.md" || { echo "FAIL: prompt.md missing [TOPIC]"; exit 1; }
grep -q '\[TOPICS\]' "$TEMPLATES/prompt.md" || { echo "FAIL: prompt.md missing [TOPICS]"; exit 1; }

# progress.md should have all 3 placeholders
grep -q '\[TOPIC_SCOREBOARD\]' "$TEMPLATES/progress.md" || { echo "FAIL: progress.md missing [TOPIC_SCOREBOARD]"; exit 1; }
grep -q '\[TOPIC_RESEARCH\]' "$TEMPLATES/progress.md" || { echo "FAIL: progress.md missing [TOPIC_RESEARCH]"; exit 1; }
grep -q '\[TOPIC_CRITIQUE\]' "$TEMPLATES/progress.md" || { echo "FAIL: progress.md missing [TOPIC_CRITIQUE]"; exit 1; }

# critique-loop.md should NOT have any placeholders
! grep -q '\[TOPIC' "$TEMPLATES/critique-loop.md" || { echo "FAIL: critique-loop.md should not have placeholders"; exit 1; }

# scoring-rubric.md should NOT have any placeholders
! grep -q '\[TOPIC' "$TEMPLATES/scoring-rubric.md" || { echo "FAIL: scoring-rubric.md should not have placeholders"; exit 1; }

# No stale v1 placeholders anywhere
! grep -q '\[TOPIC_CHECKLIST\]' "$TEMPLATES/progress.md" || { echo "FAIL: progress.md has stale [TOPIC_CHECKLIST]"; exit 1; }
! grep -q 'ALL PHASES COMPLETE' "$TEMPLATES/prompt.md" || { echo "FAIL: prompt.md has stale ALL PHASES COMPLETE"; exit 1; }
