"""Black-box tests for render_html.py."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).parent.parent
    / "skills" / "daily-briefing" / "scripts" / "render_html.py"
)


def run_script(input_json_path: Path, output_html_path: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT_PATH), str(input_json_path), str(output_html_path)],
        capture_output=True,
        text=True,
        check=False,
    )


class TestRenderHtmlScaffold(unittest.TestCase):
    def test_script_exists(self):
        self.assertTrue(SCRIPT_PATH.exists(), f"Missing: {SCRIPT_PATH}")


if __name__ == "__main__":
    unittest.main()
