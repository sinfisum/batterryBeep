# BatteryBeep

[English version](README.md)

Маленькое приложение для строки меню macOS: оно пищит, когда батарея MacBook садится. При 7% — 2 бипа, при 5% — 4, при 2% — 6. Перед сигналом приложение прибавляет громкость, а после возвращает прежнюю. В автозапуск оно добавляет себя само.

## Сборка

Нужны Xcode Command Line Tools (`xcode-select --install`). Есть две версии:

```bash
./install.sh              # BatteryBeep.app: Apple Silicon, та версия macOS, на которой собираете (~76 КБ)
./install-universal.sh    # BatteryBeep-Universal.app: Apple Silicon + Intel, macOS 11+ (~190 КБ)
```

Скрипт собирает приложение, устанавливает его в `~/Applications` и запускает. Установленной может быть только одна версия: каждый скрипт удаляет другую. Универсальная сборка также оставляет копию в `dist/BatteryBeep-Universal.app`, которую можно перенести на другой Mac.

Удаление: `./uninstall.sh`.
