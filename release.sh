#!/bin/zsh
# Собирает обе версии в dist/ для GitHub Release (без установки):
#   BatteryBeep-arm64.dmg      — BatteryBeep.app, Apple Silicon (все M1…), macOS 11+
#   BatteryBeep-Universal.dmg  — BatteryBeep-Universal.app, Apple Silicon + Intel, macOS 11+
# В каждом .dmg — приложение и ярлык «Программы», чтобы перетащить его туда.
set -e
cd "$(dirname "$0")"
rm -rf dist && mkdir dist

build() { # $1 — имя .app, $2 — имя .dmg, $3 — имя в настройках, $4 — минимальная macOS, остальное — архитектуры
	local app=dist/$1.app dmg=dist/$2.dmg name=$3 minos=$4; shift 4
	mkdir -p "$app/Contents/MacOS"
	cp Info.plist "$app/Contents/"
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $name" -c "Add :LSMinimumSystemVersion string $minos" "$app/Contents/Info.plist"
	local bins=()
	for arch in "$@"; do
		swiftc -O -target $arch-apple-macos$minos -o dist/$arch main.swift
		bins+=(dist/$arch)
	done
	lipo -create $bins -output "$app/Contents/MacOS/BatteryBeep"
	rm $bins
	strip "$app/Contents/MacOS/BatteryBeep"
	codesign -s - --force "$app"

	local stage=dist/stage
	mkdir -p $stage && cp -R "$app" $stage/ && ln -s /Applications $stage/Applications
	hdiutil create -quiet -volname "$name" -srcfolder $stage -ov -format UDZO "$dmg"
	rm -rf $stage
}

build BatteryBeep BatteryBeep-arm64 "BatteryBeep" 11.0 arm64
build BatteryBeep-Universal BatteryBeep-Universal "BatteryBeep Universal" 11.0 arm64 x86_64
ls -lh dist
