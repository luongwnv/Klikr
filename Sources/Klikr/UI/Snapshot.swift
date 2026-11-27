import AppKit
import SwiftUI

/// `Klikr --snapshot out.png [layoutID]` renders a layout to PNG without starting the app.
@MainActor
enum Snapshot {
    static func render(to path: String, layoutID: String?, demo: Bool = false) -> Bool {
        let result = LayoutStore.load()
        result.errors.forEach { FileHandle.standardError.write(Data("\($0)\n".utf8)) }
        let args = CommandLine.arguments
        let colorway = args.firstIndex(of: "--colorway").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        guard let layout = (result.layouts.first(where: { $0.id == layoutID }) ?? result.layouts.first)?.withColorway(colorway) else {
            FileHandle.standardError.write(Data("no layouts found\n".utf8))
            return false
        }
        SystemStatus.shared.refreshNow()
        let poster = EventPoster()
        poster.dryRun = true
        let engine = KeyboardEngine(layout: layout, poster: poster)
        if CommandLine.arguments.contains("--caps") {
            engine.handlePhysical(.flagsChanged(56), flags: .maskAlphaShift)
        } else if CommandLine.arguments.contains("--no-caps") {
            engine.handlePhysical(.flagsChanged(56), flags: [])
        }
        if demo {
            let shift = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 0x2)
            engine.handlePhysical(.flagsChanged(56), flags: shift)
            engine.handlePhysical(.keyDown(3, isRepeat: false), flags: shift)
            engine.handlePhysical(.media(.volUp, down: true), flags: [])
            engine.handlePhysical(.media(.volUp, down: false), flags: [])
            // Virtual press on the key that types "k", plus a one-shot modifier
            if let k = layout.keys.indices.first(where: { engine.action(for: $0, layer: 0) == .key(40, []) }) {
                engine.pressKey(k)
            }
        }
        let view = KeyboardView(engine: engine, labels: LabelProvider())
        view.animatesTravel = false
        view.debugOutlines = CommandLine.arguments.contains("--outline")
        view.debugCapOutlines = CommandLine.arguments.contains("--cap-outline")
        view.configure(scale: 2, splitGap: 0, photo: !CommandLine.arguments.contains("--vector"),
                       legends: !CommandLine.arguments.contains("--no-legends"))
        if demo {
            view.onClose = {}
            view.revealClose()
        }
        var area = view.bounds
        if let i = CommandLine.arguments.firstIndex(of: "--focus"), i + 1 < CommandLine.arguments.count,
           let act = KeyAction.parse(CommandLine.arguments[i + 1]),
           let k = layout.keys.indices.first(where: { engine.action(for: $0, layer: 0) == act }) {
            let u = view.geo.unit
            area = view.geo.keys[k].path(inflate: 0, radius: 0).boundingBoxOfPath.insetBy(dx: -u * 1.15, dy: -u * 0.6)
        }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: area) else { return false }
        view.cacheDisplay(in: area, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: URL(fileURLWithPath: path))) != nil
    }

    /// Still image of a layout for the settings preview card; nothing is posted and no timers are left running.
    static func previewImage(layout: Layout, photo: Bool, legends: Bool, scale: CGFloat = 1.6) -> NSImage? {
        let poster = EventPoster()
        poster.dryRun = true
        let engine = KeyboardEngine(layout: layout, poster: poster)
        let view = KeyboardView(engine: engine, labels: LabelProvider())
        view.animatesTravel = false
        view.live = false
        view.configure(scale: scale, splitGap: 0, photo: photo, legends: legends)
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    /// `Klikr --settings out.png [keyboard|position|system]` renders the settings window.
    static func renderSettings(to path: String, tab: String?) -> Bool {
        AnchorRendering.enabled = false
        let settings = AppSettings()
        let model = AppModel()
        let result = LayoutStore.load()
        model.layouts = result.layouts.map(LayoutSummary.init)
        model.loadErrors = result.errors
        model.canPost = CGPreflightPostEventAccess()
        model.canListen = CGPreflightListenEventAccess()
        if let l = (result.layouts.first(where: { $0.id == settings.layoutID }) ?? result.layouts.first)?
            .withColorway(settings.colorways[settings.layoutID]) {
            model.preview = previewImage(layout: l, photo: settings.renderStyle == .photo, legends: settings.showLegends)
        }
        let actions = SettingsActions(setLaunchAtLogin: { _ in }, setPreLogin: { _ in }, openAccessibility: {},
                                      openInputMonitoring: {})
        let view = SettingsView(settings: settings, model: model, actions: actions,
                                tab: SettingsTab(rawValue: tab ?? "") ?? .keyboard)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return false }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: URL(fileURLWithPath: path))) != nil
    }
}
