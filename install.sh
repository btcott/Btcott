#!/bin/bash
# Разворачивает рабочую среду на Mac. Повторный запуск безопасен.
#
#   ./install.sh               полная установка
#   ./install.sh --links-only  только симлинки, без установки программ
#   ./install.sh --check       только показать, какие ручные шаги остались

set -Eeuo pipefail

DOTFILES="$HOME/dotfiles"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
STEP="запуск"

trap 'echo "✗ Ошибка на шаге «${STEP}». Исправь причину и запусти скрипт снова." >&2' ERR

step() {
  STEP="$1"
  printf '\n==> %s\n' "$1"
}

die() {
  echo "✗ $1" >&2
  exit 1
}

load_brew() {
  local brew_bin
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$brew_bin" ]; then
      eval "$("$brew_bin" shellenv)"
      return 0
    fi
  done
  return 1
}

# Существующий файл не затирается, а переносится в бэкап.
link() {
  local src="$DOTFILES/$1" dst="$2"

  [ -e "$src" ] || die "В репозитории нет файла $1"
  [ "$(readlink "$dst" || true)" = "$src" ] && return 0

  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP"
    mv "$dst" "$BACKUP/$(basename "$dst")"
    echo "бэкап: $dst -> $BACKUP/"
  fi
  ln -s "$src" "$dst"
  echo "симлинк: $dst"
}

check_system() {
  step "Проверка системы"
  [ "$(uname -s)" = "Darwin" ] || die "Скрипт рассчитан только на macOS"

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  [ -d "$DOTFILES" ] && [ "$script_dir" = "$(cd "$DOTFILES" && pwd -P)" ] \
    || die "Репозиторий должен лежать в $DOTFILES"
}

install_command_line_tools() {
  step "Command Line Tools"
  xcode-select -p >/dev/null 2>&1 && return 0
  xcode-select --install || true
  die "Дождись окончания установки Command Line Tools и запусти скрипт снова"
}

install_homebrew() {
  step "Homebrew"
  load_brew && return 0
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_brew
}

install_packages() {
  step "Пакеты из Brewfile"
  brew bundle check --file="$DOTFILES/Brewfile" >/dev/null 2>&1 \
    || brew bundle install --file="$DOTFILES/Brewfile"

  step "EAS CLI"
  command -v eas >/dev/null 2>&1 || npm install --global eas-cli
}

create_links() {
  step "Симлинки"
  link .zshrc "$HOME/.zshrc"
  link claude/CLAUDE.md "$HOME/.claude/CLAUDE.md"
  link claude/settings.json "$HOME/.claude/settings.json"
  link scripts/statusline.sh "$HOME/.claude/statusline.sh"

  local command_file
  for command_file in "$DOTFILES"/commands/*.md; do
    link "commands/$(basename "$command_file")" "$HOME/.claude/commands/$(basename "$command_file")"
  done
}

install_claude_code() {
  step "Claude Code"
  command -v claude >/dev/null 2>&1 && return 0
  curl -fsSL https://claude.ai/install.sh | bash
}

manual_steps() {
  local android_sdk="$HOME/Library/Android/sdk" runtimes avds

  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "  - установить Xcode из App Store"
  elif ! xcodebuild -license check >/dev/null 2>&1; then
    echo "  - принять лицензию Xcode: sudo xcodebuild -license accept"
  else
    runtimes="$(xcrun simctl list runtimes 2>/dev/null || true)"
    if ! grep -q '^iOS' <<<"$runtimes"; then
      echo "  - поставить iOS-симулятор: Xcode → Settings → Components → Platform Support → iOS → Get"
    fi
  fi

  if [ ! -d "$android_sdk" ]; then
    echo "  - открыть Android Studio и установить Android SDK"
  fi
  avds="$("$android_sdk/emulator/emulator" -list-avds 2>/dev/null || true)"
  if [ -z "$avds" ]; then
    echo "  - создать виртуальное устройство: Android Studio → Device Manager"
  fi

  claude auth status >/dev/null 2>&1 || echo "  - войти в Claude Code: claude"
  gh auth status >/dev/null 2>&1 || echo "  - войти в GitHub: gh auth login"
  eas whoami >/dev/null 2>&1 || echo "  - войти в Expo: eas login"
}

print_summary() {
  local steps

  step "Итог"
  steps="$(manual_steps)"
  if [ -z "$steps" ]; then
    echo "Ручных шагов не осталось."
  else
    echo "Осталось сделать вручную:"
    echo "$steps"
  fi
}

main() {
  export PATH="$HOME/.local/bin:$PATH"

  case "${1:-}" in
    --links-only)
      check_system
      create_links
      ;;
    "")
      check_system
      install_command_line_tools
      install_homebrew
      install_packages
      create_links
      install_claude_code
      print_summary
      echo "Открой новый терминал, чтобы применился .zshrc."
      ;;
    --check)
      print_summary
      ;;
    *)
      die "Неизвестный параметр: $1. Доступны --links-only и --check"
      ;;
  esac
}

main "$@"
