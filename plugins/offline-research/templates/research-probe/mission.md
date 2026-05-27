# Research Mission: [TOPIC]

## Intent

[INTENT]

## Constraints

[CONSTRAINTS]

## Workspace layout

```
<probe_dir>/
├── mission.md              # this file
├── progress.md             # scoreboard + task queue (max_iter header)
├── scoring-rubric.md       # dims with 0/5/10 anchors
├── topics/
│   ├── 01-<topic>.md       # sub-questions per topic
│   └── ...
├── findings/               # one file per topic, written by topic-researcher
├── scores/                 # one file per scoring pass, written by critique-scorer
├── poc/                    # PoC artifacts when built
├── sources.md              # running bibliography
├── contradictions.md       # where sources disagree
├── connections.md          # cross-topic insights (lazy)
├── gaps.md                 # self-critique
├── synthesis.md            # mid/end-of-run narrative (synthesizer)
└── README.md               # final TLDR + navigation (synthesizer)
```

Run with: `/workshop-loop <this-dir>`
