# Global guidance

1. Be extremely concise. Sacrifice grammar for the sake of concision.

## Human-facing content and copy
For any human-facing content and copy (docs, Notion pages, Jira/GitHub issues, PR descriptions, READMEs, user messages): NEVER use em-dashes (—) or en-dashes (–), use plain hyphens, commas, or reword. Avoid AI-sounding language and filler (e.g. "delve", "moreover", "it's worth noting", "in today's fast-paced world", "robust/seamless/leverage", overuse of "—" as a dramatic pause). Write plainly and directly like a human would.

## Curating my casual / Slack / semi-formal messages
When I ask you to draft, curate, or reword a Slack / chat / casual / semi-formal message (to teammates, leads, etc.), write it in MY voice, not a polished corporate one:
- Mostly lowercase, relaxed punctuation. Lead with the actual ask, keep it to a couple of lines, no greeting fluff or sign-offs.
- Conversational and direct. Casual question marks are fine ("?", "??").
- Light Hinglish is natural when messaging Indian teammates ("isliye", "ha", "thoda", "kar dunga", "na") - sprinkle, don't force.
- No corporate/AI filler, no em/en-dashes (per the copy rule above).
- Scale formality to the recipient: slightly more buttoned-up for a lead, looser with peers, but always still my voice.
- Give me just the message text ready to paste, not options or commentary, unless I ask.

## Comments
Only write a comment that adds information the code itself doesn't already make obvious. NEVER add comments that restate what the code plainly does, narrate an edit, or that a competent reader (or Claude) could trivially infer from reading the line. Prefer no comment over a filler one. A comment earns its place only by explaining a non-obvious WHY (intent, constraint, gotcha, edge case), not the WHAT.

Never put ticket/tracker references (Jira like DEA-123, PRD/spec section numbers like "PRD §3.3" or "§3.3") in code comments or docstrings. The PR/commit already carries that linkage; inside the codebase it's noise that goes stale. Explain the actual WHY in plain words instead of pointing at a ticket. Same for tests and migrations.

## Comment hygiene, always
After writing or editing code, and before committing, run the `/clean-comments` skill on the changed files. Remove AI-slop comments (narration of what the code does, ticket/PR/Figma references, "added for X" justifications, commented-out code); keep only comments that match the repo's own style and explain non-obvious *why*. When unsure, remove. Applies to every project unless a project says otherwise.
