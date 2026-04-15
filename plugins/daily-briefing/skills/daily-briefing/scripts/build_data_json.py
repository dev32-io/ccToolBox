#!/usr/bin/env python3
"""Assemble the final briefing JSON from per-source staging files.

Usage: build_data_json.py <date_iso>

Reads:
  ~/.ccToolBox/daily-briefing/settings.json
  ~/.ccToolBox/daily-briefing/output/staging-<date>/*.json and weather.txt
Writes:
  ~/.ccToolBox/daily-briefing/output/daily-briefing-<date>.json
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime
from pathlib import Path


SOURCE_LABELS = {
    "tech-hn":         "HACKER NEWS",
    "tech-devto":      "DEV.TO",
    "tech-github":     "GITHUB TRENDING",
    "tech-tc":         "TECHCRUNCH",
    "reddit-claudeai": "R/CLAUDEAI",
    "ai-ml":           "AI / ML",
    "space-science":   "SPACE & SCIENCE",
    "gaming":          "GAMING",
    "maker-hobby":     "MAKER & HOBBY",
    "news-ap":         "AP NEWS",
    "extra":           "EXTRA",
}

TOP_ROW_ORDER = ("tech-hn", "tech-devto", "tech-github", "tech-tc", "reddit-claudeai", "ai-ml")


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def user_root() -> Path:
    return Path(os.environ.get("HOME", "~")).expanduser() / ".ccToolBox" / "daily-briefing"


def read_json_if_present(path: Path):
    if not path.exists():
        return None
    try:
        with open(path) as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError) as exc:
        log(f"WARNING: {path.name} unreadable ({exc}); skipping.")
        return None


def read_text_if_present(path: Path) -> str:
    if not path.exists():
        return ""
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def build(date_iso: str) -> dict:
    root = user_root()
    settings_path = root / "settings.json"
    staging = root / "output" / f"staging-{date_iso}"
    if not staging.is_dir():
        raise FileNotFoundError(f"Staging directory not found: {staging}")

    settings = json.loads(settings_path.read_text())

    # Date
    try:
        dt = datetime.strptime(date_iso, "%Y-%m-%d")
    except ValueError as exc:
        raise SystemExit(f"Invalid date_iso: {date_iso} ({exc})")
    date_human = dt.strftime("%A, %B %-d, %Y")

    # Audio path (absolute)
    audio_path = root / "output" / f"daily-briefing-{date_iso}.mp3"

    # Weather
    weather = read_text_if_present(staging / "weather.txt")

    # Lead
    lead_raw = read_json_if_present(staging / "lead.json") or {}
    lead_source_key = lead_raw.get("source_key", "")
    lead_out = {}
    if lead_raw:
        lead_out = {
            "source_label": SOURCE_LABELS.get(lead_source_key, lead_source_key.upper().replace("-", " ")),
            "title": lead_raw.get("title", ""),
            "url": lead_raw.get("url"),
            "image_url": lead_raw.get("image_url"),
            "summary_paragraphs": lead_raw.get("summary_paragraphs") or [],
        }

    # Helper — strip the lead item from a source's items list (match by title)
    def strip_lead(items: list, source_key: str) -> list:
        if source_key != lead_source_key or not items:
            return items
        lead_title = (lead_raw.get("title") or "").strip()
        if not lead_title:
            return items
        return [it for it in items if (it.get("title") or "").strip() != lead_title]

    # Top row
    top_row: list[dict] = []
    for key in TOP_ROW_ORDER:
        items = read_json_if_present(staging / f"{key}.json")
        if not isinstance(items, list) or not items:
            continue
        items = strip_lead(items, key)
        if not items:
            continue
        top_row.append({
            "key": key,
            "label": SOURCE_LABELS.get(key, key.upper()),
            "items": items,
        })

    # Bottom row
    bottom: dict = {}
    # space-science: pull APOD image
    ss_items = read_json_if_present(staging / "space-science.json")
    if isinstance(ss_items, list) and ss_items:
        apod_url = None
        cleaned = []
        for it in ss_items:
            img = it.get("image_url") if isinstance(it, dict) else None
            if img and not apod_url:
                apod_url = img
            cleaned_item = {k: v for k, v in (it.items() if isinstance(it, dict) else []) if k != "image_url"}
            cleaned.append(cleaned_item)
        space_block = {"items": cleaned}
        if apod_url:
            space_block["apod_image_url"] = apod_url
        bottom["space_science"] = space_block

    for src_key, out_key in (("gaming", "gaming"), ("maker-hobby", "maker_hobby"), ("news-ap", "news_ap")):
        items = read_json_if_present(staging / f"{src_key}.json")
        if isinstance(items, list) and items:
            bottom[out_key] = {"items": items}

    # extra — only if user customized it
    extra_items = read_json_if_present(staging / "extra.json")
    extra_desc = ""
    for src in settings.get("sources", []):
        if src.get("key") == "extra":
            extra_desc = src.get("description", "")
            break
    is_extra_customized = bool(extra_desc) and extra_desc != "(add your own sections here)"
    if is_extra_customized and isinstance(extra_items, list) and extra_items:
        bottom["extra"] = {"items": extra_items}

    # Closing
    closing: dict = {}
    if settings.get("today_in_history"):
        tih = read_json_if_present(staging / "today_in_history.json")
        if tih and (tih.get("holidays") or tih.get("events")):
            closing["today_in_history"] = {
                "holidays": tih.get("holidays", ""),
                "events": tih.get("events", ""),
            }
    if settings.get("inspiration_quote"):
        q = read_json_if_present(staging / "quote.json")
        if q and q.get("text"):
            closing["quote"] = {
                "text": q.get("text", ""),
                "author": q.get("author", ""),
            }

    data: dict = {
        "date_iso": date_iso,
        "date_human": date_human,
        "audio_path_absolute": str(audio_path),
        "weather": weather,
        "lead": lead_out,
        "top_row_sources": top_row,
        "bottom_row_sources": bottom,
    }
    if closing:
        data["closing"] = closing
    return data


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"Usage: {sys.argv[0]} <date_iso>", file=sys.stderr)
        return 1
    try:
        data = build(argv[1])
    except FileNotFoundError as exc:
        log(f"ERROR: {exc}")
        return 1
    except OSError as exc:
        log(f"ERROR: {exc}")
        return 1

    out_path = user_root() / "output" / f"daily-briefing-{argv[1]}.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    log(f"Built briefing data: {out_path}")
    print(str(out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
