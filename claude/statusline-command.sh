#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
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
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# Nerd Font glyphs — require a Nerd Font in the terminal
ICON_MODEL=$'\xef\x83\x90'    # nf-fa-magic
ICON_CTX=$'\xef\x83\xa4'         # nf-fa-tachometer
ICON_CLOCK=$'\xef\x80\x97'     # nf-fa-clock_o
ICON_REPO=$'\xef\x82\x9b'       # nf-fa-github
ICON_BRANCH=$'\xee\x82\xa0'   # powerline branch
ICON_PR=$'\xef\x84\xa6'          # nf-fa-code_fork

OSC8=$'\033]8;;'
BEL=$'\007'
sep=" ${DIM}│${RESET} "

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

# --- repo / branch / PR segment ----------------------------------------------
# Derived from the current working directory so it tracks whichever repo Claude
# is working in (the delta/ workspace holds several). The PR lookup is a network
# call, so it's cached (60s TTL) and refreshed in the background — render never
# blocks on gh.
git_str=""
append() {
  if [ -n "$git_str" ]; then git_str="${git_str}${sep}$1"; else git_str="$1"; fi
}

if [ -n "$cwd" ] && command -v git >/dev/null 2>&1 && \
   repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) && [ -n "$repo_root" ]; then

  remote_url=$(git -C "$cwd" config --get remote.origin.url 2>/dev/null)
  if [ -n "$remote_url" ]; then
    repo_name=$(basename -s .git "$remote_url")
  else
    repo_name=$(basename "$repo_root")
  fi

  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

  append "${BLUE}${ICON_REPO}${RESET} ${repo_name}"
  [ -n "$branch" ] && append "${MAGENTA}${ICON_BRANCH}${RESET} ${branch}"

  if [ -n "$branch" ] && command -v gh >/dev/null 2>&1; then
    cache_dir="$HOME/.claude/statusline-cache"
    mkdir -p "$cache_dir" 2>/dev/null
    safe=$(printf '%s' "${repo_root}__${branch}" | tr '/ ' '__')
    cache_file="$cache_dir/pr_${safe}"
    ttl=60
    now=$(date +%s)

    need=0
    if [ -f "$cache_file" ]; then
      mtime=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)
      [ $(( now - mtime )) -ge "$ttl" ] && need=1
    else
      need=1
    fi
    if [ "$need" -eq 1 ]; then
      touch "$cache_file" 2>/dev/null
      (
        cd "$repo_root" 2>/dev/null || exit
        result=$(gh pr view "$branch" --json number,url --jq '"\(.number)\t\(.url)"' 2>/dev/null)
        printf '%s' "$result" > "${cache_file}.tmp" 2>/dev/null && mv "${cache_file}.tmp" "$cache_file" 2>/dev/null
      ) >/dev/null 2>&1 &
    fi

    if [ -s "$cache_file" ]; then
      pr_num=$(cut -f1 "$cache_file" 2>/dev/null)
      pr_url=$(cut -f2 "$cache_file" 2>/dev/null)
      if [ -n "$pr_num" ] && [ -n "$pr_url" ]; then
        pr_text="${GREEN}${ICON_PR} PR #${pr_num}${RESET}"
        append "${OSC8}${pr_url}${BEL}${pr_text}${OSC8}${BEL}"
      fi
    fi
  fi
fi

rate_limit_str=$(format_rl "$rl_5h_pct" "$rl_5h_reset" "5h")

out="${CYAN}${ICON_MODEL}${RESET} ${model}${sep}${MAGENTA}${ICON_CTX}${RESET} ${usage_str}${sep}${YELLOW}${ICON_CLOCK}${RESET} ${rate_limit_str}"
[ -n "$git_str" ] && out="${git_str}${sep}${out}"

printf "%s" "$out"
