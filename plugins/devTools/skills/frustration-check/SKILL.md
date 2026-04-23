---
name: frustration-check
description: >
  Calmly intervene when the frustration-check hook has injected a
  FRUSTRATION or SELF-REALIZATION signal into the session, or when the user's
  recent messages clearly show drift/rage + constraint repetition. Steps back
  from the current tactical work, reflects on recent turns, offers
  consent-gated drift scans and knowledge-gap lookups (websearch / context7),
  and re-confirms intent before resuming. Do NOT trigger on normal user
  questions, minor corrections, or casual optimization.
tools: Bash, Read, Grep, WebSearch
---

# frustration-check — Step Back, Realign, Resume

A hook-activated intervention for two cases:

1. **Frustration mode** — the user is stuck in a drift pattern: repeating
   constraints, cursing at the output, or halting the current direction.
   Tactical work is unlikely to unstick things; they need a beat to step
   back.
2. **Assist mode** — the user has already voiced doubt ("let me step back",
   "maybe i was wrong"). They're calm and open; a lightweight recall +
   knowledge-gap offer saves everyone time.

The hook (`scripts/detect_frustration.py`) runs on every `UserPromptSubmit`
and injects one of two signals when its tiered scoring trips the threshold.
This skill responds to those signals.

## Activation

This skill activates when one of these appears in the conversation:

- `[frustration-check] FRUSTRATION signal` → run **Frustration mode**
- `[frustration-check] SELF-REALIZATION detected` → run **Assist mode**

Do NOT self-invoke on generic user frustration cues without the hook signal
— the hook does the calibration.

## Frustration mode (full intervention)

1. **One non-preachy line.** No therapy voice. Example: *"Worth stepping
   back for a second — feels like we may have drifted from the original
   intent."* Keep it under 20 words.

2. **Reflect on the last 5–10 turns** (already in your context — no tool
   call needed). In 2–3 sentences, restate:
   - What the original goal was
   - What path the conversation has been on
   - Where you think uncertainty or drift crept in

   If the original goal isn't visible in the last 10 turns, say so and ask
   the user to restate it in one sentence.

3. **Offer three paths. Wait for user pick.**

   > a) **Drift scan** — I identify which turn diverged from a stated
   > constraint and name the constraint.
   > b) **Knowledge-gap check** — I propose 1–3 *specific* websearch or
   > context7 lookups (named library / named API / named question) that
   > might invalidate a stale assumption we've been riding.
   > c) **Push on** — you were venting, path is fine.

4. **Run the chosen path.** Surface findings in ≤5 bullets.
   - For (a): quote the constraint, cite the turn where it diverged.
   - For (b): actually run the searches (use WebSearch or the context7 MCP
     tools if available), summarize what shifted. No "I would suggest
     researching X" — either do it or say you can't.
   - For (c): skip to step 5.

5. **Confirm refined intent in one sentence:** *"So: goal is X, constraint
   is Y, current plan is Z. Proceed?"* Wait for yes/no.

6. Resume normal work.

## Assist mode (light nudge)

Output one sentence and stop:

> *"Caught a step-back moment — want me to recall recent turns and scan for
> knowledge gaps before continuing? (yes / no / just keep going)"*

- If the user says yes → run steps 2–5 of Frustration mode.
- If no / silence / "keep going" → do nothing further; continue with the
  user's original request.

## Hard rules

- **No automatic research.** Always offer and wait for consent before
  running any websearch or context7 lookup. Preserves token budget when the
  user is fine.
- **Be brief.** The whole intervention should fit in the user's working
  memory. If step 2 is running long, the reflection is already too much.
- **Never lecture.** No "I noticed you seem frustrated." No "let's take a
  breath." Treat the user as a professional having a moment, not a patient.
- **One path, one time.** Don't re-offer drift scans or knowledge-gap
  checks the user already declined in this thread.

## Opt-out

Users can disable or silence the hook:

- `enabled: false` in `~/.ccToolBox/frustration-check/settings.json`
- Include the substring `skip frustration-check` in the prompt that should
  be ignored (single-turn suppression, does not alter state).

## First-run setup

On first activation of this skill, run
`scripts/init_settings.py` to create
`~/.ccToolBox/frustration-check/settings.json` from the shipped defaults.
This also handles version migration and malformed-file recovery. If the
hook is running, settings should already exist.

## Tuning

Patterns are declared in `scripts/patterns.py`. Users can extend them via
`custom_patterns` in their settings file (one list per tier). Scoring
weights and threshold are in settings (`threshold`, `decay`).

If the hook fires too often, raise `threshold` (default 5) or add custom
patterns Kevin's false-positives to a suppression list (future work).

If it rarely fires, lower `threshold` or add custom patterns to `t1`/`t2`/
`t3`. Lexical additions are fine; behavioral detection is deliberately out
of scope (see spec).
