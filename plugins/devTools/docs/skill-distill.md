# skill-distill

> Originally documented in [CHANGELOG.md](../CHANGELOG.md) under v1.7.0 / v1.7.1.
> Architectural decisions shared with [`ui-refinement.md`](ui-refinement.md) — see [`2026-05-06-v1.7.1-refactor.md`](2026-05-06-v1.7.1-refactor.md) for the v1.7.1 postmortem.

I built `skill-distill` because every successful Claude Code session was a one-shot. Patterns that worked got reinvented next time. I'd finish a solid multi-turn debug loop or a well-structured refactor and think "that was the right shape" — and then the next time I faced the same class of problem, I started from scratch with different framings, different scope guards, different escalation rules. The session was a working specification for how to do the thing. I wanted the model to teach itself, by promoting working sessions into reusable Skills.

The specific failure that pushed this over the line was `ui-refinement` itself. After that skill shipped, I looked back at the session that produced it and found five load-bearing phrases in the user prompts that were nowhere in the resulting SKILL.md. "DO NOT only look at the issues I listed, take as much iteration as you need." "Industry refs are inspiration not gospel." "Be EXTREMELY ruthless." Those framings were the reason the session worked. They didn't survive into the skill because writing the skill by hand I summarized the outcomes, not the framing. `skill-distill` is the fix: read first, extract the framings, build from the extraction.

The result is a five-phase flow that reads a source session (transcript, user-supplied path, or free-text summary), extracts what made it work across three distinct lenses, web-searches prior art, probes the target destination, and writes a generalized, slash-invocable skill directory. The output is a self-contained skill directory the user (or anyone) can run later. Not a memory note, not a doc. An invocable workflow. Built with Claude Code. No prior design spec for `skill-distill` exists in `docs/superpowers/`. The skill was distilled from the same meta-pattern that produced `ui-refinement`, and the CHANGELOG v1.7.0 entry is the primary record of intent.

The files shipped in v1.7.0: `SKILL.md` (the main flow), three reference docs (`references/claude-code-skill-format.md`, `references/distill-method.md`, `references/destination-conventions.md`), one persona (`personas/skill-author.md`), one quality checklist (`checklists/skill-quality.md`), and one design template (`templates/skill-design.md`). Six supporting files for a 419-line main SKILL.md. The extra-files pattern is `skill-distill` encoding its own advice: bias toward extra files when content exceeds 500 lines or when chunks are reusable across phases.

---

## How it works

> All file:line references below are relative to `plugins/devTools/skills/skill-distill/` unless otherwise noted.

The five-phase flow mirrors `ui-refinement`'s shape so users who've run one recognize the other: **Source → Research → Design → Plan + Approval → Ship** (`SKILL.md:28–29`). One TodoWrite item per phase keeps state visible. The flow diagram at `SKILL.md:59–75` shows the only non-linear edge: Phase 4's approval gate loops back to Phase 4 on "revise", not all the way back to Phase 1.

```
Phase 1 — Source  →  Phase 2 — Research  →  Phase 3 — Design
                                                       ↓
                             Phase 5 — Ship  ←  Phase 4 — Plan + Approval
                                                  ↑ revise (loops here only)
```

The skill dispatches three subagents total: one in Phase 1.2 (magic extraction), two in parallel in Phase 2 (steps 2.1 prior-art search and 2.3 destination probe). Subagent dispatch is the structural backbone — the main context stays lean for the design and approval phases, which are where the user's attention matters.

### Phase 1 — Source

The session starts by locating the source. Three modes: current session transcript (default), a user-supplied path, or a free-text summary. For a current-session read, the skill globs `~/.claude/projects/*/*.jsonl` and picks the most recently modified file (`SKILL.md:96–101`).

Phase 1.2 dispatches one `Agent` subagent (`SKILL.md:110–126`). The subagent gets the source path (or free-text summary), a pointer to `references/distill-method.md`, and explicit instructions to return an 8–12 item magic-ingredients list without drafting any SKILL.md content. The subagent returns; the user reviews and edits the list; that edited list is the spec for everything downstream.

The user's edits to the ingredients list are load-bearing. If the user adds a rule that wasn't in the extracted list, it means the extraction missed something they know was important. If they remove a rule, it's either too specific to the source session or not actually load-bearing. The review gate at the end of Phase 1.2 is the only point in the flow where the user can correct the extraction before it propagates into Phase 3's design. Skipping the review and treating the extraction as authoritative is the anti-pattern that produces generic skills rather than faithful distillations.

The SKILL.md frontmatter lists the tools the skill is allowed to use: `Agent, AskUserQuestion, Bash, Read, Write, Edit, Grep, Glob, ToolSearch, WebSearch, WebFetch` (`SKILL.md:16`). That list reflects the tool choices required across all five phases — `Agent` for subagent dispatch, `AskUserQuestion` for the interactive gates, `WebSearch`/`WebFetch` for prior-art research, `Glob` for transcript discovery. The allowlist is also a scope declaration: `skill-distill` does not run shell scripts, does not commit without user confirmation, does not push.

Phase 1.3 nails the skill's mission in one sentence: problem, audience, input. Plus three positive trigger phrases and three near-miss phrases the skill should not fire on (`SKILL.md:129–134`). Those near-misses matter: "this was useful, save it" is not a distillation request, it's a memory write. The frontmatter `description` in every skill is the trigger; the near-miss list is what keeps the skill from firing on casual matches.

The anti-pattern called out at `SKILL.md:50–55` applies to the skill itself: if the agent starts drafting SKILL.md before reading the source, it's extracting from training data, not from the session. The whole value is faithful extraction. Read the transcript first, build the magic-ingredients list, only then write.

### The three-lens distillation method

The subagent in Phase 1.2 applies three lenses defined in `references/distill-method.md:5–76`.

**Lens 1 — User-prompt patterns** (`distill-method.md:8–37`). What did the user write that gave the model permission, scope, or a specific framing? Persona phrases, scope caps, autonomy grants, explicit "find more" instructions. From the `ui-refinement` source session, "DO NOT only look at the issues I listed, take as much iteration as you need" is load-bearing. That framing, extracted verbatim, becomes a magic ingredient.

**Lens 2 — Agent decisions that paid off** (`distill-method.md:39–56`). Tool choices, loop structures, scope guards, failure recovery paths. From the same session: picking Playwright MCP over chrome-devtools for viewport-level inspection; committing each pass on a feature branch. These become technique sections in the skill body.

**Lens 3 — Course-corrections** (`distill-method.md:58–75`). Every user pushback. "You are being lazy and this is a hack" is a bright line. "Actually, keep X" after the agent dropped X is a durable constraint. For each correction, one rule goes into `checklists/` or as an inline rule in `SKILL.md`. This lens catches what Lens 1 misses: corrections reveal constraints that were never stated as instructions.

The output of all three lenses is a numbered list of 8–12 one-line rules, quoted load-bearing user phrasing verbatim where possible (`distill-method.md:110–128`). That list is the spec. Phase 3 encodes the list into the skill body under a `## Magic ingredients` section. Fewer than 8 rules usually means under-distillation; more than 12 usually means the session was doing two things that should be two skills.

### Phase 2 — Research (subagent dispatch)

Phase 2 splits into three steps; two of them (2.1 prior-art and 2.3 destination probe) dispatch as parallel subagents in a single message, while 2.2 format-rules synthesis stays in the main agent (`SKILL.md:143–148`).

**2.1 — Prior-art search** (`SKILL.md:149–161`): one subagent, web-only. Searches Anthropic docs, dev blogs, Claude-skill marketplaces for established naming, workflows, failure modes on the skill's problem domain. Returns a short note: what's established, what's worth borrowing, what's worth avoiding.

**2.2 — Skill format rules** (`SKILL.md:163–176`): main agent reads `references/claude-code-skill-format.md`. Hard rules: frontmatter `name` is lowercase-hyphen-numbers only, ≤64 chars; `description` ≤1024 chars using the formula "what it does + when to use + key capabilities"; body ≤500 lines (split into supporting files for longer content). These rules are loaded into main context because Phase 3 needs them live.

**2.3 — Destination probe** (`SKILL.md:177–188`): one subagent, filesystem-only. Probes the current working directory and `~/.claude/` to classify the destination (marketplace, single-plugin, plain repo) and return a recommendation order with one-line rationale per option. It does not ask the user — only research.

The reason 2.1 and 2.3 run in parallel: they're independent. One does web I/O; the other does filesystem I/O. Waiting for 2.1 to finish before starting 2.3 wastes wall time for no reason. The v1.7.1 CHANGELOG entry calls this out explicitly: "Phases 2.1 (prior-art search) + 2.3 (destination probe) dispatch as two parallel subagents since they're independent." Phase 2.2 stays in the main agent because the format rules need to be in main context for Phase 3 to self-grade against them.

### Phases 3 and 4 — Design and Plan

Phase 3 builds the skill skeleton in working memory using `templates/skill-design.md` as the shape (`SKILL.md:199–200`). Three sub-steps: name + description (self-graded against `checklists/skill-quality.md`), file layout recommendation, and generalization across platform / project / input / output axes.

The generalization step at `SKILL.md:230–241` walks four axes for each magic ingredient: platform (web / iOS / Android / language-agnostic), project (source-specific or any compatible repo), input shape (what trigger variations the skill handles), and output shape (file edits, commits, reports, runtime side effects). A magic ingredient that only applies on one platform or one project signals that the source session was too specific; it goes into the `## When NOT to use` section rather than the main flow.

Phase 3's file layout recommendation follows the pattern at `SKILL.md:217–228`: `SKILL.md` as main flow (≤500 lines), with overflow into `references/`, `personas/`, `checklists/`, `templates/`, `scripts/` as needed. Trivial skills stay a single file. The bias toward extra files is explicit: any chunk reusable across phases goes into a supporting file rather than being inlined.

Phase 4 presents the plan — one screen, five items — and asks destination via `AskUserQuestion` (`SKILL.md:277–293`). The user picks user-level, repo-level, or custom path. Custom path routes through the destination-conventions probe from Phase 2.3. No files are written until the user says `go`.

The five-item plan view (`SKILL.md:269–275`): skill name + description (frontmatter draft), magic-ingredients list (numbered, ≤12), file tree with one-line purpose per file, generalization summary, and destination recommendation with rationale. Keeping it to one screen is a hard constraint. The plan is read at approval time, and a long plan gets skimmed and approved uncritically.

### Phase 5 — Ship and bookkeeping

Files are written in order: `SKILL.md` first, then supporting files in `references/`, `personas/`, `checklists/`, `templates/` (`SKILL.md:303–311`). Body verified ≤500 lines before committing.

Bookkeeping is destination-dependent (`SKILL.md:315–338`). Marketplace destinations require four files updated in lockstep: `plugin.json` version bump (minor for new skill, patch for fix-only), matching `marketplace.json` bump, new section in `CHANGELOG.md`, new section in `README.md` under `## Skills`. Single-plugin repos drop the `marketplace.json` step. Plain repos write files and defer commit style to the user. The lockstep requirement is encoded explicitly in magic ingredient 10 (`SKILL.md:401–402`): "Bookkeeping in lockstep. Plugin version + marketplace + CHANGELOG + README in one commit, never partial."

The commit message records the distillation source — magic ingredient 11 (`SKILL.md:403–404`). The format at `SKILL.md:343–355` includes a one-paragraph distillation of what session inspired the skill, what problem it solves, and what the magic ingredients are. This is not boilerplate. A future `skill-distill` run on the destination repo can read that commit message as a free-text summary when no transcript is available. The commit message is the next run's source.

Phase 5.4 surfaces a confirmation that includes what was intentionally not included (`SKILL.md:368–374`). Skills have a hard scope; anything out of scope goes explicitly on the confirmation note rather than being silently dropped. That note is the starting point for a v2 distillation run if the scope turns out to have been too narrow.

The `personas/skill-author.md` file ships with `skill-distill` and is loaded during Phase 3. It covers skill-writing rules: voice, layout, tradeoff recording, attribution, and a self-check. The self-check asks whether the skill body reads as a distillation of real session patterns or as a generic LLM workflow. If the latter, the session extraction wasn't deep enough and Phase 1.2 needs to be re-run with a narrower lens.

---

## Tradeoffs and hard parts

### Why three lenses, not one

The rejected alternative was a single "extract what worked" pass over the transcript. That pass tends to surface the most salient content (the final working implementation, the agent's conclusions) and skip two categories that actually drive the skill's behavior.

User-prompt patterns alone miss the corrections that paid off. Corrections are the negative space of the session: they reveal what didn't work and what constraint was violated. A skill that encodes only the successful patterns will re-make the same mistakes the source session corrected. Course-corrections are bright lines; they become explicit rules in `checklists/` rather than general heuristics.

Corrections alone miss the framings that worked. "Industry refs are inspiration not gospel" is a framing the user wrote in Lens 1. That phrase didn't show up as a correction — nobody pushed back on it, because the agent honored it. A corrections-only pass would miss it entirely. The framing is load-bearing.

Agent-decisions alone miss both. The agent's tool choices and loop structures are visible in the session outputs, but without the user prompts that gave permission for them and the corrections that constrained them, you can't tell which agent decisions were intentional versus lucky.

The three-lens structure forces separate attention to each category. They're not redundant; the same session line can appear under multiple lenses for different reasons (`distill-method.md:6–8`). Forcing all three passes catches the cases any single pass would miss.

The concrete test: if all three lenses produce the same list, the session was simple and a single-file skill is probably enough. If the lists diverge — Lens 1 flags framings that Lens 3 never touched, Lens 3 flags corrections that Lens 1 missed — the divergence tells you which behaviors need explicit rules versus which ones the agent will do naturally.

### Why a subagent for magic extraction, not main context

The rejected alternative was reading the transcript directly in the main context, then continuing with Phase 2.

Large transcripts pollute the planning context. A 300-turn session JSONL file can run 50,000+ tokens. Loading that into the main context before Phase 2 means the prior-art search and destination probe run inside a window that's already 60–70% consumed by raw session content. Phases 3 and 4 (design and approval) then compete for the remaining budget. The design phase requires the most deliberate thinking of the five phases; running it in a full context degrades the quality of the output.

The subagent fix: one `Agent` call gets the transcript path and the distill-method instructions, reads the source, and returns an 8–12 item list. The list is all that enters the main context. The transcript stays in the subagent's isolated context and is discarded when that subagent finishes. The planning phases run in a lean window. This is the v1.7.1 change documented in the CHANGELOG: Phase 1.2 was originally a main-context read; the subagent dispatch was added specifically because test runs showed context pressure accumulating into Phase 3 (`SKILL.md:108–126`).

There's a secondary benefit: the subagent instruction explicitly says "do NOT draft any SKILL.md content" (`SKILL.md:120–121`). With main-context extraction, the temptation to start drafting is high — the agent has the transcript, the distill method, and the format rules all in scope at once. Isolating the extraction enforces the "read before you write" anti-pattern rule. The subagent literally cannot write any SKILL.md content because it's only handed extraction instructions.

### Why destination-aware bookkeeping, not a fixed marketplace target

The rejected alternative was writing to a fixed path and bumping the standard marketplace files.

The same skill might land in a marketplace, a single-plugin repo, or a plain repo with `.claude/skills/`. One-size-fits-one path breaks the others in specific ways: a marketplace write that skips `marketplace.json` shows a stale version in the marketplace UI; a plain-repo write that tries to bump `plugin.json` fails if no plugin manifest exists; a user-level write that commits anything at all touches files the user didn't ask to commit.

The four destination types each have a distinct bookkeeping contract:

| Destination | Files to update | Commit |
|-------------|----------------|--------|
| Marketplace | `plugin.json`, `marketplace.json`, `CHANGELOG.md`, `README.md` | required |
| Single-plugin | `plugin.json`, `CHANGELOG.md`, `README.md` | required |
| Plain repo | skill files only | user-controlled |
| User-level | skill files only | none |

The detection logic in `references/destination-conventions.md:49–50` probes for `marketplace.json` first, then `plugin.json`, then a bare git repo. Each probe result routes to a different set of write instructions. Getting this wrong produces partial commits that leave the destination in an inconsistent state: a marketplace write that skips `marketplace.json` reports a stale version in the marketplace UI until someone notices and fixes it manually. That kind of drift compounds — the version in `plugin.json` and the version in `marketplace.json` need to match exactly, and the only enforcement is the lockstep commit rule.

---

## What's next

Two open questions from the v1.7.1 design remain unresolved.

Whether the three-lens extraction can run incrementally during a session, rather than post-hoc. The current flow reads the completed transcript after the session ends. An incremental version would update the magic-ingredients list as the session progresses — flagging course-corrections in real time, accumulating user-prompt patterns as they appear, building the ingredients list before the user has to ask for distillation. The challenge is gate design: a mid-flight session isn't yet successful, extraction would be premature, and the user hasn't decided whether the session is worth capturing. A prompt on every session asking "is this worth keeping?" defeats the purpose — that's more friction than writing a memory note. The most viable version would watch for a high-concentration of Lens 3 signals (course-corrections) and offer to start an ingredients list without requiring the user to confirm success first. That would require a hook or a background monitor — neither of which `skill-distill` currently uses. The current design is entirely user-initiated.

An incremental ingredients list would also surface a secondary benefit: if the user corrects the same pattern multiple times across a session, that repetition is itself a signal that the ingredient is high-priority. Post-hoc extraction can't weight by repetition because the transcript is read once.

Whether successful distillations should auto-PR into the original session's plugin. Right now the skill writes files, the user commits, and the user pushes. A post-ship step that opens a PR against the destination repo would close the loop between the source session and the published skill. The open question is scope: committing is already in Phase 5.3 (`SKILL.md:343–355`); opening a PR adds push and `gh pr create` to the skill's footprint, which crosses a line most users want to own themselves. One narrower version: if the destination is a marketplace repo the skill already knows about (from the Phase 2.3 probe), offer a one-line suggestion of the `gh pr create` command rather than running it. The user gets the shortcut without the skill owning the push.
