# Daily Briefing Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flatten the daily-briefing plugin so smaller models can execute it reliably. Move migration, HTML rendering, and path discovery out of prose and into scripts. Ship a sibling OpenCode plugin.

**Architecture:** Two independent plugins (`plugins/daily-briefing` for Claude Code, `plugins/daily-briefing-opencode` for OpenCode). Each skill dir is self-contained — SKILL.md + `scripts/init_settings.py` + `scripts/render_html.py` + `scripts/tts.sh` + `settings.default.json`. Scripts self-locate via `__file__`. CC uses `${CLAUDE_SKILL_DIR}` for invocation, OC uses the injected "Base directory for this skill" context. Storage path normalized to `~/.ccToolBox/daily-briefing/`.

**Tech Stack:** Python 3 stdlib (no pip deps), Bash, Docker (for TTS, unchanged). Tests use stdlib `unittest` with subprocess-based black-box testing.

**Spec:** `docs/superpowers/specs/2026-04-15-daily-briefing-simplify-design.md`

---

## File Structure

### Created
- `plugins/daily-briefing/skills/daily-briefing/scripts/init_settings.py` — settings migration
- `plugins/daily-briefing/skills/daily-briefing/scripts/render_html.py` — HTML generator
- `plugins/daily-briefing/skills/daily-briefing/scripts/tts.sh` — MOVED from `plugins/daily-briefing/scripts/tts.sh`
- `plugins/daily-briefing/skills/daily-briefing/settings.default.json` — replaces `settings.default.md`
- `plugins/daily-briefing/tests/__init__.py`
- `plugins/daily-briefing/tests/test_init_settings.py`
- `plugins/daily-briefing/tests/test_render_html.py`
- `plugins/daily-briefing-opencode/.claude-plugin/plugin.json` — marker file (not registered in marketplace)
- `plugins/daily-briefing-opencode/skills/daily-briefing/SKILL.md`
- `plugins/daily-briefing-opencode/skills/daily-briefing/scripts/init_settings.py` (copy)
- `plugins/daily-briefing-opencode/skills/daily-briefing/scripts/render_html.py` (copy)
- `plugins/daily-briefing-opencode/skills/daily-briefing/scripts/tts.sh` (copy)
- `plugins/daily-briefing-opencode/skills/daily-briefing/settings.default.json`
- `plugins/daily-briefing-opencode/README.md`
- `plugins/daily-briefing-opencode/CHANGELOG.md`

### Modified
- `plugins/daily-briefing/skills/daily-briefing/SKILL.md` — full rewrite (flat flow)
- `plugins/daily-briefing/.claude-plugin/plugin.json` — bump to `2.0.0`
- `plugins/daily-briefing/CHANGELOG.md` — add `2.0.0` entry
- `plugins/daily-briefing/README.md` — path fixes, version bump
- `plugins/daily-briefing/CLAUDE.md` — path fixes
- `.claude-plugin/marketplace.json` — bump daily-briefing to `2.0.0`
- `CLAUDE.md` (repo root) — convention path fix, JSON settings note
- `.opencode/plugins/INSTALL.md` — paths + new OC plugin location

### Deleted
- `plugins/daily-briefing/agents/daily-briefing-agent.md`
- `plugins/daily-briefing/agents/` (empty dir)
- `plugins/daily-briefing/scripts/tts.sh` (moved)
- `plugins/daily-briefing/scripts/` (empty dir)
- `plugins/daily-briefing/settings.default.md`
- `plugins/daily-briefing/docs/` (stale `simplified-instructions.md`)

---

## Task 1: Scaffolding — settings.default.json, test harness, directories

**Files:**
- Create: `plugins/daily-briefing/skills/daily-briefing/settings.default.json`
- Create: `plugins/daily-briefing/skills/daily-briefing/scripts/` (directory)
- Create: `plugins/daily-briefing/tests/__init__.py`
- Create: `plugins/daily-briefing/tests/test_init_settings.py` (empty scaffold)
- Create: `plugins/daily-briefing/tests/test_render_html.py` (empty scaffold)

---

- [ ] **Step 1.1: Create the skill scripts directory**

```bash
mkdir -p plugins/daily-briefing/skills/daily-briefing/scripts
```

- [ ] **Step 1.2: Create `settings.default.json`**

Write `plugins/daily-briefing/skills/daily-briefing/settings.default.json`:

```json
{
  "version": 2,
  "voice": "en-US-AvaMultilingualNeural",
  "location": "Burnaby, BC, Canada",
  "sources": [
    {"key": "weather",         "description": "short summary for {location}"},
    {"key": "tech-hn",         "description": "2-5 items from Hacker News (AI, CS, tech)"},
    {"key": "tech-devto",      "description": "2-5 items from Dev.to (AI, CS, tech)"},
    {"key": "tech-github",     "description": "3-5 trending repositories from GitHub"},
    {"key": "tech-tc",         "description": "2-3 top TechCrunch headlines"},
    {"key": "reddit-claudeai", "description": "2-5 hot new posts from r/ClaudeAI"},
    {"key": "ai-ml",           "description": "2-3 items from arXiv AI + The Batch"},
    {"key": "space-science",   "description": "1-2 items from NASA, SpaceX, space news"},
    {"key": "gaming",          "description": "2-3 items from r/gaming, game releases"},
    {"key": "maker-hobby",     "description": "1-2 items from Instructables, r/3Dprinting"},
    {"key": "news-ap",         "description": "2-5 very short headlines from AP News"},
    {"key": "extra",           "description": "(add your own sections here)"}
  ],
  "retention_days": 14,
  "today_in_history": true,
  "inspiration_quote": true
}
```

- [ ] **Step 1.3: Verify JSON parses**

Run:
```bash
python3 -c "import json; json.load(open('plugins/daily-briefing/skills/daily-briefing/settings.default.json')); print('OK')"
```
Expected: `OK`

- [ ] **Step 1.4: Create the test directory and scaffolding**

```bash
mkdir -p plugins/daily-briefing/tests
```

Write `plugins/daily-briefing/tests/__init__.py` (empty file):

```python
```

Write `plugins/daily-briefing/tests/test_init_settings.py`:

```python
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
```

Write `plugins/daily-briefing/tests/test_render_html.py`:

```python
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
```

- [ ] **Step 1.5: Run scaffold tests (both should fail — scripts don't exist yet)**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest discover tests -v
```
Expected: 2 test failures, both asserting the script file does not exist yet. This is the baseline.

- [ ] **Step 1.6: Commit**

```bash
git add plugins/daily-briefing/skills/daily-briefing/settings.default.json plugins/daily-briefing/tests/
git commit -m "$(cat <<'EOF'
daily-briefing: scaffold settings.default.json and test harness

Start of v2.0.0 refactor. Adds JSON-shaped default settings and subprocess-based
black-box test harness for upcoming init_settings.py and render_html.py scripts.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Implement `init_settings.py`

Test-driven. Each branch gets a failing test first, then the minimal implementation to make it pass.

**Files:**
- Create: `plugins/daily-briefing/skills/daily-briefing/scripts/init_settings.py`
- Modify: `plugins/daily-briefing/tests/test_init_settings.py`

---

- [ ] **Step 2.1: Write a test for the first-run branch**

Replace `TestInitSettingsScaffold` in `plugins/daily-briefing/tests/test_init_settings.py` with:

```python
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
```

- [ ] **Step 2.2: Run the test (must fail because script doesn't exist)**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_init_settings -v
```
Expected: FAIL — test fails when subprocess returns a non-zero exit code or the file is missing.

- [ ] **Step 2.3: Create the initial `init_settings.py` with the first-run branch**

Write `plugins/daily-briefing/skills/daily-briefing/scripts/init_settings.py`:

```python
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


def main() -> int:
    default = load_default()
    root = user_root()
    user_path = root / "settings.json"
    output_dir = root / "output"
    output_dir.mkdir(parents=True, exist_ok=True)

    if not user_path.exists():
        merged = first_run(user_path, default)
    else:
        # Placeholder — later tasks add the other branches.
        with open(user_path) as f:
            merged = json.load(f)

    print(json.dumps(merged))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Then mark it executable:
```bash
chmod +x plugins/daily-briefing/skills/daily-briefing/scripts/init_settings.py
```

- [ ] **Step 2.4: Run the first-run test — must pass**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_init_settings.TestFirstRun -v
```
Expected: PASS.

- [ ] **Step 2.5: Write a test for the malformed branch**

Append to `plugins/daily-briefing/tests/test_init_settings.py`:

```python
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
```

- [ ] **Step 2.6: Run the malformed test — must fail**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_init_settings.TestMalformedReset -v
```
Expected: FAIL — subprocess likely raises `json.JSONDecodeError` and exits non-zero.

- [ ] **Step 2.7: Add the malformed branch**

In `plugins/daily-briefing/skills/daily-briefing/scripts/init_settings.py`, add this function above `main`:

```python
def malformed_reset(user_path: Path, default: dict) -> dict:
    backup = user_path.with_suffix(".json.bak")
    shutil.copy(user_path, backup)
    with open(user_path, "w") as f:
        json.dump(default, f, indent=2)
    log(
        f"Settings malformed. Backed up to {backup.name} and reset to defaults."
    )
    return default
```

Update `main` — replace the `else:` block with:

```python
    if not user_path.exists():
        merged = first_run(user_path, default)
    else:
        try:
            with open(user_path) as f:
                user = json.load(f)
        except (json.JSONDecodeError, OSError):
            merged = malformed_reset(user_path, default)
        else:
            # Placeholder for version-check branches (next steps).
            merged = user

    print(json.dumps(merged))
    return 0
```

- [ ] **Step 2.8: Run the malformed test — must pass**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_init_settings.TestMalformedReset -v
```
Expected: PASS.

- [ ] **Step 2.9: Write tests for the version-migration branches**

Append to `plugins/daily-briefing/tests/test_init_settings.py`:

```python
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
```

- [ ] **Step 2.10: Run the migration tests — must fail**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_init_settings.TestVersionMigration -v
```
Expected: FAIL across all three tests.

- [ ] **Step 2.11: Add the version-migration branches**

In `plugins/daily-briefing/skills/daily-briefing/scripts/init_settings.py`, add above `main`:

```python
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
```

Replace the `else:` tail inside `main` (where `merged = user` was the placeholder) with:

```python
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
```

- [ ] **Step 2.12: Run the migration tests — must pass**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_init_settings.TestVersionMigration -v
```
Expected: PASS across all three tests.

- [ ] **Step 2.13: Write a test for retention cleanup**

Append to `plugins/daily-briefing/tests/test_init_settings.py`:

```python
import time


class TestRetentionCleanup(unittest.TestCase):
    def test_old_output_files_deleted_after_retention_days(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            output_dir = home / ".ccToolBox" / "daily-briefing" / "output"
            output_dir.mkdir(parents=True)

            # File 30 days old — should be deleted (retention_days = 14 in default)
            old_file = output_dir / "daily-briefing-2025-01-01.html"
            old_file.write_text("ancient")
            thirty_days_ago = time.time() - (30 * 24 * 60 * 60)
            os.utime(old_file, (thirty_days_ago, thirty_days_ago))

            # Fresh file — should survive
            fresh_file = output_dir / "daily-briefing-today.html"
            fresh_file.write_text("fresh")

            result = run_script(home)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertFalse(old_file.exists(), "old file should be deleted")
            self.assertTrue(fresh_file.exists(), "fresh file should survive")
```

- [ ] **Step 2.14: Run the retention test — must fail**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_init_settings.TestRetentionCleanup -v
```
Expected: FAIL — no retention cleanup yet.

- [ ] **Step 2.15: Add retention cleanup**

In `plugins/daily-briefing/skills/daily-briefing/scripts/init_settings.py`, add above `main`:

```python
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
        pass  # find not available — skip silently
```

Call it at the end of `main`, just before the `print`:

```python
    retention_cleanup(output_dir, int(merged.get("retention_days", 14)))
    print(json.dumps(merged))
    return 0
```

- [ ] **Step 2.16: Run the retention test — must pass**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_init_settings.TestRetentionCleanup -v
```
Expected: PASS.

- [ ] **Step 2.17: Run the full `init_settings` test suite**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_init_settings -v
```
Expected: all 6 tests pass.

- [ ] **Step 2.18: Commit**

```bash
git add plugins/daily-briefing/skills/daily-briefing/scripts/init_settings.py plugins/daily-briefing/tests/test_init_settings.py
git commit -m "$(cat <<'EOF'
daily-briefing: add init_settings.py with deterministic migration

Handles first-run copy, malformed reset, version-up migration, version-down
warning, and retention cleanup. Moves the 6-branch migration logic from skill
prose into code so smaller models never have to execute it.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Implement `render_html.py`

Test-driven. Build the HTML generator incrementally — skeleton first, then each content block, then escaping/denylist enforcement.

**Files:**
- Create: `plugins/daily-briefing/skills/daily-briefing/scripts/render_html.py`
- Modify: `plugins/daily-briefing/tests/test_render_html.py`

---

- [ ] **Step 3.1: Add a test helper for building sample input JSON**

Replace `TestRenderHtmlScaffold` in `plugins/daily-briefing/tests/test_render_html.py` with this fuller scaffold:

```python
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
```

- [ ] **Step 3.2: Run the skeleton test — must fail**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_render_html.TestRenderHtmlSkeleton -v
```
Expected: FAIL — script does not exist yet.

- [ ] **Step 3.3: Create `render_html.py` with the skeleton**

Write `plugins/daily-briefing/skills/daily-briefing/scripts/render_html.py`:

```python
#!/usr/bin/env python3
"""Render a daily briefing HTML page from a structured JSON input.

Usage: render_html.py <input.json> <output.html>

All layout/theming rules live in this script — the calling skill never writes HTML.
"""
from __future__ import annotations

import html
import json
import sys
from pathlib import Path


THEME_CSS = """
:root[data-theme="light"] {
  --bg-page: #E8DCC8; --bg-paper: #F2E8D0; --bg-paper-mid: #EDE3C7;
  --bg-paper-end: #E9DDBF; --bg-accent: #E5D9BF; --border-heavy: #6B6155;
  --border-light: #C8BC9F; --text-title: #3E3830; --text-body: #5A5245;
  --text-muted: #8A7E6E; --text-faint: #9A8E7E; --img-bg: #DDD1B5;
  --btn-bg: #5A5245; --btn-text: #F2E8D0; --btn-hover: #6B6155;
  --shadow: rgba(0,0,0,0.15);
}
:root[data-theme="dark"] {
  --bg-page: #1A1610; --bg-paper: #252015; --bg-paper-mid: #221D13;
  --bg-paper-end: #201C12; --bg-accent: #2A2418; --border-heavy: #8A7E6A;
  --border-light: #3D362A; --text-title: #D4C8A8; --text-body: #B0A48A;
  --text-muted: #7A6E5A; --text-faint: #5A5040; --img-bg: #2E2820;
  --btn-bg: #D4C8A8; --btn-text: #1A1610; --btn-hover: #E0D4B4;
  --shadow: rgba(0,0,0,0.4);
}
* { box-sizing: border-box; }
body {
  margin: 0; padding: 20px; background: var(--bg-page);
  font-family: 'Georgia', 'Times New Roman', serif; color: var(--text-body);
}
.newspaper {
  max-width: 960px; margin: 0 auto;
  background: linear-gradient(180deg, var(--bg-paper), var(--bg-paper-mid), var(--bg-paper-end));
  padding: 24px; box-shadow: 0 2px 16px var(--shadow);
}
.audio-bar {
  display: flex; align-items: center; gap: 12px; padding: 10px 0 16px;
  border-bottom: 1px solid var(--border-light);
}
.play-btn {
  background: var(--btn-bg); color: var(--btn-text);
  border: none; padding: 8px 14px; font-family: inherit; font-size: 12px;
  letter-spacing: 1px; cursor: pointer; text-transform: uppercase;
}
.play-btn:hover { background: var(--btn-hover); }
.audio-track { flex: 1; height: 3px; background: var(--border-light); position: relative; }
.audio-track::after { content: ''; position: absolute; left:0; top:0; bottom:0; width: var(--progress, 0%); background: var(--border-heavy); }
.audio-time { font-size: 10px; color: var(--text-muted); font-variant-numeric: tabular-nums; }
.theme-toggle {
  position: fixed; top: 16px; right: 16px; z-index: 10;
  background: var(--btn-bg); color: var(--btn-text);
  border: none; padding: 6px 12px; font-size: 10px; letter-spacing: 1px;
  border-radius: 999px; cursor: pointer; text-transform: uppercase;
}
.masthead { text-align: center; padding: 8px 0 0; }
.masthead-date { font-size: 10px; letter-spacing: 2px; color: var(--text-muted); text-transform: uppercase; }
.masthead-title { font-size: 48px; font-weight: 900; letter-spacing: 2px; margin: 4px 0; color: var(--text-title); text-transform: uppercase; }
.masthead-subtitle { font-size: 10px; letter-spacing: 3px; color: var(--text-faint); text-transform: uppercase; }
.masthead-rule { border: none; border-top: 3px double var(--border-heavy); margin: 10px 0 4px; }
.weather-bar { text-align: center; padding: 6px 0 10px; font-size: 11px; color: var(--text-muted); font-style: italic; border-bottom: 1.5px solid var(--border-heavy); }
.row { display: grid; gap: 16px; padding: 14px 0; }
.row-top { grid-template-columns: 2fr 1fr 1fr; border-bottom: 1.5px solid var(--border-heavy); }
.row-bottom-4 { grid-template-columns: 1fr 1fr 1.2fr 1fr; }
.row-bottom-3 { grid-template-columns: 1fr 1fr 1fr; }
.col { padding: 0 12px; border-right: 1px solid var(--border-light); }
.col:first-child { padding-left: 0; }
.col:last-child { padding-right: 0; border-right: none; }
.col-divider { border: none; border-top: 1px solid var(--border-light); margin: 10px 0; }
.section-label { font-size: 8px; letter-spacing: 2px; color: var(--text-faint); text-transform: uppercase; margin-bottom: 4px; }
.header-big { font-size: 22px; font-weight: 800; text-transform: uppercase; color: var(--text-title); margin: 2px 0 8px; line-height: 1.1; }
.header-medium { font-size: 15px; font-weight: 800; text-transform: uppercase; color: var(--text-title); margin: 2px 0 4px; line-height: 1.15; }
.header-small { font-size: 12px; font-weight: 700; color: var(--text-title); margin: 2px 0 4px; }
.body-text { font-size: 10px; line-height: 1.55; color: var(--text-body); text-align: justify; hyphens: auto; }
.body-text a, .header-big a, .header-medium a, .header-small a {
  color: var(--text-title); text-decoration: none;
  border-bottom: 1px solid var(--border-light);
}
.body-text a:hover, .header-big a:hover, .header-medium a:hover, .header-small a:hover { border-bottom-color: var(--border-heavy); }
.lead-image, .section-image { width: 100%; object-fit: cover; border: 1px solid var(--border-light); margin: 4px 0 6px; }
.lead-image { max-height: 150px; }
.closing-section { border-top: 1px solid var(--border-light); text-align: center; padding: 12px 0 4px; }
.closing-history { font-size: 11px; color: var(--text-body); }
.closing-quote { font-size: 11px; color: var(--text-muted); font-style: italic; margin-top: 6px; }
@media (max-width: 900px) {
  .row-top { grid-template-columns: 1fr 1fr; }
  .row-top .col:first-child { grid-column: 1 / 3; }
  .row-bottom-4, .row-bottom-3 { grid-template-columns: 1fr 1fr; }
}
@media (max-width: 600px) {
  .row-top, .row-bottom-4, .row-bottom-3 { grid-template-columns: 1fr; }
  .row-top .col:first-child { grid-column: 1; }
  .col { border-right: none !important; padding: 0 !important; border-bottom: 1px solid var(--border-light); padding-bottom: 10px !important; margin-bottom: 10px; }
}
"""


PLAYER_JS = """
(function () {
  const audio = document.getElementById('briefing-audio');
  const btn = document.getElementById('play-btn');
  const track = document.getElementById('audio-track');
  const time = document.getElementById('audio-time');
  if (!audio || !btn) return;
  btn.addEventListener('click', () => {
    if (audio.paused) { audio.play(); btn.textContent = '⏸ Pause'; }
    else { audio.pause(); btn.textContent = '▶ Play Briefing'; }
  });
  audio.addEventListener('timeupdate', () => {
    const pct = audio.duration ? (audio.currentTime / audio.duration) * 100 : 0;
    track.style.setProperty('--progress', pct + '%');
    const m = Math.floor(audio.currentTime / 60);
    const s = Math.floor(audio.currentTime % 60).toString().padStart(2, '0');
    time.textContent = `${m}:${s}`;
  });
  const toggle = document.getElementById('theme-toggle');
  toggle.addEventListener('click', () => {
    const next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    toggle.textContent = next === 'dark' ? '☀ Light' : '☾ Dark';
  });
})();
"""


URL_DENYLIST = (
    "news.ycombinator.com/news",
    "dev.to/",
    "github.com/trending",
)


def esc(s: str) -> str:
    return html.escape(s or "", quote=True)


def is_real_url(url: str | None) -> bool:
    if not url:
        return False
    if any(bad in url for bad in URL_DENYLIST):
        return False
    return True


def linked_title(title: str, url: str | None, cls: str) -> str:
    if is_real_url(url):
        return f'<{cls}><a href="{esc(url)}" target="_blank" rel="noopener">{esc(title)}</a></{cls}>'
    return f"<{cls}>{esc(title)}</{cls}>"


def render(data: dict) -> str:
    date_human = esc(data["date_human"])
    date_iso = esc(data["date_iso"])
    audio_abs = esc(data["audio_path_absolute"])
    weather = esc(data.get("weather", ""))

    body_parts: list[str] = []
    body_parts.append(f"""
      <button id="theme-toggle" class="theme-toggle">☾ Dark</button>
      <div class="newspaper">
        <div class="audio-bar">
          <audio id="briefing-audio" src="file://{audio_abs}"></audio>
          <button id="play-btn" class="play-btn">▶ Play Briefing</button>
          <div id="audio-track" class="audio-track"></div>
          <div id="audio-time" class="audio-time">0:00</div>
        </div>
        <div class="masthead">
          <div class="masthead-date">{date_human}</div>
          <div class="masthead-title">DAILY BRIEFING</div>
          <div class="masthead-subtitle">YOUR PERSONAL MORNING PAPER</div>
          <hr class="masthead-rule">
        </div>
        <div class="weather-bar">{weather}</div>
    """)

    # Top row, bottom row, closing — added by later steps.

    body_parts.append("</div>")

    return f"""<!DOCTYPE html>
<html data-theme="light" lang="en">
<head>
  <meta charset="utf-8">
  <meta name="darkreader-lock" content="">
  <title>Daily Briefing — {date_iso}</title>
  <style>{THEME_CSS}</style>
</head>
<body>
  {"".join(body_parts)}
  <script>{PLAYER_JS}</script>
</body>
</html>
"""


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"Usage: {argv[0]} <input.json> <output.html>", file=sys.stderr)
        return 1
    try:
        with open(argv[1]) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Error reading input JSON: {exc}", file=sys.stderr)
        return 1
    for required in ("date_iso", "date_human", "audio_path_absolute"):
        if required not in data:
            print(f"Missing required field: {required}", file=sys.stderr)
            return 1
    try:
        Path(argv[2]).write_text(render(data))
    except OSError as exc:
        print(f"Error writing output: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

Then mark it executable:
```bash
chmod +x plugins/daily-briefing/skills/daily-briefing/scripts/render_html.py
```

- [ ] **Step 3.4: Run the skeleton test — must pass**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_render_html.TestRenderHtmlSkeleton -v
```
Expected: PASS.

- [ ] **Step 3.5: Add tests for the lead story block**

Append to `plugins/daily-briefing/tests/test_render_html.py`:

```python
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
```

- [ ] **Step 3.6: Run the lead story tests — must fail**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_render_html.TestLeadStory -v
```
Expected: FAIL — top row not rendered yet.

- [ ] **Step 3.7: Add top row rendering (lead story + stacked side columns)**

In `plugins/daily-briefing/skills/daily-briefing/scripts/render_html.py`, add above `render`:

```python
def render_stacked_items(source: dict) -> str:
    label = esc(source.get("label", ""))
    items = source.get("items") or []
    if not items:
        return ""
    parts = [f'<div class="section-label">{label}</div>']
    for idx, item in enumerate(items):
        title = item.get("title", "")
        url = item.get("url")
        summary = item.get("summary", "")
        heading_cls = "header-medium" if idx == 0 else "header-small"
        parts.append(linked_title(title, url, heading_cls))
        if summary:
            parts.append(f'<div class="body-text">{esc(summary)}</div>')
        if idx < len(items) - 1:
            parts.append('<hr class="col-divider">')
    return "".join(parts)


def render_lead(lead: dict) -> str:
    source_label = esc(lead.get("source_label", ""))
    title = lead.get("title", "")
    url = lead.get("url")
    image_url = lead.get("image_url")
    paragraphs = lead.get("summary_paragraphs") or []

    parts = [f'<div class="section-label">{source_label}</div>']
    parts.append(linked_title(title, url, "header-big"))
    if image_url:
        parts.append(
            f'<img class="lead-image" src="{esc(image_url)}" alt="" '
            f'onerror="this.style.display=\'none\'">'
        )
    for para in paragraphs:
        parts.append(f'<div class="body-text">{esc(para)}</div>')
    return "".join(parts)


def render_top_row(data: dict) -> str:
    lead = data.get("lead") or {}
    sides = data.get("top_row_sources") or []

    mid_col = ""
    right_col = ""
    for i, src in enumerate(sides):
        block = render_stacked_items(src)
        if i % 2 == 0:
            mid_col += block + ('<hr class="col-divider">' if mid_col and block else "")
        else:
            right_col += block + ('<hr class="col-divider">' if right_col and block else "")

    return f"""
      <div class="row row-top">
        <div class="col">{render_lead(lead)}</div>
        <div class="col">{mid_col}</div>
        <div class="col">{right_col}</div>
      </div>
    """
```

Then in `render`, replace the placeholder comment `# Top row, bottom row, closing — added by later steps.` with:

```python
    body_parts.append(render_top_row(data))
```

- [ ] **Step 3.8: Run the lead story tests — must pass**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_render_html.TestLeadStory -v
```
Expected: PASS.

- [ ] **Step 3.9: Add tests for the bottom row**

Append to `plugins/daily-briefing/tests/test_render_html.py`:

```python
class TestBottomRow(unittest.TestCase):
    def test_bottom_row_4_columns_when_extra_present(self):
        data = sample_input()
        data["bottom_row_sources"]["extra"] = {"items": [{"title": "E", "url": "https://example.com/e", "summary": "E."}]}
        with tempfile.TemporaryDirectory() as tmp:
            result, html_out = render(data, Path(tmp))
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn("row-bottom-4", html_out)
            self.assertIn("APOD today", html_out)
            self.assertIn("Game release", html_out)
            self.assertIn("Maker project", html_out)
            self.assertIn("Headline", html_out)
            self.assertIn("E.", html_out)

    def test_bottom_row_3_columns_when_extra_absent(self):
        data = sample_input()  # no extra key
        with tempfile.TemporaryDirectory() as tmp:
            result, html_out = render(data, Path(tmp))
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertIn("row-bottom-3", html_out)
            self.assertNotIn("row-bottom-4", html_out)

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
```

- [ ] **Step 3.10: Run the bottom row tests — must fail**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_render_html.TestBottomRow -v
```
Expected: FAIL — bottom row not rendered.

- [ ] **Step 3.11: Add bottom row rendering**

In `plugins/daily-briefing/skills/daily-briefing/scripts/render_html.py`, add above `render`:

```python
BOTTOM_LABELS = {
    "space_science": "SPACE & SCIENCE",
    "gaming": "GAMING",
    "maker_hobby": "MAKER & HOBBY",
    "news_ap": "AP NEWS",
    "extra": "EXTRA",
}


def render_bottom_column(key: str, source: dict) -> str:
    items = source.get("items") or []
    if not items:
        return ""
    label = BOTTOM_LABELS.get(key, key.upper())
    parts = [f'<div class="section-label">{label}</div>']

    if key == "space_science":
        apod = source.get("apod_image_url")
        if apod:
            parts.append(
                f'<img class="section-image" src="{esc(apod)}" alt="" '
                f'onerror="this.style.display=\'none\'">'
            )

    for idx, item in enumerate(items):
        title = item.get("title", "")
        url = item.get("url")
        summary = item.get("summary", "")
        heading_cls = "header-medium" if idx == 0 else "header-small"
        parts.append(linked_title(title, url, heading_cls))
        if summary:
            parts.append(f'<div class="body-text">{esc(summary)}</div>')
        if idx < len(items) - 1:
            parts.append('<hr class="col-divider">')
    return "".join(parts)


def render_bottom_row(data: dict) -> str:
    sources = data.get("bottom_row_sources") or {}
    # Gaming + Maker/Hobby share a column, stacked.
    space = render_bottom_column("space_science", sources.get("space_science") or {})
    gaming = render_bottom_column("gaming", sources.get("gaming") or {})
    maker = render_bottom_column("maker_hobby", sources.get("maker_hobby") or {})
    news = render_bottom_column("news_ap", sources.get("news_ap") or {})
    extra_src = sources.get("extra")
    extra = render_bottom_column("extra", extra_src) if extra_src else ""

    gm_stack = gaming
    if gaming and maker:
        gm_stack = gaming + '<hr class="col-divider">' + maker
    elif maker:
        gm_stack = maker

    cols: list[str] = [
        f'<div class="col">{space}</div>',
        f'<div class="col">{gm_stack}</div>',
        f'<div class="col">{news}</div>',
    ]
    grid_cls = "row-bottom-3"
    if extra:
        cols.append(f'<div class="col">{extra}</div>')
        grid_cls = "row-bottom-4"

    return f'<div class="row {grid_cls}">{"".join(cols)}</div>'
```

In `render`, replace the existing `body_parts.append(render_top_row(data))` line with:

```python
    body_parts.append(render_top_row(data))
    body_parts.append(render_bottom_row(data))
```

- [ ] **Step 3.12: Run the bottom row tests — must pass**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_render_html.TestBottomRow -v
```
Expected: PASS across all 4 tests.

- [ ] **Step 3.13: Add tests for the closing section**

Append to `plugins/daily-briefing/tests/test_render_html.py`:

```python
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
            self.assertNotIn("closing-section", html_out)
            self.assertNotIn("ON THIS DAY", html_out)

    def test_quote_only(self):
        data = sample_input()
        data["closing"] = {"quote": {"text": "Solo.", "author": "X"}}
        with tempfile.TemporaryDirectory() as tmp:
            _, html_out = render(data, Path(tmp))
            self.assertIn("Solo.", html_out)
            self.assertNotIn("ON THIS DAY", html_out)
```

- [ ] **Step 3.14: Run the closing tests — must fail**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_render_html.TestClosingSection -v
```
Expected: FAIL.

- [ ] **Step 3.15: Add closing section rendering**

In `plugins/daily-briefing/skills/daily-briefing/scripts/render_html.py`, add above `render`:

```python
def render_closing(data: dict) -> str:
    closing = data.get("closing") or {}
    hist = closing.get("today_in_history")
    quote = closing.get("quote")
    if not hist and not quote:
        return ""
    parts = ['<div class="closing-section">']
    if hist:
        holidays = esc(hist.get("holidays", ""))
        events = esc(hist.get("events", ""))
        parts.append('<div class="section-label">ON THIS DAY</div>')
        line_bits = [s for s in (holidays, events) if s]
        parts.append(f'<div class="closing-history">{" · ".join(line_bits)}</div>')
    if quote:
        text = esc(quote.get("text", ""))
        author = esc(quote.get("author", ""))
        parts.append(f'<div class="closing-quote">"{text}" — {author}</div>')
    parts.append("</div>")
    return "".join(parts)
```

In `render`, add this line after the existing `body_parts.append(render_bottom_row(data))`:

```python
    body_parts.append(render_closing(data))
```

- [ ] **Step 3.16: Run the closing tests — must pass**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_render_html.TestClosingSection -v
```
Expected: PASS across all 3 tests.

- [ ] **Step 3.17: Add tests for URL denylist and HTML escaping**

Append to `plugins/daily-briefing/tests/test_render_html.py`:

```python
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
            in_path.write_text(json.dumps({"date_iso": "2026-04-15"}))  # missing other required
            out_path = tmp_p / "out.html"
            result = run_script(in_path, out_path)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Missing required field", result.stderr)
```

- [ ] **Step 3.18: Run the URL+escaping tests — all should pass on first run**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_render_html.TestUrlAndEscaping -v
```
Expected: PASS across all 5 tests (behavior already implemented via `esc`, `is_real_url`, and `main`'s required-field check).

- [ ] **Step 3.19: Run the full `render_html` test suite**

Run:
```bash
cd plugins/daily-briefing && python3 -m unittest tests.test_render_html -v
```
Expected: all tests pass (1 skeleton + 2 lead + 4 bottom + 3 closing + 5 url/escape = 15 tests).

- [ ] **Step 3.20: Commit**

```bash
git add plugins/daily-briefing/skills/daily-briefing/scripts/render_html.py plugins/daily-briefing/tests/test_render_html.py
git commit -m "$(cat <<'EOF'
daily-briefing: add render_html.py for deterministic HTML generation

Moves the ~160-line HTML/CSS spec out of the skill prompt and into a stdlib
Python script. Handles theme system, audio player, responsive breakpoints,
URL denylist, HTML escaping, and graceful empty-source skips.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Move `tts.sh` into the skill directory

**Files:**
- Move: `plugins/daily-briefing/scripts/tts.sh` → `plugins/daily-briefing/skills/daily-briefing/scripts/tts.sh`
- Delete: `plugins/daily-briefing/scripts/` (empty dir)

---

- [ ] **Step 4.1: Move the file**

```bash
git mv plugins/daily-briefing/scripts/tts.sh plugins/daily-briefing/skills/daily-briefing/scripts/tts.sh
```

- [ ] **Step 4.2: Remove the now-empty scripts directory**

```bash
rmdir plugins/daily-briefing/scripts
```

- [ ] **Step 4.3: Verify `tts.sh` is executable**

```bash
chmod +x plugins/daily-briefing/skills/daily-briefing/scripts/tts.sh
ls -la plugins/daily-briefing/skills/daily-briefing/scripts/tts.sh
```
Expected: permissions show `-rwxr-xr-x` or similar.

- [ ] **Step 4.4: Smoke-check invocation help**

```bash
plugins/daily-briefing/skills/daily-briefing/scripts/tts.sh 2>&1 || true
```
Expected: usage error mentioning `Usage: tts.sh <text_file> <output_path> [voice]`. Script unchanged — moving it must not break it.

- [ ] **Step 4.5: Commit**

```bash
git add plugins/daily-briefing/skills/daily-briefing/scripts/tts.sh
git commit -m "$(cat <<'EOF'
daily-briefing: move tts.sh into the skill directory

Co-locates tts.sh with init_settings.py and render_html.py so the entire
skill is self-contained. No script changes; invocation contract unchanged.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Rewrite CC `SKILL.md` for a flat, linear flow

**Files:**
- Modify: `plugins/daily-briefing/skills/daily-briefing/SKILL.md` (full rewrite)

---

- [ ] **Step 5.1: Replace `SKILL.md` in full**

Write `plugins/daily-briefing/skills/daily-briefing/SKILL.md`:

````markdown
---
name: daily-briefing
description: >
  Generate a daily news/tech/weather briefing with TTS audio.
  Use when the user asks for their daily briefing, e.g. "get my daily briefing",
  "give me my daily", "show me what's happening today", "what's the news today",
  or invokes /daily-briefing.
  Do NOT trigger on casual greetings like "good morning" or "hello".
tools: Agent, Bash, Write
---

# Daily Briefing

Generate a personalized daily briefing as a newspaper-styled HTML page with TTS audio.

**Maximize parallelism. Batch tool calls. Always use system date from Bash.**

## Fetch rules (used in Step 3)

- URLs must link to specific articles/posts/repos, never homepages. Bad: `news.ycombinator.com/news`, `dev.to/`, `github.com/trending`, bare subreddit roots.
- No URL available? Omit the `url` field.
- Write dense summaries with context and analysis.
- Use only sources and closing toggles from settings. Do not invent ad-hoc sections.
- If a source returns no items, the section disappears entirely (no empty columns).
- Pass the system date (from Step 1) to every fetch prompt — never the session date.
- Fetch agents use only `WebSearch` and `WebFetch`; they do NOT write files.
- Be terse in status output. Only speak up on failures; suggest a retry or a fix.

## TTS narration rules (used in Step 6)

- Start with a short, creative greeting tied to the day/weather/holidays. Avoid "Good morning" / "Hello".
- Lead story is narrated FIRST, regardless of settings order: "Our top story today..."
- Then remaining sources in settings order with natural transitions ("Next, in tech news from Dev.to...", "Moving to space and science...").
- GitHub repos: narrate the description, not the "user/repo" path.
- Expand abbreviations (`S&P 500` → "S and P 500"). Keep `AI` as "AI".
- Never read URLs aloud.
- Closing: if `today_in_history` is enabled, narrate it; then `inspiration_quote` if enabled. End: "That's your briefing. Have a great day."

## Step 1 — Initialize settings and get the system date

Run the bootstrap script. Its stdout is JSON; capture and parse it.

```bash
!`python3 "${CLAUDE_SKILL_DIR}/scripts/init_settings.py"`
!`date +%Y-%m-%d`
!`date '+%A, %B %d, %Y'`
```

From the JSON, extract: `voice`, `location`, `sources[]`, `today_in_history`, `inspiration_quote`.
From the `date` outputs, record: `DATE_ISO` (e.g., `2026-04-15`) and `DATE_HUMAN` (e.g., `Wednesday, April 15, 2026`).

## Step 2 — Compute output paths and clear today's files

Compute once using `DATE_ISO`:

- `OUT_DIR  = ~/.ccToolBox/daily-briefing/output`
- `OUT_TXT  = $OUT_DIR/daily-briefing-$DATE_ISO.txt`
- `OUT_MP3  = $OUT_DIR/daily-briefing-$DATE_ISO.mp3`
- `OUT_JSON = $OUT_DIR/daily-briefing-$DATE_ISO.json`
- `OUT_HTML = $OUT_DIR/daily-briefing-$DATE_ISO.html`

Remove any existing files at these paths (enables re-runs):

```bash
rm -f "$OUT_TXT" "$OUT_MP3" "$OUT_JSON" "$OUT_HTML"
```

Record the absolute MP3 path (with `$HOME` expanded) — it is needed for the HTML audio `<audio src>`.

## Step 3 — Fetch sources in parallel

Dispatch ONE message containing ALL fetch agents (and the today-in-history agent if enabled).

Each fetch agent uses:
- `model: haiku`
- `tools: [WebSearch, WebFetch]`
- `description`: short (e.g., "Fetch HN stories")
- `prompt`: copy the template below, substituting `{DATE_ISO}`, `{SOURCE_KEY}`, and `{QUERY}`.

### Fetch agent prompt template

```
You are the {SOURCE_KEY} fetch agent. Today's date: {DATE_ISO}.

Search: {QUERY}

Return ONLY a JSON array of items: [{"title": "...", "url": "...", "summary": "..."}]
- url must point to a specific article/post/repo. Never homepages.
- If no URL available, omit the url field.
- Include 1-2 sentence summary giving context and analysis.
- No commentary outside the JSON array.
```

### Per-source queries (preserved from v1.5.1)

| Source key       | Query hint                                                                      |
|------------------|---------------------------------------------------------------------------------|
| weather          | `{location} weather today {DATE_ISO}` — return 1-2 sentence summary (temp/conditions/high-low/wind) |
| tech-hn          | `Hacker News top stories today {DATE_ISO}` — 2-5 items                          |
| tech-devto       | `Dev.to top posts today {DATE_ISO} AI programming` — 2-5 items                  |
| tech-github      | `GitHub trending repositories today {DATE_ISO}` — 3-5 items (repo, stars, lang) |
| tech-tc          | `TechCrunch top stories today {DATE_ISO}` — 2-3 items                           |
| reddit-claudeai  | `reddit r/ClaudeAI hot posts {DATE_ISO}` — 2-5 items                            |
| ai-ml            | `arXiv AI machine learning papers today {DATE_ISO}` AND `Andrew Ng The Batch newsletter {DATE_ISO}` — 2-3 items |
| space-science    | `NASA astronomy picture of the day {DATE_ISO}` AND `space science news today {DATE_ISO}` — 1-2 items. **Also return the NASA APOD image URL if found (field: `apod_image_url`).** |
| gaming           | `reddit r/gaming hot posts {DATE_ISO}` AND `video game news today {DATE_ISO}` — 2-3 items |
| maker-hobby      | `Instructables featured projects {DATE_ISO}` AND `reddit r/3Dprinting hot posts {DATE_ISO}` — 1-2 items |
| news-ap          | `AP News top headlines today {DATE_ISO}` — 2-5 short headlines                  |
| extra            | (only if user customized the description — skip if it still says `(add your own sections here)`). Search based on the user's description text. 1-3 items. |

If `today_in_history` is enabled, also dispatch:

| Agent key         | Query                                                                           |
|-------------------|---------------------------------------------------------------------------------|
| today_in_history  | `this day in history {month} {day}` AND `[month] [day] famous events` AND `[month] [day] holidays observances` — return `{holidays, events}` object |

Collect each agent's returned JSON.

## Step 4 — Select the lead story and fetch its image

From the collected tech results (HN, Dev.to, GitHub, TechCrunch, r/ClaudeAI, AI/ML), pick the single most impactful item:
- Broad significance (affects many developers/users)
- Novelty (breaking news over ongoing stories)
- Engagement (high vote/comment/star count)

Dispatch one more Agent (`model: haiku`, `tools: [WebSearch, WebFetch]`) with a short prompt:

```
Find one direct image URL (.jpg/.png/.webp) relevant to: "{LEAD_TITLE}".
Return the URL as plain text, or the literal string NONE if nothing suitable.
```

Record `LEAD_IMAGE_URL` (or `null` if NONE).

## Step 5 — Build the data JSON and write it to disk

Assemble a JSON object with this exact shape (see `scripts/render_html.py` for the contract):

```json
{
  "date_iso": "...",
  "date_human": "...",
  "audio_path_absolute": "/absolute/path/to/daily-briefing-YYYY-MM-DD.mp3",
  "weather": "...",
  "lead": { "source_label": "...", "title": "...", "url": "...", "image_url": "...", "summary_paragraphs": ["...", "..."] },
  "top_row_sources": [
    { "key": "tech-hn", "label": "HACKER NEWS", "items": [{"title","url","summary"}] }
  ],
  "bottom_row_sources": {
    "space_science": { "items": [...], "apod_image_url": "..." },
    "gaming":        { "items": [...] },
    "maker_hobby":   { "items": [...] },
    "news_ap":       { "items": [...] },
    "extra":         { "items": [...] }
  },
  "closing": {
    "today_in_history": { "holidays": "...", "events": "..." },
    "quote":            { "text": "...", "author": "..." }
  }
}
```

Rules:
- `lead` holds the story selected in Step 4. The lead's original source still appears in `top_row_sources`, but WITHOUT the promoted item (avoid duplication).
- `top_row_sources` contains the non-weather tech sources (HN, Dev.to, GitHub, TechCrunch, r/ClaudeAI, AI/ML), each minus the promoted lead item if it came from that source.
- `bottom_row_sources` contains the non-tech sources. Omit any key whose items list is empty.
- If `extra` was not customized by the user, omit the `extra` key entirely.
- If `today_in_history` or `inspiration_quote` is disabled in settings, omit those subkeys. If both are disabled, you may omit `closing` entirely.
- For the `quote`, pick one thematically connected to something in today's briefing.

Write the JSON to `$OUT_JSON` using the Write tool.

## Step 6 — Generate TTS + audio + HTML in parallel

Dispatch TWO agents in a SINGLE message:

### Agent A — TTS + audio (`model: sonnet`)

Prompt summary (fill in with actual data):

```
Write the briefing narration to $OUT_TXT, following the TTS narration rules at the top of SKILL.md.
Then run: bash "${CLAUDE_SKILL_DIR}/scripts/tts.sh" "$OUT_TXT" "$OUT_MP3" "{voice}"

IMPORTANT: Run tts.sh as a foreground Bash command. NEVER use run_in_background.
```

Pass the fully-built data from Step 5 (the JSON already on disk at `$OUT_JSON`) in the prompt so the agent can compose narration without re-fetching.

### Agent B — HTML rendering (`model: haiku` — script-only)

Prompt:

```
Run:
bash -c 'python3 "${CLAUDE_SKILL_DIR}/scripts/render_html.py" "$OUT_JSON" "$OUT_HTML"'

Do NOT edit HTML. Do NOT open the file. Just run the script and report success or the script's stderr.
```

## Step 7 — Verify audio and open the page

After both Step 6 agents return:

```bash
test -s "$OUT_MP3" && echo "Audio ready" || echo "Audio missing"
```

If audio is ready:

```bash
open "$OUT_HTML"
```

If audio is missing, report the TTS failure to the user and suggest re-running the skill. Do not open the HTML.
````

- [ ] **Step 5.2: Verify the skill file parses (frontmatter valid)**

Run:
```bash
python3 -c "
import sys
txt = open('plugins/daily-briefing/skills/daily-briefing/SKILL.md').read()
assert txt.startswith('---\n'), 'missing frontmatter start'
end = txt.find('---\n', 4)
assert end > 0, 'missing frontmatter end'
print('SKILL.md frontmatter OK')
"
```
Expected: `SKILL.md frontmatter OK`

- [ ] **Step 5.3: Commit**

```bash
git add plugins/daily-briefing/skills/daily-briefing/SKILL.md
git commit -m "$(cat <<'EOF'
daily-briefing: rewrite SKILL.md as flat linear flow

Removes the orchestrator agent layer. Skill itself dispatches parallel fetch
and generation subagents. Uses \${CLAUDE_SKILL_DIR} for all script invocation.
Fetch and TTS rules inlined at the top; HTML spec entirely removed (now in
render_html.py).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Delete old orchestrator agent and settings.default.md

**Files:**
- Delete: `plugins/daily-briefing/agents/daily-briefing-agent.md`
- Delete: `plugins/daily-briefing/agents/` (empty dir)
- Delete: `plugins/daily-briefing/settings.default.md`
- Delete: `plugins/daily-briefing/docs/simplified-instructions.md` (if present)
- Delete: `plugins/daily-briefing/docs/` (if empty after removal)

---

- [ ] **Step 6.1: Remove the orchestrator agent file**

```bash
git rm plugins/daily-briefing/agents/daily-briefing-agent.md
rmdir plugins/daily-briefing/agents
```

- [ ] **Step 6.2: Remove the old settings.default.md**

```bash
git rm plugins/daily-briefing/settings.default.md
```

- [ ] **Step 6.3: Remove the stale docs/ directory**

```bash
git rm plugins/daily-briefing/docs/simplified-instructions.md
rmdir plugins/daily-briefing/docs 2>/dev/null || true
```

- [ ] **Step 6.4: Sanity check — no references to deleted paths**

Run:
```bash
grep -rE "agents/daily-briefing-agent\.md|settings\.default\.md|docs/simplified-instructions" plugins/daily-briefing/ || echo "No references — clean."
```
Expected: `No references — clean.`

- [ ] **Step 6.5: Commit**

```bash
git add -A plugins/daily-briefing/
git commit -m "$(cat <<'EOF'
daily-briefing: remove orchestrator agent and obsolete files

Deletes the 332-line orchestrator (now integrated into SKILL.md), the old
markdown-based settings.default.md (replaced by settings.default.json), and
the stale docs/simplified-instructions.md.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Bump Claude Code plugin version, CHANGELOG, marketplace

**Files:**
- Modify: `plugins/daily-briefing/.claude-plugin/plugin.json`
- Modify: `plugins/daily-briefing/CHANGELOG.md`
- Modify: `.claude-plugin/marketplace.json`

---

- [ ] **Step 7.1: Bump plugin.json to 2.0.0**

Edit `plugins/daily-briefing/.claude-plugin/plugin.json` — change:

```json
  "version": "1.5.1",
```

to:

```json
  "version": "2.0.0",
```

- [ ] **Step 7.2: Bump marketplace.json entry to 2.0.0**

Edit `.claude-plugin/marketplace.json` — for the `daily-briefing` entry, change:

```json
      "version": "1.5.1",
```

to:

```json
      "version": "2.0.0",
```

- [ ] **Step 7.3: Prepend a 2.0.0 entry to CHANGELOG.md**

Edit `plugins/daily-briefing/CHANGELOG.md`. Insert this block between the top `# Changelog` / `All notable changes...` heading and the existing `## 1.5.1` entry:

```markdown
## 2.0.0

### Changed (breaking)

- Flattened architecture: orchestrator agent removed, skill itself dispatches fetch and generation subagents.
- Settings format: `settings.default.md` (markdown frontmatter) → `settings.default.json` (pure JSON). Old user settings at `~/.ccToolBox/daily-briefing/settings.md` are NOT migrated — users will see a fresh default on first run.
- Settings version: integer (2) instead of semver string.
- Storage path canonicalized to `~/.ccToolBox/daily-briefing/`. The `~/.config/ccToolBox/daily-briefing/` path referenced in some v1 docs is no longer used.
- All assets (`scripts/tts.sh`, new `scripts/init_settings.py`, new `scripts/render_html.py`, `settings.default.json`) moved INSIDE the skill dir for self-containment and reliable path discovery via `${CLAUDE_SKILL_DIR}`.

### Added

- `scripts/init_settings.py` — deterministic first-run, malformed-reset, version migration, and retention cleanup. Replaces prose-driven logic in the old orchestrator.
- `scripts/render_html.py` — renders the newspaper HTML from structured JSON. Eliminates inline CSS/layout spec in the skill prompt.
- Black-box test suite (`tests/test_init_settings.py`, `tests/test_render_html.py`) using stdlib `unittest`.
- Sibling `plugins/daily-briefing-opencode` plugin for OpenCode users (not registered in the CC marketplace).

### Removed

- `agents/daily-briefing-agent.md` orchestrator (~332 lines).
- `settings.default.md` (replaced by JSON).
- `docs/simplified-instructions.md` (stale auto-generated content).
```

- [ ] **Step 7.4: Verify both JSON files still parse**

Run:
```bash
python3 -c "import json; json.load(open('plugins/daily-briefing/.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('JSON OK')"
```
Expected: `JSON OK`

- [ ] **Step 7.5: Commit**

```bash
git add plugins/daily-briefing/.claude-plugin/plugin.json plugins/daily-briefing/CHANGELOG.md .claude-plugin/marketplace.json
git commit -m "$(cat <<'EOF'
daily-briefing: bump to 2.0.0

Major bump for breaking architecture: flattened skill, scripts-based migration
and HTML rendering, JSON settings format, canonicalized storage path at
~/.ccToolBox/daily-briefing/.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Scaffold the OpenCode sibling plugin

**Files:**
- Create: `plugins/daily-briefing-opencode/.claude-plugin/plugin.json` (marker — not registered in marketplace)
- Create: `plugins/daily-briefing-opencode/skills/daily-briefing/scripts/init_settings.py` (copy)
- Create: `plugins/daily-briefing-opencode/skills/daily-briefing/scripts/render_html.py` (copy)
- Create: `plugins/daily-briefing-opencode/skills/daily-briefing/scripts/tts.sh` (copy)
- Create: `plugins/daily-briefing-opencode/skills/daily-briefing/settings.default.json` (copy)

---

- [ ] **Step 8.1: Create the directory structure**

```bash
mkdir -p plugins/daily-briefing-opencode/.claude-plugin
mkdir -p plugins/daily-briefing-opencode/skills/daily-briefing/scripts
```

- [ ] **Step 8.2: Create the plugin.json marker**

Write `plugins/daily-briefing-opencode/.claude-plugin/plugin.json`:

```json
{
  "name": "daily-briefing-opencode",
  "description": "OpenCode-targeted daily briefing skill (not a Claude Code plugin — install via copy, see README)",
  "version": "1.0.0",
  "author": {
    "name": "dev32-io"
  }
}
```

Note: This file exists for consistency but is **not** registered in `.claude-plugin/marketplace.json`. OpenCode users install by copying the `skills/daily-briefing/` directory per the README.

- [ ] **Step 8.3: Copy scripts and settings from the CC plugin**

```bash
cp plugins/daily-briefing/skills/daily-briefing/scripts/init_settings.py plugins/daily-briefing-opencode/skills/daily-briefing/scripts/
cp plugins/daily-briefing/skills/daily-briefing/scripts/render_html.py plugins/daily-briefing-opencode/skills/daily-briefing/scripts/
cp plugins/daily-briefing/skills/daily-briefing/scripts/tts.sh plugins/daily-briefing-opencode/skills/daily-briefing/scripts/
cp plugins/daily-briefing/skills/daily-briefing/settings.default.json plugins/daily-briefing-opencode/skills/daily-briefing/
```

- [ ] **Step 8.4: Preserve executable bits**

```bash
chmod +x plugins/daily-briefing-opencode/skills/daily-briefing/scripts/init_settings.py
chmod +x plugins/daily-briefing-opencode/skills/daily-briefing/scripts/render_html.py
chmod +x plugins/daily-briefing-opencode/skills/daily-briefing/scripts/tts.sh
```

- [ ] **Step 8.5: Verify file parity**

```bash
diff plugins/daily-briefing/skills/daily-briefing/scripts/init_settings.py plugins/daily-briefing-opencode/skills/daily-briefing/scripts/init_settings.py && echo "init_settings.py identical"
diff plugins/daily-briefing/skills/daily-briefing/scripts/render_html.py plugins/daily-briefing-opencode/skills/daily-briefing/scripts/render_html.py && echo "render_html.py identical"
diff plugins/daily-briefing/skills/daily-briefing/scripts/tts.sh plugins/daily-briefing-opencode/skills/daily-briefing/scripts/tts.sh && echo "tts.sh identical"
```
Expected: three `identical` lines.

- [ ] **Step 8.6: Commit**

```bash
git add plugins/daily-briefing-opencode/
git commit -m "$(cat <<'EOF'
daily-briefing-opencode: scaffold plugin with shared scripts

Creates the OpenCode-targeted sibling plugin. Copies init_settings.py,
render_html.py, tts.sh, and settings.default.json from the CC plugin. Not
registered in marketplace.json — OC users install via copy per README.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Write the OpenCode `SKILL.md`

**Files:**
- Create: `plugins/daily-briefing-opencode/skills/daily-briefing/SKILL.md`

---

- [ ] **Step 9.1: Write the OC SKILL.md**

Write `plugins/daily-briefing-opencode/skills/daily-briefing/SKILL.md`:

````markdown
---
name: daily-briefing
description: >
  Generate a daily news/tech/weather briefing with TTS audio.
  Use when the user asks for their daily briefing, e.g. "get my daily briefing",
  "give me my daily", "show me what's happening today", "what's the news today",
  or invokes /daily-briefing.
  Do NOT trigger on casual greetings like "good morning" or "hello".
---

# Daily Briefing (OpenCode)

Generate a personalized daily briefing as a newspaper-styled HTML page with TTS audio.

The opencode-skills plugin injects the skill's base directory as "Base directory for this skill: <DIR>" at the top of your context. Substitute `<DIR>` in every script invocation below.

**Maximize parallelism. Batch `task` calls.**

## Fetch rules (used in Step 3)

- URLs must link to specific articles/posts/repos, never homepages. Bad: `news.ycombinator.com/news`, `dev.to/`, `github.com/trending`, bare subreddit roots.
- No URL available? Omit the `url` field.
- Write dense summaries with context and analysis.
- Use only sources and closing toggles from settings. Do not invent ad-hoc sections.
- If a source returns no items, the section disappears entirely (no empty columns).
- Pass the system date (from Step 1) to every fetch prompt — never the session date.
- Fetch subagents should only use `webfetch` / web-search tools; they do NOT write files.
- Be terse in status output. Only speak up on failures; suggest a retry or a fix.

## TTS narration rules (used in Step 6)

- Start with a short, creative greeting tied to the day/weather/holidays. Avoid "Good morning" / "Hello".
- Lead story is narrated FIRST, regardless of settings order: "Our top story today..."
- Then remaining sources in settings order with natural transitions ("Next, in tech news from Dev.to...", "Moving to space and science...").
- GitHub repos: narrate the description, not the "user/repo" path.
- Expand abbreviations (`S&P 500` → "S and P 500"). Keep `AI` as "AI".
- Never read URLs aloud.
- Closing: if `today_in_history` is enabled, narrate it; then `inspiration_quote` if enabled. End: "That's your briefing. Have a great day."

## Step 1 — Initialize settings and get the system date

Run:

```bash
python3 <DIR>/scripts/init_settings.py
date +%Y-%m-%d
date '+%A, %B %d, %Y'
```

From the JSON on `init_settings.py`'s stdout, extract: `voice`, `location`, `sources[]`, `today_in_history`, `inspiration_quote`.
Record `DATE_ISO` and `DATE_HUMAN` from the two `date` outputs.

## Step 2 — Compute output paths and clear today's files

- `OUT_DIR  = ~/.ccToolBox/daily-briefing/output`
- `OUT_TXT  = $OUT_DIR/daily-briefing-$DATE_ISO.txt`
- `OUT_MP3  = $OUT_DIR/daily-briefing-$DATE_ISO.mp3`
- `OUT_JSON = $OUT_DIR/daily-briefing-$DATE_ISO.json`
- `OUT_HTML = $OUT_DIR/daily-briefing-$DATE_ISO.html`

```bash
rm -f "$OUT_TXT" "$OUT_MP3" "$OUT_JSON" "$OUT_HTML"
```

Record the absolute MP3 path (with `$HOME` expanded).

## Step 3 — Fetch sources in parallel

Dispatch ONE message containing multiple `task` calls — one per source, plus one for `today_in_history` if enabled. In OpenCode, each `task` inherits the primary model and tool access; see the README for an optional `opencode.json` snippet that creates a dedicated haiku+WebSearch subagent for cost optimization.

Each fetch task prompt:

```
You are the {SOURCE_KEY} fetch agent. Today's date: {DATE_ISO}.

Search: {QUERY}

Return ONLY a JSON array of items: [{"title": "...", "url": "...", "summary": "..."}]
- url must point to a specific article/post/repo. Never homepages.
- If no URL available, omit the url field.
- Include 1-2 sentence summary giving context and analysis.
- No commentary outside the JSON array.
```

### Per-source queries (preserved from v1.5.1)

| Source key       | Query hint                                                                      |
|------------------|---------------------------------------------------------------------------------|
| weather          | `{location} weather today {DATE_ISO}` — return 1-2 sentence summary (temp/conditions/high-low/wind) |
| tech-hn          | `Hacker News top stories today {DATE_ISO}` — 2-5 items                          |
| tech-devto       | `Dev.to top posts today {DATE_ISO} AI programming` — 2-5 items                  |
| tech-github      | `GitHub trending repositories today {DATE_ISO}` — 3-5 items (repo, stars, lang) |
| tech-tc          | `TechCrunch top stories today {DATE_ISO}` — 2-3 items                           |
| reddit-claudeai  | `reddit r/ClaudeAI hot posts {DATE_ISO}` — 2-5 items                            |
| ai-ml            | `arXiv AI machine learning papers today {DATE_ISO}` AND `Andrew Ng The Batch newsletter {DATE_ISO}` — 2-3 items |
| space-science    | `NASA astronomy picture of the day {DATE_ISO}` AND `space science news today {DATE_ISO}` — 1-2 items. **Also return the NASA APOD image URL if found (field: `apod_image_url`).** |
| gaming           | `reddit r/gaming hot posts {DATE_ISO}` AND `video game news today {DATE_ISO}` — 2-3 items |
| maker-hobby      | `Instructables featured projects {DATE_ISO}` AND `reddit r/3Dprinting hot posts {DATE_ISO}` — 1-2 items |
| news-ap          | `AP News top headlines today {DATE_ISO}` — 2-5 short headlines                  |
| extra            | (only if user customized the description — skip if it still says `(add your own sections here)`). Search based on the user's description text. 1-3 items. |

If `today_in_history` is enabled, also dispatch:

| Task key          | Query                                                                           |
|-------------------|---------------------------------------------------------------------------------|
| today_in_history  | `this day in history {month} {day}` AND `[month] [day] famous events` AND `[month] [day] holidays observances` — return `{holidays, events}` object |

## Step 4 — Select the lead story and fetch its image

Pick the single most impactful tech item (broad significance + novelty + engagement). Dispatch one more `task`:

```
Find one direct image URL (.jpg/.png/.webp) relevant to: "{LEAD_TITLE}".
Return the URL as plain text, or the literal string NONE if nothing suitable.
```

Record `LEAD_IMAGE_URL` (or `null`).

## Step 5 — Build the data JSON and write it to disk

Assemble the JSON matching `scripts/render_html.py`'s input contract:

```json
{
  "date_iso": "...",
  "date_human": "...",
  "audio_path_absolute": "/absolute/path/to/daily-briefing-YYYY-MM-DD.mp3",
  "weather": "...",
  "lead": { "source_label": "...", "title": "...", "url": "...", "image_url": "...", "summary_paragraphs": ["...", "..."] },
  "top_row_sources": [
    { "key": "tech-hn", "label": "HACKER NEWS", "items": [{"title","url","summary"}] }
  ],
  "bottom_row_sources": {
    "space_science": { "items": [...], "apod_image_url": "..." },
    "gaming":        { "items": [...] },
    "maker_hobby":   { "items": [...] },
    "news_ap":       { "items": [...] },
    "extra":         { "items": [...] }
  },
  "closing": {
    "today_in_history": { "holidays": "...", "events": "..." },
    "quote":            { "text": "...", "author": "..." }
  }
}
```

Rules:
- `lead` holds the story from Step 4; the lead's original source entry in `top_row_sources` omits the promoted item.
- `top_row_sources` contains non-weather tech sources.
- Omit empty-items keys from `bottom_row_sources`. Omit `extra` if not customized.
- If both closing subkeys are disabled, omit `closing`.
- Pick the quote thematically.

Write to `$OUT_JSON` using the write tool.

## Step 6 — Generate TTS + audio + HTML in parallel

Dispatch TWO `task` calls in ONE message:

### Task A — TTS + audio

Prompt:

```
Write the briefing narration to $OUT_TXT, following the TTS narration rules at the top of SKILL.md.
Then run: bash <DIR>/scripts/tts.sh "$OUT_TXT" "$OUT_MP3" "{voice}"

IMPORTANT: Run tts.sh as a foreground Bash command. NEVER run it in the background.
```

### Task B — HTML rendering

Prompt:

```
Run: python3 <DIR>/scripts/render_html.py "$OUT_JSON" "$OUT_HTML"

Do NOT edit HTML. Do NOT open the file. Just run the script and report success or the script's stderr.
```

## Step 7 — Verify audio and open the page

```bash
test -s "$OUT_MP3" && echo "Audio ready" || echo "Audio missing"
```

If ready: `open "$OUT_HTML"` (on macOS; Linux users should substitute `xdg-open`).

If missing, report the TTS failure and suggest re-running.
````

- [ ] **Step 9.2: Frontmatter sanity check**

```bash
python3 -c "
txt = open('plugins/daily-briefing-opencode/skills/daily-briefing/SKILL.md').read()
assert txt.startswith('---\n')
end = txt.find('---\n', 4)
assert end > 0
print('OC SKILL.md frontmatter OK')
"
```
Expected: `OC SKILL.md frontmatter OK`

- [ ] **Step 9.3: Commit**

```bash
git add plugins/daily-briefing-opencode/skills/daily-briefing/SKILL.md
git commit -m "$(cat <<'EOF'
daily-briefing-opencode: add SKILL.md with task-tool dispatch

Mirrors the CC skill's linear flow but uses OpenCode conventions: the
injected "Base directory for this skill" context for paths, the task tool
for subagent dispatch, and no per-dispatch model/tool restrictions (those
are defined in opencode.json on the user side).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: OpenCode README.md and CHANGELOG.md

**Files:**
- Create: `plugins/daily-briefing-opencode/README.md`
- Create: `plugins/daily-briefing-opencode/CHANGELOG.md`

---

- [ ] **Step 10.1: Write README.md**

Write `plugins/daily-briefing-opencode/README.md`:

````markdown
# daily-briefing-opencode

Daily briefing skill for **OpenCode**. Sibling to the Claude Code-targeted `daily-briefing` plugin.

**Version:** 1.0.0

## What it does

Fetches news, tech, weather, and optional closing content from 12 sources, promotes a lead story, fetches a lead image, generates a newspaper-style HTML page with embedded audio player, and produces a TTS narration via Docker.

Same 12 sources, same layout, same `~/.ccToolBox/daily-briefing/` storage as the Claude Code version. The difference is platform idioms: subagent dispatch via `task`, path discovery via the injected "Base directory for this skill" context, and no per-dispatch model/tool restrictions.

## Prerequisites

- [OpenCode](https://opencode.ai) with the community `opencode-skills` plugin installed (so skill directories in `~/.config/opencode/skills/` get auto-discovered).
- **Docker** — required for TTS audio generation (via `scripts/tts.sh`).
- **Python 3** — required by the bundled scripts (macOS ships with it; `python3 --version` should succeed).

## Install

```bash
# Copy the skill directory into your OpenCode skills location
cp -r plugins/daily-briefing-opencode/skills/daily-briefing ~/.config/opencode/skills/

# Ensure scripts are executable
chmod +x ~/.config/opencode/skills/daily-briefing/scripts/*.py
chmod +x ~/.config/opencode/skills/daily-briefing/scripts/*.sh
```

Restart OpenCode. The skill is discovered as `daily-briefing`.

## First run

Invoke via `/daily-briefing` or say "get my daily briefing".

On first run, `scripts/init_settings.py` creates `~/.ccToolBox/daily-briefing/settings.json` with defaults. Edit that file to customize voice, location, and content sources.

## Settings

Stored at `~/.ccToolBox/daily-briefing/settings.json`:

```json
{
  "version": 2,
  "voice": "en-US-AvaMultilingualNeural",
  "location": "Burnaby, BC, Canada",
  "sources": [
    { "key": "weather", "description": "short summary for {location}" },
    { "key": "tech-hn", "description": "2-5 items from Hacker News (AI, CS, tech)" }
  ],
  "retention_days": 14,
  "today_in_history": true,
  "inspiration_quote": true
}
```

Edit `sources` to reorder, add, or remove sections. Set `retention_days` to change how many past briefings are kept in `output/`. Set `today_in_history` or `inspiration_quote` to `false` to disable those closing blocks.

## Optional: cost-optimized subagent

In OpenCode, all 12 fetch subtasks inherit whatever model your primary agent is using. If that is a premium model, fetches can be slow and expensive. To run fetches on a cheaper model, add this snippet to your `opencode.json`:

```json
{
  "agent": {
    "ccToolbox-fetcher": {
      "description": "Lightweight fetcher for the daily-briefing skill",
      "mode": "subagent",
      "model": "anthropic/claude-haiku-4-20250514",
      "tools": {
        "write": false,
        "edit": false,
        "bash": false,
        "webfetch": true
      }
    }
  }
}
```

Then adjust the fetch prompts in your local copy of `SKILL.md` to dispatch `ccToolbox-fetcher` specifically.

## Storage layout

```
~/.ccToolBox/daily-briefing/
├── settings.json                          # user settings
├── settings.json.bak                      # backup after malformed-reset
├── settings.json.v<N>.bak                 # backup before each migration
└── output/
    ├── daily-briefing-YYYY-MM-DD.json     # structured data (input to render_html.py)
    ├── daily-briefing-YYYY-MM-DD.txt      # TTS narration text
    ├── daily-briefing-YYYY-MM-DD.mp3      # generated audio
    └── daily-briefing-YYYY-MM-DD.html     # final page (opens in browser)
```

## Troubleshooting

**TTS audio not produced**
- Verify Docker is running (`docker ps` succeeds).
- Try invoking the TTS script directly: `bash ~/.config/opencode/skills/daily-briefing/scripts/tts.sh test-input.txt /tmp/test.mp3`.
- Check for port conflicts on 5050 (the TTS container binds to it).

**Settings reset unexpectedly**
- `init_settings.py` backs up malformed JSON to `~/.ccToolBox/daily-briefing/settings.json.bak` and restores defaults. Restore manually if needed.

**Skill not discovered**
- Confirm `opencode-skills` plugin is loaded. Verify `~/.config/opencode/skills/daily-briefing/SKILL.md` exists and has valid frontmatter.

## Changelog

See `CHANGELOG.md`.
````

- [ ] **Step 10.2: Write CHANGELOG.md**

Write `plugins/daily-briefing-opencode/CHANGELOG.md`:

```markdown
# Changelog

All notable changes to the daily-briefing-opencode plugin.

## 1.0.0

### Added

- Initial OpenCode-targeted daily briefing skill.
- Mirrors Claude Code `daily-briefing` v2.0.0 behavior: 12 content sources, lead-story selection, image fetching, newspaper-style HTML, TTS audio via Docker.
- Self-contained skill directory: `SKILL.md` + `scripts/init_settings.py` + `scripts/render_html.py` + `scripts/tts.sh` + `settings.default.json`.
- Storage at `~/.ccToolBox/daily-briefing/` (shared path with the Claude Code version — running one does not conflict with the other, they read the same settings).
```

- [ ] **Step 10.3: Commit**

```bash
git add plugins/daily-briefing-opencode/README.md plugins/daily-briefing-opencode/CHANGELOG.md
git commit -m "$(cat <<'EOF'
daily-briefing-opencode: add README and CHANGELOG

README covers install via copy, first-run behavior, settings file format,
optional opencode.json cost-optimization snippet, storage layout, and
troubleshooting. CHANGELOG marks the initial 1.0.0 release.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Correct stale `~/.config/ccToolBox/` paths across all docs

Five files reference the wrong path. Fix each to `~/.ccToolBox/`, and update examples to show the JSON settings format where relevant.

**Files:**
- Modify: `CLAUDE.md` (repo root)
- Modify: `.opencode/plugins/INSTALL.md`
- Modify: `plugins/daily-briefing/CLAUDE.md`
- Modify: `plugins/daily-briefing/README.md`

(`plugins/daily-briefing/agents/daily-briefing-agent.md` also contained this path but was deleted in Task 6.)

---

- [ ] **Step 11.1: Update repo-root `CLAUDE.md`**

In `CLAUDE.md`, find the Settings Convention section and replace:

```markdown
## Settings Convention

Plugins with user settings follow this pattern:
- Ship `settings.default.md` with `version: N` frontmatter in the plugin root
- User settings live at `~/.config/ccToolBox/<plugin-name>/settings.md`
- Skills handle first-run copy, version migration, and malformed settings recovery
- **When bumping a plugin version with settings changes, always bump the settings version integer in the same commit**
```

with:

```markdown
## Settings Convention

Plugins with user settings follow this pattern:
- Ship a versioned settings default in the plugin's skill directory (e.g., `settings.default.json` with integer `version`). Older plugins may still use `settings.default.md` with YAML frontmatter.
- User settings live at `~/.ccToolBox/<plugin-name>/settings.{json,md}`.
- Skills handle first-run copy, version migration, and malformed settings recovery — preferably via a dedicated script (see `daily-briefing` as reference).
- **When bumping a plugin version with settings changes, always bump the settings version integer in the same commit.**
```

Also update the repo structure diagram — change `settings.default.md` to reflect the new convention:

```markdown
ccToolBox/
├── .claude-plugin/marketplace.json   # marketplace registry
├── plugins/
│   └── <plugin-name>/
│       ├── .claude-plugin/plugin.json
│       ├── skills/
│       ├── scripts/                  # optional — plugins may also place scripts inside skills/<name>/scripts/
│       ├── settings.default.json     # or settings.default.md (legacy)
│       └── README.md
```

- [ ] **Step 11.2: Update `plugins/daily-briefing/CLAUDE.md`**

Open `plugins/daily-briefing/CLAUDE.md` and replace all occurrences of `~/.config/ccToolBox/daily-briefing/` with `~/.ccToolBox/daily-briefing/`. Also update any reference to `settings.default.md` / `settings.md` to `settings.default.json` / `settings.json` where it describes the daily-briefing plugin specifically.

Replace the "Architecture" note with the new shape:

```markdown
## Architecture

Flat skill: SKILL.md itself dispatches parallel Haiku fetch subagents for each source, performs inline lead-story selection, dispatches a lead-image subagent, then dispatches Sonnet TTS and Haiku render-HTML subagents in parallel. Settings migration and HTML rendering live in Python scripts (`scripts/init_settings.py`, `scripts/render_html.py`), not in the prompt.
```

Remove the "Components" bullet that referenced the deleted `agents/daily-briefing-agent.md`.

- [ ] **Step 11.3: Update `plugins/daily-briefing/README.md`**

Replace all `~/.config/ccToolBox/daily-briefing/` with `~/.ccToolBox/daily-briefing/`.
Replace `settings.default.md` / `settings.md` references with `settings.default.json` / `settings.json`.
Bump the `**Version:**` field to `2.0.0`.
Replace the inline markdown-format settings example with the JSON example from Task 1 step 1.2.
Replace the "Architecture" section with:

```markdown
### Architecture

SKILL.md dispatches parallel fetch subagents (Haiku), performs inline lead-story selection, fetches a lead image (Haiku), then runs TTS (Sonnet) and HTML-render (Haiku, script-only) subagents in parallel. Settings migration lives in `scripts/init_settings.py`; HTML rendering lives in `scripts/render_html.py`. All scripts sit inside the skill directory and self-locate via Python `__file__`.
```

- [ ] **Step 11.4: Update `.opencode/plugins/INSTALL.md`**

Replace all `~/.config/ccToolBox/daily-briefing/` with `~/.ccToolBox/daily-briefing/`.

Replace Step 2.2 ("Copy the Plugin Files") content with:

```markdown
#### 2.2 Copy the Plugin Files

```bash
cp -r ccToolBox/plugins/daily-briefing-opencode/skills/daily-briefing ~/.config/opencode/skills/
chmod +x ~/.config/opencode/skills/daily-briefing/scripts/*.py
chmod +x ~/.config/opencode/skills/daily-briefing/scripts/*.sh
```
```

Remove the separate 2.3 `chmod` step (now folded into 2.2). Remove the `cp -r ccToolBox/plugins/daily-briefing/agents/ ~/.config/opencode/agents/` line — there's no agents dir any more.

Replace the "File Locations Summary" table with:

```markdown
| Item | Location |
|------|----------|
| Skills | `~/.config/opencode/skills/` |
| Scripts (bundled with skill) | `~/.config/opencode/skills/daily-briefing/scripts/` |
| Settings | `~/.ccToolBox/daily-briefing/settings.json` |
| Briefing output | `~/.ccToolBox/daily-briefing/output/` |
```

Update the "Settings File Issues" troubleshooting block to reference `settings.json` (not `settings.md`).

- [ ] **Step 11.5: Verify there are no remaining stale references**

Run:
```bash
grep -rE "\.config/ccToolBox" . --include="*.md" --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.opencode/node_modules || echo "All clean."
```
Expected: `All clean.` (aside from any references in gitignored `.opencode/node_modules/` which we don't care about).

Also check:
```bash
grep -rE "settings\.default\.md|settings\.md" plugins/daily-briefing plugins/daily-briefing-opencode CLAUDE.md .opencode/plugins/INSTALL.md || echo "No legacy settings refs."
```
Expected: `No legacy settings refs.` (except possibly in the repo-root CLAUDE.md where legacy format is still allowed generally — manually verify those are correctly framed as the legacy option).

- [ ] **Step 11.6: Commit**

```bash
git add CLAUDE.md .opencode/plugins/INSTALL.md plugins/daily-briefing/CLAUDE.md plugins/daily-briefing/README.md
git commit -m "$(cat <<'EOF'
docs: normalize storage path to ~/.ccToolBox/ and document JSON settings

Corrects the ~/.config/ccToolBox/ path that crept into several docs (this path
was never actually used by the daily-briefing runtime). Updates the settings
convention note to mention JSON as the preferred format. Updates the OpenCode
install guide to target the new daily-briefing-opencode plugin dir and drops
the obsolete agents/ copy step.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Final verification

After all tasks, run once:

```bash
cd plugins/daily-briefing && python3 -m unittest discover tests -v
```
Expected: all 21+ tests pass.

Smoke-invoke the skill manually once in Claude Code:
- `/daily-briefing` (or "get my daily briefing")
- Observe: `init_settings.py` runs, parallel fetches dispatch, lead selected, JSON written, TTS + HTML run in parallel, browser opens.

Smoke-invoke once in OpenCode (after copying per INSTALL.md):
- `/daily-briefing`
- Observe: same flow; task subagents inherit primary model.

Any failure in these smoke tests → diagnose and commit a follow-up fix. Do not claim completion without both smoke tests passing.
