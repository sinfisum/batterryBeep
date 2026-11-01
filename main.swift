import Cocoa
import IOKit.ps
import CoreAudio
import ServiceManagement

// Интерфейс на английском; на русской системе — по-русски
let ru = Locale.preferredLanguages.first?.hasPrefix("ru") == true
func L(_ en: String, _ rus: String) -> String { ru ? rus : en }

// Порог заряда (%) -> количество бипов
let levels = [(2, 6), (5, 4), (7, 2)]

// LaunchAgent: автозапуск для macOS 11–12 (на 13+ — SMAppService, старый файл удаляется)
let agent = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/LaunchAgents/local.batterybeep.plist")

var autostart: Bool {
    if #available(macOS 13, *) { return SMAppService.mainApp.status == .enabled }
    let args = NSDictionary(contentsOf: agent)?["ProgramArguments"] as? [String]
    return args?.first == Bundle.main.executablePath
}

func alert(_ text: String) {
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert()
    a.messageText = "BatteryBeep"
    a.informativeText = text
    a.runModal()
}

func setAutostart(_ on: Bool) {
    if on && Bundle.main.bundlePath.contains("/AppTranslocation/") {
        return alert(L("Move BatteryBeep to the Applications folder and open it again, otherwise launch at login won't persist.",
                       "Переместите BatteryBeep в папку «Программы» и откройте снова — иначе автозапуск не сохранится."))
    }
    if #available(macOS 13, *) {
        try? FileManager.default.removeItem(at: agent)
        if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        if on && SMAppService.mainApp.status == .requiresApproval {
            alert(L("Allow launch at login: turn on BatteryBeep in Login Items. System Settings will open now.",
                    "Разрешите запуск при входе: включите BatteryBeep в «Объектах входа». Сейчас откроются настройки."))
            SMAppService.openSystemSettingsLoginItems()
        }
    } else if on {
        let plist: NSDictionary = ["Label": "local.batterybeep", "RunAtLoad": true,
                                   "ProgramArguments": [Bundle.main.executablePath!]]
        try? FileManager.default.createDirectory(at: agent.deletingLastPathComponent(), withIntermediateDirectories: true)
        plist.write(to: agent, atomically: true)
    } else {
        try? FileManager.default.removeItem(at: agent)
    }
}

final class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let info = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let auto = NSMenuItem(title: L("Launch at Login", "Запускать при входе"), action: #selector(toggleAuto), keyEquivalent: "")
    var last = 100

    func applicationDidFinishLaunching(_ n: Notification) {
        // Уже запущен другой экземпляр — выходим
        if NSRunningApplication.runningApplications(withBundleIdentifier: "local.batterybeep").count > 1 {
            return NSApp.terminate(nil)
        }
        // Включаем автозапуск, если пользователь не отключал его в меню
        if !autostart && !UserDefaults.standard.bool(forKey: "noAutostart") { setAutostart(true) }

        item.button?.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "BatteryBeep")
        let menu = NSMenu()
        menu.addItem(info)
        menu.addItem(withTitle: L("Test Sound", "Проверить звук"), action: #selector(test), keyEquivalent: "").target = self
        auto.target = self
        menu.addItem(auto)
        menu.delegate = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Quit", "Выход"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu

        last = read().pct
        update()
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let src = IOPSNotificationCreateRunLoopSource({ ctx in
            Unmanaged<App>.fromOpaque(ctx!).takeUnretainedValue().update()
        }, ctx).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
    }

    func read() -> (pct: Int, ac: Bool) {
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as Array
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
                  let cur = d[kIOPSCurrentCapacityKey] as? Int,
                  let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return (cur * 100 / max, (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue)
        }
        return (100, true)
    }

    func update() {
        let (pct, ac) = read()
        info.title = L("Battery", "Батарея") + ": \(pct)%" + (ac ? " ⚡︎" : "")
        if !ac, let hit = levels.first(where: { pct <= $0.0 && last > $0.0 }) { beep(hit.1) }
        last = pct
    }

    @discardableResult
    func script(_ s: String) -> NSAppleEventDescriptor? {
        NSAppleScript(source: s)?.executeAndReturnError(nil)
    }

    // Встроенные динамики (не наушники в разъёме, не Bluetooth/USB/HDMI)
    func speakers() -> Bool {
        func get(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> UInt32 {
            var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioDevicePropertyScopeOutput,
                                                  mElement: kAudioObjectPropertyElementMain)
            var v: UInt32 = 0, size = UInt32(4)
            AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &v)
            return v
        }
        let dev = get(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice)
        return get(dev, kAudioDevicePropertyTransportType) == kAudioDeviceTransportTypeBuiltIn
            && get(dev, kAudioDevicePropertyDataSource) != 0x6864706E // 'hdpn' — наушники
    }

    // Громкость на максимум (в наушниках 70%), бипы, затем возврат прежней громкости
    func beep(_ n: Int) {
        let vol = script("output volume of (get volume settings)")?.int32Value ?? 50
        let muted = script("output muted of (get volume settings)")?.booleanValue ?? false
        script("set volume output volume \(speakers() ? 100 : 70) without output muted")
        // NSSound(named:) — общий экземпляр; Ping длится 1.5 с, поэтому перезапускаем его
        let sound = NSSound(named: "Ping")
        for i in 0..<n {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                sound?.stop()
                sound?.play()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(n) * 0.5 + 1.6) {
            self.script("set volume output volume \(vol)" + (muted ? " with output muted" : ""))
        }
    }

    @objc func test() { beep(2) }

    @objc func toggleAuto() {
        let on = !autostart
        UserDefaults.standard.set(!on, forKey: "noAutostart")
        setAutostart(on)
    }
}

extension App: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { auto.state = autostart ? .on : .off }
}

// uninstall.sh: убрать автозапуск и выйти
if CommandLine.arguments.contains("--uninstall") {
    setAutostart(false)
    exit(0)
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
