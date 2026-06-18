---
description: Efficiently run a Greptile review loop on a PR (greploop, with reliable polling)
argument-hint: "[PR number]  (defaults to the PR for the current branch)"
allowed-tools: Bash(gh:*), Bash(git:*), Bash(jq:*)
---

# grepreview

Iteratively improve a GitHub PR with Greptile until it scores 5/5 with zero unresolved
comments. This wraps the **greploop** skill (`~/.claude/skills/greptile/greploop/SKILL.md`)
but replaces its single long-running poll loop with reliable, step-wise polling.

PR number: `$1` (if empty, detect from the current branch).

## Core rule — why this exists

The greploop skill polls inside one `while true; do ... sleep 10; done` Bash call. Claude
Code's Bash tool times out (~120s default), but Greptile reviews routinely take longer, so
that command gets killed mid-poll and the loop never completes. Also, Greptile sometimes
posts its result as a PR **review/comment** with no commit **check-run**, so a loop that only
waits on check-runs hangs forever.

**Therefore, in this command:**
- **NEVER** use a long-running `while`/`sleep` poll loop inside a single Bash call.
- Poll in **discrete Bash calls**, one status check per call (each call may `sleep 10` once,
  then exit). YOU drive the loop and re-invoke Bash for the next tick.
- Treat the review as **done** when EITHER the Greptile check-run is `completed` OR a fresh
  Greptile review/comment (newer than the current HEAD commit) has appeared.
- **Check existing state before triggering** — don't re-trigger a review that's already done
  or already running.

## Steps

### 0. Identify the PR

```bash
PR=${1:-$(gh pr view --json number -q .number)}
gh pr view "$PR" --json number,headRefName,headRefOid -q '{number,branch:.headRefName,head:.headRefOid}'
```
Switch to the PR branch if not already on it. Record `OWNER`, `REPO`, `HEAD_SHA`.

### 1. Assess current state FIRST (before triggering anything)

In a single batch, fetch:

```bash
# Prior Greptile reviews on this PR (captured BEFORE we trigger anything — for the report)
PRIOR_REVIEWS=$(gh api repos/{owner}/{repo}/pulls/$PR/reviews \
  --jq '[.[] | select(.user.login | test("greptile";"i"))] | length')
PRIOR_REVIEWS_ON_HEAD=$(gh api repos/{owner}/{repo}/pulls/$PR/reviews \
  --jq "[.[] | select(.user.login|test(\"greptile\";\"i\")) | select(.commit_id==\"$HEAD_SHA\")] | length")
echo "prior_reviews=$PRIOR_REVIEWS prior_on_head=$PRIOR_REVIEWS_ON_HEAD"

# Latest Greptile review (inline-comment review object) + score
gh api repos/{owner}/{repo}/pulls/$PR/reviews   --jq '[.[] | select(.user.login | test("greptile";"i"))] | last'
gh pr view $PR --json body -q '.body'

# CRITICAL — the Greptile *summary* lives in an issue comment, not a review.
# It contains the score AND a "Comments Outside Diff" section with findings
# that DO NOT appear as inline review comments. Always fetch + parse it.
SUMMARY=$(gh api repos/{owner}/{repo}/issues/$PR/comments \
  --jq '[.[] | select(.user.login | test("greptile";"i"))] | last | .body')
echo "$SUMMARY"

# Unresolved inline comments from Greptile
gh api repos/{owner}/{repo}/pulls/$PR/comments  --jq '[.[] | select(.user.login | test("greptile";"i"))]'

# Is a review already running?
gh api "repos/{owner}/{repo}/commits/$HEAD_SHA/check-runs" \
  --jq '.check_runs[] | select(.name | test("greptile";"i")) | {status,conclusion}'
```

Remember `PRIOR_REVIEWS` (total Greptile reviews on this PR at start) and
`PRIOR_REVIEWS_ON_HEAD` (how many of those targeted the current HEAD) — both go in the final
report.

Decide the entry point:
- **Open actionable Greptile findings exist on the current HEAD** (inline OR in the summary's
  "Comments Outside Diff" section) → go straight to **Step 4 (fix)**. Do not waste a review
  round re-triggering on unchanged code.
- **A Greptile check-run is `PENDING`/`IN_PROGRESS`** → skip triggering, go to **Step 3 (poll)**.
- **A completed review exists for the current HEAD with 5/5 AND zero inline open comments AND
  zero findings in the summary body** → done, go to **Step 6 (report)**.
- **Otherwise** (no review, or review is stale/older than HEAD, or score < 5/5) → go to
  **Step 2 (trigger)**.

### 2. Trigger a review (only when needed)

```bash
git push                      # only if there are unpushed commits
gh pr comment $PR --body "@greptile review"
```
Refresh `HEAD_SHA` after any push.

### 3. Poll — ONE background command, not foreground ticks

**Do this.** Run a single background poller that loops internally and exits when the review
is done. The Bash tool's `run_in_background: true` is the *primary* pattern here, not an
escape hatch — Claude is notified the moment the command exits, with zero foreground waiting
and zero way to trip the long-sleep block.

```bash
# Portable across macOS + Linux — no `timeout` (not on macOS by default).
# Iteration cap = 60 × 10s = 10 min hard ceiling.
bash -c '
  C_DIM="\033[2m"; C_CYAN="\033[36m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_RED="\033[31m"; C_BOLD="\033[1m"; C_OFF="\033[0m"
  printf "${C_BOLD}${C_CYAN}[grepreview]${C_OFF} polling PR #'"$PR"' @ '"${HEAD_SHA:0:7}"'\n"
  for i in $(seq 1 60); do
    CHECK=$(gh api "repos/'"$OWNER"'/'"$REPO"'/commits/'"$HEAD_SHA"'/check-runs" \
      --jq ".check_runs[] | select(.name | test(\"greptile\";\"i\")) | \"\(.status):\(.conclusion)\"" 2>/dev/null)
    REVIEW=$(gh api "repos/'"$OWNER"'/'"$REPO"'/pulls/'"$PR"'/reviews" \
      --jq "[.[] | select(.user.login|test(\"greptile\";\"i\")) | select(.commit_id==\"'"$HEAD_SHA"'\")] | length")
    if [[ "$CHECK" == completed:* ]] || [[ "${REVIEW:-0}" -ge 1 ]]; then
      printf "${C_BOLD}${C_GREEN}[grepreview] DONE${C_OFF} tick=$i check=$CHECK reviews_on_head=$REVIEW\n"
      exit 0
    fi
    printf "${C_DIM}[grepreview]${C_OFF} ${C_YELLOW}tick $i/60${C_OFF} check=${CHECK:-pending} reviews_on_head=${REVIEW:-0}\n"
    sleep 10
  done
  printf "${C_BOLD}${C_RED}[grepreview] TIMEOUT${C_OFF} after 10 min — review never completed\n"
  exit 1
'
```

Invoke this Bash call with **`run_in_background: true`**. Then **stop calling Bash** — wait
for the background-completion notification. When it fires, read the final output and proceed
to Step 4. The `for $(seq 1 60)` loop caps the wait at 10 min so it can't hang forever
(replaces `timeout 600`, which isn't installed on macOS by default).

**Do NOT** do any of these (each one re-creates the bug we already hit):

- ❌ Run a `sleep 10 && gh api ...` check as a *foreground* Bash call, one tick at a time.
  This is what made the earlier run escalate to `sleep 20/25/30` and get blocked.
- ❌ Increase the foreground `sleep` past 15. The harness blocks long leading sleeps and also
  catches chained shorter sleeps.
- ❌ Re-poll with another foreground Bash call while the background poller is already running.

### 4. Fetch results & fix actionable comments

Findings live in **three** places — check all three, every iteration:

1. **Inline review comments** — `gh api repos/{owner}/{repo}/pulls/$PR/comments` (already in
   Step 1's batch). These have threads you can resolve via GraphQL in Step 5.
2. **Score** — parse `N/5` from the latest summary issue comment (`SUMMARY` from Step 1),
   falling back to the latest review body, then PR body.
3. **The summary body's "Comments Outside Diff" section** — this is the one that bit us. The
   summary is collapsed, so it's easy to miss. Parse it:

   ```bash
   echo "$SUMMARY" | awk '/Comments Outside Diff/,/^<\/details>|^---/' | grep -E '(P1|P2|P3|alt="P[1-3]")'
   ```

   Each finding has a P-badge (`P1`/`P2`/`P3`), a title, a file path, and a body. **Treat
   them as actionable** even though they have no inline thread to resolve.

For each finding (inline OR out-of-diff), **work it end-to-end before moving to the next**:

1. Read the file in context, decide if it's actionable.
2. If actionable → make the fix with `Edit`.
3. If false-positive / pre-existing / out-of-scope → note the disposition.
4. **IMMEDIATELY resolve the thread for THIS finding** — do not batch resolutions until the
   end of the iteration or after the commit. The thread should close the moment its fix
   lands (or its dismissal is recorded). Use the GraphQL `resolveReviewThread` mutation from
   `~/.claude/skills/greptile/greploop/references/graphql-queries.md` (one thread per call is
   fine; the batch form is only useful when many are ready at once).
5. For out-of-diff findings (no thread to resolve), reply on the summary issue comment with
   a one-line disposition so the record is closed before moving on.

Only after every finding from this iteration is fixed + resolved do you move to Step 5.

**Exit-condition tightening:** do not declare success on "0 inline comments" alone. The
score must also be 5/5 AND the summary's out-of-diff section must be empty (or all findings
addressed/dispositioned). If the score stays < 5/5 after a re-trigger with no code change,
that's the signal that an out-of-diff finding is still open — re-parse `SUMMARY`.

### 5. Commit, push, loop

By now every thread from Step 4 is already resolved (that happened per-fix, not here). All
that remains is to ship the fixes:

```bash
git add -A && git commit -m "address greptile review feedback (grepreview iteration N)"
git push
```
Refresh `HEAD_SHA` and go back to **Step 2**. **Max 5 iterations.**

Sanity check before pushing: re-fetch unresolved threads from Step 1's API. The list should
be empty. If anything is still unresolved, that's a bug in Step 4 — resolve it now rather
than letting it bleed into the next iteration.

### 6. Report

Print the final report through a small bash block so the terminal renders colors and a
distinct chip — keeps the output visually consistent with the polling chip in Step 3.

```bash
bash -c '
  C_CYAN="\033[36m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_RED="\033[31m"; C_BOLD="\033[1m"; C_DIM="\033[2m"; C_OFF="\033[0m"
  # color the confidence line by score: 5/5 green, 3-4 yellow, <3 red
  SCORE_COLOR=$C_GREEN; [[ "$CONF" =~ ^[34]/5$ ]] && SCORE_COLOR=$C_YELLOW; [[ "$CONF" =~ ^[012]/5$ ]] && SCORE_COLOR=$C_RED
  STATUS_LABEL="${C_GREEN}complete${C_OFF}"; [[ "$EXIT_REASON" == "max_iter" ]] && STATUS_LABEL="${C_YELLOW}stopped (max iterations)${C_OFF}"
  [[ "$EXIT_REASON" == "timeout" ]] && STATUS_LABEL="${C_RED}stopped (poll timeout)${C_OFF}"
  printf "\n${C_BOLD}${C_CYAN}[grepreview]${C_OFF} ${STATUS_LABEL}\n"
  printf "  ${C_DIM}PR:${C_OFF}             ${C_BOLD}#${PR}${C_OFF}\n"
  printf "  ${C_DIM}Prior reviews:${C_OFF}  ${PRIOR_REVIEWS} (on HEAD before this run: ${PRIOR_REVIEWS_ON_HEAD})\n"
  printf "  ${C_DIM}Iterations:${C_OFF}     ${ITER}       ${C_DIM}# review rounds this run triggered${C_OFF}\n"
  printf "  ${C_DIM}Confidence:${C_OFF}     ${SCORE_COLOR}${C_BOLD}${CONF}${C_OFF}\n"
  printf "  ${C_DIM}Resolved:${C_OFF}       ${RESOLVED} comments   ${C_DIM}# by this run${C_OFF}\n"
  printf "  ${C_DIM}Remaining:${C_OFF}      ${REMAINING}\n\n"
'
```

Plain-text fallback (use this format if you cannot render bash here for any reason):

```
[grepreview] complete
  PR:             #<num>
  Prior reviews:  <PRIOR_REVIEWS> (on HEAD before this run: <PRIOR_REVIEWS_ON_HEAD>)
  Iterations:     <N>           # review rounds this run triggered
  Confidence:     <X>/5
  Resolved:       <N> comments  # by this run
  Remaining:      <N>
```

Make it explicit in the report that **Iterations / Resolved** count what *this run* did, while
**Prior reviews** is lifetime context for the PR — that distinction is the whole reason this
field exists.
If it stopped on max iterations or a poll timeout, list remaining issues and next steps.

## Efficiency checklist (don't skip)
- [ ] Checked existing review state before triggering
- [ ] Polled in discrete Bash calls — no `while true; sleep` inside one call
- [ ] Treated a fresh review/comment as completion, not only a check-run
- [ ] Hard cap: 30 poll ticks per round, 5 review rounds
