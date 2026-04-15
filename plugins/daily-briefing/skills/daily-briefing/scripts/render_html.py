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
/* bottom row grid injected dynamically */
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
.closing-history { font-size: 11px; color: var(--text-body); }
.closing-quote { font-size: 11px; color: var(--text-muted); font-style: italic; margin-top: 6px; }
@media (max-width: 900px) {
  .row-top { grid-template-columns: 1fr 1fr; }
  .row-top .col:first-child { grid-column: 1 / 3; }
  .row-bottom { grid-template-columns: 1fr 1fr; }
}
@media (max-width: 600px) {
  .row-top, .row-bottom { grid-template-columns: 1fr; }
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
    if extra:
        cols.append(f'<div class="col">{extra}</div>')
        grid_css = "grid-template-columns: 1fr 1fr 1.2fr 1fr"
        grid_cls = "row-bottom-4"
    else:
        grid_css = "grid-template-columns: 1fr 1fr 1fr"
        grid_cls = "row-bottom-3"

    return f'<div class="row row-bottom {grid_cls}" style="{grid_css}">{"".join(cols)}</div>'


def render_closing(data: dict) -> str:
    closing = data.get("closing") or {}
    hist = closing.get("today_in_history")
    quote = closing.get("quote")
    if not hist and not quote:
        return ""
    parts = ['<div class="closing-section" style="border-top: 1px solid var(--border-light); text-align: center; padding: 12px 0 4px;">']
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

    body_parts.append(render_top_row(data))
    body_parts.append(render_bottom_row(data))
    body_parts.append(render_closing(data))

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
