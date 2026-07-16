---
name: research-report
description: Build a report/study/analysis artifact with the standard research-memo UI (numbered sidebar TOC with scroll tracking, bordered tables, summary-figures strip, finding cards, light+dark themes). Use whenever the user asks for a research-style report artifact, a findings write-up for leads/PMs, or says "use the research report template".
---

Produce a single self-contained HTML file for the Artifact tool using the fixed template in `template.html` (same directory). The design is settled; do not redesign it.

Procedure:
1. Read `template.html`. Copy its `<style>` block, `.frame`/nav/main skeleton, and the scroll-spy `<script>` verbatim.
2. Replace only the content: `<title>`, memo header (doc kind, title, subtitle, meta cells), TOC entries, and the sections. Keep section `id`s in sync with TOC hrefs.
3. Compose sections from the provided component patterns only: prose, `.tablewrap` bordered tables (numeric cells get `class="num"`), `.keyfigs` summary strip (executive summary only), `.hbar-row` bar figures, `.stack` share bars, `.note` callouts, `.finding` cards (ID prefix per section, e.g. D1/O1/R1), `.foot` footnotes, appendix sections lettered A/B/C.
4. Numbering: sections 1..N in both TOC and `<h2><span class="sn">`; tables `Table N.M`, figures `Figure N.M`.
5. Copy rules: no em dashes or en dashes anywhere (use hyphens/commas); plain direct prose; every table gets a caption; estimates are labeled as estimates with their caveat in a `.foot` or §Methodology.
6. Bars: width = value/max x 90%; use `--bar-1..4` only; stacked bars keep the 2px ground-colored gap and a legend plus `aria-label`.
7. Publish with the Artifact tool. Favicon 📊 unless the user picks another. When updating an existing report, edit the same file path (or pass `url`) so the link is stable.

`example-full-report.html` in this directory is a complete real report built from this template; consult it only if a pattern's usage is unclear.
