# Refactor Experiment: [TITLE]

## Intent

[GOALS]

## Codebase context

[CODEBASE_CONTEXT]

## Workspace layout

```
<probe_dir>/
├── mission.md              # this file
├── progress.md             # scoreboard + task queue (max_iter header)
├── scoring-rubric.md       # co-designed dims with hint_action column
├── codebase/               # copy of target codebase (read-only for non-sandbox)
├── topics/
│   ├── 01-<topic>.md
│   └── ...
├── findings/
├── scores/
├── poc/                    # PoCs for BUILD-tagged dims
├── sources.md
├── contradictions.md
├── connections.md
├── gaps.md
├── synthesis.md
└── README.md
```

Run with: `/workshop-loop <this-dir>` for write-only HOST mode, or sandbox via:

```bash
./containers/workshop/launch.sh build --container=refactor
./containers/workshop/launch.sh shell --container=refactor <this-dir>
# inside container shell:
claude
# in Claude Code:
/workshop-loop /workspace
```
