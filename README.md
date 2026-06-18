# toolbox

Personal work tooling that doesn't belong inside any product repo — Claude Code config
and standalone scripts. Dotfiles-style: real files live here, symlinked into place.

## Layout

```
scripts/                  standalone CLI tools
  iden-lookup.sh          map a Twingate resource / URL → IdenHQ group
  .iden-auth.example      template for IdenHQ creds (real .iden-auth is gitignored)
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

## scripts/iden-lookup.sh

Finds which IdenHQ group grants access to a Twingate resource.

```bash
./scripts/iden-lookup.sh https://chatsupport.dericrypt.com/   # by URL
./scripts/iden-lookup.sh prod-chatwoot-ind-internal           # by resource name
```

Needs IdenHQ session cookies — `cp scripts/.iden-auth.example scripts/.iden-auth` and
fill in `IDEN_SESSION`, `IDEN_CSRF`, `IDEN_AWSALB` (see the script header for how to grab
them). `AWSALB` rotates, so refresh it if you hit auth errors.

How it works: IdenHQ's GraphQL API models groups as a closure table (`app_group_closures`).
The script finds the resource by name/DNS, then walks up one level to its parent group(s).
