# toolbox

Personal work tooling that doesn't belong inside any product repo — Claude Code config
and standalone scripts. Dotfiles-style: real files live here, symlinked into place.

## Layout

```
scripts/                  standalone CLI tools — one folder each, with its own README
  iden-lookup/            map a Twingate resource / URL → IdenHQ group
claude/                   Claude Code config (symlinked into ~/.claude)
  commands/               slash commands
  settings.json
  statusline-command.sh
  skills.manifest.md      third-party skills + where to install them from
install.sh                recreate symlinks on a new machine
```

## Setup on a new machine

```bash
git clone https://github.com/adityajindal-delta/toolbox.git ~/toolbox
cd ~/toolbox && ./install.sh
```

## Scripts

Each script lives in its own folder under `scripts/` with setup and usage in that folder's
README — see [`scripts/iden-lookup/`](scripts/iden-lookup/) for the first one.
