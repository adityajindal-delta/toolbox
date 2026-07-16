---
name: research-report
description: Build a report/study/analysis artifact with the standard research-memo UI (numbered sidebar TOC with scroll tracking, bordered tables, summary-figures strip, finding cards, cross-reference citation links, light+dark themes). Use whenever the user asks for a research-style report artifact, a findings write-up for leads/PMs, or says "use the research report template".
---

Produce a single self-contained HTML file for the Artifact tool using the fixed template in `template.html` (same directory). The design is settled; do not redesign it. Fill content only.

## Procedure
1. Read `template.html`. Copy its `<style>`, `.frame`/nav/main skeleton, and the scroll-spy `<script>` verbatim.
2. Replace only the content: `<title>`, memo header, TOC entries, sections. Keep section `id`s in sync with TOC hrefs.
3. Compose sections from the template's component patterns only: prose, `.tablewrap` bordered tables (numeric cells get `class="num"`), `.keyfigs` strip (executive summary only), `.hbar-row` bars, `.stack` share bars, `.note` callouts, `.finding` cards, `.foot` footnotes, appendices lettered A/B/C.
4. Bars: width = value/max x 90%; use `--bar-1..4` only; stacked bars keep the 2px ground-colored gap plus a legend and `aria-label`.
5. Publish with the Artifact tool, favicon 📊 unless the user picks another. Updating an existing report: republish the **same file path** (or pass `url`) so the link and favicon stay stable.

## Cross-references & citations (do this by default)
Any inline mention of a numbered finding, recommendation, or section must be a clickable citation, not bare text. Two steps:
- **Give each definition an `id`:** finding cards `<div class="finding" id="d1">`; action/recommendation rows `<tr id="r1"><td ...>R1</td>`; sections already have `id` on `<section>`.
- **Wrap each mention** in `<a class="ref" href="#id">...</a>` — e.g. `caused by <a class="ref" href="#d1">D1</a>`, `fixed by <a class="ref" href="#r3">R3</a>`, `see <a class="ref" href="#recs">§8</a>`. The `.ref` style (dotted monospace link) and anchor `scroll-margin-top` are already in the template CSS.
- Use short stable id conventions: `d#` drivers/findings, `o#` observability, `r#` recommendations, section slug for `§`.

## Numbering discipline
Sections, tables, and figures are hand-numbered (`Table N.M`, `Figure N.M`, `<h2><span class="sn">N</span>`). If you **insert or remove** a section, renumber every following section AND its tables/figures AND the TOC entries AND every cross-reference/citation that points at them. After any structural change, re-run the validation grep below — a missed renumber leaves gaps like 1,3,4 or dead citations.

## Content discipline (keep it to the point)
This is a memo for leads/PMs, not a narrative. Cut anything that is not problem, evidence, or fix:
- Lead with tables and numbers; keep prose tight around them. No "color" paragraphs (who the users are, languages, workload anecdotes) unless they change a decision.
- No standalone "Methodology" or "Timeline" section. Fold the two or three caveats that actually matter (sample is estimated not exhaustive, data source, any window/coverage gap) into a single `.foot` under the executive summary.
- Always label estimates as estimates and name the ground-truth source to reconcile against.
- Every table gets a `<caption>`. Every chart gets an `aria-label`.
- Copy rules: no em/en dashes anywhere (hyphens, commas); plain direct prose; no AI filler.

## Validate before publishing
Run over the file and fix anything that prints:
```
f=<file>
# every citation target exists:
for t in $(grep -o 'href="#[a-z0-9-]*"' "$f" | sed 's/href="#//;s/"//' | sort -u); do grep -q "id=\"$t\"" "$f" || echo "MISSING ANCHOR: #$t"; done
# no stray duplicate closing tags, and TOC count matches section count:
grep -c '<section id=' "$f"; grep -c 'nav.toc.*<li>' "$f" || grep -c '<li><a href="#' "$f"
```
Also eyeball: TOC numbers are contiguous, table/figure numbers match their section, no bare `R#`/`D#`/`§#` left unlinked.

`example-full-report.html` in this directory is a complete real report built from this template (with citations wired) — consult it when a pattern's usage is unclear.
