---
description: Strip AI-slop comments from code; keep only comments matching repo conventions
argument-hint: "[path]  (default: files with uncommitted changes)"
allowed-tools: Bash(git:*), Bash(rg:*), Read, Edit
---

# clean-comments

This codebase is **production code serving millions of users**. Comments must be
load-bearing, not narrate. Strip AI-generated noise (ticket links, Figma references,
"added for X" justifications, what-the-code-does narration) while preserving the few
comments that genuinely matter — and only in the style this repo already uses.

Target: `$1` if provided, otherwise files with uncommitted changes.

## Steps

### 1. Determine target files

```bash
if [ -z "$1" ]; then
  TARGETS=$( { git diff --name-only HEAD; git diff --cached --name-only; git ls-files --others --exclude-standard; } | sort -u | grep -v '^$')
else
  TARGETS="$1"
fi
echo "$TARGETS"
```

If empty, exit: "No changed files to clean."

### 2. Calibrate to the repo's actual comment style — BEFORE touching anything

Don't trust your prior on "how comments should look" — read this repo. Sample ~15 files
that were **not** changed in the current diff (they may be clean of AI slop):

```bash
git log --pretty=format: --name-only -200 | sort -u | grep -v '^$' | head -50
```

Pick 15 distinct files spanning backend, frontend, schemas, tests. Read each. Note:

- Are JSDoc/docstrings used on exports? In what shape (`/** */`, `//`, language-native)?
- Are inline `//` comments common or rare?
- Do existing comments narrate WHAT, or only explain WHY (non-obvious constraint)?
- TODO / FIXME / HACK markers — used? forbidden? If used, what format?
- Project-specific markers (NOTE:, INVARIANT:, etc.)?
- License/copyright headers on files?

Write ONE paragraph summarizing the conventions before editing. Show it to the user.

### 3. Classify every comment in every target file

For each target file, read it. For each comment, classify:

**REMOVE** (default — be aggressive):
- Narrates WHAT the code does (well-named identifiers already do that)
- References the current task / PR / fix / callers ("used by X", "added for Y feature",
  "handles the case from issue #123", "after the refactor", "post Z migration")
- Ticket links (JIRA, LINEAR, GH issue URLs) — these belong in the PR description, never
  in code
- Figma URLs, design references, screenshots
- AI hedge or justification ("I think this is the cleanest", "added for safety",
  "this is needed because the requirements say…", "matching the existing pattern")
- Restates the function name / signature
- "TODO: …" without a concrete, non-obvious follow-up
- Multi-line "what this function does" prose where a single line (or nothing) suffices
- Commented-out code

**KEEP**:
- Comments that explain non-obvious WHY: hidden constraints, workarounds for known bugs,
  subtle invariants, behavior that would surprise a reader
- Doc comments matching the repo's documented style (from Step 2)
- License/copyright headers if the repo has them
- Type / param annotations the repo uses systematically

**WHEN UNCERTAIN → REMOVE.** Less noise wins in production code.

### 4. Apply edits

Use `Edit` for each removal — one comment at a time. **Do NOT use `Write` to rewrite whole
files** — that risks accidental code changes. If a comment spans multiple lines, remove the
whole block in one Edit.

If removing a comment would change formatting in a confusing way (e.g. trailing comment on
a line of code), remove the trailing whitespace too.

### 5. Report

```
[clean-comments] done
  Files scanned:     <N>
  Comments removed:  <N>
  Comments kept:     <N>
  Conventions:       <one-paragraph summary from Step 2>
```

List a sample of removed comments grouped by category (Narration / Ticket / AI-hedge /
TODO / etc.) so the user can spot-check.

## Hard rules

- Never remove code.
- Never add a comment.
- Never reformat code (touch only comment lines).
- If a file has zero comments worth keeping, that's a fine result — don't invent any.
