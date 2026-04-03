# Ralph Loop Command

Copy your `prompt.md`, `progress.md`, `critique-loop.md`, and `scoring-rubric.md` to `/workspace/`, then run:

```
/ralph-loop:ralph-loop "Read /workspace/prompt.md for context. Read /workspace/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop." --max-iterations <TOPIC_COUNT * 8 + 10> --completion-promise "TASK DONE"
```

**Max-iterations:** `topics × 8 + 10`. Example: 7 topics → `--max-iterations 66`.
