# Daily Briefing Reliability Improvements

## Problem

Three issues with the daily briefing:

1. **Webpage opens before audio is ready** — the TTS subagent runs `tts.sh` with `run_in_background`, returns "done" to the orchestrator before the command finishes, and the orchestrator opens the browser with no audio available.
2. **Double browser open** — the orchestrator opens the page, then the lead session opens it again after the agent returns.
3. **TTS stale container conflicts** — if a previous run crashed, the leftover Docker container blocks the next run (port/name conflict).

## Changes

### 1. Orchestrator Agent (`daily-briefing-agent.md`) — Step 3

Keep Pipeline A (TTS) and Pipeline B (HTML) dispatched in parallel. Change the instructions:

- **Pipeline A**: Add explicit rule — run `tts.sh` as a **foreground** Bash command. Never use `run_in_background`.
- **Pipeline B**: Add explicit rule — **never open the HTML file in the browser**. Just write the file and return.
- **After both subagents return**: Verify MP3 exists and is non-empty (`test -s <mp3_path>`), then run `open <html_path>`.

### 2. Thin Skill (`SKILL.md`)

Add instruction: **Do not open the HTML file — the orchestrator agent handles browser opening.**

### 3. TTS Script (`tts.sh`)

Before `docker run`, kill any stale container from a previous crashed run:

```bash
if docker ps -aq --filter "name=$CONTAINER_NAME" | grep -q .; then
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi
```

### 4. Agent Chattiness Rule (added to Agent Rules in `daily-briefing-agent.md`)

**Be terse. State what you're doing and what's done. Only speak up when something fails — report the error and suggest a fix (e.g. retry).**
