import AppKit
import SwiftUI

struct LayoutSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let keyCount: Int
    let colorways: [ColorwaySpec]

    init(_ l: Layout) {
        id = l.id
        name = l.name
        keyCount = l.keys.count
        colorways = l.hasSkin ? l.colorways : []
    }
}

final class AppModel: ObservableObject {
    @Published var layouts: [LayoutSummary] = []
    @Published var loadErrors: [String] = []
    @Published var canPost = false
    @Published var canListen = false
    @Published var loginStatus = ""
    @Published var launchAtLogin = false
    @Published var preLoginInstalled = false
    @Published var preview: NSImage?
}

struct SettingsActions {
    var setLaunchAtLogin: (Bool) -> Void
    var setPreLogin: (Bool) -> Void
    var openAccessibility: () -> Void
    var openInputMonitoring: () -> Void
}

// MARK: - Design tokens (black header, pale canvas, white pills, lime accent)

enum KF {
    static let header = Color.black
    static let canvas = Color(hex: 0xF0F0F0)
    static let card = Color.white
    static let ink = Color(hex: 0x141414)
    static let muted = Color(hex: 0x9A9A9A)
    static let faint = Color(hex: 0xBDBDBD)
    static let line = Color(hex: 0xE6E6E6)
    static let tabIdle = Color(hex: 0x8C8C8C)
    static let lime = Color(hex: 0xE3EF00)
    static let red = Color(hex: 0xFF2020)
    static let green = Color(hex: 0x2BC253)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case keyboard, position, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .keyboard: L("tab.keyboard")
        case .position: L("tab.position")
        case .system: L("tab.system")
        }
    }
}

// MARK: - Root

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var model: AppModel
    var actions: SettingsActions
    @State var tab: SettingsTab = .keyboard
    @State private var status = ""
    @State private var statusToken = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                KF.canvas
                Group {
                    switch tab {
                    case .keyboard: keyboardTab
                    case .position: positionTab
                    case .system: systemTab
                    }
                }
                .padding(.horizontal, 44)
                .padding(.top, 30)
                .padding(.bottom, 18)
            }
        }
        .frame(width: 1000, height: 680)
        .ignoresSafeArea()
        .environment(\.colorScheme, .light)
        .onReceive(settings.objectWillChange) { _ in flash(L("status.updated")) }
    }

    private func flash(_ text: String) {
        statusToken += 1
        let token = statusToken
        status = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if token == statusToken { status = "" }
        }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            KF.header
            HStack(spacing: 10) {
                Color.clear.frame(width: 70)
                Image(nsImage: StatusIcon.template(height: 15))
                    .renderingMode(.template)
                    .foregroundColor(.white)
                Text("Klikr")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                RoundIconButton(symbol: settings.visible ? "eye" : "eye.slash", dark: true) {
                    settings.visible.toggle()
                }
                .help(L(settings.visible ? "toggle.hide" : "toggle.visible"))
                .padding(.trailing, 28)
            }
            HStack(spacing: 34) {
                ForEach(SettingsTab.allCases) { t in
                    Button { tab = t } label: {
                        Text(t.title)
                            .font(.system(size: 17, weight: tab == t ? .semibold : .regular))
                            .foregroundColor(tab == t ? .white : KF.tabIdle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 64)
    }

    // MARK: Keyboard tab

    private var currentLayout: LayoutSummary? {
        model.layouts.first { $0.id == settings.layoutID } ?? model.layouts.first
    }

    private var activeColorway: ColorwaySpec? {
        guard let l = currentLayout else { return nil }
        return l.colorways.first { $0.id == settings.colorways[l.id] } ?? l.colorways.first
    }

    /// Manufacturer colourways of the current board, each a real photo.
    private func colorMenu() -> [PopupItem] {
        guard let l = currentLayout else { return [] }
        return l.colorways.map { cw in
            PopupItem(title: cw.name, checked: settings.renderStyle == .photo && cw.id == activeColorway?.id,
                      swatch: cw.swatch) {
                settings.colorways[l.id] = cw.id
                settings.renderStyle = .photo
            }
        }
    }

    private var keyboardTab: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(symbol: "person.text.rectangle", title: L("sec.layout"))
                    PillMenu(title: currentLayout?.name ?? L("noLayout"), width: 260) {
                        model.layouts.map { l in
                            PopupItem(title: l.name, checked: l.id == settings.layoutID) {
                                settings.layoutID = l.id
                            }
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    SectionLabel(symbol: "square.3.layers.3d", title: L("sec.style"))
                    HStack(spacing: 8) {
                        RoundIconButton(symbol: "square.grid.2x2.fill", dark: false) {
                            settings.renderStyle = settings.renderStyle == .photo ? .vector : .photo
                        }
                        if (currentLayout?.colorways.count ?? 0) > 1 {
                            ColorwayButton(swatch: activeColorway?.swatch, items: colorMenu)
                                .help(L("theme.help"))
                        }
                        SegmentPills(options: RenderStyle.allCases.map { ($0.title, $0) }, selection: $settings.renderStyle)
                        TogglePill(label: "Aa", isOn: $settings.showLegends)
                            .help(L("toggle.legends"))
                    }
                }
            }

            ZStack {
                KF.canvas
                if let image = model.preview {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .padding(26)
                } else {
                    Text(L("noPreview")).foregroundColor(KF.muted)
                }
            }
            .frame(height: 300)

            StatusPill(text: status)

            HStack(spacing: 10) {
                SwitchPill(title: L("toggle.visible"), isOn: $settings.visible)
                SwitchPill(title: L("toggle.legends"), isOn: $settings.showLegends)
                SwitchPill(title: L("toggle.clickThrough"), isOn: $settings.clickThrough)
                SwitchPill(title: L("toggle.track"), isOn: $settings.trackPhysical)
            }

            Spacer(minLength: 0)
            Hint(text: L("hint.keyboard"))
        }
    }

    // MARK: Position tab

    private var positionTab: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 30) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(symbol: "rectangle.inset.bottomleft.filled", title: L("sec.anchor"))
                    ScreenAnchorPicker(anchor: $settings.anchor)
                    Text(settings.anchor.title)
                        .font(.system(size: 13, weight: .medium)).foregroundColor(KF.ink)
                        .padding(.leading, 4)
                    SectionLabel(symbol: "display", title: L("sec.screen")).padding(.top, 10)
                    SegmentPills(options: ScreenMode.allCases.map { ($0.title, $0) }, selection: $settings.screenMode)
                }
                .frame(width: 360, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(symbol: "slider.horizontal.3", title: L("sec.size"))
                    Card {
                        VStack(spacing: 0) {
                            SliderRow(title: L("slider.scale"), value: $settings.scale, range: 0.5...2.5) { "\(Int($0 * 100))%" }
                            Divider().overlay(KF.line)
                            SliderRow(title: L("slider.opacity"), value: $settings.opacity, range: 0.25...1) { "\(Int($0 * 100))%" }
                            Divider().overlay(KF.line)
                            SliderRow(title: L("slider.margin"), value: $settings.margin, range: 0...200) { "\(Int($0)) px" }
                            Divider().overlay(KF.line)
                            SliderRow(title: L("slider.split"), value: $settings.splitGap, range: 0...8) {
                                String(format: L("unit.keys"), $0)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            StatusPill(text: status)
            Hint(text: L("hint.position"))
        }
    }

    // MARK: System tab

    private var systemTab: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(symbol: "power", title: L("sec.startup"))
                    Card {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingRow(title: L("login.title"),
                                       detail: model.loginStatus.isEmpty ? L("login.detail") : model.loginStatus) {
                                KFSwitch(isOn: Binding(get: { model.launchAtLogin }, set: { actions.setLaunchAtLogin($0) }))
                            }
                            Divider().overlay(KF.line)
                            SettingRow(title: L("prelogin.title"),
                                       detail: L("prelogin.detail")) {
                                KFSwitch(isOn: Binding(get: { model.preLoginInstalled }, set: { actions.setPreLogin($0) }))
                            }
                        }
                    }
                    SectionLabel(symbol: "globe", title: L("sec.language")).padding(.top, 8)
                    PillMenu(title: settings.language.nativeName, width: 260) {
                        Lang.allCases.map { lang in
                            PopupItem(title: lang.nativeName, checked: lang == settings.language) { settings.language = lang }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(symbol: "lock.shield", title: L("sec.permissions"))
                    Card {
                        VStack(alignment: .leading, spacing: 0) {
                            PermissionRow(title: L("perm.ax"), detail: L("perm.ax.detail"),
                                          granted: model.canPost, open: actions.openAccessibility)
                            Divider().overlay(KF.line)
                            PermissionRow(title: L("perm.input"), detail: L("perm.input.detail"),
                                          granted: model.canListen, open: actions.openInputMonitoring)
                        }
                    }
                    if !model.loadErrors.isEmpty {
                        SectionLabel(symbol: "exclamationmark.triangle", title: L("sec.errors")).padding(.top, 8)
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(model.loadErrors, id: \.self) {
                                    Text($0).font(.system(size: 11, design: .monospaced)).foregroundColor(KF.red)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            StatusPill(text: status)
            Hint(text: L("hint.system"))
        }
    }
}

// MARK: - Components

struct SectionLabel: View {
    let symbol: String
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 15, weight: .light))
            Text(title).font(.system(size: 15))
        }
        .foregroundColor(KF.muted)
    }
}

/// White pill showing the current value, with a round chevron; opens a native menu.
struct PillMenu: View {
    let title: String
    var width: CGFloat = 220
    let items: () -> [PopupItem]
    @State private var anchor = AnchorBox()

    var body: some View {
        Button {
            Dropdown.show(items(), from: anchor.view, minWidth: width)
        } label: {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 14)).foregroundColor(KF.ink).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(KF.muted))
            }
            .padding(.leading, 14)
            .padding(.trailing, 3)
            .frame(width: width, height: 30)
            .background(Capsule().fill(KF.card))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(AnchorBackground(box: anchor))
    }
}

/// Round swatch of the current photo colourway; opens the list of the maker's colours.
struct ColorwayButton: View {
    let swatch: String?
    let items: () -> [PopupItem]
    @State private var anchor = AnchorBox()

    var body: some View {
        Button {
            Dropdown.show(items(), from: anchor.view, minWidth: 200)
        } label: {
            Circle().fill(Color(nsColor: NSColor(hex: swatch ?? "#888888") ?? .gray))
                .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
                .padding(3)
                .background(Circle().fill(KF.card))
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(AnchorBackground(box: anchor))
    }
}

/// Pops an NSMenu at the mouse; keeps closures alive for the menu's lifetime.

struct PillButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 14))
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(KF.ink)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(Capsule().fill(KF.card))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct RoundIconButton: View {
    let symbol: String
    let dark: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(dark ? Color.white.opacity(0.85) : KF.muted)
                .frame(width: 30, height: 30)
                .background(Circle().fill(dark ? Color.clear : Color(hex: 0xE4E4E4)))
                .overlay(Circle().stroke(dark ? Color.white.opacity(0.55) : Color.clear, lineWidth: 1.2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Capsule choices; the selected one is filled white with a black dot, like the layer picker.
struct SegmentPills<T: Hashable>: View {
    let options: [(String, T)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 6) {
            ForEach(options.indices, id: \.self) { i in
                let (title, value) = options[i]
                let on = value == selection
                Button { selection = value } label: {
                    Text(title)
                        .font(.system(size: 14, weight: on ? .semibold : .regular))
                        .foregroundColor(on ? .white : KF.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 30)
                        .background(Capsule().fill(on ? KF.ink : KF.card))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Round swatch showing the current colourway (alpha / modifier / accent); opens the colour menu.

/// Small round on/off chip (e.g. legends).
struct TogglePill: View {
    let label: String
    @Binding var isOn: Bool
    var body: some View {
        Button { isOn.toggle() } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isOn ? KF.ink : KF.muted)
                .frame(width: 30, height: 30)
                .background(Circle().fill(isOn ? KF.lime : Color(hex: 0xE4E4E4)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct KFSwitch: View {
    @Binding var isOn: Bool
    var body: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { isOn.toggle() } } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? KF.ink : Color(hex: 0xD3D3D3)).frame(width: 36, height: 21)
                Circle().fill(isOn ? KF.lime : Color.white).frame(width: 15, height: 15).padding(.horizontal, 3)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SwitchPill: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 13)).foregroundColor(KF.ink).lineLimit(1)
            KFSwitch(isOn: $isOn)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 33)
        .background(Capsule().fill(KF.card))
        .onTapGesture { isOn.toggle() }
    }
}

struct KFSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - 18
            let t = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0xDCDCDC)).frame(height: 4).padding(.horizontal, 9)
                Capsule().fill(KF.ink).frame(width: max(0, w * t), height: 4).padding(.leading, 9)
                Circle().fill(KF.lime)
                    .overlay(Circle().stroke(KF.ink, lineWidth: 1.5))
                    .frame(width: 18, height: 18)
                    .offset(x: w * t)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let f = min(1, max(0, (g.location.x - 9) / max(w, 1)))
                value = range.lowerBound + f * (range.upperBound - range.lowerBound)
            })
        }
        .frame(height: 22)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String
    var body: some View {
        HStack(spacing: 16) {
            Text(title).font(.system(size: 14)).foregroundColor(KF.ink).frame(width: 150, alignment: .leading)
            KFSlider(value: $value, range: range)
            Text(format(value))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundColor(KF.ink)
                .frame(width: 64, height: 24)
                .background(Capsule().fill(KF.canvas))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(KF.card))
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: Control
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(KF.ink)
                Text(detail).font(.system(size: 12)).foregroundColor(KF.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            control
        }
        .padding(18)
    }
}

struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let open: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(granted ? KF.green : KF.red).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(KF.ink)
                Text(granted ? L("perm.granted") : detail).font(.system(size: 12)).foregroundColor(KF.muted)
            }
            Spacer()
            if !granted {
                Button(action: open) {
                    HStack(spacing: 6) {
                        Text(L("perm.grant")).font(.system(size: 13))
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(KF.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(KF.canvas))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
    }
}

struct StatusPill: View {
    let text: String
    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: 12))
            .foregroundColor(KF.faint)
            .padding(.horizontal, 22)
            .frame(height: 22)
            .background(Capsule().fill(KF.card).opacity(text.isEmpty ? 0 : 1))
            .animation(.easeOut(duration: 0.2), value: text)
    }
}

struct Hint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(KF.faint)
    }
}

/// A miniature black screen with nine anchor slots; the chosen one glows lime.
struct ScreenAnchorPicker: View {
    @Binding var anchor: Anchor
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black)
                VStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { r in
                        HStack(spacing: 14) {
                            ForEach(0..<3, id: \.self) { c in
                                let a = Anchor.grid[r][c]
                                Button { anchor = a } label: {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(anchor == a ? KF.lime : Color(hex: 0x2C2C2C))
                                        .frame(width: 82, height: 40)
                                        .overlay(
                                            Circle().fill(anchor == a ? KF.ink : Color(hex: 0x4A4A4A)).frame(width: 7, height: 7)
                                        )
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help(a.title)
                            }
                        }
                    }
                }
                if anchor == .custom {
                    Text(L("anchor.free")).font(.system(size: 11, weight: .semibold)).foregroundColor(KF.lime)
                        .padding(.horizontal, 10).frame(height: 20)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                }
            }
            .frame(width: 330, height: 190)
            // Stand of the mini screen
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xCFCFCF)).frame(width: 70, height: 10)
        }
    }
}
