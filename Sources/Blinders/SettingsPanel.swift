import AppKit

final class SettingsPanel: NSObject {
    let window: NSWindow
    var onEnabled: (Bool) -> Void = { _ in }
    var onPercent: (Int) -> Void = { _ in }
    var onPause: (Int) -> Void = { _ in }
    var onResume: () -> Void = {}
    var onLogin: () -> Void = {}
    var onOpenAX: () -> Void = {}

    private let permissionBox = NSBox()
    private let power = NSSwitch()
    private let slider = NSSlider()
    private let percentLabel = NSTextField(labelWithString: "50%")
    private let pauseLabel = NSTextField(labelWithString: "")
    private let resumeButton = NSButton()
    private let login = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let loginErrorLabel = NSTextField(wrappingLabelWithString: "")
    private var ignoreControl = false

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "Blinders"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        build()
    }

    func show(on screen: NSScreen) {
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        ))
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(trusted: Bool, enabled: Bool, percent: Int, pausedMinutes: Int?, loginOn: Bool, loginError: String?) {
        ignoreControl = true
        permissionBox.isHidden = trusted
        power.state = enabled ? .on : .off
        slider.integerValue = min(100, max(10, percent))
        percentLabel.stringValue = "\(slider.integerValue)%"
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
        ignoreControl = false
    }

    private func build() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 300))
        let effect = NSVisualEffectView(frame: content.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        content.addSubview(effect)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 36),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -16),
        ])

        permissionBox.boxType = .custom
        permissionBox.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55)
        permissionBox.borderColor = NSColor.separatorColor
        permissionBox.borderWidth = 1
        permissionBox.cornerRadius = 8
        permissionBox.translatesAutoresizingMaskIntoConstraints = false
        permissionBox.widthAnchor.constraint(equalToConstant: 320).isActive = true
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
                "en": "Open Accessibility",
                "ko": "손쉬운 사용 열기",
                "ja": "アクセシビリティを開く",
                "zh": "打开辅助功能",
                "es": "Abrir Accesibilidad",
                "de": "Bedienungshilfen öffnen",
                "fr": "Ouvrir Accessibilité",
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
        slider.numberOfTickMarks = 0
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

        login.title = Copy.s([
            "en": "Launch at login",
            "ko": "로그인 시 실행",
            "ja": "ログイン時に開く",
            "zh": "登录时打开",
            "es": "Abrir al iniciar sesión",
            "de": "Beim Anmelden öffnen",
            "fr": "Ouvrir à la connexion",
        ])
        login.target = self
        login.action = #selector(loginChanged)
        stack.addArrangedSubview(login)
        loginErrorLabel.font = .systemFont(ofSize: 11)
        loginErrorLabel.textColor = .systemRed
        loginErrorLabel.maximumNumberOfLines = 2
        stack.addArrangedSubview(loginErrorLabel)

        window.contentView = content
    }

    private func pauseButton(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
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

    @objc private func openAX() { onOpenAX() }
}
