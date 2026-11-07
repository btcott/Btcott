export PATH="$HOME/.local/bin:$PATH"

# Homebrew
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Android: сборка и эмулятор для Expo
export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"

# Claude Code без запросов разрешений
alias claude='claude --dangerously-skip-permissions'

# Токены и личные настройки: файл не хранится в git
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
