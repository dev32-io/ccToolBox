"""Black-box tests for init_settings.py.

Runs the script as a subprocess with a custom HOME to isolate filesystem side effects.
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).parent.parent
    / "skills" / "daily-briefing" / "scripts" / "init_settings.py"
)


def run_script(home: Path) -> subprocess.CompletedProcess:
    """Run init_settings.py with HOME overridden. Returns CompletedProcess."""
    env = os.environ.copy()
    env["HOME"] = str(home)
    return subprocess.run(
        [sys.executable, str(SCRIPT_PATH)],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


class TestFirstRun(unittest.TestCase):
    def test_creates_settings_and_output_dir_on_first_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            result = run_script(home)
            self.assertEqual(result.returncode, 0, msg=result.stderr)

            settings_path = home / ".ccToolBox" / "daily-briefing" / "settings.json"
            output_dir = home / ".ccToolBox" / "daily-briefing" / "output"
            self.assertTrue(settings_path.exists())
            self.assertTrue(output_dir.is_dir())

            with open(settings_path) as f:
                user = json.load(f)
            self.assertEqual(user["version"], 2)
            self.assertEqual(user["voice"], "en-US-AvaMultilingualNeural")

            stdout = json.loads(result.stdout)
            self.assertEqual(stdout["version"], 2)
            self.assertIn("Created default settings", result.stderr)


class TestMalformedReset(unittest.TestCase):
    def test_malformed_user_file_is_backed_up_and_reset(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            settings_dir = home / ".ccToolBox" / "daily-briefing"
            settings_dir.mkdir(parents=True)
            bad = settings_dir / "settings.json"
            bad.write_text("{not valid json")

            result = run_script(home)
            self.assertEqual(result.returncode, 0, msg=result.stderr)

            self.assertTrue((settings_dir / "settings.json.bak").exists())
            reset = json.loads((settings_dir / "settings.json").read_text())
            self.assertEqual(reset["version"], 2)
            self.assertIn("malformed", result.stderr.lower())


class TestVersionMigration(unittest.TestCase):
    def test_user_version_lower_migrates_and_preserves_user_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            settings_dir = home / ".ccToolBox" / "daily-briefing"
            settings_dir.mkdir(parents=True)
            old = {
                "version": 1,
                "voice": "custom-voice",
                "location": "Tokyo, Japan",
            }
            (settings_dir / "settings.json").write_text(json.dumps(old))

            result = run_script(home)
            self.assertEqual(result.returncode, 0, msg=result.stderr)

            migrated = json.loads((settings_dir / "settings.json").read_text())
            self.assertEqual(migrated["version"], 2)
            self.assertEqual(migrated["voice"], "custom-voice")
            self.assertEqual(migrated["location"], "Tokyo, Japan")
            self.assertIn("sources", migrated)
            self.assertIn("retention_days", migrated)

            self.assertTrue((settings_dir / "settings.json.v1.bak").exists())
            self.assertIn("Migrated", result.stderr)

    def test_user_version_higher_proceeds_with_user_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            settings_dir = home / ".ccToolBox" / "daily-briefing"
            settings_dir.mkdir(parents=True)
            newer = {
                "version": 99,
                "voice": "future-voice",
                "location": "Mars",
                "sources": [],
                "retention_days": 14,
                "today_in_history": True,
                "inspiration_quote": True,
            }
            (settings_dir / "settings.json").write_text(json.dumps(newer))

            result = run_script(home)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            stdout = json.loads(result.stdout)
            self.assertEqual(stdout["version"], 99)
            self.assertEqual(stdout["voice"], "future-voice")
            self.assertIn("newer", result.stderr.lower())

    def test_matching_version_no_op(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            settings_dir = home / ".ccToolBox" / "daily-briefing"
            settings_dir.mkdir(parents=True)
            current = json.loads(
                (SCRIPT_PATH.parent.parent / "settings.default.json").read_text()
            )
            current["voice"] = "user-chosen-voice"
            (settings_dir / "settings.json").write_text(json.dumps(current))

            result = run_script(home)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            stdout = json.loads(result.stdout)
            self.assertEqual(stdout["voice"], "user-chosen-voice")
            self.assertIn("Settings OK", result.stderr)


import time


class TestRetentionCleanup(unittest.TestCase):
    def test_old_output_files_deleted_after_retention_days(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            output_dir = home / ".ccToolBox" / "daily-briefing" / "output"
            output_dir.mkdir(parents=True)

            old_file = output_dir / "daily-briefing-2025-01-01.html"
            old_file.write_text("ancient")
            thirty_days_ago = time.time() - (30 * 24 * 60 * 60)
            os.utime(old_file, (thirty_days_ago, thirty_days_ago))

            fresh_file = output_dir / "daily-briefing-today.html"
            fresh_file.write_text("fresh")

            result = run_script(home)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertFalse(old_file.exists(), "old file should be deleted")
            self.assertTrue(fresh_file.exists(), "fresh file should survive")


if __name__ == "__main__":
    unittest.main()
