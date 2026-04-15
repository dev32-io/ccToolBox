"""Black-box tests for build_data_json.py.

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
    / "skills" / "daily-briefing" / "scripts" / "build_data_json.py"
)
DEFAULT_SETTINGS_PATH = (
    Path(__file__).parent.parent
    / "skills" / "daily-briefing" / "settings.default.json"
)


def run_script(home: Path, date_iso: str) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env["HOME"] = str(home)
    return subprocess.run(
        [sys.executable, str(SCRIPT_PATH), date_iso],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def setup_staging(home: Path, date_iso: str, customize_extra: bool = False) -> Path:
    """Create settings + staging dir for a test. Returns staging path."""
    root = home / ".ccToolBox" / "daily-briefing"
    output = root / "output"
    staging = output / f"staging-{date_iso}"
    staging.mkdir(parents=True)
    # Copy default settings
    defaults = json.loads(DEFAULT_SETTINGS_PATH.read_text())
    if customize_extra:
        for src in defaults["sources"]:
            if src["key"] == "extra":
                src["description"] = "custom user tech"
    (root / "settings.json").write_text(json.dumps(defaults))
    return staging


class TestMinimalBuild(unittest.TestCase):
    def test_weather_and_one_top_source_assembles(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            staging = setup_staging(home, "2026-04-15")
            (staging / "weather.txt").write_text("Cloudy, 15C.")
            (staging / "tech-hn.json").write_text(json.dumps([
                {"title": "Story A", "url": "https://example.com/a", "summary": "A."}
            ]))
            result = run_script(home, "2026-04-15")
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            out = json.loads((home / ".ccToolBox/daily-briefing/output/daily-briefing-2026-04-15.json").read_text())
            self.assertEqual(out["date_iso"], "2026-04-15")
            self.assertIn("Wednesday", out["date_human"])
            self.assertTrue(out["audio_path_absolute"].endswith("daily-briefing-2026-04-15.mp3"))
            self.assertTrue(out["audio_path_absolute"].startswith(str(home)))
            self.assertEqual(out["weather"], "Cloudy, 15C.")
            self.assertEqual(len(out["top_row_sources"]), 1)
            self.assertEqual(out["top_row_sources"][0]["label"], "HACKER NEWS")


class TestLeadRemoval(unittest.TestCase):
    def test_lead_item_removed_from_its_source_list(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            staging = setup_staging(home, "2026-04-15")
            (staging / "tech-hn.json").write_text(json.dumps([
                {"title": "Lead Story", "url": "https://ex/a", "summary": "L."},
                {"title": "Other", "url": "https://ex/b", "summary": "O."},
            ]))
            (staging / "lead.json").write_text(json.dumps({
                "source_key": "tech-hn",
                "title": "Lead Story",
                "url": "https://ex/a",
                "image_url": None,
                "summary_paragraphs": ["Full lead summary."]
            }))
            result = run_script(home, "2026-04-15")
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            out = json.loads((home / ".ccToolBox/daily-briefing/output/daily-briefing-2026-04-15.json").read_text())
            self.assertEqual(out["lead"]["source_label"], "HACKER NEWS")
            self.assertEqual(out["lead"]["title"], "Lead Story")
            hn_items = out["top_row_sources"][0]["items"]
            titles = [it["title"] for it in hn_items]
            self.assertNotIn("Lead Story", titles)
            self.assertIn("Other", titles)


class TestBottomRow(unittest.TestCase):
    def test_apod_image_extracted_to_top_level(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            staging = setup_staging(home, "2026-04-15")
            (staging / "space-science.json").write_text(json.dumps([
                {"title": "APOD", "url": "https://apod/x", "summary": "Galaxy.", "image_url": "https://apod/img.jpg"},
                {"title": "Other", "url": "https://space/y", "summary": "Space.", "image_url": ""}
            ]))
            result = run_script(home, "2026-04-15")
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            out = json.loads((home / ".ccToolBox/daily-briefing/output/daily-briefing-2026-04-15.json").read_text())
            ss = out["bottom_row_sources"]["space_science"]
            self.assertEqual(ss["apod_image_url"], "https://apod/img.jpg")
            # image_url stripped from per-item
            for item in ss["items"]:
                self.assertNotIn("image_url", item)

    def test_empty_source_json_file_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            staging = setup_staging(home, "2026-04-15")
            (staging / "gaming.json").write_text(json.dumps([]))
            (staging / "news-ap.json").write_text(json.dumps([
                {"title": "H1", "url": "https://ap/1", "summary": "s."}
            ]))
            result = run_script(home, "2026-04-15")
            out = json.loads((home / ".ccToolBox/daily-briefing/output/daily-briefing-2026-04-15.json").read_text())
            self.assertNotIn("gaming", out["bottom_row_sources"])
            self.assertIn("news_ap", out["bottom_row_sources"])

    def test_extra_included_only_when_customized(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            # Default extra description = not customized
            staging = setup_staging(home, "2026-04-15", customize_extra=False)
            (staging / "extra.json").write_text(json.dumps([
                {"title": "X", "url": "https://ex/x", "summary": "x."}
            ]))
            result = run_script(home, "2026-04-15")
            out = json.loads((home / ".ccToolBox/daily-briefing/output/daily-briefing-2026-04-15.json").read_text())
            self.assertNotIn("extra", out["bottom_row_sources"])

        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            staging = setup_staging(home, "2026-04-16", customize_extra=True)
            (staging / "extra.json").write_text(json.dumps([
                {"title": "X", "url": "https://ex/x", "summary": "x."}
            ]))
            result = run_script(home, "2026-04-16")
            out = json.loads((home / ".ccToolBox/daily-briefing/output/daily-briefing-2026-04-16.json").read_text())
            self.assertIn("extra", out["bottom_row_sources"])


class TestClosing(unittest.TestCase):
    def test_closing_included_when_toggles_on_and_files_present(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            staging = setup_staging(home, "2026-04-15")
            (staging / "today_in_history.json").write_text(json.dumps({
                "holidays": "Test Day",
                "events": "1879 — Einstein born"
            }))
            (staging / "quote.json").write_text(json.dumps({
                "text": "Seeking is everything.",
                "author": "Einstein"
            }))
            result = run_script(home, "2026-04-15")
            out = json.loads((home / ".ccToolBox/daily-briefing/output/daily-briefing-2026-04-15.json").read_text())
            self.assertIn("closing", out)
            self.assertEqual(out["closing"]["today_in_history"]["holidays"], "Test Day")
            self.assertEqual(out["closing"]["quote"]["text"], "Seeking is everything.")

    def test_closing_omitted_when_files_absent(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            staging = setup_staging(home, "2026-04-15")
            result = run_script(home, "2026-04-15")
            out = json.loads((home / ".ccToolBox/daily-briefing/output/daily-briefing-2026-04-15.json").read_text())
            self.assertNotIn("closing", out)


class TestErrors(unittest.TestCase):
    def test_missing_staging_dir_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            # No setup_staging — staging dir is missing
            (home / ".ccToolBox" / "daily-briefing").mkdir(parents=True)
            (home / ".ccToolBox" / "daily-briefing" / "settings.json").write_text(
                DEFAULT_SETTINGS_PATH.read_text()
            )
            result = run_script(home, "2026-04-15")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Staging directory not found", result.stderr)

    def test_bad_date_format_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            result = run_script(home, "not-a-date")
            self.assertNotEqual(result.returncode, 0)

    def test_missing_date_arg_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            env = os.environ.copy()
            env["HOME"] = str(home)
            result = subprocess.run(
                [sys.executable, str(SCRIPT_PATH)],
                env=env, capture_output=True, text=True, check=False,
            )
            self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
