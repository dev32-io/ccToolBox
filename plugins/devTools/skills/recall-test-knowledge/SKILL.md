---
name: recall-test-knowledge
description: >
  Auto-load relevant distilled testing knowledge (methods and cases from
  `agents/docs/testing-knowledge.md` plus testing-related rule files)
  into the current session. Use when the user asks to write a test, add
  a test case, design a test plan, smoke-test a feature, verify
  behavior, or otherwise work on testing — e.g. "how do we test X",
  "write a test for Y", "add a smoke test", "what's the test plan",
  "verify this works". Do NOT trigger on casual mentions ("I tested it
  earlier", "the tests pass"). Read-only; never writes files.
tools: Agent, AskUserQuestion, Bash, Read, Grep, Glob
---

# recall-test-knowledge — Load Distilled Testing Knowledge

Read-only consumer of `agents/docs/testing-knowledge.md` (produced by the
`retro` skill) and testing-related `.claude/rules/*.md`. Dispatches a
subagent to find relevant entries, confirms the candidate set with the
user, then injects approved entries verbatim into the session.

This skill runs against the **user's target project**, not ccToolBox.
Script paths below are relative to this skill directory.

## Flow at a glance

1. **Preamble** — one-line notice the skill fired, plus the user query
   that triggered it.
2. **Context probe** — run `scripts/probe_context.sh`, parse JSON.
3. **Parse testing knowledge** — run
   `scripts/parse_testing_knowledge.sh` on `testing_file`. If missing or
   empty, stop with a one-liner.
4. **Collect session hints** — extract filenames, function / component
   names mentioned in the last few conversation turns (your judgement).
5. **Dispatch search subagent** — one `Explore` subagent ranks relevance
   across parsed entries + rule files. Returns candidate JSON.
6. **Render candidates + directive** — table with previews; wait for
   `all` / `only N,M` / `except N,M` / `preview N` / `cancel`.
7. **Inject** — output approved entries verbatim into the session.

## Step 1 — Preamble

Print a single line, no gate:

```
recall-test-knowledge fired on: "[user query]"
Scanning testing-knowledge.md + rule files…
```

No confirmation prompt here — the skill is fast and read-only. The gate
comes after the subagent returns candidates.

## Step 2 — Context probe

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/probe_context.sh"
```

Parse the JSON. Record: `REPO_ROOT`, `BRANCH`, `DIFF_PATH`, `TESTING_FILE`,
`RULE_FILES`.

If `TESTING_FILE` is empty (not yet created in this project), stop with:

```
No agents/docs/testing-knowledge.md yet. Run /retro after your next
feature branch to start distilling testing knowledge.
```

## Step 3 — Parse testing knowledge

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/parse_testing_knowledge.sh" "$TESTING_FILE"
```

Parse the returned JSON. Note `stats.methods_total`, `stats.cases_total`,
`stats.malformed`. If `methods_total == 0` and `cases_total == 0`, stop:

```
testing-knowledge.md exists but contains no ## Methods or ## Cases
entries. Run /retro to populate it.
```

## Step 4 — Collect session hints

From the last ~10 turns of the conversation (or the current user turn if
the skill fired on-trigger), extract:
- File paths mentioned (e.g. `src/auth/login.py`)
- Component / function names in backticks or CamelCase/snake_case
- Feature nouns the user used (one or two words)

Deduplicate. Cap at 20 hints.

## Step 5 — Dispatch search subagent

Use `Agent` tool with `subagent_type: "Explore"`. Prompt (fill
brackets):

> You are the search pass of the `recall-test-knowledge` skill. Return a
> single JSON object to stdout. No prose, no fences.
>
> **Inputs:**
> - User query: `[USER_QUERY]`
> - Diff path list: file `[DIFF_PATH]` (one path per line)
> - Session hints: `[HINTS_COMMA_SEPARATED]`
> - Parsed testing knowledge: `[PARSED_JSON_INLINE]`
> - Rule files (paths, read as needed):
>   `[RULE_FILES_NEWLINE_SEPARATED]`
>
> **Method:**
> 1. For each method / case entry in the parsed JSON, compute a relevance
>    score as the union of:
>    - Keyword overlap between user query and entry heading / fields
>    - Path overlap between diff paths and entry scenario / when / steps
>    - Hint overlap between session hints and entry heading / fields
> 2. For each rule file, read and decide if its content is testing-related
>    AND relevant to the user query / hints. If yes, emit a `rule-ref`
>    candidate with a one-line pointer (NOT full file content).
> 3. Return up to 8 candidates total, ranked by relevance. Under-select
>    rather than over-select.
>
> **Output schema (strict):**
> ```json
> {
>   "query": "[USER_QUERY]",
>   "stats": { "methods_scanned": N, "cases_scanned": N,
>              "rules_scanned": N, "malformed_skipped": N },
>   "candidates": [
>     {
>       "id": "kebab-case-stable-id",
>       "kind": "method|case|rule-ref",
>       "source": "testing-knowledge.md|.claude/rules/<name>.md",
>       "heading": "### <as-is> | <rule section or filename>",
>       "preview": "<first 120 chars of entry body>",
>       "content": "<full literal bytes of the entry — for method/case;
>                   one-line pointer for rule-ref>",
>       "relevance": "<one sentence on why this matched>"
>     }
>   ]
> }
> ```
>
> Malformed JSON output will trigger one retry. A second failure aborts
> the skill with a one-line message.

Parse the returned JSON. If `candidates` is empty, print and stop:

```
No relevant testing knowledge found for: "[user query]"
```

## Step 6 — Render candidates and collect directive

Render a table, columns: `#`, `kind`, `source`, `heading`, `preview`.

Below the table, prompt:

> Reply with:
>   `all`                  — inject every candidate
>   `only 1, 3`            — inject only these
>   `except 2`             — inject all except #2
>   `preview N`            — expand candidate N, then re-prompt
>   `cancel`               — stop without injecting
>
> For rule-refs, content is a pointer — Claude will read the file
> on-demand next turn if needed.

**Directive parsing:**
- `all` → approve all
- `only N[,M,…]` → approve listed #s only
- `except N[,M,…]` → approve all except listed
- `preview N` → print full `content` of #N verbatim, then re-render the
  prompt (same directive set; skip the preview keyword to decide)
- `cancel` → stop silently

## Step 7 — Inject approved entries

Output this block verbatim as assistant text (this IS the injection —
whatever you print becomes part of session context):

```
Loaded N entries from testing-knowledge.md:

---
<candidate 1 heading>
<candidate 1 content>

---
<candidate 2 heading>
<candidate 2 content>
```

Rule-refs go in a separate trailing block:

```

Rule references (read on-demand if needed):
- <candidate 1 content>
- <candidate 2 content>
```

End with:

```
---
```

Do NOT summarize, paraphrase, or condense. The content is the source of
truth.

## Notes and invariants

- **Read-only.** Never writes to `testing-knowledge.md` or any rule file.
  If the user wants to update distilled knowledge, point them at
  `/retro` in the next session.
- **No execution.** This skill does not run the documented cases or
  methods. It loads them as context; the main session decides what to do.
- **Format contract.** Parsing assumes retro v1.3 label format. If the
  retro skill changes labels, this skill's parser and prompt must bump
  together.
- **Malformed entries** are skipped (counted in `stats.malformed`). The
  skill does not attempt repair.
- **Rule files** are referenced, not injected wholesale, to avoid
  context bloat. The main agent can read them on-demand next turn.
