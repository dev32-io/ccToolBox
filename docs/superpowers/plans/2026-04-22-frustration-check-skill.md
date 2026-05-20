# frustration-check Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new `frustration-check` skill under the `devTools` plugin that auto-detects user drift/frustration via a `UserPromptSubmit` hook and runs a consent-gated recall + knowledge-gap workflow.

**Architecture:** A Python hook script (`detect_frustration.py`) runs on every user prompt, scores the prompt against tiered regex patterns, tracks per-session state with decay, and emits an activation signal to stdout when thresholds are met. A separate `SKILL.md` defines the intervention workflow that Claude auto-invokes when it sees the signal. Supporting modules (`patterns.py`, `scoring.py`, `state.py`) are split for testability.

**Tech Stack:** Python 3 (stdlib only), bash integration tests using the existing `plugins/devTools/tests/lib/assert.sh` helper, Claude Code plugin hook mechanism via `hooks/hooks.json`.

**Reference spec:** `docs/superpowers/specs/2026-04-22-frustration-check-skill-design.md`

---

## File Structure

Files created by this plan:

```
plugins/devTools/
├── hooks/
│   └── hooks.json                                        # NEW — plugin hook registration
├── skills/frustration-check/                             # NEW — skill root
│   ├── SKILL.md                                          # skill definition + workflows
│   ├── settings.default.json                             # versioned shipped defaults
│   └── scripts/
│       ├── patterns.py                                   # tier regex definitions
│       ├── scoring.py                                    # decay + weight + threshold
│       ├── state.py                                      # session state file I/O
│       ├── detect_frustration.py                         # hook entrypoint
│       └── init_settings.py                              # first-run/migrate/malformed handling
└── tests/
    ├── test_frustration_patterns.sh                      # NEW
    ├── test_frustration_scoring_and_decay.sh             # NEW
    ├── test_frustration_state.sh                         # NEW
    ├── test_frustration_hook_integration.sh             # NEW
    ├── test_frustration_init_settings.sh                 # NEW
    └── fixtures/frustration/                             # NEW — prompt fixtures
        ├── optimize_prompt.txt
        ├── t1_constraint_repetition.txt
        ├── t2_rage.txt
        ├── t3_contradiction.txt
        ├── t4_self_realization.txt
        └── normal_prompt.txt
```

Files modified:

- `plugins/devTools/.claude-plugin/plugin.json` — version bump 1.3.0 → 1.4.0
- `plugins/devTools/CHANGELOG.md` — new entry
- `.claude-plugin/marketplace.json` — devTools version bump

---

## Task 1: Scaffold skill directory and settings default

**Files:**
- Create: `plugins/devTools/skills/frustration-check/SKILL.md`
- Create: `plugins/devTools/skills/frustration-check/settings.default.json`
- Create: `plugins/devTools/skills/frustration-check/scripts/patterns.py` (empty module)
- Create: `plugins/devTools/skills/frustration-check/scripts/scoring.py` (empty module)
- Create: `plugins/devTools/skills/frustration-check/scripts/state.py` (empty module)
- Create: `plugins/devTools/skills/frustration-check/scripts/detect_frustration.py` (empty module)
- Create: `plugins/devTools/skills/frustration-check/scripts/init_settings.py` (empty module)

- [ ] **Step 1: Create skill directory structure**

```bash
mkdir -p plugins/devTools/skills/frustration-check/scripts
mkdir -p plugins/devTools/tests/fixtures/frustration
```

- [ ] **Step 2: Write `settings.default.json`**

File: `plugins/devTools/skills/frustration-check/settings.default.json`

```json
{
  "version": 1,
  "enabled": true,
  "threshold": 5,
  "decay": 0.5,
  "state_ttl_days": 7,
  "custom_patterns": {
    "t1": [],
    "t2": [],
    "t3": [],
    "t4": []
  }
}
```

- [ ] **Step 3: Create empty stub Python files with shebangs**

Each of `patterns.py`, `scoring.py`, `state.py`, `detect_frustration.py`, `init_settings.py` starts with:

```python
#!/usr/bin/env python3
"""TODO: module description set in later task."""
```

(The `"""TODO..."""` line is a placeholder only for the scaffold step; every later task replaces the full file content, so no TODO remains in the final tree.)

Only `detect_frustration.py` and `init_settings.py` need to be executable:

```bash
chmod +x plugins/devTools/skills/frustration-check/scripts/detect_frustration.py
chmod +x plugins/devTools/skills/frustration-check/scripts/init_settings.py
```

- [ ] **Step 4: Create empty SKILL.md placeholder**

File: `plugins/devTools/skills/frustration-check/SKILL.md`

```markdown
---
name: frustration-check
description: Placeholder - replaced in later task.
---

# frustration-check — placeholder

This file is populated in Task 7.
```

- [ ] **Step 5: Verify layout**

Run:
```bash
find plugins/devTools/skills/frustration-check -type f | sort
```

Expected output:
```
plugins/devTools/skills/frustration-check/SKILL.md
plugins/devTools/skills/frustration-check/scripts/detect_frustration.py
plugins/devTools/skills/frustration-check/scripts/init_settings.py
plugins/devTools/skills/frustration-check/scripts/patterns.py
plugins/devTools/skills/frustration-check/scripts/scoring.py
plugins/devTools/skills/frustration-check/scripts/state.py
plugins/devTools/skills/frustration-check/settings.default.json
```

- [ ] **Step 6: Commit**

```bash
git add plugins/devTools/skills/frustration-check plugins/devTools/tests/fixtures/frustration
git commit -m "devTools/frustration-check: scaffold skill directory and default settings"
```

---

## Task 2: `patterns.py` with tier regex definitions

**Files:**
- Modify: `plugins/devTools/skills/frustration-check/scripts/patterns.py`
- Create: `plugins/devTools/tests/fixtures/frustration/t1_constraint_repetition.txt`
- Create: `plugins/devTools/tests/fixtures/frustration/t2_rage.txt`
- Create: `plugins/devTools/tests/fixtures/frustration/t3_contradiction.txt`
- Create: `plugins/devTools/tests/fixtures/frustration/t4_self_realization.txt`
- Create: `plugins/devTools/tests/fixtures/frustration/optimize_prompt.txt`
- Create: `plugins/devTools/tests/fixtures/frustration/normal_prompt.txt`
- Create: `plugins/devTools/tests/test_frustration_patterns.sh`

- [ ] **Step 1: Write the failing test**

File: `plugins/devTools/tests/test_frustration_patterns.sh`

```bash
#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$here/../skills/frustration-check/scripts"
FIXTURES="$here/fixtures/frustration"
source "$here/lib/assert.sh"

# match_tiers(text) -> prints "T1:<n> T2:<n> T3:<n> T4:<bool>"
match() {
  local text="$1"
  python3 -c "
import sys
sys.path.insert(0, '$SCRIPTS')
from patterns import score_tiers
text = sys.stdin.read()
r = score_tiers(text)
print(f\"T1:{r['t1']} T2:{r['t2']} T3:{r['t3']} T4:{str(r['t4']).lower()}\")
" <<< "$text"
}

echo "== frustration_patterns =="

# T1 constraint repetition
t1_in="$(cat "$FIXTURES/t1_constraint_repetition.txt")"
out="$(match "$t1_in")"
assert_contains "$out" "T1:1" "T1 constraint-repetition prompt matches T1 once"
assert_contains "$out" "T2:0" "T1 prompt does not match T2"
assert_contains "$out" "T3:0" "T1 prompt does not match T3"

# T2 rage
t2_in="$(cat "$FIXTURES/t2_rage.txt")"
out="$(match "$t2_in")"
assert_contains "$out" "T2:1" "T2 rage prompt matches T2 once"

# T3 contradiction
t3_in="$(cat "$FIXTURES/t3_contradiction.txt")"
out="$(match "$t3_in")"
assert_contains "$out" "T3:1" "T3 contradiction prompt matches T3 once"

# T4 self-realization
t4_in="$(cat "$FIXTURES/t4_self_realization.txt")"
out="$(match "$t4_in")"
assert_contains "$out" "T4:true" "T4 self-realization prompt trips T4"

# Optimize prompt (should match nothing)
opt_in="$(cat "$FIXTURES/optimize_prompt.txt")"
out="$(match "$opt_in")"
assert_contains "$out" "T1:0" "optimize prompt does NOT match T1"
assert_contains "$out" "T2:0" "optimize prompt does NOT match T2"
assert_contains "$out" "T3:0" "optimize prompt does NOT match T3"
assert_contains "$out" "T4:false" "optimize prompt does NOT match T4"

# Normal prompt
n_in="$(cat "$FIXTURES/normal_prompt.txt")"
out="$(match "$n_in")"
assert_contains "$out" "T1:0" "normal prompt T1=0"
assert_contains "$out" "T2:0" "normal prompt T2=0"
assert_contains "$out" "T3:0" "normal prompt T3=0"
assert_contains "$out" "T4:false" "normal prompt T4=false"

# Compound prompt: T1 + T2 in same message
compound="i already told you to drop that, wtf are you doing"
out="$(match "$compound")"
assert_contains "$out" "T1:1" "compound T1+T2: T1 matches"
assert_contains "$out" "T2:1" "compound T1+T2: T2 matches"

# Isolated "ugh" (per spec: MUST NOT score)
out="$(match "ugh this is annoying")"
assert_contains "$out" "T1:0" "isolated ugh does not match T1"
assert_contains "$out" "T2:0" "isolated ugh does not match T2"
assert_contains "$out" "T3:0" "isolated ugh does not match T3"
assert_contains "$out" "T4:false" "isolated ugh does not match T4"

summary
```

Create fixtures:

File: `plugins/devTools/tests/fixtures/frustration/t1_constraint_repetition.txt`
```
i already told you to use the config-level fix, not the capability scope
```

File: `plugins/devTools/tests/fixtures/frustration/t2_rage.txt`
```
wtf are you proposing now
```

File: `plugins/devTools/tests/fixtures/frustration/t3_contradiction.txt`
```
no, stop — not that approach, why are you still trying the same thing
```

Note: this fixture intentionally hits both `no, stop` and `why are you still` patterns. Adjust the test to expect `T3:2` below.

File: `plugins/devTools/tests/fixtures/frustration/t4_self_realization.txt`
```
let's step back for a moment, maybe my UX design was wrong
```

File: `plugins/devTools/tests/fixtures/frustration/optimize_prompt.txt`
```
also defer the steward agent and creating multiple profiles — we need TTS to match pre-Hermes behavior first
```

File: `plugins/devTools/tests/fixtures/frustration/normal_prompt.txt`
```
Please add a new endpoint that returns the user's timezone based on their profile.
```

Update the T3 assertion in the test to expect 2 hits:
```bash
# Replace the T3 block with:
t3_in="$(cat "$FIXTURES/t3_contradiction.txt")"
out="$(match "$t3_in")"
assert_contains "$out" "T3:2" "T3 contradiction fixture matches T3 twice (no-stop AND why-are-you-still)"
```

Make test executable:
```bash
chmod +x plugins/devTools/tests/test_frustration_patterns.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash plugins/devTools/tests/test_frustration_patterns.sh
```

Expected: FAIL with `ImportError: cannot import name 'score_tiers'` or similar (patterns.py is empty).

- [ ] **Step 3: Implement `patterns.py`**

File: `plugins/devTools/skills/frustration-check/scripts/patterns.py`

```python
#!/usr/bin/env python3
"""Tier regex definitions for frustration detection.

score_tiers(text) returns:
  {
    "t1": <int>,   # number of T1 (constraint repetition) matches
    "t2": <int>,   # T2 (rage/profanity) matches
    "t3": <int>,   # T3 (contradiction/halt) matches
    "t4": <bool>,  # any T4 (self-realization) match
  }

User-supplied additional patterns can be merged via merge_custom().
"""
from __future__ import annotations

import re
from typing import Dict, List, Pattern


# Case-insensitive regex patterns per tier. Word boundaries where applicable.
T1_PATTERNS: List[str] = [
    r"\bi (already|just|literally) (told|said|asked|explained)\b",
    r"\bi made it clear\b",
    r"\bi never (wanted|said|asked)\b",
    r"\bhow many times\b",
    r"\b(again|still) (asking|telling|saying)\b",
]

T2_PATTERNS: List[str] = [
    r"\bwtf\b",
    r"\bwhat the fuck\b",
    r"\bfucking\b",
    r"\bomfg\b",
    r"\bgoddamn\b",
]

T3_PATTERNS: List[str] = [
    r"\bno[,.]?\s+(stop|not that|i said)\b",
    r"\bwhy are you still\b",
    r"\bstop (doing|trying)\b",
]

T4_PATTERNS: List[str] = [
    r"\blet'?s?\s+step back\b",
    r"\bi'?m having doubt\b",
    r"\bmaybe (my|i) (was )?wrong\b",
    r"\bwhy hasn'?t\b",
]


def _compile(patterns: List[str]) -> List[Pattern[str]]:
    return [re.compile(p, re.IGNORECASE) for p in patterns]


def merge_custom(tier: str, custom: List[str]) -> List[Pattern[str]]:
    """Compile base + user-supplied custom patterns for a tier."""
    tier_map = {
        "t1": T1_PATTERNS,
        "t2": T2_PATTERNS,
        "t3": T3_PATTERNS,
        "t4": T4_PATTERNS,
    }
    base = tier_map.get(tier, [])
    combined = base + list(custom or [])
    return _compile(combined)


def score_tiers(text: str, custom: Dict[str, List[str]] | None = None) -> Dict[str, object]:
    """Return tier match counts for the given text."""
    custom = custom or {}
    t1 = sum(len(p.findall(text)) for p in merge_custom("t1", custom.get("t1", [])))
    t2 = sum(len(p.findall(text)) for p in merge_custom("t2", custom.get("t2", [])))
    t3 = sum(len(p.findall(text)) for p in merge_custom("t3", custom.get("t3", [])))
    t4 = any(p.search(text) for p in merge_custom("t4", custom.get("t4", [])))
    return {"t1": t1, "t2": t2, "t3": t3, "t4": bool(t4)}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash plugins/devTools/tests/test_frustration_patterns.sh
```

Expected: all assertions PASS, `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/devTools/skills/frustration-check/scripts/patterns.py plugins/devTools/tests/test_frustration_patterns.sh plugins/devTools/tests/fixtures/frustration
git commit -m "devTools/frustration-check: tier regex patterns with tests"
```

---

## Task 3: `state.py` — session state load/save with corruption handling

**Files:**
- Modify: `plugins/devTools/skills/frustration-check/scripts/state.py`
- Create: `plugins/devTools/tests/test_frustration_state.sh`

- [ ] **Step 1: Write the failing test**

File: `plugins/devTools/tests/test_frustration_state.sh`

```bash
#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$here/../skills/frustration-check/scripts"
source "$here/lib/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Helper: call state.py via python one-liner
run_state() {
  python3 -c "
import sys
sys.path.insert(0, '$SCRIPTS')
import state
cmd = sys.argv[1]
state_dir = sys.argv[2]
session = sys.argv[3]
if cmd == 'load':
    print(state.load(state_dir, session))
elif cmd == 'save':
    score = float(sys.argv[4])
    turn = int(sys.argv[5])
    state.save(state_dir, session, score, turn)
    print('ok')
" "$@"
}

echo "== frustration_state =="

STATE_DIR="$TMPDIR/state"
SESSION="abc123"

# Load missing state -> defaults
out="$(run_state load "$STATE_DIR" "$SESSION")"
assert_contains "$out" "'score': 0.0" "missing state loads score=0.0"
assert_contains "$out" "'last_turn': 0" "missing state loads last_turn=0"

# Save then load roundtrip
run_state save "$STATE_DIR" "$SESSION" "4.5" "7" >/dev/null
out="$(run_state load "$STATE_DIR" "$SESSION")"
assert_contains "$out" "'score': 4.5" "saved score round-trips"
assert_contains "$out" "'last_turn': 7" "saved last_turn round-trips"

# Corrupt state file -> warning + returns defaults, does NOT crash
echo "not-json-at-all" > "$STATE_DIR/$SESSION.json"
out="$(run_state load "$STATE_DIR" "$SESSION" 2>&1)"
assert_contains "$out" "'score': 0.0" "corrupt state falls back to score=0.0"
assert_contains "$out" "'last_turn': 0" "corrupt state falls back to last_turn=0"
# Warning written to stderr (captured into $out via 2>&1)
assert_contains "$out" "corrupt" "corrupt state logs a warning"

# Different session gets its own state
run_state save "$STATE_DIR" "other-session" "2.0" "3" >/dev/null
out="$(run_state load "$STATE_DIR" "$SESSION")"
# Previous corrupt reset should have left defaults; confirm isolation
other="$(run_state load "$STATE_DIR" "other-session")"
assert_contains "$other" "'score': 2.0" "other session isolated"

summary
```

```bash
chmod +x plugins/devTools/tests/test_frustration_state.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash plugins/devTools/tests/test_frustration_state.sh
```

Expected: FAIL — `AttributeError: module 'state' has no attribute 'load'`.

- [ ] **Step 3: Implement `state.py`**

File: `plugins/devTools/skills/frustration-check/scripts/state.py`

```python
#!/usr/bin/env python3
"""Per-session frustration-check state: load/save JSON, corruption-safe.

State file path: <state_dir>/<session_id>.json
Schema: { "score": <float>, "last_turn": <int> }

Corrupt/missing files return defaults. Warnings go to stderr.
Never raises on corruption — frustration-check must not break prompt submit.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Dict


DEFAULTS: Dict[str, float | int] = {"score": 0.0, "last_turn": 0}


def _path(state_dir: str | Path, session_id: str) -> Path:
    return Path(state_dir) / f"{session_id}.json"


def load(state_dir: str | Path, session_id: str) -> Dict[str, float | int]:
    p = _path(state_dir, session_id)
    if not p.exists():
        return dict(DEFAULTS)
    try:
        with open(p) as f:
            data = json.load(f)
        score = float(data.get("score", 0.0))
        last_turn = int(data.get("last_turn", 0))
        return {"score": score, "last_turn": last_turn}
    except (json.JSONDecodeError, OSError, ValueError, TypeError) as exc:
        print(f"[frustration-check] state file corrupt at {p}: {exc}", file=sys.stderr)
        return dict(DEFAULTS)


def save(state_dir: str | Path, session_id: str, score: float, last_turn: int) -> None:
    p = _path(state_dir, session_id)
    p.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(p, "w") as f:
            json.dump({"score": float(score), "last_turn": int(last_turn)}, f)
    except OSError as exc:
        print(f"[frustration-check] failed to save state at {p}: {exc}", file=sys.stderr)


def gc_stale(state_dir: str | Path, ttl_days: int) -> None:
    """Opportunistic cleanup: delete state files older than ttl_days."""
    d = Path(state_dir)
    if not d.is_dir():
        return
    import time
    cutoff = time.time() - ttl_days * 86400
    try:
        for f in d.glob("*.json"):
            try:
                if f.stat().st_mtime < cutoff:
                    f.unlink()
            except OSError:
                continue
    except OSError:
        pass
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash plugins/devTools/tests/test_frustration_state.sh
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/devTools/skills/frustration-check/scripts/state.py plugins/devTools/tests/test_frustration_state.sh
git commit -m "devTools/frustration-check: session state with corruption-safe I/O"
```

---

## Task 4: `scoring.py` — decay + weights + threshold decision

**Files:**
- Modify: `plugins/devTools/skills/frustration-check/scripts/scoring.py`
- Create: `plugins/devTools/tests/test_frustration_scoring_and_decay.sh`

- [ ] **Step 1: Write the failing test**

File: `plugins/devTools/tests/test_frustration_scoring_and_decay.sh`

```bash
#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$here/../skills/frustration-check/scripts"
source "$here/lib/assert.sh"

run() {
  python3 -c "
import sys
sys.path.insert(0, '$SCRIPTS')
from scoring import decide
import json
req = json.loads(sys.stdin.read())
result = decide(
    prior_score=req['prior'],
    tiers=req['tiers'],
    decay=req['decay'],
    threshold=req['threshold'],
)
print(json.dumps(result))
"
}

echo "== frustration_scoring_and_decay =="

# Case 1: isolated T2 ("wtf") — 3pts — does NOT fire
req='{"prior":0,"tiers":{"t1":0,"t2":1,"t3":0,"t4":false},"decay":0.5,"threshold":5}'
out="$(echo "$req" | run)"
assert_contains "$out" '"mode": "none"' "isolated T2 does not fire"
assert_contains "$out" '"new_score": 3.0' "isolated T2 score=3.0"

# Case 2: isolated T1 ("i already told you") — 4pts — does NOT fire
req='{"prior":0,"tiers":{"t1":1,"t2":0,"t3":0,"t4":false},"decay":0.5,"threshold":5}'
out="$(echo "$req" | run)"
assert_contains "$out" '"mode": "none"' "isolated T1 does not fire"
assert_contains "$out" '"new_score": 4.0' "isolated T1 score=4.0"

# Case 3: T1 + T2 same prompt — 7pts — FIRES, resets score
req='{"prior":0,"tiers":{"t1":1,"t2":1,"t3":0,"t4":false},"decay":0.5,"threshold":5}'
out="$(echo "$req" | run)"
assert_contains "$out" '"mode": "frustration"' "T1+T2 fires frustration"
assert_contains "$out" '"new_score": 0' "frustration fires -> score resets"

# Case 4: decay brings prior down
# Prior 4, this turn no hits -> 4 * 0.5 = 2, under threshold
req='{"prior":4,"tiers":{"t1":0,"t2":0,"t3":0,"t4":false},"decay":0.5,"threshold":5}'
out="$(echo "$req" | run)"
assert_contains "$out" '"mode": "none"' "decay reduces stale score"
assert_contains "$out" '"new_score": 2.0' "decay: 4*0.5=2.0"

# Case 5: accumulation across turns
# Prior 4 (T1 last turn), this turn T2 (3): 4*0.5 + 3 = 5 -> FIRES
req='{"prior":4,"tiers":{"t1":0,"t2":1,"t3":0,"t4":false},"decay":0.5,"threshold":5}'
out="$(echo "$req" | run)"
assert_contains "$out" '"mode": "frustration"' "accumulated T1 then T2 fires on turn 2"

# Case 6: T4 only — assist mode, not frustration
req='{"prior":0,"tiers":{"t1":0,"t2":0,"t3":0,"t4":true},"decay":0.5,"threshold":5}'
out="$(echo "$req" | run)"
assert_contains "$out" '"mode": "assist"' "T4 alone fires assist mode"

# Case 7: T4 + high score — frustration wins
req='{"prior":0,"tiers":{"t1":1,"t2":1,"t3":0,"t4":true},"decay":0.5,"threshold":5}'
out="$(echo "$req" | run)"
assert_contains "$out" '"mode": "frustration"' "T4 + high score -> frustration takes precedence"

# Case 8: T3*2 + T1 — 2*2 + 4 = 8 — fires
req='{"prior":0,"tiers":{"t1":1,"t2":0,"t3":2,"t4":false},"decay":0.5,"threshold":5}'
out="$(echo "$req" | run)"
assert_contains "$out" '"mode": "frustration"' "T1+T3x2 fires"

summary
```

```bash
chmod +x plugins/devTools/tests/test_frustration_scoring_and_decay.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash plugins/devTools/tests/test_frustration_scoring_and_decay.sh
```

Expected: FAIL — `AttributeError: module 'scoring' has no attribute 'decide'`.

- [ ] **Step 3: Implement `scoring.py`**

File: `plugins/devTools/skills/frustration-check/scripts/scoring.py`

```python
#!/usr/bin/env python3
"""Scoring decision: apply decay, add tier weights, decide mode.

mode values:
  "frustration" — score >= threshold; emit FRUSTRATION signal; reset score
  "assist"      — T4 matched but frustration threshold not met
  "none"        — no-op, silent
"""
from __future__ import annotations

from typing import Dict


WEIGHTS: Dict[str, int] = {
    "t1": 4,
    "t2": 3,
    "t3": 2,
}


def decide(
    prior_score: float,
    tiers: Dict[str, object],
    decay: float,
    threshold: float,
) -> Dict[str, object]:
    """Apply decay, add weighted tier matches, decide mode.

    Returns:
      { "mode": "frustration"|"assist"|"none", "new_score": <float>, "score_before_reset": <float> }
    """
    decayed = float(prior_score) * float(decay)
    added = (
        int(tiers.get("t1", 0)) * WEIGHTS["t1"]
        + int(tiers.get("t2", 0)) * WEIGHTS["t2"]
        + int(tiers.get("t3", 0)) * WEIGHTS["t3"]
    )
    score = decayed + added

    if score >= float(threshold):
        return {"mode": "frustration", "new_score": 0, "score_before_reset": score}
    if bool(tiers.get("t4", False)):
        return {"mode": "assist", "new_score": score, "score_before_reset": score}
    return {"mode": "none", "new_score": score, "score_before_reset": score}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash plugins/devTools/tests/test_frustration_scoring_and_decay.sh
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/devTools/skills/frustration-check/scripts/scoring.py plugins/devTools/tests/test_frustration_scoring_and_decay.sh
git commit -m "devTools/frustration-check: decay + weighted scoring decision"
```

---

## Task 5: `detect_frustration.py` — hook entrypoint + integration tests

**Files:**
- Modify: `plugins/devTools/skills/frustration-check/scripts/detect_frustration.py`
- Create: `plugins/devTools/tests/test_frustration_hook_integration.sh`

**Contract:**
- Reads JSON on stdin: `{ "session_id": "...", "prompt": "...", "hook_event_name": "UserPromptSubmit", ... }` (Claude Code passes other fields too; we ignore them)
- Writes activation message to stdout on FRUSTRATION or ASSIST; nothing on no-op
- Exits 0 in all normal cases — must never crash prompt submission
- Uses settings from `~/.ccToolBox/frustration-check/settings.json`; falls back to shipped defaults if user file missing
- Uses state dir `~/.ccToolBox/frustration-check/state/`
- Supports env var `FRUSTRATION_CHECK_HOME` override for testing (points at alternate root)

- [ ] **Step 1: Write the failing test**

File: `plugins/devTools/tests/test_frustration_hook_integration.sh`

```bash
#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
HOOK="$here/../skills/frustration-check/scripts/detect_frustration.py"
DEFAULT_SETTINGS="$here/../skills/frustration-check/settings.default.json"
source "$here/lib/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Each call gets a fresh HOME with shipped settings copied in
fresh_home() {
  local home="$TMPDIR/home-$RANDOM-$RANDOM"
  mkdir -p "$home/.ccToolBox/frustration-check"
  cp "$DEFAULT_SETTINGS" "$home/.ccToolBox/frustration-check/settings.json"
  echo "$home"
}

# Call hook with a JSON payload; echo stdout, report exit code via $?
# Usage: call_hook <home> <session_id> <prompt>
call_hook() {
  local home="$1" session="$2" prompt="$3"
  FRUSTRATION_CHECK_HOME="$home/.ccToolBox/frustration-check" \
    python3 "$HOOK" <<EOF
{"session_id": "$session", "prompt": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$prompt"), "hook_event_name": "UserPromptSubmit"}
EOF
}

echo "== frustration_hook_integration =="

# --- Silent no-op on normal prompt ---
home="$(fresh_home)"
out="$(call_hook "$home" "s1" "Please add a timezone endpoint to the user profile")"
assert_eq "" "$out" "normal prompt -> zero stdout"

# --- Frustration fires on T1+T2 in one turn ---
home="$(fresh_home)"
out="$(call_hook "$home" "s2" "i already told you to stop, wtf are you doing")"
assert_contains "$out" "FRUSTRATION" "T1+T2 fires FRUSTRATION"
assert_contains "$out" "frustration-check" "output has skill tag"

# --- Isolated wtf under threshold -> silent ---
home="$(fresh_home)"
out="$(call_hook "$home" "s3" "wtf this is weird")"
assert_eq "" "$out" "isolated wtf silent (score 3 < threshold 5)"

# --- Accumulation: T1 turn 1 silent, add T2 turn 2 fires ---
home="$(fresh_home)"
out1="$(call_hook "$home" "s4" "i already told you to use config, not capabilities")"
assert_eq "" "$out1" "T1 alone (score 4) silent"
out2="$(call_hook "$home" "s4" "wtf")"
assert_contains "$out2" "FRUSTRATION" "T1 then T2: 4*0.5+3=5 fires"

# --- Assist mode on T4 ---
home="$(fresh_home)"
out="$(call_hook "$home" "s5" "let's step back for a moment, maybe my design was wrong")"
assert_contains "$out" "ASSIST" "T4 self-realization -> ASSIST"
assert_not_contains "$out" "FRUSTRATION" "ASSIST is not FRUSTRATION"

# --- Opt-out: enabled=false ---
home="$(fresh_home)"
python3 -c "
import json
p = '$home/.ccToolBox/frustration-check/settings.json'
s = json.load(open(p))
s['enabled'] = False
json.dump(s, open(p, 'w'))
"
out="$(call_hook "$home" "s6" "i already told you, wtf")"
assert_eq "" "$out" "enabled=false silences hook"

# --- Opt-out: 'skip frustration-check' substring ---
home="$(fresh_home)"
out="$(call_hook "$home" "s7" "i already told you wtf — skip frustration-check for this one")"
assert_eq "" "$out" "skip phrase suppresses hook and state update"

# --- Reset after fire ---
home="$(fresh_home)"
out1="$(call_hook "$home" "s8" "i already told you to stop, wtf")"
assert_contains "$out1" "FRUSTRATION" "s8 turn 1 fires"
# Next turn same session must not immediately re-fire from leftover score
out2="$(call_hook "$home" "s8" "okay, so what do you think?")"
assert_eq "" "$out2" "s8 turn 2 silent — score was reset after fire"

# --- Corrupt settings -> fall back to shipped defaults, do not crash ---
home="$(fresh_home)"
echo "not-json" > "$home/.ccToolBox/frustration-check/settings.json"
set +e
out="$(call_hook "$home" "s9" "Please just do X")"
rc=$?
set -e
assert_exit_code "0" "$rc" "corrupt settings -> exit 0"
assert_eq "" "$out" "corrupt settings -> normal prompt remains silent"

# --- Malformed stdin JSON -> graceful exit 0, silent ---
set +e
bad_out="$(echo "not-json" | FRUSTRATION_CHECK_HOME="$home/.ccToolBox/frustration-check" python3 "$HOOK" 2>/dev/null)"
bad_rc=$?
set -e
assert_exit_code "0" "$bad_rc" "malformed stdin -> exit 0"
assert_eq "" "$bad_out" "malformed stdin -> silent"

summary
```

```bash
chmod +x plugins/devTools/tests/test_frustration_hook_integration.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash plugins/devTools/tests/test_frustration_hook_integration.sh
```

Expected: FAIL on all assertions (hook is empty stub).

- [ ] **Step 3: Implement `detect_frustration.py`**

File: `plugins/devTools/skills/frustration-check/scripts/detect_frustration.py`

```python
#!/usr/bin/env python3
"""UserPromptSubmit hook for frustration-check.

Reads a JSON object from stdin describing the user prompt and session.
Scores the prompt against tier regex patterns, applies decay to prior
session score, and decides whether to emit a FRUSTRATION or ASSIST signal.

Output contract:
  - FRUSTRATION: single line to stdout, score reset to 0 in state file
  - ASSIST:      single line to stdout, score unchanged
  - None:        zero stdout output (silent no-op)

Hook must never crash prompt submission. All exceptions are caught at the
outer boundary; on any error, exit 0 with empty stdout and a stderr warning.

Override `FRUSTRATION_CHECK_HOME` to point at an alternate settings+state
root (used in tests).
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

# sibling modules
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import patterns  # noqa: E402
import scoring  # noqa: E402
import state as state_mod  # noqa: E402


SHIPPED_DEFAULTS_PATH = SCRIPT_DIR.parent / "settings.default.json"
SKIP_PHRASE = "skip frustration-check"


def _log(msg: str) -> None:
    print(f"[frustration-check] {msg}", file=sys.stderr)


def _home() -> Path:
    override = os.environ.get("FRUSTRATION_CHECK_HOME")
    if override:
        return Path(override)
    return Path(os.environ.get("HOME", "~")).expanduser() / ".ccToolBox" / "frustration-check"


def _load_settings() -> dict:
    """Load user settings; fall back to shipped defaults on any failure."""
    home = _home()
    user_path = home / "settings.json"
    # Always load shipped as canonical fallback
    with open(SHIPPED_DEFAULTS_PATH) as f:
        shipped = json.load(f)
    if not user_path.exists():
        return shipped
    try:
        with open(user_path) as f:
            user = json.load(f)
        # Merge: user overrides shipped (flat merge is fine for our schema)
        merged = dict(shipped)
        merged.update(user)
        # custom_patterns merges at one level deeper
        merged_custom = dict(shipped.get("custom_patterns", {}))
        merged_custom.update(user.get("custom_patterns", {}) or {})
        merged["custom_patterns"] = merged_custom
        return merged
    except (json.JSONDecodeError, OSError, ValueError) as exc:
        _log(f"settings corrupt ({exc}); using shipped defaults")
        return shipped


def _emit_frustration(score_before: float) -> None:
    print(
        f"[frustration-check] FRUSTRATION signal (score={score_before:.1f}). "
        f"Invoke frustration-check skill in FRUSTRATION mode."
    )


def _emit_assist() -> None:
    print(
        "[frustration-check] SELF-REALIZATION detected. "
        "Invoke frustration-check skill in ASSIST mode."
    )


def _main() -> int:
    # Read stdin
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except (json.JSONDecodeError, ValueError) as exc:
        _log(f"stdin not JSON ({exc}); silent exit")
        return 0

    prompt = str(payload.get("prompt", ""))
    session_id = str(payload.get("session_id", "")) or "default"

    # Opt-out: skip phrase (does NOT update state)
    if SKIP_PHRASE in prompt.lower():
        return 0

    settings = _load_settings()
    if not settings.get("enabled", True):
        return 0

    state_dir = _home() / "state"

    # Opportunistic GC
    ttl_days = int(settings.get("state_ttl_days", 7))
    state_mod.gc_stale(state_dir, ttl_days)

    # Score current prompt
    custom = settings.get("custom_patterns", {}) or {}
    tiers = patterns.score_tiers(prompt, custom)

    # Load prior score, decide, save
    prior = state_mod.load(state_dir, session_id)
    prior_score = float(prior.get("score", 0.0))
    last_turn = int(prior.get("last_turn", 0))

    decision = scoring.decide(
        prior_score=prior_score,
        tiers=tiers,
        decay=float(settings.get("decay", 0.5)),
        threshold=float(settings.get("threshold", 5)),
    )

    new_score = float(decision["new_score"])
    state_mod.save(state_dir, session_id, new_score, last_turn + 1)

    mode = decision["mode"]
    if mode == "frustration":
        _emit_frustration(float(decision["score_before_reset"]))
    elif mode == "assist":
        _emit_assist()
    # mode == "none": silent
    return 0


def main() -> int:
    try:
        return _main()
    except Exception as exc:  # last-resort: never break prompt submit
        _log(f"unexpected error ({exc}); silent exit")
        return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash plugins/devTools/tests/test_frustration_hook_integration.sh
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/devTools/skills/frustration-check/scripts/detect_frustration.py plugins/devTools/tests/test_frustration_hook_integration.sh
git commit -m "devTools/frustration-check: hook entrypoint with integration tests"
```

---

## Task 6: `init_settings.py` — first-run / migrate / malformed handling

**Files:**
- Modify: `plugins/devTools/skills/frustration-check/scripts/init_settings.py`
- Create: `plugins/devTools/tests/test_frustration_init_settings.sh`

- [ ] **Step 1: Write the failing test**

File: `plugins/devTools/tests/test_frustration_init_settings.sh`

```bash
#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
INIT="$here/../skills/frustration-check/scripts/init_settings.py"
source "$here/lib/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

run_init() {
  local home="$1"
  FRUSTRATION_CHECK_HOME="$home/.ccToolBox/frustration-check" \
    python3 "$INIT"
}

echo "== frustration_init_settings =="

# Case 1: first run — file missing, copy default
home="$TMPDIR/home1"
mkdir -p "$home"
run_init "$home" >/dev/null 2>&1
assert_eq "0" "$?" "init first-run exits 0"
[[ -f "$home/.ccToolBox/frustration-check/settings.json" ]] \
  && _pass "settings.json created" \
  || _fail "settings.json NOT created"
TESTS=$((TESTS+1))

# Verify contents include version, threshold, enabled
content="$(cat "$home/.ccToolBox/frustration-check/settings.json")"
assert_contains "$content" '"version": 1' "first-run has version 1"
assert_contains "$content" '"threshold": 5' "first-run has threshold 5"
assert_contains "$content" '"enabled": true' "first-run has enabled=true"

# Case 2: already exists at same version — no-op
home="$TMPDIR/home2"
mkdir -p "$home/.ccToolBox/frustration-check"
cat > "$home/.ccToolBox/frustration-check/settings.json" <<'EOF'
{"version": 1, "enabled": false, "threshold": 5, "decay": 0.5, "state_ttl_days": 7, "custom_patterns": {"t1":[],"t2":[],"t3":[],"t4":[]}}
EOF
run_init "$home" >/dev/null 2>&1
content="$(cat "$home/.ccToolBox/frustration-check/settings.json")"
assert_contains "$content" '"enabled": false' "same-version preserves user value"

# Case 3: malformed user file -> back up and reset
home="$TMPDIR/home3"
mkdir -p "$home/.ccToolBox/frustration-check"
echo "not-json" > "$home/.ccToolBox/frustration-check/settings.json"
run_init "$home" >/dev/null 2>&1
content="$(cat "$home/.ccToolBox/frustration-check/settings.json")"
assert_contains "$content" '"version": 1' "malformed reset produces fresh defaults"
ls "$home/.ccToolBox/frustration-check/" | grep -q 'bak' \
  && _pass "backup file created" \
  || _fail "backup file NOT created"
TESTS=$((TESTS+1))

# Case 4: older version -> migrate, preserve user values for known keys, add new ones
home="$TMPDIR/home4"
mkdir -p "$home/.ccToolBox/frustration-check"
# Simulate v0 with fewer keys and user-customized threshold
cat > "$home/.ccToolBox/frustration-check/settings.json" <<'EOF'
{"version": 0, "enabled": true, "threshold": 7}
EOF
run_init "$home" >/dev/null 2>&1
content="$(cat "$home/.ccToolBox/frustration-check/settings.json")"
assert_contains "$content" '"version": 1' "migrated to v1"
assert_contains "$content" '"threshold": 7' "user threshold preserved through migration"
assert_contains "$content" '"decay": 0.5' "new field 'decay' added"
assert_contains "$content" '"state_ttl_days": 7' "new field 'state_ttl_days' added"

summary
```

```bash
chmod +x plugins/devTools/tests/test_frustration_init_settings.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash plugins/devTools/tests/test_frustration_init_settings.sh
```

Expected: FAIL — `init_settings.py` is an empty stub.

- [ ] **Step 3: Implement `init_settings.py`**

File: `plugins/devTools/skills/frustration-check/scripts/init_settings.py`

```python
#!/usr/bin/env python3
"""Initialize frustration-check user settings.

Branches handled (in order):
  1. First run (user file missing) — copy default
  2. Malformed user file (JSON parse fails) — back up, reset to default
  3. user.version < default.version — merge-migrate, back up
  4. user.version > default.version — warn, use user file as-is
  5. Versions match — no-op

User storage is at ~/.ccToolBox/frustration-check/ (overridable via
FRUSTRATION_CHECK_HOME env var for testing).

This script is called by the skill on first activation; it is NOT a hook.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
DEFAULT_SETTINGS_PATH = SKILL_DIR / "settings.default.json"


def log(msg: str) -> None:
    print(f"[frustration-check/init] {msg}", file=sys.stderr)


def user_root() -> Path:
    override = os.environ.get("FRUSTRATION_CHECK_HOME")
    if override:
        return Path(override)
    return Path(os.environ.get("HOME", "~")).expanduser() / ".ccToolBox" / "frustration-check"


def load_default() -> dict:
    with open(DEFAULT_SETTINGS_PATH) as f:
        return json.load(f)


def first_run(user_path: Path, default: dict) -> dict:
    user_path.parent.mkdir(parents=True, exist_ok=True)
    with open(user_path, "w") as f:
        json.dump(default, f, indent=2)
    log(f"Created default settings at {user_path} — edit to customize.")
    return default


def malformed_reset(user_path: Path, default: dict) -> dict:
    backup = user_path.with_suffix(".json.bak")
    shutil.copy(user_path, backup)
    with open(user_path, "w") as f:
        json.dump(default, f, indent=2)
    log(f"Settings malformed. Backed up to {backup.name} and reset to defaults.")
    return default


def migrate_up(user_path: Path, user: dict, default: dict) -> dict:
    old_version = user.get("version", 0)
    backup = user_path.parent / f"settings.json.v{old_version}.bak"
    shutil.copy(user_path, backup)

    merged = dict(default)
    new_fields = []
    for key in default.keys():
        if key == "version":
            continue
        if key in user:
            merged[key] = user[key]
        else:
            new_fields.append(key)
    merged["version"] = default["version"]

    with open(user_path, "w") as f:
        json.dump(merged, f, indent=2)

    suffix = f" New fields: {', '.join(new_fields)}." if new_fields else ""
    log(f"Migrated from v{old_version} to v{default['version']}.{suffix}")
    return merged


def version_higher_warn(user: dict, default: dict) -> dict:
    log(
        f"User settings version (v{user['version']}) is newer than plugin "
        f"default (v{default['version']}). Proceeding as-is."
    )
    return user


def _main() -> int:
    default = load_default()
    root = user_root()
    user_path = root / "settings.json"

    if not user_path.exists():
        first_run(user_path, default)
        return 0
    if not user_path.is_file():
        log(f"ERROR: {user_path} exists but is not a regular file. Remove it and retry.")
        return 1

    try:
        with open(user_path) as f:
            user = json.load(f)
    except (json.JSONDecodeError, OSError):
        malformed_reset(user_path, default)
        return 0

    user_version = user.get("version", 0)
    default_version = default["version"]
    if user_version < default_version:
        migrate_up(user_path, user, default)
    elif user_version > default_version:
        version_higher_warn(user, default)
    else:
        log(f"Settings OK (v{default_version}).")
    return 0


def main() -> int:
    try:
        return _main()
    except OSError as exc:
        log(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash plugins/devTools/tests/test_frustration_init_settings.sh
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/devTools/skills/frustration-check/scripts/init_settings.py plugins/devTools/tests/test_frustration_init_settings.sh
git commit -m "devTools/frustration-check: first-run + migration for user settings"
```

---

## Task 7: Write `SKILL.md` with dual-mode workflow

**Files:**
- Modify: `plugins/devTools/skills/frustration-check/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

File: `plugins/devTools/skills/frustration-check/SKILL.md`

```markdown
---
name: frustration-check
description: >
  Calmly intervene when the frustration-check hook has injected a
  FRUSTRATION or SELF-REALIZATION signal into the session, or when the user's
  recent messages clearly show drift/rage + constraint repetition. Steps back
  from the current tactical work, reflects on recent turns, offers
  consent-gated drift scans and knowledge-gap lookups (websearch / context7),
  and re-confirms intent before resuming. Do NOT trigger on normal user
  questions, minor corrections, or casual optimization.
tools: Bash, Read, Grep, WebSearch
---

# frustration-check — Step Back, Realign, Resume

A hook-activated intervention for two cases:

1. **Frustration mode** — the user is stuck in a drift pattern: repeating
   constraints, cursing at the output, or halting the current direction.
   Tactical work is unlikely to unstick things; they need a beat to step
   back.
2. **Assist mode** — the user has already voiced doubt ("let me step back",
   "maybe i was wrong"). They're calm and open; a lightweight recall +
   knowledge-gap offer saves everyone time.

The hook (`scripts/detect_frustration.py`) runs on every `UserPromptSubmit`
and injects one of two signals when its tiered scoring trips the threshold.
This skill responds to those signals.

## Activation

This skill activates when one of these appears in the conversation:

- `[frustration-check] FRUSTRATION signal` → run **Frustration mode**
- `[frustration-check] SELF-REALIZATION detected` → run **Assist mode**

Do NOT self-invoke on generic user frustration cues without the hook signal
— the hook does the calibration.

## Frustration mode (full intervention)

1. **One non-preachy line.** No therapy voice. Example: *"Worth stepping
   back for a second — feels like we may have drifted from the original
   intent."* Keep it under 20 words.

2. **Reflect on the last 5–10 turns** (already in your context — no tool
   call needed). In 2–3 sentences, restate:
   - What the original goal was
   - What path the conversation has been on
   - Where you think uncertainty or drift crept in

   If the original goal isn't visible in the last 10 turns, say so and ask
   the user to restate it in one sentence.

3. **Offer three paths. Wait for user pick.**

   > a) **Drift scan** — I identify which turn diverged from a stated
   > constraint and name the constraint.
   > b) **Knowledge-gap check** — I propose 1–3 *specific* websearch or
   > context7 lookups (named library / named API / named question) that
   > might invalidate a stale assumption we've been riding.
   > c) **Push on** — you were venting, path is fine.

4. **Run the chosen path.** Surface findings in ≤5 bullets.
   - For (a): quote the constraint, cite the turn where it diverged.
   - For (b): actually run the searches (use WebSearch or the context7 MCP
     tools if available), summarize what shifted. No "I would suggest
     researching X" — either do it or say you can't.
   - For (c): skip to step 5.

5. **Confirm refined intent in one sentence:** *"So: goal is X, constraint
   is Y, current plan is Z. Proceed?"* Wait for yes/no.

6. Resume normal work.

## Assist mode (light nudge)

Output one sentence and stop:

> *"Caught a step-back moment — want me to recall recent turns and scan for
> knowledge gaps before continuing? (yes / no / just keep going)"*

- If the user says yes → run steps 2–5 of Frustration mode.
- If no / silence / "keep going" → do nothing further; continue with the
  user's original request.

## Hard rules

- **No automatic research.** Always offer and wait for consent before
  running any websearch or context7 lookup. Preserves token budget when the
  user is fine.
- **Be brief.** The whole intervention should fit in the user's working
  memory. If step 2 is running long, the reflection is already too much.
- **Never lecture.** No "I noticed you seem frustrated." No "let's take a
  breath." Treat the user as a professional having a moment, not a patient.
- **One path, one time.** Don't re-offer drift scans or knowledge-gap
  checks the user already declined in this thread.

## Opt-out

Users can disable or silence the hook:

- `enabled: false` in `~/.ccToolBox/frustration-check/settings.json`
- Include the substring `skip frustration-check` in the prompt that should
  be ignored (single-turn suppression, does not alter state).

## First-run setup

On first activation of this skill, run
`scripts/init_settings.py` to create
`~/.ccToolBox/frustration-check/settings.json` from the shipped defaults.
This also handles version migration and malformed-file recovery. If the
hook is running, settings should already exist.

## Tuning

Patterns are declared in `scripts/patterns.py`. Users can extend them via
`custom_patterns` in their settings file (one list per tier). Scoring
weights and threshold are in settings (`threshold`, `decay`).

If the hook fires too often, raise `threshold` (default 5) or add custom
patterns Kevin's false-positives to a suppression list (future work).

If it rarely fires, lower `threshold` or add custom patterns to `t1`/`t2`/
`t3`. Lexical additions are fine; behavioral detection is deliberately out
of scope (see spec).
```

- [ ] **Step 2: Verify no placeholders, description fits one-line summary semantics**

```bash
grep -n 'TODO\|TBD\|FIXME' plugins/devTools/skills/frustration-check/SKILL.md
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add plugins/devTools/skills/frustration-check/SKILL.md
git commit -m "devTools/frustration-check: SKILL.md with dual-mode workflow"
```

---

## Task 8: Register hook via `hooks/hooks.json`

**Files:**
- Create: `plugins/devTools/hooks/hooks.json`

Claude Code plugins expose hooks via a `hooks/hooks.json` file at the plugin root. The format matches the `hooks` section of a normal `~/.claude/settings.json`. Path literals may reference `${CLAUDE_PLUGIN_ROOT}` which Claude Code substitutes with the plugin's absolute path on load.

- [ ] **Step 1: Create `hooks/hooks.json`**

File: `plugins/devTools/hooks/hooks.json`

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/skills/frustration-check/scripts/detect_frustration.py"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Sanity-check JSON validity**

Run:
```bash
python3 -c "import json; json.load(open('plugins/devTools/hooks/hooks.json'))"
```

Expected: no output, exit code 0.

- [ ] **Step 3: Verify hook script path exists and is executable**

Run:
```bash
ls -l plugins/devTools/skills/frustration-check/scripts/detect_frustration.py
```

Expected: file exists and starts with `-rwx` (executable bit set).

- [ ] **Step 4: Commit**

```bash
git add plugins/devTools/hooks/hooks.json
git commit -m "devTools/frustration-check: register UserPromptSubmit hook"
```

---

## Task 9: Plugin version bump + changelog + marketplace

**Files:**
- Modify: `plugins/devTools/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugins/devTools/CHANGELOG.md`

Per `CLAUDE.md` and memory feedback: plugin version bumps must land in **both** `plugin.json` **and** `marketplace.json` in the same commit, with a changelog entry. Current version: `1.3.0`. Target: `1.4.0` (new skill = minor bump).

- [ ] **Step 1: Bump `plugins/devTools/.claude-plugin/plugin.json`**

Replace contents with:

```json
{
  "name": "devTools",
  "description": "Developer productivity skills for software engineering workflows",
  "version": "1.4.0",
  "author": { "name": "dev32-io" }
}
```

- [ ] **Step 2: Bump `.claude-plugin/marketplace.json`**

In the `devTools` entry (plugins array), change `"version": "1.3.0"` to `"version": "1.4.0"`. Full replacement of the devTools entry:

```json
    {
      "name": "devTools",
      "description": "Developer productivity skills for software engineering workflows",
      "version": "1.4.0",
      "source": "./plugins/devTools",
      "category": "productivity"
    }
```

(Also update the top-level `description` field on the marketplace-entry description to align with the plugin.json wording, since the current marketplace description still mentions only retro + recall-test-knowledge.)

- [ ] **Step 3: Prepend new changelog entry**

Edit `plugins/devTools/CHANGELOG.md` — insert BEFORE the existing `## 1.3.0` block:

```markdown
## 1.4.0 — 2026-04-22

- `frustration-check`: new skill with auto-triggering `UserPromptSubmit`
  hook. Detects drift/frustration via tiered regex (T1 constraint
  repetition, T2 rage, T3 contradiction) with decay-based scoring across
  turns, plus T4 self-realization phrases for a lighter "assist mode"
  trigger. When fired, runs a consent-gated intervention: step-back one-
  liner → recent-turn reflection → offered drift scan / knowledge-gap
  websearch / push-on → intent re-confirmation. Calibrated against real
  session data: profanity alone (default threshold 5) does NOT fire;
  constraint repetition is the dominant signal.
- `frustration-check`: opt-out via `enabled: false` in
  `~/.ccToolBox/frustration-check/settings.json` or by including the
  substring `skip frustration-check` in a prompt. Settings ship at
  `version: 1` with threshold, decay, TTL, and user-extensible custom
  patterns per tier.
```

- [ ] **Step 4: Verify marketplace and plugin manifest agree**

Run:
```bash
python3 -c "
import json
m = json.load(open('.claude-plugin/marketplace.json'))
p = json.load(open('plugins/devTools/.claude-plugin/plugin.json'))
for e in m['plugins']:
    if e['name'] == 'devTools':
        assert e['version'] == p['version'], f\"mismatch: marketplace={e['version']} plugin={p['version']}\"
        print(f'OK devTools version: {e[\"version\"]}')
        break
else:
    raise SystemExit('devTools entry missing from marketplace')
"
```

Expected: `OK devTools version: 1.4.0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/devTools/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/devTools/CHANGELOG.md
git commit -m "devTools: bump to 1.4.0 for frustration-check skill"
```

---

## Task 10: End-to-end manual verification

**Files:** none modified in this task.

- [ ] **Step 1: Run all new tests together**

```bash
for t in plugins/devTools/tests/test_frustration_*.sh; do
  echo "=== $t ==="
  bash "$t" || { echo "FAILED: $t"; exit 1; }
done
echo "ALL FRUSTRATION TESTS PASSED"
```

Expected: all five new test files pass, final line `ALL FRUSTRATION TESTS PASSED`.

- [ ] **Step 2: Run the pre-existing devTools tests to confirm no regression**

```bash
for t in plugins/devTools/tests/test_*.sh; do
  bash "$t" || { echo "FAILED: $t"; exit 1; }
done
echo "ALL DEVTOOLS TESTS PASSED"
```

Expected: all devTools tests pass (existing + new).

- [ ] **Step 3: Smoke-test the hook entrypoint directly**

```bash
TMP="$(mktemp -d)"
mkdir -p "$TMP/home/.ccToolBox/frustration-check"
cp plugins/devTools/skills/frustration-check/settings.default.json "$TMP/home/.ccToolBox/frustration-check/settings.json"

# Should be silent
echo '{"session_id":"smoke","prompt":"Please add a feature","hook_event_name":"UserPromptSubmit"}' \
  | FRUSTRATION_CHECK_HOME="$TMP/home/.ccToolBox/frustration-check" \
    python3 plugins/devTools/skills/frustration-check/scripts/detect_frustration.py

# Should fire FRUSTRATION
echo '{"session_id":"smoke2","prompt":"i already told you to stop, wtf","hook_event_name":"UserPromptSubmit"}' \
  | FRUSTRATION_CHECK_HOME="$TMP/home/.ccToolBox/frustration-check" \
    python3 plugins/devTools/skills/frustration-check/scripts/detect_frustration.py

rm -rf "$TMP"
```

Expected:
- First invocation: zero stdout.
- Second invocation: one line starting with `[frustration-check] FRUSTRATION signal (score=7.0).`

- [ ] **Step 4: Verify `hooks.json` format is parseable and references existing script**

```bash
python3 -c "
import json, os
cfg = json.load(open('plugins/devTools/hooks/hooks.json'))
cmds = cfg['hooks']['UserPromptSubmit'][0]['hooks']
assert cmds[0]['type'] == 'command'
# Substitute CLAUDE_PLUGIN_ROOT with the actual plugin path to verify the script exists
ref_path = cmds[0]['command'].replace('\${CLAUDE_PLUGIN_ROOT}', 'plugins/devTools').split(' ', 1)[1]
assert os.path.exists(ref_path), f'hook script not found at {ref_path}'
print(f'OK hook registered: {ref_path}')
"
```

Expected: `OK hook registered: plugins/devTools/skills/frustration-check/scripts/detect_frustration.py`.

- [ ] **Step 5: Final review of the plugin tree**

```bash
find plugins/devTools/skills/frustration-check plugins/devTools/hooks -type f | sort
```

Expected output:
```
plugins/devTools/hooks/hooks.json
plugins/devTools/skills/frustration-check/SKILL.md
plugins/devTools/skills/frustration-check/scripts/detect_frustration.py
plugins/devTools/skills/frustration-check/scripts/init_settings.py
plugins/devTools/skills/frustration-check/scripts/patterns.py
plugins/devTools/skills/frustration-check/scripts/scoring.py
plugins/devTools/skills/frustration-check/scripts/state.py
plugins/devTools/skills/frustration-check/settings.default.json
```

- [ ] **Step 6: No commit**

This task only runs verifications. If any fail, fix inline and commit as a follow-up to the task that introduced the bug.

---

## Self-Review Checklist (from writing-plans)

Before handing off to execution:

**Spec coverage:**
- [x] Hook + Skill split → Tasks 5, 7, 8
- [x] State file with decay and corruption handling → Tasks 3, 4
- [x] Tiered patterns (T1/T2/T3/T4) → Task 2 + spec calibration examples in Task 5 tests
- [x] Settings with version/threshold/decay/TTL/custom_patterns → Tasks 1, 6
- [x] Dual-mode workflow in skill → Task 7
- [x] Opt-out (`enabled: false` + skip phrase) → Task 5 tests
- [x] Testing — bash integration style matching existing repo conventions → Tasks 2, 3, 4, 5, 6
- [x] First-run / migrate / malformed settings → Task 6
- [x] Plugin version bump + changelog + marketplace → Task 9
- [x] E2E verification → Task 10

**Placeholder scan:** No "TBD/TODO/fill in" — every code step has complete content.

**Type consistency:**
- `score_tiers()` returns `{"t1","t2","t3","t4"}` dict — consumed identically by `scoring.decide()` and `detect_frustration._main()`.
- `state.load()` returns `{"score","last_turn"}` — consumed in `_main()` with those exact keys.
- `scoring.decide()` returns `{"mode","new_score","score_before_reset"}` — consumed with those exact keys.
- `settings.default.json` schema (`version`, `enabled`, `threshold`, `decay`, `state_ttl_days`, `custom_patterns`) matches `_load_settings` access patterns.

---

## Notes for executor

- This work is scoped to one plugin (`devTools`) and does not affect other plugins. No worktree strictly required, but a dedicated branch `feat/frustration-check` is recommended.
- The user's standing preference is to leave spec/plan docs uncommitted (see memory). Do not commit `docs/superpowers/plans/2026-04-22-frustration-check-skill.md` or the linked spec.
- If any test fails due to a Claude Code hook input-schema drift (payload shape), adjust field access in `_main()` of `detect_frustration.py`. Spec-level contract is "read `session_id` and `prompt` from stdin JSON"; everything else is ignored.
- Per feedback memory: plugin version and settings version must both bump in the same commit when settings change. Settings ship at `version: 1` (brand new) so no extra bump required now; future edits must bump both.
