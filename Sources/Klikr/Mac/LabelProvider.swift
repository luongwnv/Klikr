import Carbon

/// Resolves key legends through the active macOS input source, so labels follow ABC, Dvorak, Vietnamese, etc.
final class LabelProvider {
    private var cache: [Int: String?] = [:]
    private var layoutData: Data?

    init() { reload() }

    func reload() {
        cache.removeAll()
        layoutData = nil
        guard let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData)
        else { return }
        layoutData = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
    }

    func character(for code: UInt16, shift: Bool) -> String? {
        let k = Int(code) << 1 | (shift ? 1 : 0)
        if let hit = cache[k] { return hit }
        let r = translate(code, shift: shift)
        cache[k] = r
        return r
    }

    private func translate(_ code: UInt16, shift: Bool) -> String? {
        guard let data = layoutData else { return nil }
        return data.withUnsafeBytes { raw -> String? in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var dead: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var len = 0
            let mods: UInt32 = shift ? UInt32(shiftKey >> 8) & 0xFF : 0
            let status = UCKeyTranslate(
                base, code, UInt16(kUCKeyActionDisplay), mods, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysMask), &dead, chars.count, &len, &chars)
            guard status == noErr, len > 0 else { return nil }
            let s = String(utf16CodeUnits: chars, count: len)
            if s.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) { return nil }
            return s
        }
    }
}
