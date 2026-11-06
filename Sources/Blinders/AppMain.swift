import AppKit
import Carbon
import ServiceManagement

enum Copy {
    static var ko: Bool { Locale.preferredLanguages.first?.hasPrefix("ko") == true }
    static func s(_ korean: String, _ english: String) -> String { ko ? korean : english }
}

extension Notification.Name {
    static let blindersShow = Notification.Name("com.joonit.blinders.show")
}

final class Hotkey {
    var onFire: () -> Void = {}
    private(set) var registrationError: OSStatus = 0
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func install() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let target = GetEventDispatcherTarget()
        let installStatus = InstallEventHandler(target, { _, _, user in
            guard let user else { return noErr }
            Unmanaged<Hotkey>.fromOpaque(user).takeUnretainedValue().onFire()
            return noErr
        }, 1, &spec, refcon, &handler)

        let hotKeyID = EventHotKeyID(signature: FourCharCode(0x424C4E44), id: 1)
        let modifiers = UInt32(cmdKey | optionKey | controlKey)
        let registerStatus = RegisterEventHotKey(UInt32(kVK_ANSI_D), modifiers, hotKeyID, target, 0, &hotKey)
        registrationError = registerStatus == noErr ? installStatus : registerStatus
    }
}

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let focus = FocusMonitor()
    private let overlay = Overlay()
    private let hotkey = Hotkey()
    private var monitors: [Any] = []
    private var percent: Int
    private var savedPercent: Int
    private var pauseUntil: Date?
    private var pauseTimer: Timer?
    private var loginError: String?
    private var fnDown = false
    private var wasShowing = false
    private var scrollBucket: CGFloat = 0
    private var notice: NSWindow?

    override init() {
        let defaults = UserDefaults.standard
        let stored = defaults.object(forKey: "percent") as? Int
        let initial = ((stored ?? 50) / 10) * 10
        percent = min(100, max(0, initial))
        let saved = defaults.object(forKey: "savedPercent") as? Int
        let savedInitial = ((saved ?? max(percent, 10)) / 10) * 10
        savedPercent = min(100, max(10, savedInitial))
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        assert(runDimTargetSelfCheck())
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        menu.delegate = self
        if let button = statusItem.button {
            button.title = "B"
            button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            button.target = self
            button.action = #selector(showMenu)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            if let image = NSImage(systemSymbolName: "rectangle.lefthalf.filled", accessibilityDescription: "Blinders") {
                image.isTemplate = true
                image.size = NSSize(width: 16, height: 16)
                button.image = image
                button.imagePosition = .imageLeading
            }
        }
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showMenu),
            name: .blindersShow,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        installMonitors()
        hotkey.onFire = { [weak self] in self?.primaryAction() }
        hotkey.install()
        focus.onChange = { [weak self] in self?.render() }
        focus.start()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        render()
        DispatchQueue.main.async { [weak self] in
            guard let self, !accessibilityTrusted(prompt: false) else { return }
            self.showNotice()
        }
    }

    @objc func showMenu() {
        if !accessibilityTrusted(prompt: false) {
            showNotice()
            return
        }
        menu.update()
        menu.popUp(positioning: nil, at: menuAnchor(), in: nil)
    }

    private func showNotice() {
        let window = notice ?? makeNotice()
        notice = window
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        ))
        window.collectionBehavior = [.moveToActiveSpace]
        window.level = .statusBar
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeNotice() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 188),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Blinders"
        window.isReleasedWhenClosed = false
        let text = NSTextField(wrappingLabelWithString: Copy.s(
            "실행 중입니다. 다른 창을 어둡게 하려면 설정에서 Blinders 스위치를 켜세요. 켠 뒤에도 이 창이 남아 있으면 다시 실행을 누르세요.",
            "Blinders is running. Turn on its switch in Settings to dim other windows. If this window stays after that, click Relaunch."
        ))
        text.frame = NSRect(x: 20, y: 64, width: 400, height: 100)
        let settings = NSButton(
            title: Copy.s("설정 열기", "Open Settings"),
            target: self,
            action: #selector(openAX)
        )
        settings.frame = NSRect(x: 20, y: 16, width: 140, height: 32)
        let again = NSButton(
            title: Copy.s("다시 실행", "Relaunch"),
            target: self,
            action: #selector(relaunch)
        )
        again.frame = NSRect(x: 172, y: 16, width: 140, height: 32)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 188))
        content.addSubview(text)
        content.addSubview(settings)
        content.addSubview(again)
        window.contentView = content
        return window
    }

    @objc private func relaunch() {
        let path = Bundle.main.bundleURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.7; exec /usr/bin/open \"$1\"", "sh", path]
        try? task.run()
        NSApp.terminate(nil)
    }

    private func menuAnchor() -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        if let button = statusItem.button, let window = button.window {
            let rect = window.convertToScreen(button.bounds)
            let inMenuBar = rect.height > 2 && abs(screen.frame.maxY - rect.maxY) < 40
            if inMenuBar {
                let x = min(max(rect.minX, screen.frame.minX), screen.frame.maxX - 420)
                return NSPoint(x: x, y: screen.frame.maxY - 8)
            }
        }
        return NSPoint(x: screen.frame.maxX - 420, y: screen.frame.maxY - 8)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let trusted = accessibilityTrusted(prompt: false)
        if !trusted {
            menu.addItem(item(Copy.s("손쉬운 사용 설정 열기", "Open Accessibility Settings"), #selector(openAX)))
            let note = item(Copy.s(
                "권한이 없으면 창을 어둡게 하지 않습니다",
                "Dimming stays off until Accessibility is allowed"
            ), nil)
            note.isEnabled = false
            menu.addItem(note)
            menu.addItem(.separator())
        }

        if isPaused {
            let minutes = remainingMinutes()
            menu.addItem(item(Copy.s("다시 켜기 · \(minutes)분", "Resume · \(minutes) min"), #selector(resume)))
            menu.addItem(item(Copy.s("끄기", "Turn Off"), #selector(turnOffAction)))
        } else if percent > 0 {
            let off = item(Copy.s("끄기\t⌃⌥⌘D", "Turn Off\t⌃⌥⌘D"), #selector(primary))
            off.state = (trusted && !fnDown) ? .on : .off
            menu.addItem(off)
        } else {
            menu.addItem(item(Copy.s("켜기\t⌃⌥⌘D", "Turn On\t⌃⌥⌘D"), #selector(primary)))
        }

        let brightness = percent == 0
            ? Copy.s("밝기 꺼짐", "Brightness off")
            : Copy.s("밝기 \(percent)%", "Brightness \(percent)%")
        let label = item(brightness, nil)
        label.isEnabled = false
        menu.addItem(label)
        menu.addItem(item(Copy.s("더 어둡게", "Darker"), #selector(darker)))
        menu.addItem(item(Copy.s("더 밝게", "Brighter"), #selector(brighter)))
        menu.addItem(.separator())
        menu.addItem(item(Copy.s("10분 일시정지", "Pause for 10 minutes"), #selector(pause10)))
        menu.addItem(item(Copy.s("1시간 일시정지", "Pause for 1 hour"), #selector(pause60)))
        menu.addItem(.separator())
        let login = item(Copy.s("로그인 시 실행", "Launch at Login"), #selector(loginAction))
        login.state = loginIsOn() ? .on : .off
        menu.addItem(login)
        if let loginError {
            let errorItem = item(Copy.s("로그인 항목 실패: \(loginError)", "Login item failed: \(loginError)"), nil)
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }
        if hotkey.registrationError != noErr {
            let errorItem = item("Hotkey \(hotkey.registrationError)", nil)
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }
        menu.addItem(.separator())
        menu.addItem(item(Copy.s("종료", "Quit"), #selector(quit)))
    }

    private func render() {
        guard statusItem != nil else { return }
        let trusted = accessibilityTrusted(prompt: false)
        if trusted {
            notice?.orderOut(nil)
        }
        let show = trusted && percent > 0 && !isPaused && !fnDown
        let animated = show != wasShowing
        wasShowing = show
        if !show {
            overlay.apply(target: .hidden, percent: percent, covered: nil, animated: animated)
        } else {
            let info = focus.info
            overlay.apply(
                target: dimTarget(bundleID: info.bundleID, windowID: info.windowID),
                percent: percent,
                covered: coveredDisplayID(frame: info.frame),
                animated: animated
            )
        }
        let active = show
        statusItem.button?.appearsDisabled = !active
    }

    private func primaryAction() {
        if isPaused {
            clearPause()
            return
        }
        if percent == 0 {
            percent = savedPercent >= 10 ? savedPercent : 50
        } else {
            savedPercent = percent
            percent = 0
        }
        store()
        render()
    }

    private func step(_ delta: Int) {
        let snapped = min(100, max(0, ((percent + delta) / 10) * 10))
        if snapped > 0 { savedPercent = snapped }
        percent = snapped
        store()
        render()
    }

    private func pause(minutes: Int) {
        pauseUntil = Date().addingTimeInterval(Double(minutes) * 60)
        armPause()
        render()
    }

    private func clearPause() {
        pauseUntil = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
        render()
    }

    private var isPaused: Bool {
        guard let pauseUntil else { return false }
        if pauseUntil.timeIntervalSinceNow <= 0 {
            self.pauseUntil = nil
            return false
        }
        return true
    }

    private func armPause() {
        pauseTimer?.invalidate()
        guard let pauseUntil else { return }
        let left = pauseUntil.timeIntervalSinceNow
        guard left > 0 else { return }
        let timer = Timer(timeInterval: left, repeats: false) { [weak self] _ in
            self?.pauseUntil = nil
            self?.render()
        }
        RunLoop.main.add(timer, forMode: .common)
        pauseTimer = timer
    }

    private func remainingMinutes() -> Int {
        guard let pauseUntil else { return 1 }
        let seconds = max(1, pauseUntil.timeIntervalSinceNow)
        return max(1, Int((seconds / 60).rounded(.up)))
    }

    private func store() {
        UserDefaults.standard.set(percent, forKey: "percent")
        UserDefaults.standard.set(savedPercent, forKey: "savedPercent")
    }

    private func loginIsOn() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func toggleLogin() {
        do {
            if loginIsOn() {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
    }

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [.scrollWheel, .flagsChanged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handle(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let down = event.modifierFlags.contains(.function)
            if down != fnDown {
                fnDown = down
                render()
            }
            return
        }
        guard event.type == .scrollWheel, pointerOverStatusItem() else { return }
        let delta = event.scrollingDeltaY
        if event.hasPreciseScrollingDeltas {
            scrollBucket += delta
            while scrollBucket >= 8 {
                scrollBucket -= 8
                step(10)
            }
            while scrollBucket <= -8 {
                scrollBucket += 8
                step(-10)
            }
        } else if delta > 0 {
            step(10)
        } else if delta < 0 {
            step(-10)
        }
    }

    private func pointerOverStatusItem() -> Bool {
        guard let frame = statusItem.button?.window?.frame else { return false }
        return frame.contains(NSEvent.mouseLocation)
    }

    private func item(_ title: String, _ action: Selector?) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        return entry
    }

    @objc private func primary() { primaryAction() }
    @objc private func turnOffAction() {
        if percent > 0 { savedPercent = percent }
        percent = 0
        pauseUntil = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
        store()
        render()
    }
    @objc private func resume() { clearPause() }
    @objc private func darker() { step(10) }
    @objc private func brighter() { step(-10) }
    @objc private func pause10() { pause(minutes: 10) }
    @objc private func pause60() { pause(minutes: 60) }
    @objc private func loginAction() { toggleLogin() }
    @objc private func openAX() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func screensChanged() { render() }
}

@main
enum Main {
    static var keep: AppController?

    static func main() {
        if CommandLine.arguments.contains("--self-check") {
            if !runDimTargetSelfCheck() {
                fputs("dimTarget self-check failed\n", stderr)
                exit(1)
            }
            exit(0)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: "com.joonit.blinders")
            .filter { $0.processIdentifier != getpid() }
        if !others.isEmpty {
            DistributedNotificationCenter.default().postNotificationName(
                .blindersShow,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            exit(0)
        }
        let controller = AppController()
        keep = controller
        app.delegate = controller
        app.run()
    }
}
