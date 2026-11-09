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
            pauseLabel.stringValue = Copy.s("\(pausedMinutes)분 남음", "\(pausedMinutes) min left")
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
        let permissionText = NSTextField(wrappingLabelWithString: Copy.s(
            "다른 창을 어둡게 하려면 손쉬운 사용에서 Blinders를 한 번 켜 주세요.",
            "Turn Blinders on once in Accessibility to dim other windows."
        ))
        permissionText.translatesAutoresizingMaskIntoConstraints = false
        let permissionButton = NSButton(
            title: Copy.s("손쉬운 사용 열기", "Open Accessibility"),
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
        let powerLabel = NSTextField(labelWithString: Copy.s("사용", "On"))
        powerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        power.target = self
        power.action = #selector(powerChanged)
        power.setContentHuggingPriority(.required, for: .horizontal)
        powerRow.addArrangedSubview(powerLabel)
        powerRow.addArrangedSubview(NSView())
        powerRow.addArrangedSubview(power)
        stack.addArrangedSubview(powerRow)
        powerRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let dimLabel = NSTextField(labelWithString: Copy.s("어둡기", "Darkness"))
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

        let pauseTitle = NSTextField(labelWithString: Copy.s("일시정지", "Pause"))
        pauseTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(pauseTitle)
        let pauseRow = NSStackView()
        pauseRow.orientation = .horizontal
        pauseRow.spacing = 8
        pauseRow.addArrangedSubview(pauseButton(Copy.s("10분", "10 min"), #selector(pause10)))
        pauseRow.addArrangedSubview(pauseButton(Copy.s("1시간", "1 hour"), #selector(pause60)))
        stack.addArrangedSubview(pauseRow)

        pauseLabel.font = .systemFont(ofSize: 12)
        pauseLabel.textColor = .secondaryLabelColor
        resumeButton.title = Copy.s("다시 켜기", "Resume")
        resumeButton.bezelStyle = .rounded
        resumeButton.target = self
        resumeButton.action = #selector(resume)
        let resumeRow = NSStackView()
        resumeRow.orientation = .horizontal
        resumeRow.spacing = 8
        resumeRow.addArrangedSubview(pauseLabel)
        resumeRow.addArrangedSubview(resumeButton)
        stack.addArrangedSubview(resumeRow)

        login.title = Copy.s("로그인 시 실행", "Launch at login")
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
