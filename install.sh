#!/bin/zsh
# Сборка (Apple Silicon, текущая macOS) и установка в ~/Applications.
# Автозапуск приложение включает само при первом запуске.
set -e
cd "$(dirname "$0")"
APP=~/Applications/BatteryBeep.app
OTHER=~/Applications/BatteryBeep-Universal.app
AGENT=~/Library/LaunchAgents/local.batterybeep.plist

pkill -x BatteryBeep 2>/dev/null || true
launchctl bootout gui/$UID "$AGENT" 2>/dev/null || true
# Убираем универсальную версию, если стоит
[[ -x "$OTHER/Contents/MacOS/BatteryBeep" ]] && "$OTHER/Contents/MacOS/BatteryBeep" --uninstall
rm -rf "$OTHER"
mkdir -p ~/Applications
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
swiftc -O -o "$APP/Contents/MacOS/BatteryBeep" main.swift
strip "$APP/Contents/MacOS/BatteryBeep"
codesign -s - --force "$APP"
open "$APP"
echo "Готово: $APP ($(du -h "$APP/Contents/MacOS/BatteryBeep" | cut -f1))"
