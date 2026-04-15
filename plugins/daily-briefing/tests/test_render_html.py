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


def sample_input() -> dict:
    return {
        "date_iso": "2026-04-15",
        "date_human": "Wednesday, April 15, 2026",
        "audio_path_absolute": "/tmp/daily-briefing-2026-04-15.mp3",
        "weather": "17°C, light clouds, high 19° low 11°, wind 8 km/h.",
        "lead": {
            "source_label": "HACKER NEWS",
            "title": "New AI Breakthrough",
            "url": "https://news.ycombinator.com/item?id=123",
            "image_url": "https://example.com/img.jpg",
            "summary_paragraphs": ["First paragraph.", "Second paragraph."],
        },
        "top_row_sources": [
            {
                "key": "tech-hn",
                "label": "HACKER NEWS",
                "items": [
                    {"title": "Story A", "url": "https://news.ycombinator.com/item?id=456", "summary": "Summary A."},
                    {"title": "Story B", "url": "https://news.ycombinator.com/item?id=789", "summary": "Summary B."},
                ],
            },
            {
                "key": "tech-devto",
                "label": "DEV.TO",
                "items": [
                    {"title": "Post X", "url": "https://dev.to/author/post-x", "summary": "Post summary."},
                ],
            },
        ],
        "bottom_row_sources": {
            "space_science": {"items": [{"title": "APOD today", "url": "https://apod.nasa.gov/apod/ap260415.html", "summary": "A nice galaxy."}], "apod_image_url": "https://apod.nasa.gov/img.jpg"},
            "gaming":        {"items": [{"title": "Game release", "url": "https://example.com/game", "summary": "A game."}]},
            "maker_hobby":   {"items": [{"title": "Maker project", "url": "https://example.com/maker", "summary": "A project."}]},
            "news_ap":       {"items": [{"title": "Headline", "url": "https://apnews.com/article/abc", "summary": "News."}]},
        },
        "closing": {
            "today_in_history": {"holidays": "🥧 Pi Day", "events": "1879 — Einstein born"},
            "quote": {"text": "Knowledge is power.", "author": "Bacon"},
        },
    }


def render(data: dict, tmp: Path) -> tuple[subprocess.CompletedProcess, str]:
    """Write data to a tmp JSON, run the script, return (result, html)."""
    in_path = tmp / "in.json"
    out_path = tmp / "out.html"
    in_path.write_text(json.dumps(data))
    result = run_script(in_path, out_path)
    html = out_path.read_text() if out_path.exists() else ""
    return result, html


class TestRenderHtmlSkeleton(unittest.TestCase):
    def test_emits_self_contained_html(self):
        with tempfile.TemporaryDirectory() as tmp:
            result, html = render(sample_input(), Path(tmp))
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn("<!DOCTYPE html>", html)
            self.assertIn('<meta name="darkreader-lock"', html)
            self.assertIn('data-theme="light"', html)
            self.assertIn("--bg-paper", html)
            self.assertIn("audio-bar", html)
            self.assertIn("/tmp/daily-briefing-2026-04-15.mp3", html)


class TestLeadStory(unittest.TestCase):
    def test_lead_story_rendered_with_image_and_link(self):
        with tempfile.TemporaryDirectory() as tmp:
            result, html_out = render(sample_input(), Path(tmp))
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn("HACKER NEWS", html_out)
            self.assertIn("New AI Breakthrough", html_out)
            self.assertIn('href="https://news.ycombinator.com/item?id=123"', html_out)
            self.assertIn('src="https://example.com/img.jpg"', html_out)
            self.assertIn("First paragraph.", html_out)
            self.assertIn("Second paragraph.", html_out)

    def test_lead_story_without_image_omits_img_tag(self):
        data = sample_input()
        data["lead"]["image_url"] = None
        with tempfile.TemporaryDirectory() as tmp:
            result, html_out = render(data, Path(tmp))
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertNotIn("<img", html_out.split("weather-bar")[1].split("row")[0])


class TestBottomRow(unittest.TestCase):
    def test_bottom_row_4_columns_when_extra_present(self):
        data = sample_input()
        data["bottom_row_sources"]["extra"] = {"items": [{"title": "E", "url": "https://example.com/e", "summary": "E."}]}
        with tempfile.TemporaryDirectory() as tmp:
            result, html_out = render(data, Path(tmp))
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn('class="row row-bottom row-bottom-4"', html_out)
            self.assertIn("APOD today", html_out)
            self.assertIn("Game release", html_out)
            self.assertIn("Maker project", html_out)
            self.assertIn("Headline", html_out)
            self.assertIn("E.", html_out)

    def test_bottom_row_3_columns_when_extra_absent(self):
        data = sample_input()
        with tempfile.TemporaryDirectory() as tmp:
            result, html_out = render(data, Path(tmp))
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn('class="row row-bottom row-bottom-3"', html_out)
            self.assertNotIn('class="row row-bottom row-bottom-4"', html_out)

    def test_apod_image_rendered_when_present(self):
        data = sample_input()
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertIn('src="https://apod.nasa.gov/img.jpg"', html_out)

    def test_empty_source_skipped(self):
        data = sample_input()
        data["bottom_row_sources"]["gaming"] = {"items": []}
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertNotIn("GAMING", html_out)


class TestClosingSection(unittest.TestCase):
    def test_closing_full_when_both_enabled(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(sample_input(), Path(tmp))
            self.assertIn("ON THIS DAY", html_out)
            self.assertIn("Pi Day", html_out)
            self.assertIn("Einstein born", html_out)
            self.assertIn("Knowledge is power.", html_out)
            self.assertIn("Bacon", html_out)

    def test_closing_omitted_when_both_subkeys_missing(self):
        data = sample_input()
        data["closing"] = {}
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertNotIn('class="closing-section"', html_out)
            self.assertNotIn("ON THIS DAY", html_out)

    def test_quote_only(self):
        data = sample_input()
        data["closing"] = {"quote": {"text": "Solo.", "author": "X"}}
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertIn("Solo.", html_out)
            self.assertNotIn("ON THIS DAY", html_out)


class TestUrlAndEscaping(unittest.TestCase):
    def test_denylisted_homepage_url_dropped_to_plain_text(self):
        data = sample_input()
        data["top_row_sources"][0]["items"][0]["url"] = "https://news.ycombinator.com/news"
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertNotIn('href="https://news.ycombinator.com/news"', html_out)
            self.assertIn("Story A", html_out)

    def test_missing_url_renders_plain_text(self):
        data = sample_input()
        data["top_row_sources"][0]["items"][0].pop("url", None)
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertNotIn("Story A</a>", html_out)
            self.assertIn("Story A", html_out)

    def test_html_special_chars_escaped(self):
        data = sample_input()
        data["lead"]["title"] = 'Rise of <script>alert("xss")</script>'
        data["lead"]["summary_paragraphs"] = ['A & B < C > D']
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertNotIn("<script>alert", html_out)
            self.assertIn("&lt;script&gt;", html_out)
            self.assertIn("A &amp; B &lt; C &gt; D", html_out)

    def test_malformed_input_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_p = Path(tmp)
            in_path = tmp_p / "bad.json"
            in_path.write_text("{not-valid")
            out_path = tmp_p / "out.html"
            result = run_script(in_path, out_path)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(not out_path.exists() or out_path.stat().st_size == 0)

    def test_missing_required_field_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_p = Path(tmp)
            in_path = tmp_p / "in.json"
            in_path.write_text(json.dumps({"date_iso": "2026-04-15"}))
            out_path = tmp_p / "out.html"
            result = run_script(in_path, out_path)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Missing required field", result.stderr)


class TestTopRowDividers(unittest.TestCase):
    def test_dividers_placed_between_stacked_items_not_after(self):
        data = sample_input()
        # Three top sources: i=0 goes mid, i=1 goes right, i=2 goes mid
        data["top_row_sources"].append({
            "key": "tech-github",
            "label": "GITHUB",
            "items": [{"title": "Repo Z", "url": "https://github.com/user/repo", "summary": "Z."}],
        })
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            # mid column should contain HACKER NEWS ... <hr> ... GITHUB
            # Find the mid column boundaries
            hn_idx = html_out.find("HACKER NEWS")
            gh_idx = html_out.find("GITHUB")
            self.assertGreater(gh_idx, hn_idx, "GITHUB should come after HACKER NEWS in mid col")
            between = html_out[hn_idx:gh_idx]
            self.assertIn("col-divider", between, "Divider should be between HN and GH, not after GH")


class TestUrlProtocolGuard(unittest.TestCase):
    def test_javascript_url_rejected(self):
        data = sample_input()
        data["lead"]["url"] = "javascript:alert(1)"
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertNotIn('href="javascript:', html_out)

    def test_devto_article_url_kept(self):
        data = sample_input()
        # Regression: article URLs on dev.to must survive (previously denied by substring match)
        data["top_row_sources"][1]["items"][0]["url"] = "https://dev.to/author/my-post"
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertIn('href="https://dev.to/author/my-post"', html_out)

    def test_devto_homepage_url_dropped(self):
        data = sample_input()
        data["top_row_sources"][1]["items"][0]["url"] = "https://dev.to/"
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertNotIn('href="https://dev.to/"', html_out)


if __name__ == "__main__":
    unittest.main()
