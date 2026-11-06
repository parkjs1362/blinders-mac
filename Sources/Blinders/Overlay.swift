import AppKit

final class ShadeWindow: NSWindow {
    let displayID: CGDirectDisplayID

    init(screen: NSScreen) {
        displayID = screen.displayID
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        level = .normal
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .black
        hasShadow = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isMovable = false
        isRestorable = false
        animationBehavior = .none
        sharingType = .none
        alphaValue = 0
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.black.cgColor
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class Overlay {
    private var windows: [CGDirectDisplayID: ShadeWindow] = [:]
    private var effectOn = false
    private var hideToken = 0

    func apply(target: DimTarget, percent: Int, covered: CGDirectDisplayID?, animated: Bool) {
        syncScreens()
        let alpha = CGFloat(percent) / 100
        switch target {
        case .hidden:
            hideAll(animated: animated)
        case .behind(let id):
            let fade = animated && !effectOn
            for window in windows.values {
                if window.displayID == covered {
                    window.alphaValue = 0
                    window.orderOut(nil)
                } else {
                    order(window, below: id, alpha: alpha, fadeIn: fade)
                }
            }
            effectOn = true
        case .coverAll:
            let fade = animated && !effectOn
            for window in windows.values {
                orderFront(window, alpha: alpha, fadeIn: fade)
            }
            effectOn = true
        }
    }

    private func order(_ window: ShadeWindow, below id: CGWindowID, alpha: CGFloat, fadeIn: Bool) {
        window.level = .normal
        let fade = fadeIn && window.alphaValue < 0.01 && !reduceMotion
        if fade { window.alphaValue = 0 }
        window.order(.below, relativeTo: Int(id))
        if fade {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().alphaValue = alpha
            }
        } else {
            window.alphaValue = alpha
        }
    }

    private func orderFront(_ window: ShadeWindow, alpha: CGFloat, fadeIn: Bool) {
        window.level = .normal
        let fade = fadeIn && window.alphaValue < 0.01 && !reduceMotion
        if fade { window.alphaValue = 0 }
        window.orderFrontRegardless()
        if fade {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().alphaValue = alpha
            }
        } else {
            window.alphaValue = alpha
        }
    }

    private func hideAll(animated: Bool) {
        hideToken += 1
        let token = hideToken
        let fade = animated && effectOn && !reduceMotion
        for window in windows.values {
            if fade && window.isVisible && window.alphaValue > 0.01 {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    window.animator().alphaValue = 0
                }, completionHandler: {
                    DispatchQueue.main.async {
                        guard self.hideToken == token else { return }
                        window.orderOut(nil)
                    }
                })
            } else {
                window.alphaValue = 0
                window.orderOut(nil)
            }
        }
        effectOn = false
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func syncScreens() {
        let screens = NSScreen.screens.filter { $0.displayID != 0 }
        let ids = Set(screens.map(\.displayID))
        for id in windows.keys where !ids.contains(id) {
            windows[id]?.orderOut(nil)
            windows.removeValue(forKey: id)
        }
        for screen in screens {
            if let window = windows[screen.displayID] {
                if window.frame != screen.frame {
                    window.setFrame(screen.frame, display: true)
                }
            } else {
                windows[screen.displayID] = ShadeWindow(screen: screen)
            }
        }
    }
}
