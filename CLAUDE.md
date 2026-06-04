# OpenCode Agent Rules — DQ Project

## SYSTEM RULES (mandatory for every session)

### 1. FILE WRITE VERIFICATION
After writing ANY file, always verify:
```bash
$ cat <filepath> | head -5
```
If empty or missing, write again before proceeding.
Never assume a write succeeded without verification.

### 2. FILE READ FAILURE = HARD STOP
If any required file is not found:
- STOP immediately
- Report: "BLOCKED — <filename> not found. Cannot proceed."
- Do NOT continue, skip, or substitute with context

### 3. SCOPE LOCK
- Fix ONLY what is explicitly listed in the prompt
- Do NOT fix, suggest, or report anything outside defined scope
- Do NOT refactor, reformat, or restructure outside fix scope

### 4. SELF-VERIFY
After all edits:
- Re-read the FULL modified file, not just a 10-line window
- Confirm every changed line matches the issue description exactly
- Run any specified verification commands before reporting FIXED

### 5. EDIT SAFETY
- Never leave duplicate keyword arguments in function calls
- Always read the exact line content before attempting str_replace
- If oldString match fails, re-read the file and retry once
- Never attempt to edit before fully reading the target file

### 6. MODEL ROLE LOCK
- Coder: edits files only, never writes reports or updates Notion
- Reviewer: reads files only, never edits code
- Planner: writes markdown logs only, never edits code or SQL

### 7. COMMIT REMINDER
After every fix session, remind the user:
"Fixes complete — commit before next session:
git add <files> && git commit -m <message>"

### 8. NO SILENT FAILURES
- Never swallow errors or continue after a failed operation
- Always report tool call failures explicitly
- Never invent or hallucinate file contents if read fails

### 9. GREP BEFORE DECLARE
Before declaring any fix complete:
- Run grep or sed to confirm the exact change is in the file
- Never rely solely on the edit tool's success message

### 10. ONE MODEL ONE JOB
- If the prompt says Reviewer — only read and report
- If the prompt says Coder — only edit files
- If the prompt says Planner — only write markdown logs
- Never mix roles in a single session

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
