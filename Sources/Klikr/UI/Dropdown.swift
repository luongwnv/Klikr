import AppKit
import SwiftUI

struct PopupItem {
    let title: String
    var checked = false
    /// Colour dot shown before the title (hex).
    var swatch: String? = nil
    let action: () -> Void
}

/// Weak handle to the AppKit view behind a SwiftUI control, so a dropdown can open right under it.
final class AnchorBox {
    weak var view: NSView?
}

/// Off while Settings is rendered to an image, where AppKit views would show as placeholders.
@MainActor
enum AnchorRendering {
    static var enabled = true
}

struct AnchorBackground: View {
    let box: AnchorBox
    var body: some View {
        if AnchorRendering.enabled { AnchorReader(box: box) } else { Color.clear }
    }
}

struct AnchorReader: NSViewRepresentable {
    let box: AnchorBox
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        box.view = v
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) { box.view = nsView }
}

/// Dropdown in the Settings design: a white rounded card under its anchor, with colour dots and a lime check.
@MainActor
enum Dropdown {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private static var panel: NSPanel?
    private static weak var anchor: NSView?
    private static var monitors: [Any] = []
    private static var resignObserver: NSObjectProtocol?

    static func show(_ items: [PopupItem], from view: NSView?, minWidth: CGFloat) {
        let reopening = panel != nil && anchor === view
        close()
        guard !reopening, let view, let window = view.window, !items.isEmpty else { return }
        let rect = window.convertToScreen(view.convert(view.bounds, to: nil))
        let rowH: CGFloat = 34, pad: CGFloat = 6
        let width = max(minWidth, 180)
        let height = min(CGFloat(items.count) * rowH + pad * 2, 400)
        var origin = NSPoint(x: rect.minX, y: rect.minY - 6 - height)
        if let screen = window.screen?.visibleFrame {
            if origin.y < screen.minY { origin.y = rect.maxY + 6 }
            origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - width - 8)
        }
        let list = DropdownList(items: items, rowHeight: rowH, padding: pad) { item in
            close()
            item.action()
        }
        let p = Panel(contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
                      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.contentView = NSHostingView(rootView: list.frame(width: width, height: height))
        window.addChildWindow(p, ordered: .above)
        p.makeKeyAndOrderFront(nil)
        panel = p
        anchor = view

        if let m = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown], handler: { e in
            MainActor.assumeIsolated {
                if e.type == .keyDown {
                    if e.keyCode == 53 { close(); return nil }
                    return e
                }
                guard e.window !== panel else { return e }
                // A click on the anchor itself only closes, so the button does not reopen it
                if let a = anchor, e.window === a.window, a.bounds.contains(a.convert(e.locationInWindow, from: nil)) {
                    close()
                    return nil
                }
                close()
                return e
            }
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { _ in
            MainActor.assumeIsolated { close() }
        }) { monitors.append(m) }
        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: p,
                                                                queue: .main) { _ in
            MainActor.assumeIsolated { close() }
        }
    }

    static func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        if let o = resignObserver { NotificationCenter.default.removeObserver(o) }
        resignObserver = nil
        guard let p = panel else { return }
        panel = nil
        p.parent?.removeChildWindow(p)
        p.orderOut(nil)
        p.parent?.makeKey()
    }
}

private struct DropdownList: View {
    let items: [PopupItem]
    let rowHeight: CGFloat
    let padding: CGFloat
    let pick: (PopupItem) -> Void

    init(items: [PopupItem], rowHeight: CGFloat, padding: CGFloat, pick: @escaping (PopupItem) -> Void) {
        self.items = items
        self.rowHeight = rowHeight
        self.padding = padding
        self.pick = pick
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: items.count > 11) {
                VStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { i in
                        DropdownRow(item: items[i], height: rowHeight) { pick(items[i]) }.id(i)
                    }
                }
                .padding(padding)
            }
            .onAppear {
                if let i = items.firstIndex(where: \.checked) { proxy.scrollTo(i, anchor: .center) }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(KF.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(KF.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DropdownRow: View {
    let item: PopupItem
    let height: CGFloat
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let hex = item.swatch {
                    Circle().fill(Color(nsColor: NSColor(hex: hex) ?? .gray))
                        .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
                        .frame(width: 16, height: 16)
                }
                Text(item.title).font(.system(size: 14)).foregroundColor(KF.ink).lineLimit(1)
                Spacer(minLength: 8)
                if item.checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(KF.ink)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(KF.lime))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(hover ? KF.canvas : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
