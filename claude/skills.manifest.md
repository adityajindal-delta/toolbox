# Skills manifest

## Vendored here (self-authored)

These are custom skills I wrote, so they live in this repo under `claude/skills/` and
`install.sh` symlinks each into `~/.claude/skills/`.

| Skill | What it does |
|---|---|
| `grepreview` | Reliable Greptile review loop on a PR until 5/5 with zero unresolved comments (hardened `greploop`). |
| `research-report` | Build a research-memo report artifact (sidebar TOC, bordered tables, finding cards, light/dark). |

## Third-party (not vendored)

The rest are third-party packs, so they're **not vendored** here; install them from
source instead. Listed for reproducibility on a new machine.

| Skill(s) | Source |
|---|---|
| `handoff`, `tdd`, `teach`, `writing-*`, `grill-me`, … | Matt Pocock skills pack (installed via `find-skills`) |
| `greptile`, `check-pr`, `greploop` | Greptile |
| `impeccable` | impeccable |
| `make-interfaces-feel-better` | make-interfaces-feel-better |
| `terminal-ui` | terminal-ui |

> Note: installing one Matt Pocock skill (e.g. `handoff`) pulls the whole pack via its
> lockfile. Install only what you want, then prune the rest from `~/.agents/skills/`.
