import AppKit

/// Settings laid out like a Mac sidebar window: a page list on the left, the chosen page on the right.
final class SettingsPanel: NSObject {
    let window: NSWindow
    var onEnabled: (Bool) -> Void = { _ in }
    var onPercent: (Int) -> Void = { _ in }
    var onPause: (Int) -> Void = { _ in }
    var onResume: () -> Void = {}
    var onLogin: () -> Void = {}
    var onMenuBar: (Bool) -> Void = { _ in }
    var onDock: (Bool) -> Void = { _ in }
    var onQuit: () -> Void = {}
    var onOpenAX: () -> Void = {}

    private let permissionBox = NSBox()
    private let power = NSSwitch()
    private let slider = NSSlider()
    private let percentLabel = NSTextField(labelWithString: "50%")
    private let pauseLabel = NSTextField(labelWithString: "")
    private let resumeButton = NSButton()
    private let login = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let menuBar = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dock = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let presenceHint = NSTextField(wrappingLabelWithString: "")
    private let loginErrorLabel = NSTextField(wrappingLabelWithString: "")
    private let aboutAccess = NSTextField(wrappingLabelWithString: "")
    private let aboutAXButton = NSButton()
    private var rows: [NSButton] = []
    private var pages: [NSStackView] = []
    private let detail = NSView()
    private var pageConstraints: [NSLayoutConstraint] = []
    private var page = 0
    private var ignoreControl = false

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = Copy.s([
            "en": "Settings", "ko": "설정", "ja": "設定", "zh": "设置", "es": "Ajustes", "de": "Einstellungen", "fr": "Réglages",
        ])
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 680, height: 460)
        build()
    }

    func show(on screen: NSScreen) {
        if !window.isVisible {
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            ))
        }
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(trusted: Bool, enabled: Bool, percent: Int, pausedMinutes: Int?, loginOn: Bool, loginError: String?, menuBarOn: Bool, dockOn: Bool, presenceNote: String?) {
        ignoreControl = true
        permissionBox.isHidden = trusted
        power.state = enabled ? .on : .off
        slider.integerValue = min(90, max(10, percent))
        percentLabel.stringValue = "\(slider.integerValue)%"
        menuBar.state = menuBarOn ? .on : .off
        dock.state = dockOn ? .on : .off
        presenceHint.stringValue = presenceNote ?? ""
        presenceHint.isHidden = presenceNote == nil
        if let pausedMinutes {
            pauseLabel.stringValue = Copy.s([
                "en": "\(pausedMinutes) min left",
                "ko": "\(pausedMinutes)분 남음",
                "ja": "残り\(pausedMinutes)分",
                "zh": "剩余 \(pausedMinutes) 分钟",
                "es": "\(pausedMinutes) min restantes",
                "de": "noch \(pausedMinutes) Min.",
                "fr": "\(pausedMinutes) min restantes",
            ])
            pauseLabel.isHidden = false
            resumeButton.isHidden = false
        } else {
            pauseLabel.isHidden = true
            resumeButton.isHidden = true
        }
        login.state = loginOn ? .on : .off
        loginErrorLabel.stringValue = loginError ?? ""
        loginErrorLabel.isHidden = loginError == nil
        aboutAccess.stringValue = trusted
            ? Copy.s([
                "en": "Accessibility is on.",
                "ko": "손쉬운 사용이 켜져 있습니다.",
                "ja": "アクセシビリティはオンです。",
                "zh": "辅助功能已开启。",
                "es": "Accesibilidad está activada.",
                "de": "Bedienungshilfen sind an.",
                "fr": "Accessibilité est activée.",
            ])
            : Copy.s([
                "en": "Accessibility is off, so other windows stay bright.",
                "ko": "손쉬운 사용이 꺼져 있어 다른 창은 밝게 남습니다.",
                "ja": "アクセシビリティがオフなので、ほかのウィンドウは明るいままです。",
                "zh": "辅助功能未开，所以其他窗口保持明亮。",
                "es": "Accesibilidad está desactivada, así que las otras ventanas siguen claras.",
                "de": "Bedienungshilfen sind aus, andere Fenster bleiben hell.",
                "fr": "Accessibilité est désactivée, les autres fenêtres restent claires.",
            ])
        aboutAXButton.isHidden = trusted
        ignoreControl = false
    }

    private func build() {
        let content = NSView()
        let backdrop = NSVisualEffectView()
        backdrop.material = .windowBackground
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(backdrop)

        let sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sidebar)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(divider)

        let sideList = NSStackView()
        sideList.orientation = .vertical
        sideList.alignment = .leading
        sideList.spacing = 2
        sideList.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sideList)

        let titles = [
            Copy.s(["en": "Dimming", "ko": "어둡게", "ja": "暗くする", "zh": "变暗", "es": "Atenuación", "de": "Abdunkeln", "fr": "Assombrissement"]),
            Copy.s(["en": "App", "ko": "앱", "ja": "アプリ", "zh": "应用", "es": "App", "de": "App", "fr": "App"]),
            Copy.s(["en": "About", "ko": "정보", "ja": "情報", "zh": "关于", "es": "Acerca de", "de": "Info", "fr": "À propos"]),
        ]
        let symbols = ["circle.lefthalf.filled", "macwindow", "info.circle"]
        for index in titles.indices {
            let button = sidebarRow(titles[index], symbols[index], index)
            sideList.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: sideList.widthAnchor).isActive = true
            rows.append(button)
        }

        detail.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(detail)

        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: content.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: content.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 200),
            divider.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            divider.topAnchor.constraint(equalTo: content.topAnchor),
            divider.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            sideList.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            sideList.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            sideList.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 52),
            detail.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            detail.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            detail.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            detail.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        pages = [dimmingPage(), appPage(), aboutPage()]
        showPage(0)
        window.contentView = content
    }

    private func sidebarRow(_ title: String, _ symbol: String, _ index: Int) -> NSButton {
        let button = NSButton(title: "  " + title, target: self, action: #selector(pickPage(_:)))
        button.tag = index
        button.isBordered = false
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = .labelColor
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            button.image = image
        }
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.setButtonType(.momentaryChange)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return button
    }

    private func showPage(_ index: Int) {
        page = index
        for row in rows {
            let on = row.tag == index
            row.layer?.backgroundColor = (on ? NSColor.controlAccentColor.withAlphaComponent(0.28) : NSColor.clear).cgColor
            row.contentTintColor = .labelColor
        }
        NSLayoutConstraint.deactivate(pageConstraints)
        for child in detail.subviews { child.removeFromSuperview() }
        let stack = pages[index]
        stack.translatesAutoresizingMaskIntoConstraints = false
        detail.addSubview(stack)
        pageConstraints = [
            stack.leadingAnchor.constraint(equalTo: detail.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: detail.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: detail.topAnchor, constant: 8),
        ]
        NSLayoutConstraint.activate(pageConstraints)
    }

    private func pageStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        return stack
    }

    private func heading(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        return label
    }

    private func dimmingPage() -> NSStackView {
        let stack = pageStack()
        stack.addArrangedSubview(heading(Copy.s([
            "en": "Dimming", "ko": "어둡게", "ja": "暗くする", "zh": "变暗", "es": "Atenuación", "de": "Abdunkeln", "fr": "Assombrissement",
        ])))

        permissionBox.boxType = .custom
        permissionBox.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55)
        permissionBox.borderColor = NSColor.separatorColor
        permissionBox.borderWidth = 1
        permissionBox.cornerRadius = 8
        permissionBox.translatesAutoresizingMaskIntoConstraints = false
        let permissionText = NSTextField(wrappingLabelWithString: Copy.s([
            "en": "Turn Blinders on once in Accessibility to dim other windows.",
            "ko": "다른 창을 어둡게 하려면 손쉬운 사용에서 Blinders를 한 번 켜 주세요.",
            "ja": "ほかのウィンドウを暗くするには、アクセシビリティで Blinders を一度オンにしてください。",
            "zh": "要让其他窗口变暗，请在辅助功能中打开一次 Blinders。",
            "es": "Activa Blinders una vez en Accesibilidad para atenuar las otras ventanas.",
            "de": "Schalte Blinders einmal in den Bedienungshilfen ein, damit andere Fenster dunkler werden.",
            "fr": "Activez Blinders une fois dans Accessibilité pour assombrir les autres fenêtres.",
        ]))
        permissionText.translatesAutoresizingMaskIntoConstraints = false
        let permissionButton = NSButton(
            title: Copy.s([
                "en": "Open Accessibility", "ko": "손쉬운 사용 열기", "ja": "アクセシビリティを開く",
                "zh": "打开辅助功能", "es": "Abrir Accesibilidad", "de": "Bedienungshilfen öffnen", "fr": "Ouvrir Accessibilité",
            ]),
            target: self,
            action: #selector(openAX)
        )
        permissionButton.bezelStyle = .rounded
        permissionButton.translatesAutoresizingMaskIntoConstraints = false
        permissionBox.addSubview(permissionText)
        permissionBox.addSubview(permissionButton)
        NSLayoutConstraint.activate([
            permissionText.leadingAnchor.constraint(equalTo: permissionBox.leadingAnchor, constant: 12),
            permissionText.trailingAnchor.constraint(equalTo: permissionBox.trailingAnchor, constant: -12),
            permissionText.topAnchor.constraint(equalTo: permissionBox.topAnchor, constant: 10),
            permissionButton.leadingAnchor.constraint(equalTo: permissionText.leadingAnchor),
            permissionButton.topAnchor.constraint(equalTo: permissionText.bottomAnchor, constant: 8),
            permissionButton.bottomAnchor.constraint(equalTo: permissionBox.bottomAnchor, constant: -10),
        ])
        stack.addArrangedSubview(permissionBox)
        permissionBox.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let powerRow = NSStackView()
        powerRow.orientation = .horizontal
        let powerLabel = NSTextField(labelWithString: Copy.s([
            "en": "On", "ko": "사용", "ja": "使用", "zh": "开启", "es": "Activar", "de": "Ein", "fr": "Activé",
        ]))
        powerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        power.target = self
        power.action = #selector(powerChanged)
        power.setContentHuggingPriority(.required, for: .horizontal)
        powerRow.addArrangedSubview(powerLabel)
        powerRow.addArrangedSubview(NSView())
        powerRow.addArrangedSubview(power)
        stack.addArrangedSubview(powerRow)
        powerRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let dimLabel = NSTextField(labelWithString: Copy.s([
            "en": "Darkness", "ko": "어둡기", "ja": "暗さ", "zh": "暗度", "es": "Oscuridad", "de": "Dunkelheit", "fr": "Obscurité",
        ]))
        dimLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(dimLabel)
        slider.minValue = 10
        slider.maxValue = 90
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        percentLabel.alignment = .right
        percentLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let sliderRow = NSStackView()
        sliderRow.orientation = .horizontal
        sliderRow.addArrangedSubview(slider)
        sliderRow.addArrangedSubview(percentLabel)
        stack.addArrangedSubview(sliderRow)
        sliderRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let pauseTitle = NSTextField(labelWithString: Copy.s([
            "en": "Pause", "ko": "일시정지", "ja": "一時停止", "zh": "暂停", "es": "Pausa", "de": "Pause", "fr": "Pause",
        ]))
        pauseTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(pauseTitle)
        let pauseRow = NSStackView()
        pauseRow.orientation = .horizontal
        pauseRow.spacing = 8
        pauseRow.addArrangedSubview(pauseButton(Copy.s([
            "en": "10 min", "ko": "10분", "ja": "10分", "zh": "10分钟", "es": "10 min", "de": "10 Min.", "fr": "10 min",
        ]), #selector(pause10)))
        pauseRow.addArrangedSubview(pauseButton(Copy.s([
            "en": "1 hour", "ko": "1시간", "ja": "1時間", "zh": "1小时", "es": "1 hora", "de": "1 Stunde", "fr": "1 heure",
        ]), #selector(pause60)))
        stack.addArrangedSubview(pauseRow)
        pauseLabel.font = .systemFont(ofSize: 12)
        pauseLabel.textColor = .secondaryLabelColor
        resumeButton.title = Copy.s([
            "en": "Resume", "ko": "다시 켜기", "ja": "再開", "zh": "恢复", "es": "Reanudar", "de": "Fortsetzen", "fr": "Reprendre",
        ])
        resumeButton.bezelStyle = .rounded
        resumeButton.target = self
        resumeButton.action = #selector(resume)
        let resumeRow = NSStackView()
        resumeRow.orientation = .horizontal
        resumeRow.spacing = 8
        resumeRow.addArrangedSubview(pauseLabel)
        resumeRow.addArrangedSubview(resumeButton)
        stack.addArrangedSubview(resumeRow)
        return stack
    }

    private func appPage() -> NSStackView {
        let stack = pageStack()
        stack.addArrangedSubview(heading(Copy.s([
            "en": "App", "ko": "앱", "ja": "アプリ", "zh": "应用", "es": "App", "de": "App", "fr": "App",
        ])))
        let intro = NSTextField(wrappingLabelWithString: Copy.s([
            "en": "Blinders lives in the menu bar, the Dock, or both. One of them stays on.",
            "ko": "Blinders는 메뉴 막대, 독, 또는 둘 다에 둡니다. 하나는 켜 둡니다.",
            "ja": "Blinders はメニューバー、Dock、またはその両方に置きます。どちらかは残します。",
            "zh": "Blinders 可以留在菜单栏、程序坞，或两边都留。至少保留一个。",
            "es": "Blinders puede estar en la barra de menús, en el Dock o en ambos. Uno sigue visible.",
            "de": "Blinders sitzt in der Menüleiste, im Dock oder in beiden. Eines bleibt an.",
            "fr": "Blinders reste dans la barre des menus, le Dock, ou les deux. L'un des deux reste affiché.",
        ]))
        intro.textColor = .secondaryLabelColor
        intro.font = .systemFont(ofSize: 13)
        stack.addArrangedSubview(intro)
        intro.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        menuBar.title = Copy.s([
            "en": "Show in the menu bar", "ko": "메뉴 막대에 표시", "ja": "メニューバーに表示",
            "zh": "在菜单栏中显示", "es": "Mostrar en la barra de menús", "de": "In der Menüleiste anzeigen", "fr": "Afficher dans la barre des menus",
        ])
        menuBar.target = self
        menuBar.action = #selector(menuBarChanged)
        stack.addArrangedSubview(menuBar)
        dock.title = Copy.s([
            "en": "Show in the Dock", "ko": "독에 표시", "ja": "Dock に表示",
            "zh": "在程序坞中显示", "es": "Mostrar en el Dock", "de": "Im Dock anzeigen", "fr": "Afficher dans le Dock",
        ])
        dock.target = self
        dock.action = #selector(dockChanged)
        stack.addArrangedSubview(dock)
        presenceHint.font = .systemFont(ofSize: 12)
        presenceHint.textColor = .secondaryLabelColor
        presenceHint.maximumNumberOfLines = 2
        presenceHint.isHidden = true
        stack.addArrangedSubview(presenceHint)
        presenceHint.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        login.title = Copy.s([
            "en": "Launch at login", "ko": "로그인 시 실행", "ja": "ログイン時に開く",
            "zh": "登录时打开", "es": "Abrir al iniciar sesión", "de": "Beim Anmelden öffnen", "fr": "Ouvrir à la connexion",
        ])
        login.target = self
        login.action = #selector(loginChanged)
        stack.addArrangedSubview(login)
        loginErrorLabel.font = .systemFont(ofSize: 11)
        loginErrorLabel.textColor = .systemRed
        loginErrorLabel.maximumNumberOfLines = 2
        stack.addArrangedSubview(loginErrorLabel)
        loginErrorLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let quit = NSButton(
            title: Copy.s([
                "en": "Quit Blinders", "ko": "Blinders 종료", "ja": "Blinders を終了",
                "zh": "退出 Blinders", "es": "Salir de Blinders", "de": "Blinders beenden", "fr": "Quitter Blinders",
            ]),
            target: self,
            action: #selector(quit)
        )
        quit.bezelStyle = .rounded
        stack.addArrangedSubview(quit)
        return stack
    }

    private func aboutPage() -> NSStackView {
        let stack = pageStack()
        stack.addArrangedSubview(heading("Blinders"))
        let blurb = NSTextField(wrappingLabelWithString: Copy.s([
            "en": "The front window stays bright. Everything else fades.",
            "ko": "앞 창은 밝게 두고, 나머지는 어둡게 합니다.",
            "ja": "手前のウィンドウは明るく、それ以外は暗くします。",
            "zh": "最前面的窗口保持明亮，其余变暗。",
            "es": "La ventana de delante sigue clara. El resto se atenúa.",
            "de": "Das vordere Fenster bleibt hell. Der Rest wird dunkler.",
            "fr": "La fenêtre de devant reste claire. Le reste s'assombrit.",
        ]))
        blurb.textColor = .secondaryLabelColor
        blurb.font = .systemFont(ofSize: 13)
        stack.addArrangedSubview(blurb)
        blurb.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let versionLabel = NSTextField(labelWithString: version)
        versionLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(versionLabel)
        aboutAccess.font = .systemFont(ofSize: 13)
        aboutAccess.maximumNumberOfLines = 2
        stack.addArrangedSubview(aboutAccess)
        aboutAccess.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        aboutAXButton.title = Copy.s([
            "en": "Open Accessibility", "ko": "손쉬운 사용 열기", "ja": "アクセシビリティを開く",
            "zh": "打开辅助功能", "es": "Abrir Accesibilidad", "de": "Bedienungshilfen öffnen", "fr": "Ouvrir Accessibilité",
        ])
        aboutAXButton.bezelStyle = .rounded
        aboutAXButton.target = self
        aboutAXButton.action = #selector(openAX)
        stack.addArrangedSubview(aboutAXButton)
        return stack
    }

    private func pauseButton(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func pickPage(_ sender: NSButton) {
        showPage(sender.tag)
    }

    @objc private func powerChanged() {
        guard !ignoreControl else { return }
        onEnabled(power.state == .on)
    }

    @objc private func sliderChanged() {
        guard !ignoreControl else { return }
        let value = min(90, max(10, slider.integerValue))
        percentLabel.stringValue = "\(value)%"
        onPercent(value)
    }

    @objc private func pause10() { onPause(10) }
    @objc private func pause60() { onPause(60) }
    @objc private func resume() { onResume() }
    @objc private func loginChanged() {
        guard !ignoreControl else { return }
        onLogin()
    }

    @objc private func menuBarChanged() {
        guard !ignoreControl else { return }
        onMenuBar(menuBar.state == .on)
    }

    @objc private func dockChanged() {
        guard !ignoreControl else { return }
        onDock(dock.state == .on)
    }

    @objc private func quit() { onQuit() }
    @objc private func openAX() { onOpenAX() }
}
