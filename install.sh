#!/usr/bin/env bash
# install.sh — symlink this toolbox into the right places on a new machine.
# Real files live here in the repo; ~/.claude points at them.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p ~/.claude

ln -sfn "$REPO/claude/commands"             ~/.claude/commands
ln -sfn "$REPO/claude/settings.json"        ~/.claude/settings.json
ln -sfn "$REPO/claude/statusline-command.sh" ~/.claude/statusline-command.sh

chmod +x "$REPO"/scripts/*/*.sh

echo "Linked claude/ into ~/.claude."
echo "Each script lives in scripts/<name>/ with its own README — see there for setup."
