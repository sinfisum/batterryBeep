#!/bin/zsh
# Удаляет обе версии (обычную и универсальную) и автозапуск
AGENT=~/Library/LaunchAgents/local.batterybeep.plist
pkill -x BatteryBeep 2>/dev/null
for APP in ~/Applications/BatteryBeep.app ~/Applications/BatteryBeep-Universal.app; do
	[[ -x "$APP/Contents/MacOS/BatteryBeep" ]] && "$APP/Contents/MacOS/BatteryBeep" --uninstall
	rm -rf "$APP"
done
launchctl bootout gui/$UID "$AGENT" 2>/dev/null
rm -f "$AGENT"
echo "Удалено"
