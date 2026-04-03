# Ralph Loop Command

Copy your `prompt.md`, `progress.md`, `critique-loop.md`, and `scoring-rubric.md` to `/workspace/`, then run:

```
/ralph-loop:ralph-loop "Read /workspace/prompt.md and execute the research mission. Read /workspace/progress.md to find your current phase and next incomplete task. For deep dive topics, read the spec from /workspace/topics/ and write output to /workspace/findings/. Update progress.md after each step. Output <promise>ALL PHASES COMPLETE</promise> when every phase is done." --max-iterations <TOPIC_COUNT + 15> --completion-promise "ALL PHASES COMPLETE"
```

**Max-iterations:** Count your initial topics and add 15. Example: 8 topics → `--max-iterations 23`.
