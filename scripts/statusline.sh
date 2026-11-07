#!/bin/bash
# Claude Code status line: модель | папка | git-ветка | заполненность контекста.
# Claude Code передаёт JSON о сессии в stdin; первая строка stdout становится статусной.

input=$(cat)

model=$(jq -r '.model.display_name // "?"' <<<"$input")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
# floor в jq, а не printf: при немецкой локали printf не разберёт "12.5".
pct=$(jq -r '.context_window.used_percentage // empty | floor' <<<"$input")

reset=$'\033[0m'
dim=$'\033[2m'
cyan=$'\033[36m'
blue=$'\033[34m'
magenta=$'\033[35m'
green=$'\033[32m'
yellow=$'\033[33m'
red=$'\033[31m'

sep=" ${dim}|${reset} "
line="${cyan}${model}${reset}"

if [ -n "$dir" ]; then
  tilde='~'
  line+="${sep}${blue}${dir/#$HOME/$tilde}${reset}"

  # --no-optional-locks: не мешать параллельным git-командам, скрипт запускается часто.
  # Вне ветки (detached HEAD) показываем короткий хеш, вне репозитория — ничего.
  branch=$(git --no-optional-locks -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null \
    || git --no-optional-locks -C "$dir" rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && line+="${sep}${magenta}${branch}${reset}"
fi

# used_percentage равен null, пока в сессии не было ни одного ответа модели.
if [ -n "$pct" ]; then
  if [ "$pct" -ge 80 ]; then
    color=$red
  elif [ "$pct" -ge 50 ]; then
    color=$yellow
  else
    color=$green
  fi

  width=10
  filled=$((pct * width / 100))
  [ "$filled" -gt "$width" ] && filled=$width
  bar=""
  for ((i = 0; i < width; i++)); do
    if [ "$i" -lt "$filled" ]; then bar+="█"; else bar+="░"; fi
  done

  line+="${sep}${color}${bar} ${pct}%${reset}"
else
  line+="${sep}${dim}контекст: —${reset}"
fi

printf '%s\n' "$line"
