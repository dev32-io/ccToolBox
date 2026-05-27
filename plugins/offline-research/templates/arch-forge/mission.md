# Architecture: [PROJECT_NAME]

## Intent

[PROJECT_INTENT]

## Constraints

[CONSTRAINTS]

## Sketch architecture

[ARCHITECTURE_SKETCH]

## Workspace layout

```
<probe_dir>/
├── mission.md              # this file
├── progress.md             # scoreboard + task queue
├── scoring-rubric.md       # Alignment/Feasibility/Maintainability/Risk/Effort
├── topics/                 # one file per decision area (called "topics/" for tool-uniformity)
│   ├── 01-<decision>.md
│   └── ...
├── findings/               # one file per decision, written by topic-researcher (Explore tasks)
├── scores/                 # critique-scorer output
├── poc/                    # PoCs for Feasibility BUILD tags
├── sources.md
├── contradictions.md
├── connections.md
├── gaps.md
├── synthesis.md
└── README.md
```

Run with: `/workshop-loop <this-dir>`
