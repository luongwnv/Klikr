import AppKit

enum PhysicalEvent {
    case keyDown(UInt16, isRepeat: Bool)
    case keyUp(UInt16)
    case flagsChanged(UInt16)
    case media(MediaKey, down: Bool)
}

/// Listen-only event tap: observes real keyboard input without altering it (needs Input Monitoring).
final class PhysicalMonitor {
    var handler: ((PhysicalEvent, CGEventFlags) -> Void)?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        var mask: CGEventMask = 0
        for t in [CGEventType.keyDown, .keyUp, .flagsChanged] { mask |= 1 << t.rawValue }
        mask |= 1 << 14 // NX_SYSDEFINED: media keys and encoders
        let ref = Unmanaged.passUnretained(self).toOpaque()
        // HID level sees raw keys before IMEs (EVKey...) swallow or rewrite them at session level
        guard let t = [CGEventTapLocation.cghidEventTap, .cgSessionEventTap].lazy.compactMap({ location in
            CGEvent.tapCreate(tap: location, place: .headInsertEventTap, options: .listenOnly,
                              eventsOfInterest: mask, callback: physicalTapCallback, userInfo: ref)
        }).first
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
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        if event.getIntegerValueField(.eventSourceUserData) == EventPoster.marker { return }
        // Events posted by other apps (e.g. EVKey's backspace + replacement text) come from a private source
        let state = event.getIntegerValueField(.eventSourceStateID)
        if state != Int64(CGEventSourceStateID.hidSystemState.rawValue),
           event.getIntegerValueField(.eventSourceUnixProcessID) != 0 { return }
        let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let e: PhysicalEvent
        switch type {
        case .keyDown:
            e = .keyDown(code, isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        case .keyUp:
            e = .keyUp(code)
        case .flagsChanged:
            e = .flagsChanged(code)
        default:
            guard type.rawValue == 14, let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else { return }
            let data = ns.data1
            guard let k = MediaKey(rawValue: Int32((data & 0xFFFF_0000) >> 16)) else { return }
            e = .media(k, down: (data & 0xFF00) >> 8 == 0xA)
        }
        handler?(e, event.flags)
    }
}

private func physicalTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let refcon {
        Unmanaged<PhysicalMonitor>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
