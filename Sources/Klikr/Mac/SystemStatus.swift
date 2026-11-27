import Foundation
import IOKit.ps

extension Notification.Name {
    static let klikrStatusChanged = Notification.Name("KlikrStatusChanged")
}

/// Live Bluetooth and battery state for on-screen status icons.
/// Battery prefers a connected Bluetooth keyboard (what a keyboard's own screen would show), then the Mac's battery.
final class SystemStatus {
    struct Snapshot: Equatable {
        var bluetoothOn = false
        var keyboardConnected = false
        var keyboardName: String?
        var batteryLevel: Int?
        var charging = false
    }

    static let shared = SystemStatus()
    private(set) var current = Snapshot()
    private var timer: Timer?
    private let queue = DispatchQueue(label: "klikr.status", qos: .utility)

    func start() {
        guard timer == nil else { return }
        refresh()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func refresh() {
        queue.async {
            let snap = Self.read()
            DispatchQueue.main.async {
                guard snap != self.current else { return }
                self.current = snap
                NotificationCenter.default.post(name: .klikrStatusChanged, object: nil)
            }
        }
    }

    /// Synchronous read, used by snapshots.
    func refreshNow() {
        current = Self.read()
    }

    private static func read() -> Snapshot {
        var s = Snapshot()
        if let bt = bluetooth() {
            s.bluetoothOn = bt.on
            if let kb = bt.keyboards.first {
                s.keyboardConnected = true
                s.keyboardName = kb.name
                s.batteryLevel = kb.battery ?? cachedBattery(kb.name)
                if let level = kb.battery { cacheBattery(kb.name, level) }
            }
        }
        if s.batteryLevel == nil, let mac = macBattery() {
            s.batteryLevel = mac.level
            s.charging = mac.charging
        }
        return s
    }

    // BLE keyboards report battery only now and then; keep the last reading for a day
    private static func cacheBattery(_ name: String, _ level: Int) {
        UserDefaults.standard.set(["level": level, "at": Date().timeIntervalSince1970], forKey: "battery.\(name)")
    }

    private static func cachedBattery(_ name: String) -> Int? {
        guard let d = UserDefaults.standard.dictionary(forKey: "battery.\(name)"),
              let level = d["level"] as? Int, let at = d["at"] as? Double,
              Date().timeIntervalSince1970 - at < 86_400 else { return nil }
        return level
    }

    private static func bluetooth() -> (on: Bool, keyboards: [(name: String, battery: Int?)])? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "mini"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = (root["SPBluetoothDataType"] as? [[String: Any]])?.first else { return nil }
        let state = (info["controller_properties"] as? [String: Any])?["controller_state"] as? String
        var keyboards: [(String, Int?)] = []
        for entry in info["device_connected"] as? [[String: Any]] ?? [] {
            for (name, value) in entry {
                guard let dev = value as? [String: Any],
                      (dev["device_minorType"] as? String)?.localizedCaseInsensitiveContains("keyboard") == true
                else { continue }
                let level = dev.first { $0.key.hasPrefix("device_batteryLevel") }?.value as? String
                keyboards.append((name.trimmingCharacters(in: .whitespaces), level.flatMap { Int($0.filter(\.isNumber)) }))
            }
        }
        // Keyboards that report a battery first
        keyboards.sort { ($0.1 != nil ? 0 : 1) < ($1.1 != nil ? 0 : 1) }
        return (state == "attrib_on", keyboards)
    }

    private static func macBattery() -> (level: Int, charging: Bool)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            return (cur * 100 / max, d[kIOPSIsChargingKey] as? Bool ?? false)
        }
        return nil
    }
}
