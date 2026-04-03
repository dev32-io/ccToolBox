#!/bin/bash
# Test: arch-forge template files have expected placeholders and no stale ones
set -euo pipefail

TEMPLATES="$(cd "$(dirname "$0")/../../.." && pwd)/plugins/offline-research/templates/arch-forge"

# prompt.md should have all project placeholders
grep -q '\[PROJECT_NAME\]' "$TEMPLATES/prompt.md" || { echo "FAIL: prompt.md missing [PROJECT_NAME]"; exit 1; }
grep -q '\[PROJECT_INTENT\]' "$TEMPLATES/prompt.md" || { echo "FAIL: prompt.md missing [PROJECT_INTENT]"; exit 1; }
grep -q '\[CONSTRAINTS\]' "$TEMPLATES/prompt.md" || { echo "FAIL: prompt.md missing [CONSTRAINTS]"; exit 1; }
grep -q '\[ARCHITECTURE_SKETCH\]' "$TEMPLATES/prompt.md" || { echo "FAIL: prompt.md missing [ARCHITECTURE_SKETCH]"; exit 1; }
grep -q '\[DECISIONS\]' "$TEMPLATES/prompt.md" || { echo "FAIL: prompt.md missing [DECISIONS]"; exit 1; }

# progress.md should have all 3 decision placeholders
grep -q '\[DECISION_SCOREBOARD\]' "$TEMPLATES/progress.md" || { echo "FAIL: progress.md missing [DECISION_SCOREBOARD]"; exit 1; }
grep -q '\[DECISION_EXPLORATION\]' "$TEMPLATES/progress.md" || { echo "FAIL: progress.md missing [DECISION_EXPLORATION]"; exit 1; }
grep -q '\[DECISION_SCORING\]' "$TEMPLATES/progress.md" || { echo "FAIL: progress.md missing [DECISION_SCORING]"; exit 1; }

# expansion-loop.md should NOT have any [DECISION or [PROJECT placeholders
! grep -q '\[DECISION' "$TEMPLATES/expansion-loop.md" || { echo "FAIL: expansion-loop.md should not have [DECISION placeholders"; exit 1; }
! grep -q '\[PROJECT' "$TEMPLATES/expansion-loop.md" || { echo "FAIL: expansion-loop.md should not have [PROJECT placeholders"; exit 1; }

# scoring-rubric.md should NOT have any [DECISION or [PROJECT placeholders
! grep -q '\[DECISION' "$TEMPLATES/scoring-rubric.md" || { echo "FAIL: scoring-rubric.md should not have [DECISION placeholders"; exit 1; }
! grep -q '\[PROJECT' "$TEMPLATES/scoring-rubric.md" || { echo "FAIL: scoring-rubric.md should not have [PROJECT placeholders"; exit 1; }
