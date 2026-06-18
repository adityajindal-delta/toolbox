#!/bin/bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
worktree=$(echo "$input" | jq -r '.worktree.name // empty')
current_dir=$(echo "$input" | jq -r '.worktree.original_cwd // empty')
rl_5h_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | awk '{printf "%.0f", $1}')
rl_5h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

if [ -n "$used" ]; then
  used_display=$(printf "%.0f" "$used")
  usage_str="${used_display}%"
else
  usage_str="0%"
fi

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
MAGENTA=$'\033[35m'
BLUE=$'\033[34m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# Nerd Font glyphs — require a Nerd Font in the terminal
ICON_MODEL=$'\xef\x83\x90'    # nf-fa-magic
ICON_CTX=$'\xef\x83\xa4'         # nf-fa-tachometer
ICON_CLOCK=$'\xef\x80\x97'     # nf-fa-clock_o
ICON_DIR=$'\xef\x81\xbb'         # nf-fa-folder
ICON_TREE=$'\xef\x86\xbb'       # nf-fa-tree
ICON_BRANCH=$'\xee\x9c\xa5'   # nf-dev-git_branch

is_git_repo=0
git_str=""
worktree_str=""
if (cd "$current_dir" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1); then
  is_git_repo=1
  branch=$(cd "$current_dir" && git branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(cd "$current_dir" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
  staged=$(cd "$current_dir" && git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  modified=$(cd "$current_dir" && git diff --numstat 2>/dev/null | wc -l | tr -d ' ')

  git_str="$branch"
  [ "$staged" -gt 0 ] && git_str="${git_str} ${GREEN}+${staged}${RESET}"
  [ "$modified" -gt 0 ] && git_str="${git_str} ${YELLOW}~${modified}${RESET}"

  [ -n "$worktree" ] && worktree_str="$worktree"
fi

make_bar() {
  pct="$1"
  width=10
  filled=$(( pct * width / 100 ))
  bar=""
  i=0
  while [ $i -lt $filled ]; do bar="${bar}█"; i=$(( i + 1 )); done
  while [ $i -lt $width ];  do bar="${bar}░"; i=$(( i + 1 )); done
  printf "%s" "$bar"
}

format_rl() {
  pct="$1"
  reset_ts="$2"
  label="$3"
  [ -z "$pct" ] && return
  if [ "$pct" -ge 90 ]; then color="$RED"
  elif [ "$pct" -ge 70 ]; then color="$YELLOW"
  else color="$GREEN"
  fi
  reset_time=$(date -r "$reset_ts" "+%-I:%M%p" 2>/dev/null || date -d "@$reset_ts" "+%-I:%M%p" 2>/dev/null)
  bar=$(make_bar "$pct")
  printf "${color}${label} ${bar} ${pct}%% resets ${reset_time}${RESET}"
}

rate_limit_str=$(format_rl "$rl_5h_pct" "$rl_5h_reset" "5h")

sep=" ${DIM}│${RESET} "
out="${CYAN}${ICON_MODEL}${RESET} ${model}${sep}${MAGENTA}${ICON_CTX}${RESET} ${usage_str}${sep}${YELLOW}${ICON_CLOCK}${RESET} ${rate_limit_str}"

if [ "$is_git_repo" -eq 1 ]; then
  repo_root=$(cd "$current_dir" && git rev-parse --show-toplevel 2>/dev/null)
  dir_display=$(basename "$repo_root")
  out="${out}${sep}${BLUE}${ICON_DIR}${RESET} ${dir_display}"
  [ -n "$worktree_str" ] && out="${out}${sep}${GREEN}${ICON_TREE}${RESET} ${worktree_str}"
  [ -n "$git_str" ] && out="${out}${sep}${MAGENTA}${ICON_BRANCH}${RESET} ${git_str}"
fi

printf "%s" "$out"
