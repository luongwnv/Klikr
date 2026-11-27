import AppKit

/// Consumes left clicks on virtual keys at the HID tap, before session-level taps see them.
/// Vietnamese IMEs such as EVKey reset their word buffer on every mouse down, which breaks composing
/// (aa -> â, tones) when typing by clicking. Needs Accessibility permission.
final class ClickInterceptor {
    /// Quartz global point -> true if the click started a virtual key press.
    var onDown: ((CGPoint) -> Bool)?
    var onUp: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var capturing = false

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        var mask: CGEventMask = 0
        for t in [CGEventType.leftMouseDown, .leftMouseUp, .leftMouseDragged] { mask |= 1 << t.rawValue }
        let ref = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: clickTapCallback, userInfo: ref)
        else { return false }
        tap = t
        runLoopSource = CFMachPortCreateRunLoopSource(nil, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    func stop() {
        guard let t = tap else { return }
        CGEvent.tapEnable(tap: t, enable: false)
        if let s = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        CFMachPortInvalidate(t)
        tap = nil
        runLoopSource = nil
        if capturing {
            capturing = false
            onUp?()
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .leftMouseDown:
            capturing = onDown?(event.location) ?? false
            return capturing
        case .leftMouseDragged:
            return capturing
        case .leftMouseUp:
            guard capturing else { return false }
            capturing = false
            onUp?()
            return true
        default:
            return false
        }
    }
}

private func clickTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let consumed = Unmanaged<ClickInterceptor>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
    return consumed ? nil : Unmanaged.passUnretained(event)
}
