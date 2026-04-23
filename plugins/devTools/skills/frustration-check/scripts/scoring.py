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
