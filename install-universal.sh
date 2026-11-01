#!/bin/zsh
# Универсальная версия: Apple Silicon + Intel, macOS 11+
# Собирает dist/BatteryBeep-Universal.app и ставит в ~/Applications.
# Если swiftc нет (другой Mac без Xcode), берёт уже собранный dist/BatteryBeep-Universal.app.
# Автозапуск приложение включает само при первом запуске.
set -e
cd "$(dirname "$0")"
DIST=dist/BatteryBeep-Universal.app
APP=~/Applications/BatteryBeep-Universal.app
OTHER=~/Applications/BatteryBeep.app
AGENT=~/Library/LaunchAgents/local.batterybeep.plist

if command -v swiftc >/dev/null; then
	rm -rf "$DIST" && mkdir -p "$DIST/Contents/MacOS"
	cp Info.plist "$DIST/Contents/"
	/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 11.0" "$DIST/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleName BatteryBeep Universal" "$DIST/Contents/Info.plist"
	swiftc -O -target arm64-apple-macos11 -o dist/arm64 main.swift
	swiftc -O -target x86_64-apple-macos11 -o dist/x86_64 main.swift
	lipo -create dist/arm64 dist/x86_64 -output "$DIST/Contents/MacOS/BatteryBeep"
	rm dist/arm64 dist/x86_64
	strip "$DIST/Contents/MacOS/BatteryBeep"
	codesign -s - --force "$DIST"
fi
[[ -d "$DIST" ]] || { echo "Нет $DIST и нет swiftc для сборки"; exit 1; }

pkill -x BatteryBeep 2>/dev/null || true
launchctl bootout gui/$UID "$AGENT" 2>/dev/null || true
# Убираем обычную версию, если стоит
[[ -x "$OTHER/Contents/MacOS/BatteryBeep" ]] && "$OTHER/Contents/MacOS/BatteryBeep" --uninstall
rm -rf "$OTHER"
mkdir -p ~/Applications
rm -rf "$APP" && cp -R "$DIST" "$APP"
xattr -cr "$APP"
open "$APP"
echo "Готово: $APP ($(lipo -archs "$APP/Contents/MacOS/BatteryBeep"), $(du -h "$APP/Contents/MacOS/BatteryBeep" | cut -f1))"
