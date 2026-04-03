# Critique & Score — How It Works

You are handling a `Critique & Score: <topic>` task from the queue.

## Step 1: Spawn Sonnet Subagent

Spawn a subagent for this ONE topic:

- **Model:** sonnet
- **Isolation:** The subagent gets ONLY the scoring rubric and the topic's output. No other context. No web access. No research history. This isolation is the point — if the subagent can't understand your findings without extra context, your findings aren't good enough.
- **Prompt:** "You MUST read `<path>/scoring-rubric.md` before producing ANY output. Your scoring is invalid without it. Do not score from memory or assumption. After reading the rubric, read `<path>/findings/<topic>.md` and score it according to the rubric. Be curious — wonder what's missing, what doesn't add up, what you'd want to know more about."

Replace `<path>` with the actual workspace path. For PoC topics, point the subagent at whatever the topic produced in `poc/<topic>/`.

## Step 2: Update Scoreboard

Record the scores in progress.md. Compute Δ (this score's total minus the last score's total for this topic). Update streak.

## Step 3: Expand the Task Queue

Based on the score result, append items to the task queue in progress.md:

```
Δ > 3 (topic is gaining):
├── Append: Improve: <topic> (gaps: ...) — from subagent's friction log
├── Append: Research: <new-topic> — if subagent surfaced new areas
├── Append: Research: poc-<name> — if building something would help
└── Streak → 0

Δ ≤ 3, streak 0 (first plateau):
├── Append: Improve: <topic> (last chance: ...) — one more try
└── Streak → 1

Δ ≤ 3, streak ≥ 1 (second plateau):
├── Append nothing
├── Mark CONCLUDED in scoreboard
└── Topic done — no more tasks will be added for it
```

Before adding any new topic, deduplicate against ALL topics in the scoreboard (ACTIVE and CONCLUDED).

After the last `Critique & Score` item in the current round, also append `Synthesize` and `Final report` to keep the research output fresh.

## Worked Example

Starting state — first round of scoring underway:

```
- [x] ... (expand, survey, research, synthesize, report done)
- [x] Critique & Score: stt-providers → 28/50 (gaps: no latency benchmarks, missing Groq Whisper)
- [ ] Critique & Score: openrouter-streaming
- [ ] Critique & Score: cloud-tts-providers
- [ ] Improve: stt-providers (gaps: latency benchmarks, Groq Whisper)
- [ ] Research: groq-whisper-integration ← NEW
- [ ] Synthesize
- [ ] Final report
```

**Agent picks: `Critique & Score: openrouter-streaming`**

Spawns Sonnet → 25/50 (gaps: no code examples, pricing stale). Δ = 25 (first score, gaining). Appends:

```
- [x] Critique & Score: openrouter-streaming → 25/50
- [ ] Critique & Score: cloud-tts-providers
- [ ] Improve: stt-providers (gaps: latency benchmarks, Groq Whisper)
- [ ] Research: groq-whisper-integration
- [ ] Improve: openrouter-streaming (gaps: code examples, pricing) ← APPENDED
- [ ] Synthesize
- [ ] Final report
```

Outputs TASK DONE.

**Agent picks: `Improve: stt-providers (gaps: latency benchmarks, Groq Whisper)`**

Adds benchmarks table, writes Groq Whisper section. Appends:

```
- [x] Improve: stt-providers ✓
- [ ] ...
- [ ] Critique & Score: stt-providers ← APPENDED (to verify improvement)
```

Outputs TASK DONE.

**`Critique & Score: stt-providers` (second time) — Score: 40/50. Δ = +12. Gaining.**

```
- [ ] Improve: stt-providers (gaps: VAD section thin) ← APPENDED
- [ ] Research: vad-pipeline-integration ← NEW
```

**`Critique & Score: stt-providers` (third time) — Score: 42/50. Δ = +2. First plateau (streak → 1).**

```
- [ ] Improve: stt-providers (last chance: tighten VAD section) ← APPENDED
```

**`Critique & Score: stt-providers` (fourth time) — Score: 43/50. Δ = +1. Second plateau (streak → 2). CONCLUDED.**

Nothing appended. Topic done.
