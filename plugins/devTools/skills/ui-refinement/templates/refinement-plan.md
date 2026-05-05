# Refinement Plan — `<scope>`

> Present this filled-in template to the user at the end of Phase 3.
> They reply `go` / `revise` / `stop`. Do not start Phase 4 without
> `go`.

## Brief

**Target:** <which screen(s) / component(s)>
**Form factors:** <phone / tablet / desktop / all + any specific
profiles>
**Goals:** <one paragraph from Phase 1>
**Design-system guardrail:** <must-keep elements + bright line>
**Out of scope:** <explicitly excluded surfaces>

## Inspection matrix

The agent will capture and critique each cell:

| Viewport       | Scenario                | State        |
|----------------|-------------------------|--------------|
| 320 × 568      | initial load            | empty        |
| 390 × 844      | initial load            | empty        |
| 390 × 844      | one user message + reply | static      |
| 390 × 844      | tool-call cycle         | with pills   |
| 390 × 844      | long markdown reply     | scrolled     |
| 390 × 844      | mid-stream cycle        | streaming    |
| 768 × 1024     | one user message + reply | static      |
| 1280 × 900     | full multi-turn         | regression   |

(Adjust the table to the actual scope — usually 4–8 cells is right.)

## Test inputs

Concrete content the agent will drive into the feature:

- "Hello"
- "what's the weather tomorrow"
- "search the news for today"
- "give me a 200-word recipe for pancakes with markdown"
- "is the kitchen light on" (if HA tools available)
- "turn off all kitchen lights" (multi-tool fan-out)
- "show me a python hello world example with code block"

(Drop / replace based on the feature. Agent may invent more during the
loop; user can pre-seed required edge cases here.)

## Initial issue list

Confirmed by the user:

1. <user-listed issue 1>
2. <user-listed issue 2>
3. ...

To-verify (agent's static review, may turn out to be non-issues):

1. <agent-spotted issue 1>
2. ...

> The agent will find more during Phase 4. The list above is a seed,
> not a cap.

## Regression scope

Surfaces that must remain unchanged after every pass:

- Desktop chat at 1280 × 900
- Settings panel
- Wizard flow
- ...

## Done definition

The loop exits when:

- [ ] The agent runs Phase 4.2 critique on the latest state and
      produces zero findings flagged as `blocker` or `major`.
- [ ] All seeded `confirmed` issues are resolved or explicitly
      deferred (with reason).
- [ ] All regression-scope surfaces match their baseline.
- [ ] The agent's senior-designer pass answers "would I ship this?" =
      yes.

User can pin a stricter or looser bar (e.g. "match the Figma frame
within 5% pixel diff" / "just hit the 5 listed issues, ignore
everything else").

## Cadence

- Branch: `<feature/ui-refinement-scope>` off `<parent>`.
- Commit: each meaningful pass (1 fix-cluster per commit).
- Push: hold until end; user will trigger.
- Estimated passes: <3–10> based on initial issue count and surface
  size.

## Approve

Reply with:

- `go` — start Phase 4.
- `revise <what>` — adjust the plan and re-present.
- `stop` — abandon the skill.
