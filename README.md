# BatteryBeep

[Русская версия](README.ru.md)

A tiny macOS menu bar app that beeps when your MacBook battery runs low: 2 beeps at 7%, 4 at 5% and 6 at 2%. Before beeping it turns the volume up, and afterwards it restores your volume. The app adds itself to login items.

## Build

You need the Xcode Command Line Tools (`xcode-select --install`). There are two versions:

```bash
./install.sh              # BatteryBeep.app: Apple Silicon, the macOS version you build on (~76 KB)
./install-universal.sh    # BatteryBeep-Universal.app: Apple Silicon + Intel, macOS 11+ (~190 KB)
```

The script builds the app, installs it to `~/Applications` and launches it. Only one version can be installed at a time: each script removes the other version. The universal build also leaves a copy in `dist/BatteryBeep-Universal.app` that you can move to another Mac.

To uninstall, run `./uninstall.sh`.
