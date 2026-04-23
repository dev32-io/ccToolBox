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
