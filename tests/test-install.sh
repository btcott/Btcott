#!/bin/bash
# Проверяет install.sh --links-only во временном HOME, настоящие файлы не затрагиваются.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
failures=0

pass() { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; failures=$((failures + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

new_home() {
  local home
  home="$(mktemp -d)"
  mkdir "$home/dotfiles"
  (cd "$REPO" && tar --exclude .git -cf - .) | tar -xf - -C "$home/dotfiles"
  echo "$home"
}

install() { HOME="$1" "$1/dotfiles/install.sh" --links-only; }

echo "Чистый HOME"
home="$(new_home)"
install "$home" >/dev/null
check "код выхода 0" "[ $? -eq 0 ]"
for path in .zshrc .claude/CLAUDE.md .claude/settings.json .claude/statusline.sh \
  .claude/commands/edit-global-rules.md .claude/commands/expo-check.md; do
  check "симлинк $path" "[ -L '$home/$path' ] && [ -e '$home/$path' ]"
done
check "бэкап не создан" "[ ! -e '$home/.dotfiles-backup' ]"

echo "Повторный запуск"
# shellcheck disable=SC2034 # используется внутри eval в check
output="$(install "$home")"
check "ничего не меняется" "! grep -qE '^(бэкап|симлинк):' <<<\"\$output\""
check "бэкап не создан" "[ ! -e '$home/.dotfiles-backup' ]"
rm -rf "$home"

echo "На месте симлинка обычный файл"
home="$(new_home)"
echo "старое содержимое" >"$home/.zshrc"
install "$home" >/dev/null
check "создан симлинк" "[ -L '$home/.zshrc' ]"
check "файл сохранён в бэкапе" "grep -q 'старое содержимое' '$home'/.dotfiles-backup/*/.zshrc"
rm -rf "$home"

echo "Ошибка на середине и повторный запуск"
home="$(new_home)"
touch "$home/.claude"
install "$home" >/dev/null 2>"$home/stderr"
status=$?
check "скрипт упал" "[ $status -ne 0 ]"
check "назван шаг с ошибкой" "grep -q 'Симлинки' '$home/stderr'"
rm "$home/.claude"
install "$home" >/dev/null
check "повторный запуск завершился" "[ $? -eq 0 ]"
check "симлинки на месте" "[ -L '$home/.claude/settings.json' ]"
rm -rf "$home"

echo "Настройки"
check "settings.json валиден" "jq -e . '$REPO/claude/settings.json' >/dev/null"

echo
if [ "$failures" -eq 0 ]; then
  echo "Все проверки пройдены"
else
  echo "Провалено проверок: $failures"
  exit 1
fi
