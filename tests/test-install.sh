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

# Подменяет программу заглушкой: stub <папка> <имя> <тело скрипта>
stub() {
  mkdir -p "$1"
  printf '#!/bin/bash\n%s\n' "$3" >"$1/$2"
  chmod +x "$1/$2"
}

# Заглушки для состояния «всё сделано». Сценарии переопределяют нужные из них.
new_check_home() {
  local home
  home="$(new_home)"
  stub "$home/stubs" xcodebuild 'exit 0'
  stub "$home/stubs" xcrun 'echo "iOS 27.2 (27.2 - 27C1) - com.apple.CoreSimulator"'
  stub "$home/stubs" claude 'exit 0'
  stub "$home/stubs" gh 'exit 0'
  stub "$home/stubs" eas 'exit 0'
  stub "$home/Library/Android/sdk/emulator" emulator 'echo Pixel_9'
  echo "$home"
}

run_check() { HOME="$1" PATH="$1/stubs:$PATH" "$1/dotfiles/install.sh" --check >"$1/out" 2>&1; }

echo "Ручные шаги: всё сделано"
home="$(new_check_home)"
run_check "$home"
check "код выхода 0" "[ $? -eq 0 ]"
check "шагов не осталось" "grep -q 'Ручных шагов не осталось' '$home/out'"
check "список не выводится" "! grep -q '^  - ' '$home/out'"
rm -rf "$home"

echo "Ручные шаги: ничего не сделано"
home="$(new_check_home)"
for name in xcodebuild xcrun claude gh eas; do stub "$home/stubs" "$name" 'exit 1'; done
rm -rf "$home/Library/Android"
run_check "$home"
check "код выхода 0" "[ $? -eq 0 ]"
for text in 'установить Xcode' 'установить Android SDK' 'виртуальное устройство' \
  'войти в Claude Code' 'войти в GitHub' 'войти в Expo'; do
  check "есть шаг: $text" "grep -q '$text' '$home/out'"
done
check "нет шага про лицензию" "! grep -q 'лицензию' '$home/out'"
rm -rf "$home"

echo "Ручные шаги: не принята лицензия Xcode"
home="$(new_check_home)"
# shellcheck disable=SC2016 # $1 раскрывается внутри заглушки
stub "$home/stubs" xcodebuild '[ "$1" = -version ]'
run_check "$home"
check "есть шаг про лицензию" "grep -q 'принять лицензию' '$home/out'"
check "нет шага про установку Xcode" "! grep -q 'установить Xcode' '$home/out'"
rm -rf "$home"

echo "Ручные шаги: нет iOS runtime"
home="$(new_check_home)"
stub "$home/stubs" xcrun 'echo "== Runtimes =="'
run_check "$home"
check "есть шаг про симулятор" "grep -q 'iOS-симулятор' '$home/out'"
check "других шагов нет" "[ \"\$(grep -c '^  - ' '$home/out')\" -eq 1 ]"
rm -rf "$home"

echo "Ручные шаги: нет виртуального устройства"
home="$(new_check_home)"
stub "$home/Library/Android/sdk/emulator" emulator 'exit 0'
run_check "$home"
check "есть шаг про устройство" "grep -q 'виртуальное устройство' '$home/out'"
check "нет шага про Android SDK" "! grep -q 'установить Android SDK' '$home/out'"
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
