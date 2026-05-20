# ui-refinement

> Originally documented in [CHANGELOG.md](../CHANGELOG.md) under v1.6.0 / v1.7.0 / v1.7.1.
> Architectural decisions shared with [`skill-distill.md`](skill-distill.md) — see [`2026-05-06-v1.7.1-refactor.md`](2026-05-06-v1.7.1-refactor.md) for the v1.7.1 postmortem.

I built `ui-refinement` because UI iteration with Claude Code kept stopping at "works for the happy path." I wanted a loop that holds the bar without me sitting in front of it. Captures the screen, critiques it as if a senior designer and a ruthless tester were both reviewing, then fixes and re-captures until the standard is met.

The specific failure was a mobile chat view. I gave Claude a list of issues and it fixed exactly the list. The fixes were locally correct. The screen still looked bad. Every problem I hadn't listed was untouched, and Claude had no mechanism to go looking for the ones I missed. The model was waiting for me to find the next defect and report it. That's not iteration; that's a ticket system. What I wanted was for Claude to own the loop end-to-end: look at the actual rendered screen, form an opinion about every defect visible, fix a tight cluster, look again, and not stop until nothing left would embarrass a serious product team.

The session that broke this open produced 5 production commits. The framings that made it work were in the user prompts: "DO NOT only look at the issues I listed, take as much iteration as you need." "Be EXTREMELY ruthless." "Industry refs are inspiration not gospel." None of those made it into the first SKILL.md draft, because writing the skill by hand I summarized the outcomes, not the framings. `skill-distill` is the downstream fix. This skill is the problem that made that one necessary.

The files shipped with v1.6.0: `SKILL.md` (main flow, 504 lines), two persona docs, three platform docs (`platforms/web.md`, `platforms/ios.md`, `platforms/android.md`), two checklists (`checklists/visual-critique.md`, `checklists/design-system-guard.md`), one plan template. No scripts. The CHANGELOG v1.6.0 entry is the primary record of intent.

This is a skill in the same pattern as `skill-distill`: a five-phase numbered flow, TodoWrite items per phase for visible state, explicit anti-patterns called out by name, and magic ingredients encoded directly in the SKILL.md so the model re-reads them at the start of every Phase 4 pass. The anti-patterns and magic ingredients are the load-bearing parts. Without them, the model falls back to one-shot behavior: fix the list, exit. The ingredients keep it in the loop.

The Phase 1 Define step does work that a one-shot prompt skips: it identifies the exact target screens and form factors via `AskUserQuestion` (`SKILL.md:101–114`), optionally loads design references (Figma URL, competitor screenshot, design-system doc), and produces a brief the user signs off on before any inspection begins (`SKILL.md:96–149`). The brief includes the design-system guardrail as a named constraint. Getting this wrong at Phase 1 means the loop spends passes on the wrong surface, or fixes things the user's design system treats as intentional. The guardrail is what separates iteration from drift.

---

## How it works

> All file:line references below are relative to `plugins/devTools/skills/ui-refinement/` unless otherwise noted.

The skill runs a five-phase loop: **Define → Setup → Plan → Execute → Done** (`SKILL.md:96–421`). One TodoWrite item per phase; Phase 4 nests one item per iteration pass. The flow diagram at `SKILL.md:70–89` shows the only non-linear edge: the re-critique check at Phase 4.8 (`SKILL.md:408–418`) loops back into Phase 4 on "iterate" and exits to Phase 5 only when the agent can no longer find a finding, or the user stops it.

```
Phase 1 — Define  →  Phase 2 — Setup  →  Phase 3 — Plan
                                                    ↓
                  Phase 5 — Done  ←  Phase 4 — Execute loop
                                          ↑ iterate (loops here only)
```

### MCP integration and platform fallback

The skill drives a real browser or simulator through whatever MCP is installed. Phase 2.1 detects the platform and reads the matching platform doc (`SKILL.md:160–173`). The fallback ladder:

| Priority | MCP | Platform | Platform doc |
|----------|-----|----------|--------------|
| 1st | Playwright MCP | Web | `platforms/web.md` |
| 2nd | Chrome DevTools MCP | Web (fallback) | `platforms/web.md` |
| 3rd | iOS simulator MCP | Native mobile | `platforms/ios.md` |
| 4th | Manual screenshot loop | Any (last resort) | per-platform |

If no MCP is installed for the target platform, the skill surfaces the gap and stops. Text-only critique defeats the entire skill (`SKILL.md:168–171`). The deferred MCP tools are gated via `ToolSearch` before any inspection begins, with the exact `select:` queries defined in each `platforms/*.md` file.

The Phase 2.2 and 2.3 steps handle everything that lets the loop actually run: offering to commit or stash any open changes before branching, detecting compose files and dev scripts and proposing (not running) the bringup command, and enumerating external dependencies the feature needs end-to-end: API tokens, external services, test data, environment variables (`SKILL.md:176–210`). Cost protection is an explicit encode: when the user provides credentials for paid services, the skill asks whether to use them. Some users deliberately withhold expensive keys so the loop stays free. That constraint holds for the entire session.

### Instruction-driven personas

The two critique guides (`personas/senior-designer.md`, `personas/ruthless-tester.md`) are written as rules and scan orders, not role-play. `senior-designer.md` is titled "Visual-quality critique guide" and opens with: "No role-play, no 'imagine you are...' — just apply the rules below to the captured screenshot" (`senior-designer.md:5–6`). `ruthless-tester.md` is titled "Edge-state critique guide" with the same framing: "Not role-play; a state-coverage discipline" (`ruthless-tester.md:4–5`).

This was the v1.7.1 shift documented in the CHANGELOG: "Dropped the 'you are a senior designer' / 'you are a frustrated power user' role-play framings — the model treats role-play as noise and the rules as signal" (CHANGELOG v1.7.1). The content (scan order, finding format, operating rules) is preserved; what changed was the framing. The full story is in `2026-05-06-v1.7.1-refactor.md`.

`senior-designer.md` prescribes a ten-step scan order: hierarchy, alignment, spacing rhythm, sizing consistency, density, type, color, motion, edges, affordance (`senior-designer.md:22–55`). Every finding requires four fields: What, Where (selector or bbox), Why (rule cited), Severity. Hedged findings are explicitly banned: "the spacing might be a little tight" is bad; the good form cites a measurement and a rule (`senior-designer.md:57–68`).

`ruthless-tester.md` runs the edge-state coverage: empty, one, few, many, overflow, loading, error, streaming, interrupted, multi-locale, multi-density, light plus dark, keyboard open, tap targets (`ruthless-tester.md:54–76`). It also lists defects often missed in pure visual review: truncation traps, hover-only affordances on touch, z-index conflicts, animation jank, a11y regressions from visual fixes (`ruthless-tester.md:92–107`).

### Phase 4.1 — Aggressive exploration mandate

Phase 4.1 is not "open the page and screenshot it." The mandate is: click every interactive element, open every entrance, exit every exit, try every input, walk every flow end-to-end (`SKILL.md:251–282`). For each distinct state reached, capture both a screenshot (for visual critique) and an accessibility snapshot or DOM inspection for measurements. The bar for finishing Phase 4.1: the agent can no longer think of a fresh interaction to try in scope. Stopping earlier means going back (`SKILL.md:283–286`).

The anti-pattern at `SKILL.md:58–66` names what Phase 4.1 replaces: "passive exploration," defined as screenshotting the default state and calling it done. The skill names this explicitly because it is the single most common failure mode. A model with no explicit instruction tends to settle into default-state capture and theoretical critique ("I think the bubble is too wide"). The Phase 4.1 mandate forces the model into the actual operating mode: use the feature like a power user before forming any opinion.

The "ruthless tester is not a hat the agent puts on for a moment" (`SKILL.md:63–64`). It is the operating mode for the entire exploration pass. The exploration drives both critique subagents in Phase 4.2: Subagent A needs the settled-state screenshots, Subagent B needs the edge-state screenshots. If Phase 4.1 was passive, both subagents work from the wrong inputs.

Screenshots are labeled with a deterministic name (`<scope>-<viewport>-<scenario>-<state>.png`), saved to the project's existing screenshot directory if one exists, otherwise to `.playwright-mcp/`.

### Phase 4.2 — Parallel subagent dispatch

Phase 4.2 dispatches two `Agent` subagents in a single message (`SKILL.md:289–296`). Each subagent gets the captured screenshot paths, the design-system guardrail from Phase 1.3, and one critique guide.

Subagent A runs the visual-quality guide (`personas/senior-designer.md`) plus `checklists/visual-critique.md`. It returns a findings table with columns: What, Where, Why, Severity. No hedged findings; every finding cites a checklist item or design-system rule (`SKILL.md:300–312`).

Subagent B runs the edge-state guide (`personas/ruthless-tester.md`) and hunts for defects the visual pass would miss: edge content lengths, error/loading/streaming states, mobile probes, a11y. It returns a findings table with a Category column added: edge-state, a11y, mobile, design-language (`SKILL.md:313–320`).

Each subagent gets the design-system guardrail from Phase 1.3 verbatim so both passes can check findings against it independently, without coordination through the main agent. The main agent's role in Phase 4.2 is merge, dedupe, and escalate contradictions. It does not re-run either critique pass in its own context.

The main agent merges and dedupes when both return, keeps the more-specific phrasing where both found the same defect, and flags contradictions for explicit user resolution (`SKILL.md:320–326`). If the scope is too small for two passes (single component, one viewport), the skill collapses into one subagent that runs both guides sequentially. Neither guide is skipped (`SKILL.md:327–329`).

### Phase 3 — Plan and Phase 5 — Done

Phase 3 produces a written iteration plan using `templates/refinement-plan.md` as the shape (`SKILL.md:218–243`). The plan covers five items: inspection matrix (viewports times scenarios times states), test inputs (actual content the agent will use to drive the feature), initial issue list (user-listed plus agent-spotted, marked confirmed or to-verify), regression scope (surfaces that must stay unaffected), and done definition (the agent's own bar stated explicitly). The plan is presented for approval via `AskUserQuestion`. No files are touched until the user says go.

Phase 5 produces a one-screen recap: branch name and commit count, before/after summary (numeric where possible, e.g. "list gap 24px → 14px"), anything intentionally not fixed and why, and recommended next steps (`SKILL.md:421–433`). That numeric format forces the agent to have taken measurements during Phase 4.1 rather than describing changes only in terms of what it intended to do. Anything out of scope gets listed explicitly on the Phase 5 confirmation, not silently dropped, because the Phase 5 note is the starting point for a follow-up session.

### Phase 4.3–4.7 — Fix cycle per pass

After Phase 4.2 produces a merged findings table, Phase 4.3 picks a tight cluster of 1–4 findings that share a fix surface, usually one CSS block or one component (`SKILL.md:332–342`). Before touching code, the scope guard runs: does the fix risk affecting other viewports or surfaces? Does it use existing design tokens? Does it preserve the Phase 1 guardrail? If all three pass, Phase 4.4 makes the edit via `Edit` (preferred) or `Write`, minimal change, nothing outside the cluster (`SKILL.md:343–359`).

Phase 4.5 re-captures the same viewport and scenario, compares to baseline, and notes explicitly whether the targeted defect resolved and whether any unintended change appeared: color shift, layout reflow, content truncation (`SKILL.md:361–369`). Phase 4.6 re-captures every viewport in the regression scope to eyeball for obvious breakage (`SKILL.md:371–379`). If a regression is found, the change is reverted or scoped behind a media query. The rule is absolute: do not ship a fix that breaks an unaffected surface (`SKILL.md:377–379`). Phase 4.7 commits the pass with a descriptive message: type, scope, one-line summary, body noting the specific defect resolved (`SKILL.md:381–404`).

The twelve Magic ingredients at `SKILL.md:456–490` are re-read at the start of every Phase 4 pass. They encode the behavioral rules that can't be enforced structurally: "exit on quality bar, not iteration count," "real running stack, real data," "find more than the list." Encoding them as a re-read list rather than rules buried in phase descriptions keeps them in active context throughout the loop. The list is the difference between a model that knows the rules and a model that applies them.

### Design-system guardrail with escalation

Phase 1.3 produces a written brief that includes an explicit design-system guardrail (`SKILL.md:134–149`). The guardrail states what must stay: design tokens, component patterns, element shapes the user owns as their design language. Every Phase 4.3 fix is scope-guarded before the edit (`SKILL.md:335–342`): does the fix use existing design tokens? Does it preserve the guardrail from Phase 1? If a check fails, two options: revise the fix to stay inside the guardrail, or escalate to the user with the tradeoff in one sentence. The guardrail is live across the whole loop. Course-corrections from the user during the loop update the agent's working-notes copy of the guardrail, and every future pass must respect the updated version (`SKILL.md:441–450`).

The two escalation options (revise or escalate) matter because they prevent a failure mode common in unconstrained refinement loops: the model silently drops a user's design decision in service of a "better" pattern it learned from training data. Avatars, asymmetric bubble corners, meta-row patterns. These are design language, not errors. Without a named guardrail, the model doesn't know the difference between a real defect and an intentional design choice. The escalation path for "no" answers gives the user agency without stopping the loop entirely. The course-correction protocol at `SKILL.md:438–450` describes what happens when the user pushes back mid-loop: revert immediately, update the guardrail in working notes, one-sentence acknowledgment, continue. The loop doesn't stop; the scope narrows.

---

## Tradeoffs and hard parts

### Why two personas, not one

The rejected alternative was a single "review this screenshot" pass using both critique criteria together.

Bundling the two guides into one prompt causes the model to drop one. The visual-quality pass (`senior-designer.md`) scans for hierarchy, spacing rhythm, type scale, color contrast: things visible in a settled state. The edge-state pass (`ruthless-tester.md`) hunts for what the settled state hides: overflow content, loading transitions, mobile keyboard interactions, a11y regressions from visual fixes. The visual pass produces clean findings on the happy-path screenshot. The edge-state pass finds that the same component breaks entirely when the content is 200 words long or the soft keyboard is open.

Bundled into one prompt, the model optimizes for one lens. On a screenshot with many hierarchy and spacing issues, the visual findings crowd out the edge-state hunt. On a component with obvious edge-state problems, the model fixes those and underweights the visual polish. Splitting into two subagents enforces that each guide gets a full, uninfluenced pass. Subagent B's mandate is explicit: "Find at least N more defects than the user listed" (`ruthless-tester.md:9–10`). That mandate would be diluted if the same subagent also had to produce hierarchy and spacing findings.

The division maps directly onto the two failure modes the skill was built to address. Senior-designer catches what a visual review would catch. Ruthless-tester catches what only someone actively using the feature would find. Neither mode is a substitute for the other.

The two guides are also structured differently in a way that reinforces the split. `senior-designer.md` prescribes a fixed scan order (hierarchy first, affordance last) with four required fields per finding. `ruthless-tester.md` prescribes a state-coverage mandate ("drive empty, one, few, many, overflow, loading, error, streaming, interrupted...") with an explicit category column in the findings table. Different structure means different operating mode. Combining them into one file would create pressure to unify the structure and lose the distinction that makes each one precise.

### Why parallel subagent dispatch, not sequential

The rejected alternative was running Subagent A, waiting for findings, then running Subagent B with the same screenshots.

Sequential dispatch is slower, but the more important reason to run in parallel is context budget. A long iteration loop, Phase 4 running 5–7 passes on a multi-viewport scope, accumulates significant context pressure in the main agent. Each pass adds screenshots, findings tables, fix descriptions, regression checks, and commit notes. Running the two critique subagents in parallel means the main context carries only the merged findings table, not the full working context of each subagent. The v1.7.1 CHANGELOG is explicit: "Keeps the main context lean over long iteration loops; speeds up each pass" (CHANGELOG v1.7.1). Each subagent runs in an isolated context and discards that context when it returns. The main agent gets only the output.

A secondary benefit: the two guides don't share context, so neither subagent is influenced by the other's findings mid-run. Subagent B can surface a finding that Subagent A would have dismissed if they had run sequentially and B had read A's output first. Independent context means independent judgment.

The same reasoning applies in `skill-distill`: the two parallel subagents in Phase 2 (prior-art search and destination probe) are independent and run in parallel for the same reason. The v1.7.1 release updated both skills simultaneously with this pattern (`SKILL.md:292–296`; `skill-distill` SKILL.md Phase 2). It's a structural decision about how to use Claude as a runtime, not a performance optimization added on top of a working design.

### Why "top-tier team" as the standard, not "good enough"

The rejected alternative was a qualitative bar like "are there obvious issues?"

The loop exits when the agent can no longer find a finding (`SKILL.md:408–418`). The exit condition is self-assessed. That means the bar the agent applies directly controls when iteration stops. A "good enough" bar gives the model permission to exit on mediocre UI: nothing is obviously wrong, the listed defects are fixed, the model stops. The "top-tier team" bar is encoded at `SKILL.md:65–66` and again in the Magic ingredients at `SKILL.md:469–470`: "The bar is 'would a top-tier team ship this?' — not 'is it tolerable?'." The same phrase appears in `senior-designer.md:10–12`: "Hold a very high standard — the question is not 'is it tolerable?' but 'would a top-tier product team ship this with their name on it?'."

The bar matters because it determines convergence. A model instructed to hold a high standard keeps finding things to fix until the work is genuinely done. A model given a low bar finds a local minimum and stops. The specific phrasing "with their name on it" is load-bearing because it invokes pride of authorship rather than checkbox compliance. A checklist can be satisfied by a mediocre result that technically passes each item. "Would a top-tier team ship this with their name on it?" cannot.

This is also why the Magic ingredients at `SKILL.md:456–490` include the standard verbatim rather than paraphrasing it. The exact words matter. Paraphrased into "hold a high bar" or "aim for quality," the phrase loses its specificity. The model has trained against many prompts that say "be thorough" and learned to exit on the first acceptable answer. The "top-tier team" framing is distinct enough to carry a different behavioral signal.

There is a related anti-pattern at `SKILL.md:51–56`: "theoretical critique," defined as writing "I think the bubble is too wide" or "this might feel cramped on mobile" without opening the browser. The anti-pattern is named there, and the bar is named in the Magic ingredients. Both are guards on the same failure mode: a model exiting the loop on impressions rather than evidence. The exit condition, the exploration mandate, and the bar are all three parts of one design decision. Change any one and the loop stops at the wrong place.

---

## What's next

Three open questions from v1.7.1 remain unresolved.

Whether the loop should self-tune the bar over multiple sessions. The current design applies a fixed standard on every run. A version that tracked findings-per-pass over time could detect that a given codebase converges fast (few findings per pass, consistent UI system) versus slowly (many findings per pass, inconsistent patterns) and adjust how aggressively the model hunts before proposing exit. That would require state across sessions, and the skill currently holds none. The Phase 4.8 checkin at `SKILL.md:415–417` already surfaces pass count to the user: "Pass 5 done. I think we're at the bar — want me to keep looking or wrap up?" That's a manual version of the same feedback. The harder challenge is distinguishing calibration from drift: a lower exit bar on a well-maintained codebase might mean the quality floor genuinely rose, or it might mean the model is exiting too early. Enforcing the distinction without human review on every exit would be difficult. One conservative version: track the count of findings returned per pass and surface it at Phase 5 as a trend line. The user could decide whether the trend means the codebase improved or the bar slipped. That doesn't require autonomous self-tuning and avoids the drift problem, but it shifts the judgment to the user, which may or may not be the right place for it.

Whether mobile and desktop should split into separate personas. The current setup uses one senior-designer guide and one ruthless-tester guide regardless of viewport. Desktop and phone critique share most criteria but diverge sharply on density conventions, tap-target sizing, thumb-reach, and soft-keyboard layout. A finding that's a major defect on phone ("tap targets below 44pt") may not apply on desktop at all. Splitting into mobile-specific and desktop-specific variants of each guide would produce more targeted findings at the cost of four persona files instead of two. The simpler version, adding explicit mobile-versus-desktop branches inside the existing guides, may be sufficient and avoids the overhead of loading extra files on every pass. The `ruthless-tester.md` file already has a mobile-specific probes section (`ruthless-tester.md:79–89`), so the branching exists in embryo; the question is whether it should be promoted to a separate file. Neither version exists yet.

Whether iOS Safari requires its own platform handling. The current web platform doc (`platforms/web.md`) covers Playwright MCP and Chrome DevTools MCP, both Chromium-based. Safari rendering differences (font smoothing, scroll behavior, safe-area insets, position-fixed handling, rubber-band scroll) are only caught if the user explicitly configures a Safari-capable Playwright setup or uses the iOS simulator path. The iOS simulator path works for native apps but is awkward for pure web: it requires Xcode, a booted simulator, and a different MCP, and the feedback loop is slower. Most of the `platforms/ios.md` path assumes a native app. For progressive web apps that must render well on iOS Safari, none of the current platform paths give reliable coverage. That is a real gap and remains unaddressed.
