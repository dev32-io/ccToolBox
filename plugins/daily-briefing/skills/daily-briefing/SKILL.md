---
name: daily-briefing
description: >
  Generate a daily news/tech/weather briefing with TTS audio.
  Use when the user asks for their daily briefing, e.g. "get my daily briefing",
  "give me my daily", "show me what's happening today", "what's the news today",
  or invokes /daily-briefing.
  Do NOT trigger on casual greetings like "good morning" or "hello".
tools: Agent, Bash
---

# Daily Briefing

Dispatch the `daily-briefing-agent` orchestrator agent to generate the briefing.

**Before dispatching**, determine the plugin root (two directories up from this skill file) and get the current system date via `date +%Y-%m-%d`. Pass both to the agent prompt so it can find settings and scripts.
