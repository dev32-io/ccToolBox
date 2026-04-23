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

# T3 contradiction fixture hits both "no, stop" and "why are you still"
t3_in="$(cat "$FIXTURES/t3_contradiction.txt")"
out="$(match "$t3_in")"
assert_contains "$out" "T3:2" "T3 contradiction fixture matches T3 twice (no-stop AND why-are-you-still)"

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
