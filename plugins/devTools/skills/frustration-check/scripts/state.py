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
