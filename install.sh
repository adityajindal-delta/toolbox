#!/usr/bin/env bash
# install.sh — symlink this toolbox into the right places on a new machine.
# Real files live here in the repo; ~/.claude points at them.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p ~/.claude

ln -sfn "$REPO/claude/commands"             ~/.claude/commands
ln -sfn "$REPO/claude/settings.json"        ~/.claude/settings.json
ln -sfn "$REPO/claude/statusline-command.sh" ~/.claude/statusline-command.sh

# Custom (self-authored) skills are vendored here; link each into ~/.claude/skills
# individually so third-party skills already installed there are left untouched.
mkdir -p ~/.claude/skills
for skill in "$REPO"/claude/skills/*/; do
  ln -sfn "${skill%/}" ~/.claude/skills/"$(basename "$skill")"
done

chmod +x "$REPO"/scripts/*/*.sh

echo "Linked claude/ into ~/.claude."
echo "Each script lives in scripts/<name>/ with its own README — see there for setup."
