import Foundation

enum Anchor: String, CaseIterable, Identifiable {
    case topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight, custom
    var id: String { rawValue }

    var title: String { L("anchor.\(rawValue)") }

    static let grid: [[Anchor]] = [[.topLeft, .top, .topRight], [.left, .center, .right], [.bottomLeft, .bottom, .bottomRight]]
}

enum ScreenMode: String, CaseIterable, Identifiable {
    case primary, mouse
    var id: String { rawValue }
    var title: String { L("screen.\(rawValue)") }
}

enum RenderStyle: String, CaseIterable, Identifiable {
    case photo, vector
    var id: String { rawValue }
    var title: String { L(self == .photo ? "style.photo" : "style.vector") }
}

final class AppSettings: ObservableObject {
    private let d = UserDefaults.standard

    @Published var layoutID: String { didSet { d.set(layoutID, forKey: "layoutID") } }
    @Published var anchor: Anchor { didSet { d.set(anchor.rawValue, forKey: "anchor") } }
    @Published var screenMode: ScreenMode { didSet { d.set(screenMode.rawValue, forKey: "screenMode") } }
    @Published var margin: Double { didSet { d.set(margin, forKey: "margin") } }
    @Published var scale: Double { didSet { d.set(scale, forKey: "scale") } }
    @Published var opacity: Double { didSet { d.set(opacity, forKey: "opacity") } }
    @Published var splitGap: Double { didSet { d.set(splitGap, forKey: "splitGap") } }
    @Published var visible: Bool { didSet { d.set(visible, forKey: "visible") } }
    @Published var clickThrough: Bool { didSet { d.set(clickThrough, forKey: "clickThrough") } }
    @Published var trackPhysical: Bool { didSet { d.set(trackPhysical, forKey: "trackPhysical") } }
    @Published var renderStyle: RenderStyle { didSet { d.set(renderStyle.rawValue, forKey: "renderStyle") } }
    @Published var showLegends: Bool { didSet { d.set(showLegends, forKey: "showLegends") } }
    @Published var language: Lang {
        didSet {
            d.set(language.rawValue, forKey: "language")
            L10n.lang = language
        }
    }
    /// Photo colourway chosen per layout id.
    @Published var colorways: [String: String] { didSet { d.set(colorways, forKey: "colorways") } }
    @Published var customX: Double { didSet { d.set(customX, forKey: "customX") } }
    @Published var customY: Double { didSet { d.set(customY, forKey: "customY") } }

    var isFirstLaunch: Bool {
        get { !d.bool(forKey: "didLaunchBefore") }
        set { d.set(!newValue, forKey: "didLaunchBefore") }
    }

    init() {
        // Carry settings over from the app's previous name (bundle dev.keyfun.Keyfun) on first launch
        if d.object(forKey: "layoutID") == nil, let old = d.persistentDomain(forName: "dev.keyfun.Keyfun") {
            for (k, v) in old { d.set(v, forKey: k) }
        }
        d.register(defaults: [
            "layoutID": "split40", "anchor": Anchor.bottom.rawValue, "screenMode": ScreenMode.primary.rawValue,
            "margin": 24.0, "scale": 1.0, "opacity": 0.96, "splitGap": 0.0,
            "visible": true, "clickThrough": false, "trackPhysical": true, "customX": 100.0, "renderStyle": RenderStyle.photo.rawValue, "language": Lang.vi.rawValue, "showLegends": true, "customY": 100.0,
        ])
        if PreLogin.isActiveMode { d.register(defaults: PreLogin.overrides()) }
        layoutID = d.string(forKey: "layoutID") ?? "split40"
        anchor = Anchor(rawValue: d.string(forKey: "anchor") ?? "") ?? .bottom
        screenMode = ScreenMode(rawValue: d.string(forKey: "screenMode") ?? "") ?? .primary
        margin = d.double(forKey: "margin")
        scale = d.double(forKey: "scale")
        opacity = d.double(forKey: "opacity")
        splitGap = d.double(forKey: "splitGap")
        visible = d.bool(forKey: "visible")
        clickThrough = d.bool(forKey: "clickThrough")
        trackPhysical = d.bool(forKey: "trackPhysical")
        renderStyle = RenderStyle(rawValue: d.string(forKey: "renderStyle") ?? "") ?? .photo
        showLegends = d.bool(forKey: "showLegends")
        let lang = Lang(rawValue: d.string(forKey: "language") ?? "") ?? .vi
        language = lang
        L10n.lang = lang
        colorways = d.dictionary(forKey: "colorways") as? [String: String] ?? [:]
        customX = d.double(forKey: "customX")
        customY = d.double(forKey: "customY")
    }
}
