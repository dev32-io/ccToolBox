# frustration-check skill — design

**Date:** 2026-04-22
**Plugin:** `devTools`
**Skill name:** `frustration-check`

## Problem

Kevin (the user) occasionally gets stuck in bad interaction patterns with Claude:

1. **Fixation on a wrong initial premise** — he commits to a flawed design early, pushes Claude to keep making it work, and the solutions grow in complexity until he realizes the whole premise was wrong.
2. **Riding Claude's outdated assumptions** — Claude proposes something based on stale training knowledge (library API that changed, deprecated pattern), Kevin goes along with it because the feedback looks right and fast, and neither party researches first.

Both modes cause real friction. Kevin wants a skill that detects the frustration or drift signals *for him* — because when he's in the middle of it, he won't have the clarity to invoke the skill manually. Once triggered, the skill should calmly nudge him to step back, offer to recall recent exchanges, and propose targeted websearch/context7 lookups for knowledge gaps before re-aligning intent.

## Prior art

Claude Code ships a built-in regex-based frustration detector (`userPromptKeywords.ts`, surfaced in the March 2026 source leak). It only modulates Claude's response tone — it does NOT trigger a workflow-level intervention. No community skill found that performs the full "pause → calm → backfill context → realign intent" loop. This skill is novel.

## Goals

- Auto-activate without the user having to call it.
- Trigger reliably on genuine drift/frustration episodes; fire rarely enough that it doesn't waste token budget or become noise.
- When fired, produce a short non-preachy nudge plus a consent-gated recall + knowledge-gap research workflow.
- Also catch the lighter "self-realization" moments ("let me step back", "maybe i was wrong") with a gentler offer, since those are prime opportunities for the recall/research workflow.

## Non-goals

- Sentiment analysis on every prompt (too expensive, too noisy).
- Automatic research or summarization without user consent.
- Detecting rapid micro-corrections — per explicit user feedback, Kevin optimizes Claude's output on the fly and doesn't want that pattern to trigger the hook.
- Generic "you seem stressed" interventions. Only actionable drift/realization moments.

## Architecture

Two-component system:

```
plugins/devTools/skills/frustration-check/
├── SKILL.md                       # the skill content
├── settings.default.json          # shipped defaults (versioned)
└── scripts/
    ├── detect_frustration.py      # UserPromptSubmit hook entrypoint
    ├── patterns.py                # tier regex definitions
    └── init_settings.py           # first-run copy + version migration
```

- **Hook** (`detect_frustration.py`): A `UserPromptSubmit` hook. Scores every user prompt against tier patterns, tracks cumulative score per-session with decay, and emits an activation signal to stdout when a threshold is met. Silent otherwise.
- **Skill** (`SKILL.md`): Claude auto-invokes when the hook's injected signal appears in the conversation. Defines the two workflows (frustration mode, assist mode).

**State file:** `~/.ccToolBox/frustration-check/state/<session_id>.json` — `{ "score": float, "last_turn": int }`. Garbage-collected after N days stale (7 days default).

**User settings:** `~/.ccToolBox/frustration-check/settings.json` — auto-copied from `settings.default.json` on first run, with integer version field for migration. Fields:

```json
{
  "version": 1,
  "enabled": true,
  "threshold": 5,
  "decay": 0.5,
  "custom_patterns": {
    "t1": [], "t2": [], "t3": [], "t4": []
  }
}
```

## Detection model

Calibrated against real working-session transcripts. Key findings from calibration:

- Profanity is NOT the primary frustration signal — ~0.07% rate of "wtf" across ~5400 lines, near-zero "fuck/shit".
- **Constraint repetition** ("i already told you", "i made it clear", "i never wanted") is the strongest ground-truth signal — it aligns with every real drift episode.
- "Self-realization" phrases ("let me step back", "maybe i was wrong", "i'm having doubt") are already-calm moments; they shouldn't trigger full intervention but are prime targets for the recall/research workflow.

### Tier patterns

Regex matching is case-insensitive, word-boundary aware. The lists below are the **initial shipped set**; the authoritative list lives in `patterns.py` and is extensible at runtime via `custom_patterns` in the user settings file.

| Tier | Purpose | Example patterns | Weight |
|---|---|---|---|
| **T1** | Constraint repetition | `\bi (already\|just\|literally) (told\|said\|asked\|explained)\b`, `\bi made it clear\b`, `\bi never (wanted\|said\|asked)\b`, `\bhow many times\b`, `\b(again\|still) (asking\|telling\|saying)\b` | **4** |
| **T2** | Explicit rage/profanity | `\bwtf\b`, `\bwhat the fuck\b`, `\bfucking\b`, `\bomfg\b`, `\bgoddamn\b` | **3** |
| **T3** | Contradiction / halt | `\bno[,.]?\s+(stop\|not that\|i said)\b`, `\bwhy are you still\b`, `\bstop (doing\|trying)\b` | **2** |
| **T4** | Self-realization (assist mode) | `\blet(\'s)?\s+step back\b`, `\bi\'?m having doubt\b`, `\bmaybe (my\|i) (was )?wrong\b`, `\bwhy hasn\'?t\b` | — (not scored; assist mode marker) |

Patterns are centralized in `patterns.py` and exposed as lists of compiled regex per tier, so tests can import them directly and users can extend via `custom_patterns` in settings.

### Scoring and threshold

On each `UserPromptSubmit`:

```
score = score * decay                     # default decay = 0.5
score += sum(weight for each tier match)
if score >= threshold:                    # default threshold = 5
    emit FRUSTRATION signal
    score = 0                             # reset to avoid retriggering
elif T4 matched:
    emit ASSIST signal                    # does not alter score
else:
    no-op, silent
```

### Calibration examples

| Real or synthetic episode | Score | Fires? |
|---|---|---|
| "wtf are you... i already told you" (one prompt) | T1(4) + T2(3) = 7 | ✅ FRUSTRATION |
| "why are you disabling capabilities?! session leak has nothing to do with..." | T3(2) + context buildup over 2 turns | ✅ FRUSTRATION within 1–2 turns |
| "let's step back, maybe my UX isn't clear" | T4 match | ✅ ASSIST |
| "also defer the steward agent, we want TTS to match pre-Hermes" | 0 | ❌ no trigger (optimization) |
| isolated "ugh" | 0 | ❌ no trigger |
| single "wtf" on its own | 3 | ❌ no trigger (under threshold) |
| "i told you" followed by "wtf" next turn | 4 then (4×0.5)+3 = 5 | ✅ FRUSTRATION on turn 2 |

### Opt-out

Two mechanisms:

1. `"enabled": false` in `~/.ccToolBox/frustration-check/settings.json` — disables the hook entirely.
2. Substring `skip frustration-check` anywhere in a user prompt — hook treats that turn as a no-op and does not update state.

## Skill workflows

The skill's description is narrow enough that Claude only invokes it when the hook's injected signal appears in the conversation (not on generic frustration-adjacent user messages).

### Frustration mode (full intervention)

1. **One non-preachy line.** No therapy voice. Example: *"Worth stepping back for a second — feels like we may have drifted from the original intent."*
2. **Reflect on recent turns** (last 5–10 turns, already in Claude's context — no tool call). Restate in 2–3 sentences: original goal → path taken → where uncertainty crept in. If the original goal isn't in the last 10 turns, say so and ask the user to restate it.
3. **Offer three paths, user picks one:**
   - **(a) Drift scan** — identify which turn diverged from a stated constraint and what the constraint was.
   - **(b) Knowledge-gap check** — propose 1–3 *specific* websearch or context7 lookups. Must name the specific library/API/question — no vague "research X".
   - **(c) Push on** — user was venting, path is fine.
4. Run the chosen path. Surface findings in ≤5 bullets.
5. **Confirm refined intent** in one sentence: *"So: goal is X, constraint is Y, current plan is Z. Proceed?"*
6. Resume normal work.

### Assist mode (light nudge)

Single-sentence offer:

> *"Caught a step-back moment — want me to recall recent turns and scan for knowledge gaps before continuing? (yes / no / just keep going)"*

- If yes → run frustration-mode steps 2–5.
- If no / silence → do nothing further, continue with the user's request.

**Hard rule across both modes:** no automatic research. Always offer and wait for consent before spending tokens on recall/websearch. Preserves token budget when the user doesn't need the intervention.

## Hook implementation details

- **Language:** Python 3. Regex-heavy, needs to be readable and extensible. Startup cost is negligible vs the LLM call it precedes.
- **Input:** JSON on stdin from Claude Code: `{ "prompt": "...", "session_id": "..." }` (exact shape to be verified against Claude Code hook spec during implementation).
- **Output:** Plain text to stdout, which Claude Code injects as additional context visible to the model. Emits a single short line for each activation, nothing on no-op.
- **Failure mode:** If state file is corrupt, log a warning and reset to `{score: 0, last_turn: 0}`. Never crash the prompt submission.
- **Hook registration:** Via the plugin's hook registration mechanism. Exact convention inside ccToolBox to be verified during implementation; devTools may not yet have a precedent, in which case this skill establishes it.

## Settings migration (ccToolBox pattern)

`init_settings.py` follows the `daily-briefing` pattern:

1. On first run, if `~/.ccToolBox/frustration-check/settings.json` doesn't exist, copy `settings.default.json`.
2. If it exists but `version` is lower than `settings.default.json`'s version, perform a merge-migration preserving user customizations.
3. If it exists but is malformed, back it up to `settings.json.corrupt-<timestamp>` and replace with defaults.

## Testing

Shell-based tests under `plugins/devTools/tests/` (matching existing test style):

- `test_frustration_patterns_t1.sh` — T1 constraint-repetition prompts trip, optimization-style prompts don't.
- `test_frustration_patterns_t2_t3.sh` — rage and contradiction patterns score correctly.
- `test_frustration_patterns_t4.sh` — self-realization phrases emit ASSIST, not FRUSTRATION.
- `test_frustration_scoring_and_decay.sh` — simulated session verifies: isolated "wtf" doesn't fire, "i told you" + "wtf" within 2 turns does, decay brings stale score back down, reset-after-fire works.
- `test_frustration_disabled_and_skip.sh` — `enabled:false` and `"skip frustration-check"` both silence the hook.
- `test_frustration_silent_noop.sh` — normal prompts produce zero stdout output.
- `test_frustration_state_corruption.sh` — corrupt state file → warning + reset, never crash.

All tests run patterns and scoring in isolation (importing from `patterns.py` and the hook module) rather than spinning up a real Claude Code session.

## Versioning

- Ships as a new skill under `plugins/devTools/skills/frustration-check/`.
- Triggers a `devTools` plugin version bump in both `marketplace.json` and `plugin.json`.
- `settings.default.json` starts at `version: 1`.
- Changelog entry explains the skill purpose, the hook's auto-activation, and the opt-out paths.

## Open items for implementation phase

- Verify exact JSON shape Claude Code sends to `UserPromptSubmit` hooks, and the stdout-as-context contract.
- Verify ccToolBox's hook registration convention (plugin.json vs settings merge vs separate hooks.json) and follow the existing precedent, or establish one if this is the first hook-based skill in the repo.
- Pick the stale-state GC trigger: opportunistic cleanup at hook start (cheapest) vs separate cron (more predictable). Lean: opportunistic.
