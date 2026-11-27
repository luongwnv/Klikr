import AppKit

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
        let rest = args.dropFirst(i + 2).filter { !$0.hasPrefix("--") }
        exit(Snapshot.render(to: args[i + 1], layoutID: rest.first, demo: args.contains("--demo")) ? 0 : 1)
    }
    if let i = args.firstIndex(of: "--icon"), i + 1 < args.count {
        let img = StatusIcon.image(height: 128)
        let png = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
            .map { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) } ?? nil
        exit((try? png?.write(to: URL(fileURLWithPath: args[i + 1]))) != nil ? 0 : 1)
    }
    if let i = args.firstIndex(of: "--settings"), i + 1 < args.count {
        exit(Snapshot.renderSettings(to: args[i + 1], tab: args.dropFirst(i + 2).first) ? 0 : 1)
    }
    if args.contains("--status") {
        SystemStatus.shared.refreshNow()
        print(SystemStatus.shared.current)
        exit(0)
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
