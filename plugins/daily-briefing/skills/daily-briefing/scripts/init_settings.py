#!/usr/bin/env python3
"""Initialize daily-briefing settings. Prints merged settings as JSON on stdout.

Branches handled (in order):
  1. First run (user file missing) — copy default
  2. Malformed user file (JSON parse fails) — back up, reset to default
  3. user.version < default.version — migrate, back up
  4. user.version > default.version — warn, use user file as-is
  5. Versions match — no-op

Also performs retention cleanup on the output directory.

Self-locates settings.default.json via __file__. User storage is at
~/.ccToolBox/daily-briefing/.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
DEFAULT_SETTINGS_PATH = SKILL_DIR / "settings.default.json"


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def user_root() -> Path:
    return Path(os.environ.get("HOME", "~")).expanduser() / ".ccToolBox" / "daily-briefing"


def load_default() -> dict:
    with open(DEFAULT_SETTINGS_PATH) as f:
        return json.load(f)


def first_run(user_path: Path, default: dict) -> dict:
    user_path.parent.mkdir(parents=True, exist_ok=True)
    with open(user_path, "w") as f:
        json.dump(default, f, indent=2)
    log(
        f"Created default settings at {user_path} — edit this file to customize."
    )
    return default


def malformed_reset(user_path: Path, default: dict) -> dict:
    backup = user_path.with_suffix(".json.bak")
    shutil.copy(user_path, backup)
    with open(user_path, "w") as f:
        json.dump(default, f, indent=2)
    log(
        f"Settings malformed. Backed up to {backup.name} and reset to defaults."
    )
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

    suffix = ""
    if new_fields:
        suffix = f" New fields: {', '.join(new_fields)}."
    log(
        f"Migrated from v{old_version} to v{default['version']}.{suffix}"
    )
    return merged


def version_higher_warn(user: dict, default: dict) -> dict:
    log(
        f"User settings version (v{user['version']}) is newer than plugin "
        f"default (v{default['version']}). Proceeding as-is."
    )
    return user


def retention_cleanup(output_dir: Path, retention_days: int) -> None:
    if not output_dir.is_dir():
        return
    try:
        subprocess.run(
            [
                "find", str(output_dir),
                "-name", "daily-briefing-*",
                "-mtime", f"+{retention_days}",
                "-delete",
            ],
            check=False,
            capture_output=True,
        )
    except FileNotFoundError:
        pass


def _main() -> int:
    default = load_default()
    root = user_root()
    user_path = root / "settings.json"
    output_dir = root / "output"
    output_dir.mkdir(parents=True, exist_ok=True)

    if not user_path.exists():
        merged = first_run(user_path, default)
    elif not user_path.is_file():
        log(f"ERROR: {user_path} exists but is not a regular file. Remove it and retry.")
        return 1
    else:
        try:
            with open(user_path) as f:
                user = json.load(f)
        except (json.JSONDecodeError, OSError):
            merged = malformed_reset(user_path, default)
        else:
            user_version = user.get("version", 0)
            default_version = default["version"]
            if user_version < default_version:
                merged = migrate_up(user_path, user, default)
            elif user_version > default_version:
                merged = version_higher_warn(user, default)
            else:
                log(f"Settings OK (v{default_version}).")
                merged = user

    retention_cleanup(output_dir, int(merged.get("retention_days", 14)))
    print(json.dumps(merged))
    return 0


def main() -> int:
    try:
        return _main()
    except OSError as exc:
        log(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
