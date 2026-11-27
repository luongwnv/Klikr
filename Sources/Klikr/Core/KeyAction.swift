import CoreGraphics

enum Modifier: String, CaseIterable, Hashable {
    case lctrl, lopt, lshift, lcmd, rctrl, ropt, rshift, rcmd, fn

    init?(name: String) {
        switch name {
        case "shift": self = .lshift
        case "ctrl", "control": self = .lctrl
        case "opt", "alt", "option", "lalt": self = .lopt
        case "ralt": self = .ropt
        case "cmd", "command", "gui", "lgui": self = .lcmd
        case "rgui": self = .rcmd
        default:
            guard let m = Modifier(rawValue: name) else { return nil }
            self = m
        }
    }

    init?(keyCode: UInt16) {
        guard let m = Modifier.allCases.first(where: { $0.keyCode == keyCode }) else { return nil }
        self = m
    }

    var keyCode: UInt16 {
        switch self {
        case .lshift: 56
        case .rshift: 60
        case .lctrl: 59
        case .rctrl: 62
        case .lopt: 58
        case .ropt: 61
        case .lcmd: 55
        case .rcmd: 54
        case .fn: 63
        }
    }

    var deviceMask: UInt64 {
        switch self {
        case .lctrl: 0x1
        case .lshift: 0x2
        case .rshift: 0x4
        case .lcmd: 0x8
        case .rcmd: 0x10
        case .lopt: 0x20
        case .ropt: 0x40
        case .rctrl: 0x2000
        case .fn: 0
        }
    }

    var kind: Modifier {
        switch self {
        case .rshift: .lshift
        case .rctrl: .lctrl
        case .ropt: .lopt
        case .rcmd: .lcmd
        default: self
        }
    }

    var genericFlag: CGEventFlags {
        switch kind {
        case .lshift: .maskShift
        case .lctrl: .maskControl
        case .lopt: .maskAlternate
        case .lcmd: .maskCommand
        default: .maskSecondaryFn
        }
    }

    var flags: CGEventFlags { CGEventFlags(rawValue: genericFlag.rawValue | deviceMask) }

    var symbol: String {
        switch kind {
        case .lshift: "⇧"
        case .lctrl: "⌃"
        case .lopt: "⌥"
        case .lcmd: "⌘"
        default: "fn"
        }
    }

    var sortOrder: Int {
        switch kind {
        case .lctrl: 0
        case .lopt: 1
        case .lshift: 2
        case .lcmd: 3
        default: 4
        }
    }

    func isDown(in flags: CGEventFlags) -> Bool {
        if deviceMask != 0 { return flags.rawValue & deviceMask != 0 }
        return flags.contains(genericFlag)
    }

    // fn is excluded: arrow and function keys carry the fn flag on their own events
    static func held(in flags: CGEventFlags) -> Set<Modifier> {
        var set = Set<Modifier>()
        for m in allCases where m != .fn && m.isDown(in: flags) { set.insert(m) }
        for kind in [Modifier.lshift, .lctrl, .lopt, .lcmd] where flags.contains(kind.genericFlag) {
            if !set.contains(where: { $0.kind == kind }) { set.insert(kind) }
        }
        return set
    }
}

enum MediaKey: Int32, CaseIterable {
    case volUp = 0, volDown = 1, brightUp = 2, brightDown = 3, mute = 7, play = 16, next = 17, prev = 18

    init?(name: String) {
        switch name {
        case "vol+", "volup", "volu": self = .volUp
        case "vol-", "voldown", "vold": self = .volDown
        case "bright+", "brightup", "briu": self = .brightUp
        case "bright-", "brightdown", "brid": self = .brightDown
        case "mute": self = .mute
        case "play", "playpause", "pp": self = .play
        case "next": self = .next
        case "prev", "previous": self = .prev
        default: return nil
        }
    }

    var symbolName: String {
        switch self {
        case .volUp: "speaker.wave.3.fill"
        case .volDown: "speaker.wave.1.fill"
        case .mute: "speaker.slash.fill"
        case .brightUp: "sun.max.fill"
        case .brightDown: "sun.min.fill"
        case .play: "playpause.fill"
        case .next: "forward.fill"
        case .prev: "backward.fill"
        }
    }

    var repeats: Bool { [.volUp, .volDown, .brightUp, .brightDown].contains(self) }
}

enum LayerMode { case momentary, toggle }

enum KeyAction: Equatable {
    case key(UInt16, Set<Modifier>)
    case modifier(Modifier)
    case layer(Int, LayerMode)
    case media(MediaKey)
    case noop

    /// Returns nil for a transparent slot (falls through to the layer below).
    static func parse(_ raw: String?) -> KeyAction? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty || s == "_" || s.lowercased() == "trans" { return nil }
        let lower = s.lowercased()
        if lower == "none" || lower == "xx" { return .noop }
        if let n = layerArg(lower, prefix: "mo") { return .layer(n, .momentary) }
        if let n = layerArg(lower, prefix: "tg") { return .layer(n, .toggle) }
        if let m = MediaKey(name: lower) { return .media(m) }
        if let m = Modifier(name: lower) { return .modifier(m) }
        if let c = KeyCodes.byName[lower] { return .key(c, []) }

        let parts = s.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        if parts.count >= 2, !parts.contains(where: \.isEmpty) {
            var mods = Set<Modifier>()
            for p in parts.dropLast() {
                guard let m = Modifier(name: p.lowercased()) else { return .noop }
                mods.insert(m)
            }
            if let c = KeyCodes.byName[parts.last!.lowercased()] { return .key(c, mods) }
        }
        return .noop
    }

    private static func layerArg(_ s: String, prefix: String) -> Int? {
        guard s.hasPrefix(prefix + "("), s.hasSuffix(")") else { return nil }
        return Int(s.dropFirst(prefix.count + 1).dropLast())
    }
}

enum KeyCodes {
    static let byName: [String: UInt16] = {
        var m: [String: UInt16] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
            "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
            "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
            "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, "`": 50, "§": 10,
            "enter": 36, "return": 36, "ret": 36,
            "tab": 48, "space": 49, "spc": 49,
            "bspc": 51, "backspace": 51,
            "esc": 53, "escape": 53,
            "capslock": 57, "caps": 57,
            "del": 117, "delete": 117, "help": 114, "insert": 114, "ins": 114,
            "print": 105, "prtsc": 105, "scroll": 107, "pause": 113,
            "home": 115, "end": 119, "pgup": 116, "pageup": 116, "pgdn": 121, "pagedown": 121,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "f13": 105, "f14": 107, "f15": 113, "f16": 106, "f17": 64, "f18": 79, "f19": 80, "f20": 90,
            "menu": 110,
            "kp0": 82, "kp1": 83, "kp2": 84, "kp3": 85, "kp4": 86, "kp5": 87, "kp6": 88, "kp7": 89, "kp8": 91,
            "kp9": 92, "kp.": 65, "kp*": 67, "kp+": 69, "kp/": 75, "kp-": 78, "kp=": 81, "kpenter": 76, "numlock": 71,
        ]
        let fkeys: [UInt16] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
        for (i, c) in fkeys.enumerated() { m["f\(i + 1)"] = c }
        return m
    }()

    static let printable: Set<UInt16> = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
        26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 50,
    ]

    static let fallbackChars: [UInt16: String] = {
        var m: [UInt16: String] = [:]
        for (name, code) in byName where name.count == 1 { m[code] = name }
        return m
    }()

    static func name(for code: UInt16) -> String {
        switch code {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "space"
        case 51: return "⌫"
        case 53: return "esc"
        case 57: return "⇪"
        case 117: return "⌦"
        case 114: return "ins"
        case 110: return "≣"
        case 82: return "0"
        case 83...89: return String(code - 82)
        case 91: return "8"
        case 92: return "9"
        case 65: return "."
        case 67: return "*"
        case 69: return "+"
        case 75: return "/"
        case 78: return "-"
        case 81: return "="
        case 76: return "↩"
        case 71: return "num"
        case 115: return "home"
        case 119: return "end"
        case 116: return "pg↑"
        case 121: return "pg↓"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            if let f = byName.first(where: { $0.value == code && $0.key.hasPrefix("f") && $0.key.count <= 3 }) {
                return f.key.uppercased()
            }
            return fallbackChars[code] ?? "#\(code)"
        }
    }

    static func extraFlags(_ code: UInt16) -> CGEventFlags {
        switch code {
        case 123...126: return [.maskNumericPad, .maskSecondaryFn]
        case 96...111, 113...122, 64, 79, 80, 90: return .maskSecondaryFn
        default: return []
        }
    }
}
