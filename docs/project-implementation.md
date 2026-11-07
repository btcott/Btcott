# Рабочая среда для Claude Code и Expo — План реализации

**Цель:** на новом Mac одна команда `~/dotfiles/install.sh` разворачивает среду, в которой можно создать Expo-приложение и запустить его на iOS-симуляторе и Android-эмуляторе.

Дизайн: `~/dotfiles/docs/project-design.md`. Прочитай его перед началом работы.

## Процесс выполнения

**Изучи контекст:**
- Найди первую незакрытую фичу в плане

**Выполни фичу:**
- Выполни все шаги фичи
- Тесты обязательны для каждой фичи

**Подведи итог:**
- Напиши короткий итог: что сделал, что работает, есть ли проблемы
- Жди подтверждения пользователя
- После подтверждения: отметь шаги `- [x]` и поставь ✅ в заголовке фичи

## Принципы

- **DRY** — не дублируй код, выноси общее
- **YAGNI** — не добавляй то, что не описано в дизайне

## Что важно знать

- **Пользователь:** почти нет опыта программирования. Объясняй простыми словами, ручные шаги описывай по пунктам. Общение на русском.
- **Репозиторий:** `~/dotfiles`, удалённый `git@github.com:btcott/Btcott.git`, **публичный**. Секреты в него не попадают.
- **Git:** работа идёт в ветке `setup-environment`. Коммит и пуш только по просьбе пользователя, в `main` без прямой просьбы не пушить.
- **Симлинки:** `~/.claude/CLAUDE.md`, `settings.json`, `statusline.sh` и `commands/*` указывают в `~/dotfiles`. Файлы, которых нет в `main`, при переключении на `main` пропадут, и симлинки сломаются. Не переключайся на `main` до слияния.
- **Тесты и настоящие файлы:** `tests/test-install.sh` работает во временном `HOME` и безопасен. Прямой запуск `install.sh` меняет настоящие файлы, старые версии попадают в `~/.dotfiles-backup/`.
- **Shell агента:** `.zshrc` может быть не загружен. Перед командами выполни:

  ```bash
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home
  export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
  ```

- **bash 3.2:** `install.sh` работает на системном bash. Имена переменных рядом с не-ASCII символами пиши в скобках: `${STEP}`, а не `$STEP`.

## Состояние на 07.11.2026

- **Готово, но не закоммичено:** `install.sh`, `Brewfile`, `.gitignore`, `.zshrc`, `claude/`, `commands/expo-check.md`, `tests/test-install.sh`, `.github/workflows/install.yml`.
- **Применено на этом Mac:** симлинки, Homebrew и все пакеты из `Brewfile`, Xcode 27.2 с принятой лицензией, Android Studio.
- **Не сделано:** iOS-симулятор (runtime), Android SDK, виртуальное устройство Android, вход в `gh` и `eas`.

## Актуальные версии

| Инструмент | Версия | Примечание |
|---|---|---|
| Expo SDK | 58 | React Native 0.88, TypeScript 6.0 |
| Node.js | 26.13 (LTS) | Минимум для SDK 58: 22.13; верхнего предела в документации нет |
| Xcode | 27.2 | Минимум для SDK 58: 26.4 |
| JDK | Zulu 17 | `cask "zulu@17"` |
| Android SDK | Platform 36 | SDK 58: `targetSdkVersion` 36, `compileSdkVersion` 37 |
| `actions/checkout` | v7 | В workflow пока стоит v4 |

## Известные подводные камни

- **Свежий шаблон Expo не проходит проверки.** На шаблоне SDK 58 `tsc` дал 3 ошибки (CSS-файлы и типы в `*.web.tsx`), а `lint` дал 1 ошибку (`react-hooks/set-state-in-effect`). Сборка при этом проходит, а `expo-doctor` показывает 20 из 20.
- **Первый запуск `npx expo lint` падает** после автоустановки ESLint с сообщением о версии. Второй запуск работает.
- **`expo-env.d.ts`.** Файл создаёт `npx expo customize tsconfig.json`, он уже есть в `.gitignore` шаблона. Команда убирает 2 ошибки `tsc` про CSS. Остаются 1 ошибка `tsc` в `app-tabs.web.tsx` и 1 ошибка `lint` в `use-color-scheme.web.ts`: это проблемы шаблона.
- **Xcode 27.** Вместо приложения Simulator используется `open -a DeviceHub`, но `npx expo start --ios` работает с Xcode 27.2 без дополнительных действий.
- **Установка Expo Go на Android.** С adb 37.0.1 и эмулятором на API 37 `npx expo start --android` падает на установке Expo Go: потоковая установка `adb` не может разобрать APK, хотя файл целый. Причина не выяснена. Обход: `adb install --no-streaming -r -t ~/.expo/android-apk-cache/Expo-Go-<версия>.apk`, затем снова `npx expo start --android`.
- **Android Platform.** На этом Mac установлена Platform 37, а не 36 из документации Expo. Для Expo Go этого хватает, отдельная сборка не проверялась.
- **`CI=1`** отключает интерактивные запросы Expo CLI и завершает команду с ошибкой на обязательных запросах.
- **`workflow_dispatch`** запускается только для workflow, который уже есть в ветке по умолчанию. Поэтому Фича 6 идёт после слияния в `main`.
- **`permissions.deny`** не закрывает чтение через `python3`, см. раздел «Безопасность» в дизайне.

---

### Фича 1: Зафиксировать текущую реализацию ✅

**Цель:** готовая реализация закоммичена в `setup-environment`, дизайн совпадает с кодом.

**Файлы:**
- Изменить: `~/dotfiles/docs/project-design.md`, `~/dotfiles/.github/workflows/install.yml`
- Закоммитить: `~/dotfiles/install.sh`, `~/dotfiles/Brewfile`, `~/dotfiles/.gitignore`, `~/dotfiles/.zshrc`, `~/dotfiles/claude/`, `~/dotfiles/commands/expo-check.md`, `~/dotfiles/.github/`, `~/dotfiles/docs/`
- Тесты: `~/dotfiles/tests/test-install.sh`

**Шаги:**
- [x] В `install.yml` заменить `actions/checkout@v4` на `actions/checkout@v7`
- [x] В дизайне обновить дерево файлов: убрать Watchman, добавить `tests/`, `.github/`, `.gitignore`
- [x] В дизайне заменить `set -euo pipefail` на `set -Eeuo pipefail`
- [x] В дизайне описать `--links-only` и `~/.zshrc.local`
- [x] В дизайне добавить ручные шаги: лицензия Xcode, iOS runtime, Android SDK и виртуальное устройство
- [x] Спросить пользователя, можно ли коммитить, и после согласия сделать отдельные коммиты: настройка среды, тесты и CI, документация

**Проверка:**
- [x] `~/dotfiles/tests/test-install.sh` — последняя строка «Все проверки пройдены»
- [x] `cd ~/dotfiles && shellcheck install.sh tests/test-install.sh scripts/statusline.sh` — пустой вывод, код 0
- [x] `jq -e . ~/dotfiles/claude/settings.json >/dev/null` — код 0
- [x] `gitleaks dir ~/dotfiles --no-banner` — «no leaks found»
- [x] `gitleaks git ~/dotfiles --no-banner` — «no leaks found»
- [x] `git -C ~/dotfiles status --short` — пустой вывод

---

### Фича 2: Подсказки о ручных шагах ✅

**Цель:** `install.sh` показывает только те ручные шаги, которые действительно остались, включая лицензию Xcode, iOS runtime и виртуальное устройство Android.

**Файлы:**
- Изменить: `~/dotfiles/install.sh`, `~/dotfiles/docs/project-design.md`
- Тесты: `~/dotfiles/tests/test-install.sh`

**Шаги:**
- [x] Добавить в `print_summary` проверку лицензии Xcode: `xcodebuild -checkFirstLaunchStatus` или `xcrun simctl list runtimes`
- [x] Добавить проверку iOS runtime: в выводе `xcrun simctl list runtimes` есть строка `iOS`
- [x] Добавить проверку виртуального устройства: `emulator -list-avds` выводит хотя бы одно имя
- [x] Заменить общую строку про аккаунты отдельными проверками `gh auth status` и `eas whoami`
- [x] Добавить режим `./install.sh --check`, который запускает только `print_summary` и нужен для тестов и повторной проверки
- [x] В `tests/test-install.sh` подменить `xcrun`, `emulator`, `gh` и `eas` заглушками через `PATH` и проверить оба случая: шаг выполнен и шаг не выполнен
- [x] Описать `--check` в дизайне

**Проверка:**
- [x] `~/dotfiles/tests/test-install.sh` — последняя строка «Все проверки пройдены»
- [x] `~/dotfiles/install.sh --check` — перечислены iOS runtime, Android SDK, виртуальное устройство, `gh`, `eas`; лицензии Xcode в списке нет
- [x] `cd ~/dotfiles && shellcheck install.sh tests/test-install.sh` — пустой вывод, код 0

---

### Фича 3: Доработка `/expo-check` ✅

**Цель:** команда даёт надёжный результат на новом проекте и отличает ошибки шаблона от настоящих поломок.

**Файлы:**
- Изменить: `~/dotfiles/commands/expo-check.md`
- Тесты: прогон на `/tmp/expo-accept/test-app`

**Шаги:**
- [x] Создать проект: `mkdir -p /tmp/expo-accept && cd /tmp/expo-accept && CI=1 npx --yes create-expo-app@latest test-app --yes`
- [x] Выполнить `npx expo customize tsconfig.json` и проверить, исчезают ли ошибки `tsc` про CSS
- [x] Если исчезают, добавить этот шаг в команду перед `tsc`
- [x] Добавить правило: если `lint` упал сразу после автоустановки ESLint, запустить его ещё раз и считать результатом второй запуск
- [x] Добавить в отчёт отметку, что ошибки в нетронутых файлах шаблона не означают поломку среды
- [x] Использовать `npm run lint`, только если скрипт есть, иначе отметить проверку как пропущенную

**Проверка:**
- [x] `cd /tmp/expo-accept/test-app && command claude -p --dangerously-skip-permissions "/expo-check"` — таблица из четырёх проверок: типы, линтер, тесты, `expo-doctor`
- [x] В таблице `expo-doctor` пройден, тесты пропущены, в отчёте нет ошибки про версию ESLint
- [x] В папке без `package.json`: `cd /tmp && command claude -p --dangerously-skip-permissions "/expo-check"` — сообщение, что это не Expo-проект

---

### Фича 4: Завершить ручную настройку ✅

**Цель:** на Mac есть рабочий iOS-симулятор и Android-эмулятор, пользователь вошёл в аккаунты.

Эти шаги выполняет пользователь, агент даёт инструкции и проверяет результат.

**Файлы:**
- Создать: нет
- Изменить: нет
- Тесты: `~/dotfiles/install.sh --check`

**Шаги:**
- [x] Xcode → Settings → Components → Platform Support → iOS → Get
- [x] Открыть Android Studio и пройти мастер первого запуска
- [x] В SDK Manager установить Android SDK Platform 36, Sources for Android 36, Build-Tools и Android Emulator
- [x] В Device Manager создать виртуальное устройство
- [x] Выполнить `gh auth login`
- [x] Выполнить `eas login`; если аккаунта нет, создать его на expo.dev

**Проверка:**
- [x] `xcrun simctl list devices available | grep iPhone` — хотя бы одно устройство
- [x] `emulator -list-avds` — хотя бы одно имя
- [x] `adb --version` — выводит версию
- [x] `gh auth status` — «Logged in»
- [x] `eas whoami` — имя аккаунта
- [x] `~/dotfiles/install.sh --check` — ручных шагов не осталось

---

### Фича 5: Приёмка среды ✅

**Цель:** тестовое приложение запускается на обеих платформах, открытые вопросы дизайна закрыты, среда признана готовой.

**Файлы:**
- Изменить: `~/dotfiles/docs/project-design.md`
- Тесты: приёмка на `/tmp/expo-accept/test-app`

**Шаги:**
- [x] Если `/tmp/expo-accept/test-app` нет, создать его командой из Фичи 3
- [x] Запустить на iOS: `cd /tmp/expo-accept/test-app && npx expo start --ios`
- [x] Сделать снимок экрана: `xcrun simctl io booted screenshot /tmp/expo-accept/ios.png`
- [x] Запустить эмулятор Android: `emulator -avd <имя> &`, затем `npx expo start --android`
- [x] Сделать снимок экрана: `adb exec-out screencap -p > /tmp/expo-accept/android.png`
- [x] Выполнить `/expo-check` в проекте
- [x] Попросить пользователя посмотреть на statusline в Claude Code: после первого ответа модели должна быть шкала с процентами, а не `контекст: —`
- [x] Если шкалы нет, поправить поле в `~/dotfiles/scripts/statusline.sh`
- [x] Удалить тестовое приложение: `rm -rf /tmp/expo-accept`
- [x] Записать результаты в раздел «Проверено при реализации», убрать закрытые пункты из «Открытых вопросов»

**Проверка:**
- [x] `/tmp/expo-accept/ios.png` показывает экран приложения, а не ошибку
- [x] `/tmp/expo-accept/android.png` показывает экран приложения, а не ошибку
- [x] `adb devices` — строка вида `emulator-5554	device`
- [x] `/expo-check` — `expo-doctor` пройден, остальные проблемы только в нетронутых файлах шаблона
- [x] Пользователь подтвердил шкалу контекста в statusline
- [x] `ls /tmp/expo-accept` — «No such file or directory»

---

### Фича 6: Публикация и чистая установка ✅

**Цель:** всё лежит в `main`, чистая установка проходит на GitHub Actions.

**Файлы:**
- Изменить: `~/dotfiles/docs/project-design.md`, при необходимости `~/dotfiles/.github/workflows/install.yml`
- Тесты: `~/dotfiles/.github/workflows/install.yml`

**Шаги:**
- [x] Напомнить, что репозиторий публичный: будут видны правила, настройки, локаль и список плагинов
- [x] После прямой просьбы пользователя влить `setup-environment` в `main` через `git merge --ff-only` и запушить
- [x] Запустить workflow: `gh workflow run install.yml --repo btcott/Btcott`
- [x] Дождаться результата: `gh run watch --repo btcott/Btcott --exit-status`
- [x] Если workflow упал, исправить причину и повторить, изменения вносить через новую ветку
- [x] Удалить ветку `setup-environment` локально и на GitHub, если пользователь согласен
- [x] Записать результат в дизайн

**Проверка:**
- [x] `gh run list --repo btcott/Btcott --workflow install.yml --limit 1` — статус `completed`, результат `success`
- [x] `git -C ~/dotfiles status -sb` — `## main...origin/main`, других строк нет
- [x] `ls -L ~/.claude/settings.json ~/.claude/statusline.sh ~/.claude/commands/expo-check.md` — все пути существуют

---

## Источники

- [Настройка окружения Expo](https://docs.expo.dev/get-started/set-up-your-environment/)
- [Версии Expo SDK](https://docs.expo.dev/versions/latest/)
- [Android Studio Emulator](https://docs.expo.dev/workflow/android-studio-emulator/)
- [iOS Simulator](https://docs.expo.dev/workflow/ios-simulator/)
- [TypeScript в Expo](https://docs.expo.dev/guides/typescript/)
- [ESLint в Expo](https://docs.expo.dev/guides/using-eslint/)
- [Expo CLI](https://docs.expo.dev/more/expo-cli/)
- [EAS Build](https://docs.expo.dev/build/setup/)
- [Релизы Node.js](https://nodejs.org/en/about/previous-releases)
- [Релизы actions/checkout](https://github.com/actions/checkout/releases)
