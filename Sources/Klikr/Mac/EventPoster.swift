import AppKit
import IOKit
import IOKit.hidsystem

final class EventPoster {
    static let marker: Int64 = 0x4B46_554E
    /// Snapshots exercise the engine without sending any input to the system.
    var dryRun = false

    private let source: CGEventSource? = {
        let s = CGEventSource(stateID: .hidSystemState)
        s?.userData = EventPoster.marker
        return s
    }()

    /// At the login window CGEvent posting can be refused; root can still inject through IOHIDSystem.
    var useIOHID = false
    private var hidConnection: io_connect_t = 0

    func key(_ code: UInt16, down: Bool, flags: CGEventFlags, isRepeat: Bool = false) {
        guard !dryRun else { return }
        if useIOHID {
            let result = postIOHID(code, down: down, flags: flags, isRepeat: isRepeat)
            PreLogin.log("iohid key \(code) down=\(down) result=\(result)")
            return
        }
        PreLogin.log("cgevent key \(code) down=\(down)")
        guard let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return }
        e.flags = flags
        if isRepeat { e.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
        e.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        e.post(tap: .cghidEventTap)
    }

    func media(_ k: MediaKey, down: Bool) {
        guard !dryRun else { return }
        let state = down ? 0xA : 0xB
        let ev = NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
            subtype: 8, data1: (Int(k.rawValue) << 16) | (state << 8), data2: -1)
        guard let cg = ev?.cgEvent else { return }
        cg.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        cg.post(tap: .cghidEventTap)
    }

    private func postIOHID(_ code: UInt16, down: Bool, flags: CGEventFlags, isRepeat: Bool) -> kern_return_t {
        if hidConnection == 0 {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
            guard service != 0 else { return KERN_FAILURE }
            defer { IOObjectRelease(service) }
            let r = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &hidConnection)
            guard r == KERN_SUCCESS else { return r }
        }
        var data = NXEventData()
        let isModifier = Modifier(keyCode: code) != nil || code == 57
        let type: Int32
        if isModifier {
            type = NX_FLAGSCHANGED
        } else {
            type = down ? NX_KEYDOWN : NX_KEYUP
        }
        data.key.keyCode = code
        data.key.repeat = isRepeat ? 1 : 0
        let options = IOOptionBits(kIOHIDSetGlobalEventFlags)
        return IOHIDPostEvent(hidConnection, UInt32(type), IOGPoint(x: 0, y: 0), &data, UInt32(kNXEventDataVersion),
                              IOOptionBits(truncatingIfNeeded: flags.rawValue), options)
    }

    // Synthetic caps lock key events do not toggle the lock state, so flip it through IOHIDSystem
    func toggleCapsLock() {
        guard !dryRun else { return }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &conn) == KERN_SUCCESS else { return }
        defer { IOServiceClose(conn) }
        var state = false
        IOHIDGetModifierLockState(conn, Int32(kIOHIDCapsLockState), &state)
        IOHIDSetModifierLockState(conn, Int32(kIOHIDCapsLockState), !state)
    }

    static func systemFlags() -> CGEventFlags {
        let keep: UInt64 = CGEventFlags.maskShift.rawValue | CGEventFlags.maskControl.rawValue
            | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue
            | CGEventFlags.maskAlphaShift.rawValue | 0x207F
        return CGEventFlags(rawValue: CGEventSource.flagsState(.combinedSessionState).rawValue & keep)
    }
}
