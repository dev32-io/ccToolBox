# Research Mission: [TOPIC]

You have full autonomy. Do not ask questions. Use your best judgement.

## Workspace Structure

```
/workspace/
├── progress.md              # scoreboard + task queue — your instruction sheet
├── critique-loop.md         # how to handle Critique & Score tasks
├── scoring-rubric.md        # scoring dimensions for subagents
├── topics/
│   ├── 01-topic-name.md     # sub-topics + questions
│   └── ...
├── findings/
│   ├── topic-name.md        # research output per topic
│   └── ...
├── poc/                     # prototypes, architectures, visual explorations
│   └── ...
├── sources.md               # running bibliography — URLs, titles, notes
├── contradictions.md        # where sources disagree
├── connections.md           # cross-topic patterns and insights
├── gaps.md                  # self-critique — what's weak, what needs more work
└── README.md                # final TLDR + navigation
```

## How This Works

1. Read `progress.md` and find the next unchecked item in the Task Queue
2. Do that ONE item
3. Check it off in progress.md
4. Output `TASK DONE`
5. Stop — you will be re-invoked automatically

When the task queue is empty, output `<promise>TASK DONE</promise>` instead.

Research isn't only reading. When a topic would benefit from *making something* — you should definitely do it. Build prototypes, draft architectures, sketch mockups. Create a folder in `poc/` and treat it as a topic.

## Initial Topics

[TOPICS]
