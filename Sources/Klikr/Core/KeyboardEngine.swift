import AppKit

/// Owns the virtual keyboard state (layers, sticky modifiers, pressed keys) and the mirrored physical state.
@MainActor
final class KeyboardEngine {
    enum Latch { case oneShot, locked }
    enum EncoderPart { case ccw, cw, press }

    private struct Active {
        let action: KeyAction
        let postedMods: [Modifier]
        let flags: CGEventFlags
    }

    private(set) var layout: Layout
    private let poster: EventPoster
    var onChange: (() -> Void)?

    private(set) var oneShotLayer: Int?
    private(set) var lockedLayer: Int?
    private(set) var previewLayer: Int?
    private(set) var latched: [Modifier: Latch] = [:]

    private(set) var virtualKeys: Set<Int> = []
    private(set) var virtualEncoders: Set<Int> = []
    private(set) var physicalKeys: Set<Int> = []
    private(set) var physicalEncoders: Set<Int> = []
    private(set) var physicalMods: Set<Modifier> = []
    private(set) var capsLock = false
    private(set) var encoderAngles: [Int: CGFloat] = [:]

    private var triggers: Set<Int> = []
    private var triggerIndex: [[Int: [Int]]] = []
    private var active: Active?
    private var repeatTimer: Timer?
    private var sweepTimer: Timer?

    private static let mediaBase = 10_000

    init(layout: Layout, poster: EventPoster) {
        self.layout = layout
        self.poster = poster
        capsLock = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
        rebuildIndex()
    }

    var virtualLayer: Int { oneShotLayer ?? lockedLayer ?? 0 }
    var displayLayer: Int { previewLayer ?? virtualLayer }

    var shiftActive: Bool {
        physicalMods.contains { $0.kind == .lshift } || latched.keys.contains { $0.kind == .lshift }
    }

    func setLayout(_ l: Layout) {
        release()
        layout = l
        oneShotLayer = nil
        lockedLayer = nil
        previewLayer = nil
        latched = [:]
        encoderAngles = [:]
        rebuildIndex()
        recomputePhysical()
        onChange?()
    }

    func action(for key: Int, layer: Int) -> KeyAction {
        let acts = layout.keyActions[key]
        var l = min(layer, acts.count - 1)
        while l >= 0 {
            if let a = acts[l] { return a }
            l -= 1
        }
        return .noop
    }

    // MARK: Virtual input

    func pressKey(_ i: Int) {
        release()
        virtualKeys.insert(i)
        press(action(for: i, layer: virtualLayer))
        onChange?()
    }

    func pressEncoder(_ j: Int, part: EncoderPart) {
        release()
        let acts = layout.encoderActions[j]
        switch part {
        case .ccw:
            encoderAngles[j, default: 0] -= .pi / 8
            press(acts.ccw ?? .noop)
        case .cw:
            encoderAngles[j, default: 0] += .pi / 8
            press(acts.cw ?? .noop)
        case .press:
            virtualEncoders.insert(j)
            press(acts.press ?? .noop)
        }
        onChange?()
    }

    func release() {
        stopRepeat()
        if let a = active {
            active = nil
            finish(a)
        }
        guard !virtualKeys.isEmpty || !virtualEncoders.isEmpty else { return }
        virtualKeys.removeAll()
        virtualEncoders.removeAll()
        onChange?()
    }

    private func press(_ action: KeyAction) {
        switch action {
        case .noop:
            break
        case .modifier(let m):
            switch latched[m] {
            case nil: latched[m] = .oneShot
            case .oneShot: latched[m] = .locked
            case .locked: latched[m] = nil
            }
        case .layer(let n, let mode):
            if mode == .toggle {
                lockedLayer = lockedLayer == n ? nil : n
                oneShotLayer = nil
            } else if oneShotLayer == n {
                oneShotLayer = nil
                lockedLayer = n
            } else if lockedLayer == n {
                lockedLayer = nil
            } else {
                oneShotLayer = n
            }
            recomputePhysical()
        case .key(57, let mods) where mods.isEmpty:
            poster.toggleCapsLock()
            capsLock.toggle()
        case .key(let code, let mods):
            let want = mods.union(latched.keys)
            let toPost = want
                .filter { m in !physicalMods.contains { $0.kind == m.kind } }
                .sorted { $0.sortOrder < $1.sortOrder }
            var flags = EventPoster.systemFlags()
            for m in toPost {
                flags.insert(m.flags)
                poster.key(m.keyCode, down: true, flags: flags)
            }
            for m in want { flags.insert(m.flags) }
            let keyFlags = flags.union(KeyCodes.extraFlags(code))
            poster.key(code, down: true, flags: keyFlags)
            active = Active(action: action, postedMods: toPost, flags: flags)
            startRepeat { [poster] in poster.key(code, down: true, flags: keyFlags, isRepeat: true) }
        case .media(let k):
            poster.media(k, down: true)
            active = Active(action: action, postedMods: [], flags: [])
            if k.repeats {
                startRepeat { [poster] in
                    poster.media(k, down: false)
                    poster.media(k, down: true)
                }
            }
        }
    }

    private func finish(_ a: Active) {
        switch a.action {
        case .key(let code, _):
            var flags = a.flags
            poster.key(code, down: false, flags: flags.union(KeyCodes.extraFlags(code)))
            for m in a.postedMods.reversed() {
                flags.remove(CGEventFlags(rawValue: m.deviceMask))
                if !flags.contains(where: m) { flags.remove(m.genericFlag) }
                poster.key(m.keyCode, down: false, flags: flags)
            }
            latched = latched.filter { $0.value == .locked }
            oneShotLayer = nil
            recomputePhysical()
        case .media(let k):
            poster.media(k, down: false)
        default:
            break
        }
    }

    private func startRepeat(_ action: @escaping () -> Void) {
        let (initial, interval) = Self.repeatTiming()
        // A lost mouse-up must never leave a key auto-repeating
        let fire = { [weak self] in
            MainActor.assumeIsolated {
                if NSEvent.pressedMouseButtons & 1 == 0 { self?.release() } else { action() }
            }
        }
        let first = Timer(timeInterval: initial, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.active != nil else { return }
                fire()
                let t = Timer(timeInterval: interval, repeats: true) { _ in fire() }
                RunLoop.main.add(t, forMode: .common)
                self.repeatTimer = t
            }
        }
        RunLoop.main.add(first, forMode: .common)
        repeatTimer = first
    }

    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    private static func repeatTiming() -> (TimeInterval, TimeInterval) {
        let d = UserDefaults.standard
        let initial = (d.object(forKey: "InitialKeyRepeat") as? NSNumber)?.doubleValue ?? 25
        let rate = (d.object(forKey: "KeyRepeat") as? NSNumber)?.doubleValue ?? 6
        return (max(initial * 0.015, 0.15), max(rate * 0.015, 0.015))
    }

    // MARK: Physical input

    func handlePhysical(_ e: PhysicalEvent, flags: CGEventFlags) {
        switch e {
        case .keyDown(let c, _):
            updateFlags(flags)
            triggers.insert(Int(c))
        case .keyUp(let c):
            updateFlags(flags)
            triggers.remove(Int(c))
        case .flagsChanged(let c):
            updateFlags(flags)
            if let m = Modifier(keyCode: c) {
                if m == .fn ? flags.contains(.maskSecondaryFn) : m.isDown(in: flags) {
                    triggers.insert(Int(c))
                } else {
                    triggers.remove(Int(c))
                }
            } else if c == 57 {
                flash(trigger: 57)
            }
        case .media(let k, let down):
            let t = Self.mediaBase + Int(k.rawValue)
            if down {
                triggers.insert(t)
                spinEncoders(for: k)
            } else {
                triggers.remove(t)
            }
        }
        recomputePhysical()
        ensureSweep()
        onChange?()
    }

    func clearPhysical() {
        triggers.removeAll()
        physicalMods = []
        recomputePhysical()
        onChange?()
    }

    private func updateFlags(_ f: CGEventFlags) {
        physicalMods = Modifier.held(in: f)
        capsLock = f.contains(.maskAlphaShift)
    }

    private func flash(trigger t: Int) {
        triggers.insert(t)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard let self else { return }
            self.triggers.remove(t)
            self.recomputePhysical()
            self.onChange?()
        }
    }

    private func spinEncoders(for k: MediaKey) {
        for (j, acts) in layout.encoderActions.enumerated() {
            if acts.cw == .media(k) { encoderAngles[j, default: 0] += .pi / 8 }
            if acts.ccw == .media(k) { encoderAngles[j, default: 0] -= .pi / 8 }
            if acts.press == .media(k) {
                physicalEncoders.insert(j)
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 160_000_000)
                    self?.physicalEncoders.remove(j)
                    self?.onChange?()
                }
            }
        }
    }

    // Event taps go quiet during secure input, so drop keys the HID state no longer reports as held
    private func ensureSweep() {
        guard sweepTimer == nil, !triggers.isEmpty else { return }
        let t = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sweep() }
        }
        RunLoop.main.add(t, forMode: .common)
        sweepTimer = t
    }

    private func sweep() {
        let flags = CGEventSource.flagsState(.hidSystemState)
        let stale = triggers.filter { t in
            guard t < Self.mediaBase else { return false }
            let code = UInt16(t)
            if let m = Modifier(keyCode: code) {
                return m == .fn ? !flags.contains(.maskSecondaryFn) : !m.isDown(in: flags)
            }
            if code == 57 { return false }
            return !CGEventSource.keyState(.hidSystemState, key: code)
        }
        if !stale.isEmpty {
            triggers.subtract(stale)
            physicalMods = Modifier.held(in: flags)
            recomputePhysical()
            onChange?()
        }
        if triggers.isEmpty {
            sweepTimer?.invalidate()
            sweepTimer = nil
        }
    }

    // MARK: Physical key -> on-screen position

    private static func trigger(of a: KeyAction) -> Int? {
        switch a {
        case .key(let c, _): Int(c)
        case .modifier(let m): Int(m.keyCode)
        case .media(let k): mediaBase + Int(k.rawValue)
        default: nil
        }
    }

    private func rebuildIndex() {
        triggerIndex = (0..<layout.layerCount).map { l in
            var m: [Int: [Int]] = [:]
            for i in layout.keys.indices {
                if let t = Self.trigger(of: action(for: i, layer: l)) { m[t, default: []].append(i) }
            }
            return m
        }
    }

    /// Among keys sharing a trigger, keep those whose required modifiers are physically held, preferring the most specific.
    private func matching(_ hits: [Int], layer: Int) -> [Int] {
        let held = Set(physicalMods.map(\.kind))
        var best: [Int] = []
        var bestCount = -1
        for i in hits {
            var count = 0
            if case .key(_, let mods) = action(for: i, layer: layer) {
                let kinds = Set(mods.map(\.kind))
                guard kinds.isSubset(of: held) else { continue }
                count = kinds.count
            }
            if count > bestCount {
                best = [i]
                bestCount = count
            } else if count == bestCount {
                best.append(i)
            }
        }
        return best
    }

    private func recomputePhysical() {
        var keys = Set<Int>()
        var preview: Int?
        let base = virtualLayer
        let order = [base] + (0..<layout.layerCount).filter { $0 != base }
        for t in triggers {
            for l in order where l < triggerIndex.count {
                let hits = matching(triggerIndex[l][t] ?? [], layer: l)
                if hits.isEmpty { continue }
                keys.formUnion(hits)
                if l != base, preview == nil { preview = l }
                break
            }
        }
        physicalKeys = keys
        previewLayer = preview
    }
}

private extension CGEventFlags {
    func contains(where m: Modifier) -> Bool {
        Modifier.allCases.contains { $0 != m && $0.kind == m.kind && rawValue & $0.deviceMask != 0 }
    }
}
