# arch-forge: Architecture Expansion Skill

**Status**: Approved  
**Date**: 2026-04-03  
**Plugin**: offline-research  

## Overview

A new skill inside the offline-research plugin that takes a sketch architecture and expands it through the container loop. The user walks in with a skeleton plan, the container explores decisions, builds PoCs, scores each exploration, and produces a living architecture document with 2-3 scored approaches per area.

Mirrors the research-probe pattern but adapted for architecture refinement: decisions are the atomic unit (not research topics), scoring evaluates design quality (not information quality), and expansion logic is dimension-aware.

## Problem

Going from a sketch architecture to a confident, validated architecture requires exploring alternatives, building prototypes, and evaluating trade-offs. This is time-consuming and easy to do shallowly. The research-probe proved that the container loop pattern — autonomous iteration with scoring and expansion — produces thorough, well-scored output. arch-forge applies this pattern to architecture design.

## Skill Flow

```
User arrives with sketch architecture (from brainstorming or freehand)
         |
[Interactive Refinement] - skill extracts decisions/unknowns,
    identifies constraints, clarifies project intent (3-5 questions)
         |
[Seed Prompt Generation] - fills 4 templates, writes to user's
    chosen directory
         |
[Container Loop] - agent explores freely:
    decisions -> research -> PoCs -> score -> expand
         |
[User Returns] - reviews architecture.md with scored approaches,
    PoC references, diagrams -> makes final calls ->
    breaks into specs for implementation
```

### Interactive Refinement Phase

Lighter than research-probe (user already has a formed idea). Focuses on:

1. **Intake** - Read sketch, extract:
   - Project intent (one paragraph anchor)
   - Constraints (hard boundaries)
   - Architecture components/stack
   - Implicit decisions (open questions the user hasn't answered yet)

2. **Quick survey** - 2-5 web searches:
   - Known gotchas for proposed components
   - Existing solutions that match the sketch
   - Early infeasibility flags

3. **Refinement** - One question at a time (3-5 total):
   - Confirm extracted decisions
   - Clarify constraints
   - Suggest decisions the user didn't think of

4. **Generate seed files** - Fill 4 templates, write to chosen directory

5. **Handoff** - Present run options (auto-resume, manual, local)

## Scoring Rubric

Five dimensions, 0-10 each, max 50. Scored by isolated Sonnet subagent (same pattern as research-probe). Every dimension is evaluated relative to the project's stated intent and constraints.

### Dimensions

**1. Feasibility & Validation (0-10)**
- Was this tried or just theorized?
- 0: Pure speculation, no evidence
- 5: Research-backed but unvalidated
- 10: Working PoC with measured results

**2. Maintainability & Testability (0-10)**
- Can a single person maintain this? Can components be tested in isolation?
- 0: Monolithic, untestable, requires team
- 5: Modular but testing strategy unclear
- 10: Clear module boundaries, test strategy documented, one-person viable

**3. Risk & Trade-offs (0-10)**
- Are failure modes identified? Trade-offs explicit? Unknowns surfaced?
- 0: No risks mentioned, trade-offs ignored
- 5: Some risks listed but no mitigation
- 10: Risks ranked by severity, mitigations proposed, unknowns called out

**4. Effort & Complexity (0-10)**
- Is this the simplest approach that works? Is effort proportional to value?
- 0: Massively over-engineered for the use case
- 5: Reasonable but could be simpler
- 10: Minimal viable complexity, clear build path

**5. Alignment (0-10)**
- Does this serve the original project intent? Has the exploration wandered?
- 0: Completely disconnected from project goals
- 5: Related but solving a different problem
- 10: Directly advances the stated project intent

### Friction-Based Deduction

- Wanting to ask "but would this actually work?" -> deduct from Feasibility
- Wanting to ask "who maintains this?" -> deduct from Maintainability
- Feeling uneasy but unsure why -> deduct from Risk
- Thinking "this seems overkill" -> deduct from Effort
- Thinking "why are we building this?" -> deduct from Alignment

### Scorer Output Format

```
## Scores
- Feasibility & Validation: N/10
- Maintainability & Testability: N/10
- Risk & Trade-offs: N/10
- Effort & Complexity: N/10
- Alignment: N/10
- **Total: N/50**

## Friction Log
- [dimension]: "description of friction"

## What's Missing
- gap or unknown

## What's Strong
- what works well
```

## Expansion Logic

Dimension-aware expansion — what the agent does next depends on which dimension is weak.

### Expansion Rules

| Weakest Dimension | Expansion Action |
|---|---|
| Feasibility < 6 | Spawn a PoC task. Don't research more — build something. |
| Maintainability < 6 | Spawn a decomposition task — break into smaller pieces, redraw boundaries. |
| Risk < 6 | Spawn a risk investigation — find failure modes, check edge cases, prior art on what went wrong. |
| Effort < 6 | Spawn a simplification task — find a simpler alternative, or cut scope. |
| Alignment < 6 | **Do NOT expand.** Re-read project intent, refocus the exploration. This is the brake pedal. |

**Priority when multiple dimensions are weak**: Alignment first (stop wandering before doing more work), then Feasibility (build before theorizing), then the rest.

### Conclusion Rules

- **Delta > 3**: Topic gaining, keep expanding per rules above
- **Delta <= 3, streak 0**: One more improvement attempt
- **Delta <= 3, streak >= 1**: Mark CONCLUDED
- **Minimum 2 approaches before CONCLUDED**: If only one approach explored, spawn an alternative exploration before concluding. The user must always have options.
- **All areas CONCLUDED**: Trigger final synthesize step

### Task Queue Pattern

After scoring, new tasks are inserted before the tail synthesize step:

```
After scoring "gateway-runtime" at 32/50:
  Feasibility: 4/10 -> insert: "PoC: bun-websocket-server"
  Risk: 5/10        -> insert: "Investigate: Bun production stability"

Queue becomes:
  - [ ] PoC: bun-websocket-server
  - [ ] Investigate: Bun production stability
  - [ ] Score: gateway-runtime
  - [ ] ... other pending tasks ...
  - [ ] Synthesize: update architecture.md    <- always at tail
```

## Living Architecture Document

`architecture.md` is the primary output — a living document updated at every synthesize step.

### Structure

Each architectural area gets a full section with:
- Mermaid diagrams (component interaction, sequence diagrams, data flow)
- 2-3 approaches with detailed pros/cons
- Score breakdown per approach
- References to supporting PoCs in `poc/`
- Status indicator (exploring / scored / concluded)

### Example Section

```markdown
## Gateway Runtime

### System Context
\`\`\`mermaid
graph LR
    Client -->|WebSocket| Gateway
    Gateway -->|streaming| STT[Deepgram]
    Gateway -->|SSE| LLM[OpenRouter]
    Gateway -->|HTTP| TTS[ElevenLabs]
    Gateway -->|file I/O| Persona[Memory Store]
\`\`\`

### Approach 1: Bun + Native WebSocket
**Score: 41/50** | PoC: `poc/bun-gateway/`

[detailed description, what the PoC proved, measured results...]

#### Audio Pipeline Flow
\`\`\`mermaid
sequenceDiagram
    Client->>Gateway: audio chunk (WS)
    Gateway->>Deepgram: forward stream
    Deepgram-->>Gateway: transcript
    Gateway->>OpenRouter: prompt (SSE)
    OpenRouter-->>Gateway: token stream
    Gateway->>TTS: sentence chunk
    TTS-->>Gateway: audio
    Gateway-->>Client: audio chunk (WS)
\`\`\`

| Dimension | Score | Notes |
|-----------|-------|-------|
| Feasibility | 9/10 | PoC handles 500 connections at 12MB |
| Maintainability | 7/10 | Bun ecosystem still maturing |
| Risk | 7/10 | Production stability unclear |
| Effort | 9/10 | Minimal boilerplate |
| Alignment | 9/10 | Directly serves home gateway use case |

### Approach 2: Node.js + ws
**Score: 36/50** | PoC: `poc/node-gateway/`
[...]

### Approach 3: Rust + tokio
**Score: 28/50** | Research only (no PoC)
[...]
```

### Update Cadence

The synthesize step is always at the tail of the task queue. As new tasks get inserted from scoring expansion, a new synthesize step is appended. The architecture document reflects whatever the loop has discovered so far — if the loop terminates early, the last synthesize output is still a useful artifact.

## Workspace Structure

```
/workspace/<project-name>/
├── prompt.md                # seed architecture + project intent (read-only reference)
├── progress.md              # scoreboard + task queue (live state)
├── expansion-loop.md        # scoring + expansion protocol
├── scoring-rubric.md        # 5 quality dimensions
├── architecture.md          # LIVING DOCUMENT - the primary output
├── explorations/            # research + analysis per decision area
│   ├── gateway-runtime.md
│   ├── client-protocol.md
│   └── ...
├── poc/                     # working prototypes (executed as poc user)
│   ├── bun-gateway/
│   ├── node-gateway/
│   └── ...
├── risks.md                 # cross-cutting risks + mitigations
├── sources.md               # running bibliography
└── connections.md           # cross-component dependencies + interactions
```

## Container: `containers/arch-tool/`

Replicated from `containers/offline-research/` with security additions for code execution.

### Security Model

The key threat: arch-forge encourages PoC code execution (npm install, running prototypes), which increases supply chain risk. The container already isolates from the host via Docker, but `.claude/` is mounted for authentication.

**Mitigations:**

| Mitigation | Implementation |
|---|---|
| Read-only auth mount | `.claude/` mounted as `:ro` — prevents tampering |
| Separate PoC user | Dockerfile creates `poc` user. PoC code executes via `su -c "..." poc`. `.claude/` owned by `node:node` with `700` — `poc` user cannot read auth tokens |
| Build-time dependencies only | Extra tools (Rust, Go, etc.) installed via Dockerfile layers. No `curl \| bash` at runtime |
| Resource limits | `--memory=4g --cpus=4` on container (generous but bounded) |
| Ephemeral PoCs | PoC artifacts live in `/workspace/poc/` only |

**Accepted risks:**
- Claude Code process itself can read `.claude/` (required for subscription auth)
- Prompt injection to Claude Code is an inherent risk of the subscription + container model
- Network egress is unrestricted (needed for web search + npm install)

### Container Files

```
containers/arch-tool/
├── Dockerfile               # standalone copy (not extending offline-research), adds poc user + permissions
├── launch.sh                # :ro mount, resource limits, same interface as research tool
├── run-arch.sh              # iteration loop (replicated from run-research.sh)
├── entrypoint.sh            # same as research tool
└── .env.example             # RESEARCH_HOURS, TZ, CONTAINER_NAME
```

### Dockerfile Key Differences from offline-research

The Dockerfile is a standalone copy of `containers/offline-research/Dockerfile` so it can evolve independently. It includes everything from the research container (Node.js 20, Python3, git, curl, jq, ripgrep, build-essential, gh, Claude Code) plus additional coding dependencies for PoC building:

```dockerfile
# --- PoC build dependencies (on top of research base) ---

# Runtimes & languages
RUN curl -fsSL https://bun.sh/install | bash                                    # Bun
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y    # Rust
RUN apt-get update && apt-get install -y golang-go                               # Go

# Node.js ecosystem (already has node 20 from base)
RUN npm install -g typescript ts-node tsx pnpm yarn                              # TS tooling + package managers

# Python ecosystem (already has python3 from base)
RUN apt-get install -y python3-pip python3-venv                                  # pip + venv

# Databases & storage
RUN apt-get install -y sqlite3 libsqlite3-dev redis-tools                        # SQLite, Redis CLI

# Headless browser (for web/frontend PoCs)
RUN apt-get install -y chromium chromium-driver                                  # Headless Chrome
RUN npm install -g playwright && npx playwright install --with-deps chromium     # Playwright

# Build tools & common libs
RUN apt-get install -y cmake pkg-config libssl-dev protobuf-compiler             # C/C++, SSL, protobuf
RUN apt-get install -y net-tools dnsutils iputils-ping                           # Network debugging

# --- Security additions ---

# Create poc user for sandboxed code execution
RUN useradd -m -s /bin/bash poc

# Ensure .claude/ is only readable by node user
# (permissions enforced at runtime via entrypoint since .claude/ is a mount)
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
```

Note: This makes the image significantly larger than the research container. That's an acceptable trade-off — the image is built once and reused across runs.

The entrypoint sets `.claude/` permissions on startup:
```bash
chmod 700 /home/node/.claude 2>/dev/null || true
exec claude --dangerously-skip-permissions "$@"
```

### Launch Script Changes

```bash
# Mount .claude/ as read-only
-v "${CLAUDE_PATH}:/home/node/.claude:ro"

# Resource limits
--memory=4g --cpus=4 --pids-limit=200
```

## File Structure Changes

### New Files
- `plugins/offline-research/skills/arch-forge/SKILL.md` — skill definition
- `plugins/offline-research/templates/arch-forge/prompt.md` — seed prompt template
- `plugins/offline-research/templates/arch-forge/progress.md` — scoreboard + task queue template
- `plugins/offline-research/templates/arch-forge/expansion-loop.md` — scoring protocol (static)
- `plugins/offline-research/templates/arch-forge/scoring-rubric.md` — 5 dimensions (static)
- `containers/arch-tool/Dockerfile` — replicated + security additions
- `containers/arch-tool/launch.sh` — replicated + :ro mount + resource limits
- `containers/arch-tool/run-arch.sh` — replicated iteration loop
- `containers/arch-tool/entrypoint.sh` — replicated
- `containers/arch-tool/.env.example` — replicated

### Modified Files
- `plugins/offline-research/skills/research-probe/SKILL.md` — update template paths from `templates/` to `templates/research-probe/`
- `plugins/offline-research/.claude-plugin/plugin.json` — add arch-forge skill entry
- Move existing templates: `templates/*.md` -> `templates/research-probe/*.md`

## Max Iterations Formula

```
decisions x 10 + 15
```

Higher multiplier than research-probe (x8 + 10) because architecture exploration has more expansion surface: each decision can spawn PoCs, alternative explorations, risk investigations, and decomposition tasks.

## Verification

1. **Template generation**: Run arch-forge with a test sketch (e.g., "simple HTTP API with SQLite and auth"). Verify 4 seed files are generated with correct placeholders filled.
2. **Container build**: Build arch-tool container. Verify `poc` user exists, `.claude/` is read-only inside container, resource limits are applied.
3. **PoC isolation**: Inside container, write a test script as `poc` user, verify it cannot read `/home/node/.claude/`.
4. **Scoring**: Run a single score task manually, verify Sonnet subagent produces correct output format with all 5 dimensions.
5. **Expansion**: After a low-feasibility score, verify the agent inserts a PoC task (not more research).
6. **Alignment brake**: After a low-alignment score, verify the agent does NOT expand but refocuses.
7. **Living report**: After 2+ synthesize steps, verify `architecture.md` has mermaid diagrams, multiple approaches per area, and PoC references.
8. **Early termination**: Kill the loop mid-run, verify `architecture.md` from last synthesize step is coherent and useful.
9. **Template reorganization**: After moving research-probe templates, verify research-probe still reads from correct paths.
