import AppKit

/// Runs Klikr on the macOS login window through a pre-login LaunchAgent (LimitLoadToSessionType = LoginWindow).
/// Not available on the FileVault unlock screen, which runs before macOS itself starts.
enum PreLogin {
    static let label = "dev.klikr.Klikr.prelogin"
    /// Agent of the app under its old name, removed when this one is installed.
    static let legacyAgentPath = "/Library/LaunchAgents/dev.keyfun.Keyfun.prelogin.plist"
    static let agentPath = "/Library/LaunchAgents/\(label).plist"
    static let supportDir = "/Library/Application Support/Klikr"
    static let installedApp = "/Applications/Klikr.app"

    static var isActiveMode: Bool { CommandLine.arguments.contains("--prelogin") }

    static let logPath = "/Users/Shared/Klikr/prelogin.log"

    /// Diagnostics for the login window, where there is no console to look at. No-op in a user session.
    static func log(_ message: @autoclosure () -> String) {
        guard isActiveMode else { return }
        let fm = FileManager.default
        try? fm.createDirectory(atPath: (logPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o777])
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message())\n"
        if let h = FileHandle(forWritingAtPath: logPath) {
            h.seekToEndOfFile()
            h.write(Data(line.utf8))
            try? h.close()
        } else {
            fm.createFile(atPath: logPath, contents: Data(line.utf8), attributes: [.posixPermissions: 0o666])
        }
    }
    static var isInstalled: Bool { FileManager.default.fileExists(atPath: agentPath) }

    /// Settings copied from the user at install time; the login window always shows the keyboard.
    static func overrides() -> [String: Any] {
        var d = (NSDictionary(contentsOfFile: supportDir + "/settings.plist") as? [String: Any]) ?? [:]
        d["visible"] = true
        d["clickThrough"] = false
        return d
    }

    static func install() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("klikr-prelogin-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let settings = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        try PropertyListSerialization.data(fromPropertyList: settings, format: .xml, options: 0)
            .write(to: tmp.appendingPathComponent("settings.plist"))
        let agent: [String: Any] = [
            "Label": label,
            "LimitLoadToSessionType": "LoginWindow",
            "ProgramArguments": [installedApp + "/Contents/MacOS/Klikr", "--prelogin"],
            "RunAtLoad": true,
        ]
        try PropertyListSerialization.data(fromPropertyList: agent, format: .xml, options: 0)
            .write(to: tmp.appendingPathComponent("agent.plist"))

        var lines = [
            "set -e",
            "rm -f \(q(legacyAgentPath))",
            "rm -rf '/Library/Application Support/Keyfun' /Applications/Keyfun.app",
            "mkdir -p \(q(supportDir))",
            "cp \(q(tmp.path + "/settings.plist")) \(q(supportDir + "/settings.plist"))",
        ]
        let userLayouts = LayoutStore.userDirectory.path
        if fm.fileExists(atPath: userLayouts) {
            lines += ["rm -rf \(q(supportDir + "/layouts"))", "cp -R \(q(userLayouts)) \(q(supportDir + "/layouts"))"]
        }
        let bundle = Bundle.main.bundlePath
        if bundle != installedApp {
            lines += ["rm -rf \(q(installedApp))", "ditto \(q(bundle)) \(q(installedApp))"]
        }
        lines += [
            "cp \(q(tmp.path + "/agent.plist")) \(q(agentPath))",
            "chown root:wheel \(q(agentPath))",
            "chmod 644 \(q(agentPath))",
        ]
        try runPrivileged(lines, in: tmp)
    }

    static func uninstall() throws {
        let tmp = FileManager.default.temporaryDirectory
        try runPrivileged(["rm -f \(q(agentPath))", "rm -rf \(q(supportDir))"], in: tmp)
    }

    private static func runPrivileged(_ lines: [String], in dir: URL) throws {
        let script = dir.appendingPathComponent("klikr-\(UUID().uuidString).sh")
        try lines.joined(separator: "\n").write(to: script, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: script) }
        let source = "do shell script \"/bin/bash \" & quoted form of \"\(script.path)\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let msg = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
            throw NSError(domain: "Klikr", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private static func q(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
