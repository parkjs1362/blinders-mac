import AppKit
import ApplicationServices

// Private, but it is the call that returns a window number with only the
// Accessibility permission. Screen Recording is not required.
@_silgen_name("_AXUIElementGetWindow")
private func axWindowID(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

enum DimTarget: Equatable, CustomStringConvertible {
    case behind(CGWindowID)
    case coverAll
    case hidden

    var description: String {
        switch self {
        case .behind(let id): return "behind(\(id))"
        case .coverAll: return "coverAll"
        case .hidden: return "hidden"
        }
    }
}

func dimTarget(bundleID: String?, windowID: CGWindowID?) -> DimTarget {
    if let windowID, windowID != 0 {
        return .behind(windowID)
    }
    if bundleID == "com.apple.finder" {
        return .hidden
    }
    return .coverAll
}

func runDimTargetSelfCheck() -> Bool {
    let cases: [(String?, CGWindowID?, DimTarget)] = [
        ("com.apple.Safari", 5, .behind(5)),
        ("com.apple.finder", nil, .hidden),
        ("com.apple.finder", 0, .hidden),
        ("com.google.Chrome", nil, .coverAll),
        (nil, nil, .coverAll),
    ]
    for (bundle, wid, expected) in cases where dimTarget(bundleID: bundle, windowID: wid) != expected {
        return false
    }
    return true
}

struct FrontInfo: Equatable {
    var bundleID: String?
    var windowID: CGWindowID?
    var frame: CGRect?
}

func accessibilityTrusted(prompt: Bool) -> Bool {
    guard prompt else { return AXIsProcessTrusted() }
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [key: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func readFront() -> FrontInfo {
    guard let app = NSWorkspace.shared.frontmostApplication else {
        return FrontInfo(bundleID: nil, windowID: nil, frame: nil)
    }
    let bundleID = app.bundleIdentifier
    let element = AXUIElementCreateApplication(app.processIdentifier)
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &ref) == .success,
          let ref else {
        return FrontInfo(bundleID: bundleID, windowID: nil, frame: nil)
    }
    let window = ref as! AXUIElement
    var wid: CGWindowID = 0
    let gotID = axWindowID(window, &wid) == .success && wid != 0
    return FrontInfo(
        bundleID: bundleID,
        windowID: gotID ? wid : nil,
        frame: axFrame(window).map { roundRect(appKitFrame(fromAX: $0)) }
    )
}

func coveredDisplayID(frame: CGRect?) -> CGDirectDisplayID? {
    guard let frame else { return nil }
    for screen in NSScreen.screens {
        let overlap = screen.frame.intersection(frame)
        if overlap.isNull || overlap.isEmpty { continue }
        let ratio = (overlap.width * overlap.height) / (screen.frame.width * screen.frame.height)
        if ratio > 0.9 {
            return screen.displayID
        }
    }
    return nil
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}

private func axFrame(_ element: AXUIElement) -> CGRect? {
    var positionRef: CFTypeRef?
    var sizeRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
          AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
          let positionRef, let sizeRef else { return nil }
    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
          AXValueGetValue(sizeRef as! AXValue, .cgSize, &size),
          size.width >= 2, size.height >= 2 else { return nil }
    return CGRect(origin: position, size: size)
}

private func appKitFrame(fromAX ax: CGRect) -> CGRect {
    let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first
    let height = primary?.frame.height ?? ax.height
    return CGRect(x: ax.origin.x, y: height - ax.origin.y - ax.height, width: ax.width, height: ax.height)
}

private func roundRect(_ rect: CGRect) -> CGRect {
    CGRect(
        x: rect.origin.x.rounded(),
        y: rect.origin.y.rounded(),
        width: rect.width.rounded(),
        height: rect.height.rounded()
    )
}

final class FocusMonitor {
    var onChange: () -> Void = {}
    private(set) var info = FrontInfo(bundleID: nil, windowID: nil, frame: nil)
    private var observer: AXObserver?
    private var observedPID: pid_t = -1
    private var timer: Timer?
    private var ticks = 0
    private var last = FrontInfo(bundleID: nil, windowID: nil, frame: nil)

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh(force: true)
        }
        center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh(force: true)
        }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh(force: true)
    }

    private func poll() {
        ticks += 1
        refresh(force: ticks % 4 == 0)
    }

    private func refresh(force: Bool) {
        if let app = NSWorkspace.shared.frontmostApplication {
            watch(pid: app.processIdentifier)
        }
        let next = readFront()
        if force || next != last {
            last = next
            info = next
            onChange()
        }
    }

    private func watch(pid: pid_t) {
        if pid == observedPID, observer != nil { return }
        clearObserver()
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var created: AXObserver?
        let err = AXObserverCreate(pid, { _, _, _, ref in
            guard let ref else { return }
            let monitor = Unmanaged<FocusMonitor>.fromOpaque(ref).takeUnretainedValue()
            DispatchQueue.main.async { monitor.refresh(force: true) }
        }, &created)
        guard err == .success, let created else { return }
        let element = AXUIElementCreateApplication(pid)
        let notes = [
            kAXFocusedWindowChangedNotification,
            kAXWindowMovedNotification,
            kAXWindowResizedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
        ]
        for note in notes {
            AXObserverAddNotification(created, element, note as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        observedPID = pid
    }

    private func clearObserver() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedPID = -1
    }
}
