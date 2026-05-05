# Skill Design — `<skill-name>`

> Present this filled-in template at the end of Phase 4. The user
> replies `go` / `revise <what>` / `stop`. Do not write files until
> `go`.

## Mission (one sentence)

> <What problem the skill solves, for whom, on what input.>

## Frontmatter draft

```yaml
---
name: <skill-name>
description: >
  <what + when + key capabilities. ≤1024 chars. Include 3+ trigger
  phrases and 1+ "do not trigger on" near-miss.>
tools: <comma-separated allowlist or omit>
---
```

## Magic ingredients

The load-bearing rules distilled from the source session. The skill
encodes these as inline rules in its body and / or supporting
checklists.

1. <rule 1>
2. <rule 2>
3. <rule 3>
4. <rule 4>
5. <rule 5>
6. <rule 6>
7. <rule 7>
8. <rule 8>

(8–12 typical. Fewer = under-distilled. More = the skill is doing too
many things.)

## File tree

```
<skill-name>/
├── SKILL.md                              # main flow, ≤500 lines
├── references/
│   ├── <topic1>.md                       # <one-line purpose>
│   └── <topic2>.md                       # <one-line purpose>
├── personas/
│   └── <role>.md                         # <one-line mindset>
├── checklists/
│   └── <aspect>.md                       # <one-line discipline>
├── templates/
│   └── <artifact>.md                     # <one-line output shape>
└── scripts/                              # (optional)
    └── <helper>.sh                       # <one-line job>
```

## Generalization

| Axis     | Behavior                                              |
|----------|-------------------------------------------------------|
| Platform | <web / iOS / Android / desktop / language-agnostic>   |
| Project  | <source-project-only / any project / probed>         |
| Input    | <trigger forms + optional args>                       |
| Output   | <files / commits / report / runtime side effects>     |

## Destination recommendation

**Lead with:** <user / repo / custom>

**Why:** <one-line rationale>

**Alternatives:** <other reasonable choices + when to pick them>

User picks for real via the upcoming `AskUserQuestion`. This is just
the recommendation.

## Approve

Reply with:

- `go` — start Phase 5 (write + bookkeep + commit).
- `revise <what>` — adjust and re-present.
- `stop` — abandon the skill.
