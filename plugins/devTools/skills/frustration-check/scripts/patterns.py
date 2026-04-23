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
