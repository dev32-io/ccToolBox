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


class TestInitSettingsScaffold(unittest.TestCase):
    def test_script_exists(self):
        self.assertTrue(SCRIPT_PATH.exists(), f"Missing: {SCRIPT_PATH}")


if __name__ == "__main__":
    unittest.main()
