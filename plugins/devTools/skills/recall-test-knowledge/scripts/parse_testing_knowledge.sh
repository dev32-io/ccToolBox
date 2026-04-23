#!/usr/bin/env bash
# parse_testing_knowledge.sh — emit a JSON object with parsed methods + cases.
# Usage: parse_testing_knowledge.sh <path/to/testing-knowledge.md>
# Exit: 0 on success (even if file is malformed); 2 on missing arg or file.
set -euo pipefail

command -v jq >/dev/null || { echo "parse_testing_knowledge.sh: jq is required" >&2; exit 2; }

[[ $# -eq 1 ]] || { echo "usage: $0 <file>" >&2; exit 2; }
FILE="$1"
[[ -f "$FILE" ]] || { echo "parse_testing_knowledge.sh: file not found: $FILE" >&2; exit 2; }

python3 - "$FILE" <<'PY'
import sys, re, json, pathlib
path = pathlib.Path(sys.argv[1])
text = path.read_text()

# Split into top-level sections keyed by `## Heading` (case sensitive, exact).
sections = {}
current = None
buf = []
for line in text.splitlines():
    m = re.match(r'^##\s+(.+?)\s*$', line)
    if m and not line.startswith('### '):
        if current is not None:
            sections[current] = "\n".join(buf).strip()
        current = m.group(1).strip()
        buf = []
    else:
        if current is not None:
            buf.append(line)
if current is not None:
    sections[current] = "\n".join(buf).strip()

def split_entries(body: str):
    if not body.strip():
        return []
    # Entries start at `### `.
    parts = re.split(r'(?m)^###\s+', body)
    # First part may be preamble before any entry.
    entries = []
    for chunk in parts[1:]:
        chunk = chunk.rstrip()
        if not chunk:
            continue
        first_nl = chunk.find('\n')
        if first_nl == -1:
            heading = chunk.strip()
            content = ""
        else:
            heading = chunk[:first_nl].strip()
            content = chunk[first_nl+1:].rstrip()
        entries.append((heading, content))
    return entries

def parse_method(heading, content):
    # Required labels in order: Tool, When, Why this tool, How.
    labels = ["Tool", "When", "Why this tool", "How"]
    fields = {}
    for lab in labels:
        m = re.search(r'(?m)^\*\*' + re.escape(lab) + r':\*\*\s*(.+?)$', content)
        fields[lab.lower().replace(' ', '_')] = m.group(1).strip() if m else None
    valid = all(fields[l.lower().replace(' ', '_')] for l in labels)
    return {
        "kind": "method",
        "heading": "### " + heading,
        "surface": heading,
        "fields": fields,
        "valid": valid,
        "raw": f"### {heading}\n{content}".rstrip(),
    }

def parse_case(heading, content):
    # Required labels: Scenario, Why added, Steps, Expected.
    scenario_m = re.search(r'(?m)^\*\*Scenario:\*\*\s*(.+?)$', content)
    why_m      = re.search(r'(?m)^\*\*Why added:\*\*\s*(.+?)$', content)
    steps_m    = re.search(r'(?m)^\*\*Steps:\*\*\s*\n((?:[ \t]*\d+\.[ \t]+[^\n]+\n?)+)', content)
    expected_m = re.search(r'(?m)^\*\*Expected:\*\*\s*(.+?)$', content)
    steps_list = []
    if steps_m:
        for line in steps_m.group(1).splitlines():
            mm = re.match(r'\s*\d+\.\s+(.+)', line)
            if mm:
                steps_list.append(mm.group(1).strip())
    fields = {
        "scenario": scenario_m.group(1).strip() if scenario_m else None,
        "why_added": why_m.group(1).strip() if why_m else None,
        "steps": steps_list,
        "expected": expected_m.group(1).strip() if expected_m else None,
    }
    valid = bool(fields["scenario"] and fields["why_added"]
                 and fields["steps"] and fields["expected"])
    return {
        "kind": "case",
        "heading": "### " + heading,
        "name": heading,
        "fields": fields,
        "valid": valid,
        "raw": f"### {heading}\n{content}".rstrip(),
    }

methods_body = sections.get("Methods", "")
cases_body   = sections.get("Cases", "")

methods = [parse_method(h, c) for h, c in split_entries(methods_body)]
cases   = [parse_case(h, c)   for h, c in split_entries(cases_body)]

malformed = sum(1 for e in methods + cases if not e["valid"])

out = {
    "file": str(path),
    "stats": {
        "methods_total": len(methods),
        "cases_total": len(cases),
        "malformed": malformed,
    },
    "methods": methods,
    "cases": cases,
}
print(json.dumps(out, indent=2))
PY
