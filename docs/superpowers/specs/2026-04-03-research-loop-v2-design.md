# Research Loop v2 — Checklist-Driven Design

## Problem

The v1 research loop had two critical failures in practice:

1. **Batching:** The agent deep-dived all topics in one iteration and improved all topics in one bulk pass. Phases described as prose don't translate to one-at-a-time behavior. 9 of 22 iterations used.
2. **Stale scoring:** The agent re-scored unchanged files twice, scores wobbled from Sonnet variance, and plateau detection concluded everything without actual work done.

Root cause: the loop relied on the agent internalizing rules from a wall of text in critique-loop.md. It didn't.

## Solution

Replace phase-based instructions with a **checklist-driven loop**. The task queue in progress.md IS the instruction. The agent picks the next unchecked item, does it, checks it off, outputs a stop word, and the loop runner re-invokes. One item per iteration, mechanically enforced.

## How It Works

### Item Types

- **`Research: <topic>`** — explore a new topic from scratch, write findings
- **`Improve: <topic> (gaps: ...)`** — fix specific flaws on existing findings flagged by scorer
- **`Critique & Score: <topic>`** — spawn Sonnet subagent, update scoreboard, expand task list based on Δ
- **`Synthesize`** — update connections.md, contradictions.md, gaps.md, README.md
- **`Final report`** — update README.md with TLDR + navigation

### The Two-Sequence Flow

```
CRITIQUE & SCORE SEQUENCE         WORK SEQUENCE

Pick next Critique & Score        Pick next Research/Improve
        ↓                                  ↓
Read critique-loop.md             Do the work, update findings
Read scoring-rubric.md                     ↓
        ↓                         Append: Critique & Score: <topic>
Spawn Sonnet subagent                      ↓
        ↓                         Check off item ✓
Update scoreboard                 Output TASK DONE
        ↓
Δ > 3?
   ↓         ↓
  yes        no
   ↓         ↓
Append:    Streak++
- Improve     ↓
- New topics  Streak ≥ 2?
- PoC tasks     ↓       ↓
   ↓          yes      no
Check off    Mark       Append:
item ✓     CONCLUDED   - Improve (last chance)
Output       ↓           ↓
stop word  (nothing    Check off item ✓
           added)      Output TASK DONE
```

Score feeds Work. Work feeds Score. When a topic plateaus twice (Δ ≤ 3 for 2 consecutive scores), it's CONCLUDED — no more items appended for it.

### Plateau Detection

- **Δ > 3** → topic is gaining. Append Improve tasks for gaps, new Research tasks for discovered topics, PoC tasks if useful.
- **Δ ≤ 3, streak 0** → first plateau. Streak becomes 1. Append one Improve task (last chance).
- **Δ ≤ 3, streak ≥ 1** → second plateau. Mark CONCLUDED in scoreboard. Append nothing.

Threshold is 3 (not 1) because Sonnet scorer variance produces ±2-3 noise on unchanged content.

### One Item Per Invocation

The prompt instructs the agent: **do ONE checklist item, check it off, output `TASK DONE`, then stop.**

When the queue is empty, the agent outputs `<promise>TASK DONE</promise>` to stop the loop.

### Re-synthesis

After the last Critique & Score item in each round, the agent appends `Synthesize` and `Final report` to the queue so the research output stays fresh across rounds.

## Template File Changes

### `prompt.md` — Radical simplification

Strip all phase descriptions. The prompt becomes:

1. Mission title and autonomy statement
2. Workspace structure diagram
3. One instruction: follow the task queue in progress.md, one item at a time, output stop word after each

### `progress.md` — Pre-seeded task queue + scoreboard

The skill pre-populates the full initial queue:

```markdown
# Research Progress

## Scoreboard
| Topic | Status | Src | Depth | Action | Cohere | Confid | Total | Δ | Streak |
|-------|--------|-----|-------|--------|--------|--------|-------|---|--------|
| stt-providers | ACTIVE | - | - | - | - | - | - | - | 0 |
| openrouter-streaming | ACTIVE | - | - | - | - | - | - | - | 0 |
...

## Task Queue

> For every `Critique & Score` task: you MUST read `critique-loop.md` and `scoring-rubric.md` before starting. Do not score from memory or assumption.

- [ ] Expand scope: all topics (create topic files in topics/)
- [ ] Survey: all topics (skim sources, log in sources.md)
- [ ] Research: stt-providers
- [ ] Research: openrouter-streaming
- [ ] Research: tts-preprocessing
- [ ] Research: cloud-tts-providers
- [ ] Research: self-hosted-tts
- [ ] Research: audio-delivery
- [ ] Research: gateway-architecture
- [ ] Synthesize
- [ ] Final report
- [ ] Critique & Score: stt-providers
- [ ] Critique & Score: openrouter-streaming
- [ ] Critique & Score: tts-preprocessing
- [ ] Critique & Score: cloud-tts-providers
- [ ] Critique & Score: self-hosted-tts
- [ ] Critique & Score: audio-delivery
- [ ] Critique & Score: gateway-architecture
- [ ] Synthesize
- [ ] Final report
```

### `critique-loop.md` — Rewrite

Focused on three things only:
1. The two-sequence flowchart (how Score results drive the queue)
2. Plateau rules (Δ ≤ 3, streak 2 = CONCLUDED)
3. Worked example showing 3-4 iterations of queue evolution

No loop mechanics to explain — the checklist drives the loop.

### `scoring-rubric.md` — No changes

Same friction-based scoring with 5 dimensions (0-10 each, max 50).

### `SKILL.md` — Updated

- Pre-populates full task queue in progress.md (not just scoreboard rows)
- Max-iterations formula: `topics × 8 + 10`
- Update ralph-loop command to use `--completion-promise "TASK DONE"` (was `"ALL PHASES COMPLETE"`)

## Max-Iterations Formula

`topics × 8 + 10`

Covers at least 3 rounds of research + critique & score + synthesize, plus buffer for new topics and PoC work.

Example: 7 topics → `7 × 8 + 10 = 66`

## Worked Example (3 iterations from voice gateway)

Starting queue after initial research + first scoring round:

```
- [x] ... (expand, survey, research, synthesize, report all done)
- [x] Critique & Score: stt-providers → 28/50 (gaps: no latency benchmarks, missing Groq Whisper)
- [x] Critique & Score: openrouter-streaming → 25/50 (gaps: no code examples, pricing stale)
- [x] Critique & Score: cloud-tts-providers → 27/50 (gaps: missing Sesame, no pricing table)
- [ ] Critique & Score: self-hosted-tts
- [ ] Critique & Score: audio-delivery
- [ ] Critique & Score: gateway-architecture
- [ ] Improve: stt-providers (gaps: latency benchmarks, Groq Whisper)
- [ ] Improve: openrouter-streaming (gaps: code examples, pricing)
- [ ] Research: groq-whisper-integration ← NEW from stt-providers scoring
- [ ] Improve: cloud-tts-providers (gaps: Sesame, pricing table)
- [ ] Research: sesame-csm-voice ← NEW from cloud-tts scoring
- [ ] Synthesize
- [ ] Final report
```

**Iteration picks: `Critique & Score: self-hosted-tts`**

Agent reads critique-loop.md + scoring-rubric.md, spawns Sonnet, gets 26/50 (gaps: no GPU memory numbers, missing Parler-TTS). Δ = 26 (first score). Appends:

```
- [x] Critique & Score: self-hosted-tts → 26/50
- [ ] Critique & Score: audio-delivery
- [ ] ...
- [ ] Improve: self-hosted-tts (gaps: GPU memory, Parler-TTS)
- [ ] Research: parler-tts ← NEW
```

Outputs TASK DONE. Loop re-invokes.

**Iteration picks: `Critique & Score: audio-delivery`**

Same process. 29/50. Appends Improve task. Outputs TASK DONE.

**Iteration picks: `Critique & Score: gateway-architecture`**

31/50. Appends Improve task + new topic `Research: poc-latency-benchmark` (agent decides a test script would help). Outputs TASK DONE.

**Iteration picks: `Improve: stt-providers (gaps: latency benchmarks, Groq Whisper)`**

Agent adds benchmarks table, writes Groq Whisper section. Appends `Critique & Score: stt-providers`. Outputs TASK DONE.

**Iteration picks: `Improve: openrouter-streaming (gaps: code examples, pricing)`**

Agent adds code examples, updates pricing. Appends `Critique & Score: openrouter-streaming`. Outputs TASK DONE.

**Later — `Critique & Score: stt-providers` (second time)**

Score: 40/50. Δ = +12. Streak reset to 0. Topic is gaining. Appends:

```
- [ ] Improve: stt-providers (gaps: VAD section still thin)
- [ ] Research: vad-pipeline-integration ← NEW
```

**Even later — `Critique & Score: stt-providers` (third time)**

Score: 42/50. Δ = +2. Streak becomes 1. First plateau. Appends one last chance:

```
- [ ] Improve: stt-providers (last chance: tighten VAD section)
```

**Final — `Critique & Score: stt-providers` (fourth time)**

Score: 43/50. Δ = +1. Streak becomes 2. Mark CONCLUDED. Nothing appended. Topic done.

## Files Changed

1. **`plugins/offline-research/templates/prompt.md`** — Strip phase descriptions, replace with task-queue-driven instruction
2. **`plugins/offline-research/templates/progress.md`** — Add task queue section with pre-seeded items, keep scoreboard
3. **`plugins/offline-research/templates/critique-loop.md`** — Rewrite: flowchart + plateau rules + worked example only
4. **`plugins/offline-research/templates/scoring-rubric.md`** — No changes
5. **`plugins/offline-research/skills/research-probe/SKILL.md`** — Pre-populate task queue, update max-iterations to `topics × 8 + 10`, update stop word handling
