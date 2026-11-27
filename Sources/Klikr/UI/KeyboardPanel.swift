import AppKit

/// Borderless, non-activating panel: clicks never steal focus from the app being typed into.
final class KeyboardPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        canBecomeVisibleWithoutLogin = true
        if PreLogin.isActiveMode {
            level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class KeyboardPanelController {
    let panel = KeyboardPanel()
    let view: KeyboardView
    private let settings: AppSettings

    init(engine: KeyboardEngine, labels: LabelProvider, settings: AppSettings) {
        self.settings = settings
        view = KeyboardView(engine: engine, labels: labels)
        panel.contentView = view
        engine.onChange = { [weak view] in view?.engineChanged() }
        // No menu bar at the login window to bring a hidden keyboard back
        if !PreLogin.isActiveMode {
            view.onClose = { [weak self] in self?.settings.visible = false }
        }
        view.onMoved = { [weak self] origin in
            guard let self else { return }
            self.settings.customX = origin.x
            self.settings.customY = origin.y
            self.settings.anchor = .custom
        }
    }

    func apply() {
        view.configure(scale: settings.scale, splitGap: settings.splitGap,
                       photo: settings.renderStyle == .photo, legends: settings.showLegends)
        panel.alphaValue = settings.opacity
        panel.ignoresMouseEvents = settings.clickThrough
        reposition()
        if settings.visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func reposition() {
        let size = view.geo.size
        guard let screen = targetScreen() else { return }
        let vf = screen.visibleFrame
        let m = settings.margin
        let left = vf.minX + m, right = vf.maxX - m - size.width, midX = vf.midX - size.width / 2
        let bottom = vf.minY + m, top = vf.maxY - m - size.height, midY = vf.midY - size.height / 2
        var origin: NSPoint
        switch settings.anchor {
        case .topLeft: origin = NSPoint(x: left, y: top)
        case .top: origin = NSPoint(x: midX, y: top)
        case .topRight: origin = NSPoint(x: right, y: top)
        case .left: origin = NSPoint(x: left, y: midY)
        case .center: origin = NSPoint(x: midX, y: midY)
        case .right: origin = NSPoint(x: right, y: midY)
        case .bottomLeft: origin = NSPoint(x: left, y: bottom)
        case .bottom: origin = NSPoint(x: midX, y: bottom)
        case .bottomRight: origin = NSPoint(x: right, y: bottom)
        case .custom: origin = clamp(NSPoint(x: settings.customX, y: settings.customY), size: size)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    /// Handles a click arriving from the HID-level interceptor (Quartz global coordinates, origin top-left).
    func interceptClick(at q: CGPoint) -> Bool {
        guard settings.visible, !settings.clickThrough, panel.isVisible,
              let primaryHeight = NSScreen.screens.first?.frame.height else { return false }
        let p = NSPoint(x: q.x, y: primaryHeight - q.y)
        let frame = panel.frame
        guard frame.contains(p), NSWindow.windowNumber(at: p, belowWindowWithWindowNumber: 0) == panel.windowNumber
        else { return false }
        return view.pressTarget(at: CGPoint(x: p.x - frame.minX, y: frame.maxY - p.y))
    }

    private func targetScreen() -> NSScreen? {
        if settings.screenMode == .mouse {
            let p = NSEvent.mouseLocation
            if let s = NSScreen.screens.first(where: { NSMouseInRect(p, $0.frame, false) }) { return s }
        }
        return NSScreen.screens.first
    }

    // Keeps a dragged keyboard reachable when displays change
    private func clamp(_ p: NSPoint, size: CGSize) -> NSPoint {
        let frame = NSRect(origin: p, size: size)
        if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame.insetBy(dx: size.width * 0.3, dy: size.height * 0.3)) }) {
            return p
        }
        guard let vf = NSScreen.screens.first?.visibleFrame else { return p }
        return NSPoint(x: vf.midX - size.width / 2, y: vf.minY + settings.margin)
    }
}
