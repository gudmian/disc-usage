# DiscUsage

Бесплатный аналог CleanDiskGo: анализ занятого места на всём диске (treemap)
и безопасная очистка мусора для macOS 15+.

## Возможности

- **Обзор** — treemap всего диска, drill-down по папкам, удаление в Корзину.
- **Большие файлы** — топ-100 тяжёлых файлов с фильтром по размеру.
- **Очистка** — системный мусор, мусор разработчика (DerivedData, симуляторы,
  кэши Gradle/npm/Homebrew), браузерные данные, старые iOS-бэкапы.
  Только белый список путей; по умолчанию — в Корзину.

## Сборка

### Требования

- macOS 15 (Sequoia) или новее
- Swift 6.0+ (Xcode 16 или новее, либо отдельный toolchain с swift.org)

Проверить toolchain: `swift --version` — должно быть `swift-driver version: ... 6.0`
или выше.

### Сборка .app

```bash
git clone https://github.com/gudmian/disc-usage.git
cd disc-usage
./Scripts/build-app.sh
```

Скрипт делает три вещи: `swift build -c release`, собирает бандл
`build/DiscUsage.app` (исполняемый файл + `Scripts/Info.plist`) и подписывает
его ad-hoc подписью (`codesign --sign -`). Каталог `build/` в `.gitignore` —
артефакты не версионируются.

Готовое приложение можно перенести в `/Applications`:

```bash
cp -R build/DiscUsage.app /Applications/
```

### Разработка

```bash
swift run DiscUsage          # запуск из исходников (debug)
swift test                   # все тесты (Swift Testing)
swift test --filter ScanKit   # тесты одного таргета
swift build -c release       # только сборка релизного бинарника
```

При запуске через `swift run` бандла нет, поэтому Full Disk Access выдаётся
терминалу — для проверки полного скана диска собирайте `.app`.

## Full Disk Access

Приложению нужен «Полный доступ к диску»: Системные настройки →
Конфиденциальность и безопасность → Полный доступ к диску → добавьте
собранный `DiscUsage.app` (из `build/` или `/Applications`). Без него часть
диска будет видна как «нет доступа». После перемещения `.app` разрешение нужно
выдать заново — система привязывает его к конкретному пути.

## Архитектура

SPM-пакет: `ScanKit` (скан диска), `CleanupKit` (правила очистки и удаление),
`DiscUsageUI` (SwiftUI), `DiscUsage` (исполняемый таргет).
Дизайн: `docs/superpowers/specs/2026-07-08-discusage-design.md`.
