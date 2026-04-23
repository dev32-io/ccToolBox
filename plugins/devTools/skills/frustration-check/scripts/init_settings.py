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
