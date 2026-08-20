#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/DiscUsage.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/DiscUsage "$APP/Contents/MacOS/DiscUsage"
cp Scripts/Info.plist "$APP/Contents/Info.plist"
cp Scripts/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Готово: $APP"
echo "Full Disk Access: Системные настройки → Конфиденциальность и безопасность →"
echo "Полный доступ к диску → добавить $PWD/$APP"
