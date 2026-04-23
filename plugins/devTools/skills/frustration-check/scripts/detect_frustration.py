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

# sibling modules — imported defensively so import failures never crash prompt submit
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

_IMPORT_ERROR: Exception | None = None
try:
    import patterns  # noqa: E402
    import scoring  # noqa: E402
    import state as state_mod  # noqa: E402
except Exception as exc:  # noqa: BLE001
    _IMPORT_ERROR = exc


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
    with open(SHIPPED_DEFAULTS_PATH) as f:
        shipped = json.load(f)
    if not user_path.exists():
        return shipped
    try:
        with open(user_path) as f:
            user = json.load(f)
        merged = dict(shipped)
        merged.update(user)
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
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except (json.JSONDecodeError, ValueError) as exc:
        _log(f"stdin not JSON ({exc}); silent exit")
        return 0

    prompt = str(payload.get("prompt", ""))
    session_id = str(payload.get("session_id", "")) or "default"

    if SKIP_PHRASE in prompt.lower():
        return 0

    settings = _load_settings()
    if not settings.get("enabled", True):
        return 0

    state_dir = _home() / "state"

    ttl_days = int(settings.get("state_ttl_days", 7))
    state_mod.gc_stale(state_dir, ttl_days)

    custom = settings.get("custom_patterns", {}) or {}
    tiers = patterns.score_tiers(prompt, custom)

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
    return 0


def main() -> int:
    if _IMPORT_ERROR is not None:
        _log(f"sibling module import failed ({_IMPORT_ERROR}); hook disabled for this invocation")
        return 0
    try:
        return _main()
    except Exception as exc:
        _log(f"unexpected error ({exc}); silent exit")
        return 0


if __name__ == "__main__":
    sys.exit(main())
