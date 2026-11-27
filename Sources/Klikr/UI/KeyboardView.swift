import AppKit

enum KeyLabel {
    case text(String)
    case symbol(String)
}

@MainActor
final class KeyboardView: NSView {
    let engine: KeyboardEngine
    let labels: LabelProvider
    private(set) var geo: BoardGeometry
    private var scale: CGFloat = 1
    private var splitGap: CGFloat = 0
    private var photo = true
    private var legends = true
    private var usesPhoto: Bool { photo && !geo.skins.isEmpty }

    var onMoved: ((NSPoint) -> Void)?
    var onClose: (() -> Void)?
    var debugOutlines = false
    var debugCapOutlines = false
    private var closeShown = false
    private var closeTimer: Timer?
    var contextMenuProvider: (() -> NSMenu)?

    private var drag: (mouse: NSPoint, origin: NSPoint)?
    private var dragMoved = false

    private let physicalAccent = NSColor(hex: "#2f8cff")!
    private let virtualAccent = NSColor(hex: "#ff8a00")!

    init(engine: KeyboardEngine, labels: LabelProvider) {
        self.engine = engine
        self.labels = labels
        geo = BoardGeometry(layout: engine.layout, scale: 1, splitGap: 0)
        super.init(frame: NSRect(origin: .zero, size: geo.size))
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func configure(scale: CGFloat, splitGap: CGFloat, photo: Bool = true, legends: Bool = true) {
        self.scale = scale
        self.splitGap = splitGap
        self.photo = photo
        self.legends = legends
        rebuild()
    }

    func rebuild() {
        travel.removeAll()
        lastDown.removeAll()
        travelTimer?.invalidate()
        travelTimer = nil
        geo = BoardGeometry(layout: engine.layout, scale: scale, splitGap: splitGap)
        setFrameSize(geo.size)
        needsDisplay = true
        scheduleClock()
    }

    // MARK: Key travel

    private struct Travel {
        var pressedAt: CFTimeInterval
        var releasedAt: CFTimeInterval?
        var releaseFrom: CGFloat = 1
        var accent: NSColor
    }

    private static let pressTime: CFTimeInterval = 0.04
    private static let releaseTime: CFTimeInterval = 0.2
    private var travel: [Int: Travel] = [:]
    private var lastDown: Set<Int> = []
    private var travelTimer: Timer?
    /// Off for snapshots: keys are drawn fully up or fully down.
    var animatesTravel = true
    /// Off for one-off renders: no clock timer or status polling is started.
    var live = true

    /// Called on every engine change: starts press/release motion for keys whose state flipped.
    func engineChanged() {
        let down = engine.physicalKeys.union(engine.virtualKeys)
        let now = CACurrentMediaTime()
        for i in down.subtracting(lastDown) {
            let accent = engine.physicalKeys.contains(i) ? physicalAccent : virtualAccent
            travel[i] = Travel(pressedAt: now, accent: accent)
        }
        for i in lastDown.subtracting(down) where travel[i] != nil {
            let from = depth(i, at: now)
            travel[i]?.releaseFrom = from
            travel[i]?.releasedAt = now
        }
        lastDown = down
        needsDisplay = true
        if !travel.isEmpty, travelTimer == nil, animatesTravel {
            let t = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.stepTravel() }
            }
            RunLoop.main.add(t, forMode: .common)
            travelTimer = t
        }
    }

    private func stepTravel() {
        let now = CACurrentMediaTime()
        for (i, tr) in travel {
            if let r = tr.releasedAt, now - r > Self.releaseTime { travel[i] = nil }
            if i < geo.keys.count {
                setNeedsDisplay(geo.keys[i].path(inflate: geo.unit * 0.12, radius: 0).boundingBoxOfPath)
            }
        }
        if travel.isEmpty {
            travelTimer?.invalidate()
            travelTimer = nil
        }
    }

    /// 0 = at rest, 1 = bottomed out; dips slightly below 0 as the cap springs back up.
    private func depth(_ i: Int, at t: CFTimeInterval = CACurrentMediaTime()) -> CGFloat {
        guard animatesTravel else {
            return engine.physicalKeys.contains(i) || engine.virtualKeys.contains(i) ? 1 : 0
        }
        guard let tr = travel[i] else { return 0 }
        if let r = tr.releasedAt {
            let x = t - r
            if x >= Self.releaseTime { return 0 }
            return tr.releaseFrom * CGFloat(exp(-x / 0.045) * cos(x * 2 * .pi / 0.18))
        }
        let x = min(1, (t - tr.pressedAt) / Self.pressTime)
        return CGFloat(1 - pow(1 - x, 3))
    }

    private func travelAccent(_ i: Int) -> NSColor? { travel[i]?.accent }

    // MARK: Live screens

    private var clockTimer: Timer?
    private var clockObservers: [NSObjectProtocol] = []

    /// Redraws on every minute boundary, and right away when the clock, time zone, locale or sleep state changes.
    private func scheduleClock() {
        clockTimer?.invalidate()
        clockTimer = nil
        guard live, !geo.displays.isEmpty else { return }
        if clockObservers.isEmpty {
            let refresh: @Sendable (Notification) -> Void = { [weak self] _ in
                MainActor.assumeIsolated {
                    ClockFormat.shared.reset()
                    self?.scheduleClock()
                }
            }
            let nc = NotificationCenter.default
            clockObservers = [
                nc.addObserver(forName: .NSSystemClockDidChange, object: nil, queue: .main, using: refresh),
                nc.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main, using: refresh),
                nc.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main, using: refresh),
                NSWorkspace.shared.notificationCenter.addObserver(
                    forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: refresh),
                nc.addObserver(forName: .klikrStatusChanged, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.needsDisplay = true }
                },
            ]
        }
        if geo.displays.contains(where: { $0.spec.lines.contains { StatusIcon.isStatus($0.format) } }) {
            SystemStatus.shared.start()
        }
        let now = Date()
        let next = Calendar.current.nextDate(after: now, matching: DateComponents(second: 0), matchingPolicy: .nextTime)
            ?? now.addingTimeInterval(60)
        let t = Timer(fire: next.addingTimeInterval(0.05), interval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.needsDisplay = true }
        }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        clockTimer = t
        needsDisplay = true
    }

    private func drawDisplays(_ ctx: CGContext) {
        guard !geo.displays.isEmpty else { return }
        let now = Date()
        for (rect, spec) in geo.displays {
            ctx.saveGState()
            ctx.clip(to: rect)
            for line in spec.lines {
                if StatusIcon.isStatus(line.format) {
                    StatusIcon.draw(line, in: rect, ctx: ctx, status: SystemStatus.shared.current)
                    continue
                }
                guard let text = ClockFormat.shared.text(line.format, now), !text.isEmpty else { continue }
                var size = rect.height * CGFloat(line.size)
                var font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: ClockFormat.weight(line.weight))
                let color = NSColor(hex: line.color ?? "#ffffff") ?? .white
                var str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
                let maxWidth = rect.width * 0.94
                if str.size().width > maxWidth {
                    size *= maxWidth / str.size().width
                    font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: ClockFormat.weight(line.weight))
                    str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
                }
                let w = str.size().width
                let anchorX = rect.minX + rect.width * CGFloat(line.x ?? 0.5)
                let x: CGFloat
                switch line.align {
                case "left": x = anchorX
                case "right": x = anchorX - w
                default: x = anchorX - w / 2
                }
                let mid = rect.minY + rect.height * CGFloat(line.y)
                let baseline = mid + font.capHeight / 2
                str.draw(at: CGPoint(x: x, y: baseline - font.ascender))
            }
            ctx.restoreGState()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = convert(point, from: superview)
        if closeShown, closeRect.contains(p) { return self }
        return geo.caseContains(p, photo: usesPhoto) ? self : nil
    }

    // MARK: Close button

    private var closeRect: CGRect {
        let r = max(9, geo.unit * 0.2)
        let c = CGPoint(x: geo.contentRect.maxX - r * 0.5, y: geo.contentRect.minY + r * 0.5)
        return CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    }

    /// Shows the close button for a few seconds after any click on the keyboard.
    func revealClose() {
        guard onClose != nil else { return }
        closeTimer?.invalidate()
        if !closeShown {
            closeShown = true
            needsDisplay = true
        }
        let t = Timer(timeInterval: 4, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.closeShown = false
                self?.needsDisplay = true
            }
        }
        RunLoop.main.add(t, forMode: .common)
        closeTimer = t
    }

    private func drawDebugOutlines(_ ctx: CGContext) {
        if debugCapOutlines {
            ctx.setStrokeColor(NSColor.systemCyan.cgColor)
            ctx.setLineWidth(max(1.5, geo.unit * 0.025))
            for k in geo.keys {
                ctx.saveGState()
                ctx.concatenate(k.transform)
                ctx.addPath(capOutline(k))
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
        guard debugOutlines else { return }
        ctx.setStrokeColor(NSColor.systemRed.cgColor)
        ctx.setLineWidth(1)
        for k in geo.keys { ctx.addPath(k.path(inflate: 0, radius: 0)) }
        ctx.strokePath()
    }

    private func drawClose(_ ctx: CGContext) {
        guard closeShown else { return }
        let r = closeRect
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 4, color: NSColor.black.withAlphaComponent(0.4).cgColor)
        ctx.setFillColor(NSColor(white: 0.12, alpha: 0.9).cgColor)
        ctx.fillEllipse(in: r)
        ctx.restoreGState()
        let d = r.width * 0.2
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(max(1.5, r.width * 0.09))
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: r.midX - d, y: r.midY - d))
        ctx.addLine(to: CGPoint(x: r.midX + d, y: r.midY + d))
        ctx.move(to: CGPoint(x: r.midX + d, y: r.midY - d))
        ctx.addLine(to: CGPoint(x: r.midX - d, y: r.midY + d))
        ctx.strokePath()
    }

    // MARK: Mouse

    /// Starts a key or encoder press at a point in view coordinates; false if the point is not on one.
    func pressTarget(at p: CGPoint) -> Bool {
        if closeShown, closeRect.contains(p) {
            closeTimer?.invalidate()
            closeShown = false
            needsDisplay = true
            onClose?()
            return true
        }
        revealClose()
        if let i = geo.keyIndex(at: p) {
            engine.pressKey(i)
            return true
        }
        if let (j, part) = geo.encoderHit(at: p) {
            engine.pressEncoder(j, part: part)
            return true
        }
        return false
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        PreLogin.log("view mouseDown at \(p)")
        if !pressTarget(at: p), let w = window {
            drag = (NSEvent.mouseLocation, w.frame.origin)
            dragMoved = false
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let d = drag, let w = window else { return }
        let m = NSEvent.mouseLocation
        w.setFrameOrigin(NSPoint(x: d.origin.x + m.x - d.mouse.x, y: d.origin.y + m.y - d.mouse.y))
        dragMoved = true
    }

    override func mouseUp(with event: NSEvent) {
        if drag != nil {
            if dragMoved, let w = window { onMoved?(w.frame.origin) }
            drag = nil
            return
        }
        engine.release()
    }

    override func menu(for event: NSEvent) -> NSMenu? { contextMenuProvider?() }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if usesPhoto {
            drawPhoto(ctx)
            return
        }
        let layout = engine.layout
        let u = geo.unit

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -u * 0.06), blur: u * 0.25,
                      color: NSColor.black.withAlphaComponent(0.4).cgColor)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for g in geo.groups {
            ctx.setFillColor(color(layout.style(g).case, "#2b2b2d").cgColor)
            // An explicit case outline replaces the default "keys grown by casePad" shape
            let hasCase = geo.cases.contains { $0.group == g }
            if !hasCase {
                for k in geo.keys where k.group == g { fill(ctx, k.path(inflate: geo.casePad, radius: geo.casePad)) }
                for e in geo.encoders where e.group == g {
                    let r = e.radius + geo.casePad
                    ctx.fillEllipse(in: CGRect(x: e.center.x - r, y: e.center.y - r, width: 2 * r, height: 2 * r))
                }
                for c in geo.covers where c.group == g {
                    fill(ctx, CGPath(roundedRect: c.rect.insetBy(dx: -geo.coverPad, dy: -geo.coverPad),
                                     cornerWidth: geo.coverPad * 2, cornerHeight: geo.coverPad * 2, transform: nil))
                }
            }
            for c in geo.cases where c.group == g {
                fill(ctx, CGPath(roundedRect: c.rect, cornerWidth: c.radius, cornerHeight: c.radius, transform: nil))
            }
        }
        ctx.endTransparencyLayer()
        ctx.restoreGState()

        let frosted = geo.covers.filter { $0.color == nil }
        if !frosted.isEmpty {
            ctx.saveGState()
            ctx.setAlpha(0.5)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            ctx.setFillColor(NSColor(white: 0.84, alpha: 1).cgColor)
            for c in frosted {
                fill(ctx, CGPath(roundedRect: c.rect, cornerWidth: u * 0.1, cornerHeight: u * 0.1, transform: nil))
            }
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        }
        for c in geo.covers {
            guard let hex = c.color, let fillColor = NSColor(hex: hex) else { continue }
            ctx.setFillColor(fillColor.cgColor)
            fill(ctx, CGPath(roundedRect: c.rect, cornerWidth: c.radius, cornerHeight: c.radius, transform: nil))
        }

        for g in geo.groups {
            ctx.setFillColor(color(layout.style(g).plate, "#1b1b1c").cgColor)
            for k in geo.keys where k.group == g { fill(ctx, k.path(inflate: u * 0.04, radius: u * 0.08)) }
        }

        for j in geo.encoders.indices { drawEncoder(ctx, j) }
        for i in geo.keys.indices { drawKey(ctx, i) }
        drawDisplays(ctx)
        drawLeds(ctx)
        drawIndicator(ctx)
        drawClose(ctx)
        drawDebugOutlines(ctx)
    }

    // MARK: Photo skin

    private func drawSkin(_ ctx: CGContext, _ skin: BoardGeometry.SkinShape) {
        ctx.saveGState()
        ctx.translateBy(x: skin.rect.minX, y: skin.rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .high
        ctx.draw(skin.image.image, in: CGRect(origin: .zero, size: skin.rect.size))
        ctx.restoreGState()
    }

    private func skin(for group: String) -> BoardGeometry.SkinShape? {
        geo.skins.first { $0.group == group }
    }

    private func drawPhoto(_ ctx: CGContext) {
        let u = geo.unit
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -u * 0.06), blur: u * 0.3,
                      color: NSColor.black.withAlphaComponent(0.45).cgColor)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for sk in geo.skins { drawSkin(ctx, sk) }
        ctx.endTransparencyLayer()
        ctx.restoreGState()

        for j in geo.encoders.indices { drawPhotoEncoder(ctx, j) }
        for i in geo.keys.indices { drawPhotoKey(ctx, i) }
        drawDisplays(ctx)
        drawLeds(ctx)
        drawIndicator(ctx)
        drawClose(ctx)
        drawDebugOutlines(ctx)
    }

    private func drawPhotoEncoder(_ ctx: CGContext, _ j: Int) {
        let e = geo.encoders[j]
        guard let sk = skin(for: e.group) else { return }
        let angle = engine.encoderAngles[j] ?? 0
        let pressed = engine.virtualEncoders.contains(j) || engine.physicalEncoders.contains(j)
        if let rect = e.rollerRect, let size = e.roller {
            guard angle != 0 || pressed else { return }
            drawRoller(ctx, rect: rect, size: size, angle: angle, pressed: pressed) { ctx in drawSkin(ctx, sk) }
            return
        }
        guard angle != 0 || pressed else { return }
        let r = e.radius * 0.97
        let circle = CGRect(x: e.center.x - r, y: e.center.y - r, width: 2 * r, height: 2 * r)
        ctx.saveGState()
        ctx.addEllipse(in: circle)
        ctx.clip()
        ctx.translateBy(x: e.center.x, y: e.center.y)
        ctx.rotate(by: angle)
        if pressed { ctx.scaleBy(x: 0.95, y: 0.95) }
        ctx.translateBy(x: -e.center.x, y: -e.center.y)
        drawSkin(ctx, sk)
        ctx.restoreGState()
        if pressed {
            ctx.setStrokeColor(physicalAccent.cgColor)
            ctx.setLineWidth(max(1.5, geo.unit * 0.04))
            ctx.strokeEllipse(in: circle.insetBy(dx: 1, dy: 1))
        }
    }

    private func drawPhotoKey(_ ctx: CGContext, _ i: Int) {
        let k = geo.keys[i]
        let u = geo.unit
        let layer = engine.displayLayer
        let action = engine.action(for: i, layer: layer)
        let physical = engine.physicalKeys.contains(i)
        let virtual = engine.virtualKeys.contains(i)
        var latch: KeyboardEngine.Latch?
        switch action {
        case .modifier(let m): latch = engine.latched[m]
        case .layer(let n, _):
            if engine.oneShotLayer == n { latch = .oneShot }
            if engine.lockedLayer == n { latch = .locked }
        default: break
        }
        let down = physical || virtual
        let (cap, _) = capShape(k)
        let style = engine.layout.style(k.group)

        ctx.saveGState()
        ctx.concatenate(k.transform)

        let d = depth(i)
        // The colour fades in with the key's travel and out again on release
        let strength = max(down || latch != nil ? 1 : 0, min(1, max(d, 0)))
        if strength > 0.01 {
            // Colour the whole key cell, which sits exactly on the photo's key wherever the cap leans
            let accent = down ? (physical ? physicalAccent : virtualAccent) : (latch != nil ? virtualAccent : travelAccent(i) ?? virtualAccent)
            let lw = max(1.5, u * 0.03)
            // Out to the cell's sides and bottom (further where the cap leans past them), but the top stops
            // at the cap's own top edge, which sits below the cell's in a photo taken from above
            let c = capInsets(k)
            let area = k.outline(left: min(-u * 0.005, c.l - u * 0.012), top: max(0, c.t - u * 0.008),
                                 right: min(-u * 0.005, c.r - u * 0.012), bottom: min(-u * 0.005, c.b - u * 0.012),
                                 radius: u * 0.07)
            ctx.setFillColor(accent.withAlphaComponent((latch == .locked && !down ? 0.42 : 0.55) * strength).cgColor)
            fill(ctx, area)
            ctx.setStrokeColor(accent.withAlphaComponent(strength).cgColor)
            ctx.setLineWidth(lw)
            ctx.setLineJoin(.round)
            ctx.addPath(area)
            ctx.strokePath()
        }

        let spec = engine.layout.keys[i]
        let printed = engine.layout.file.skinLegends == true
        var differs = layer == 0 ? spec.remap == true : action != engine.action(for: i, layer: 0)
        // A layer shown only because a physical key lives there relabels just the keys being pressed
        if engine.previewLayer == layer, layer != 0, !down { differs = false }
        if legends, !printed || differs {
            let base = color(spec.legend ?? style.legend, "#333333")
            let legend = down ? NSColor.white : base.withAlphaComponent(0.9)
            let top = CGRect(x: cap.minX + u * 0.1, y: cap.minY + u * 0.08 + u * 0.022 * max(d, 0),
                             width: cap.width - u * 0.2, height: cap.height - u * 0.24)
            let wiped = layer == 0 && spec.remap == true && engine.layout.file.remapCleaned == true
            if printed, !wiped {
                // Cover the printed legend so the remapped one reads cleanly
                let plate = color(spec.color ?? style.keyTop, "#f2f2f2")
                ctx.setFillColor((down ? plate.shadow(withLevel: 0.25) ?? plate : plate).cgColor)
                fill(ctx, CGPath(roundedRect: top.insetBy(dx: -u * 0.03, dy: -u * 0.03),
                                 cornerWidth: u * 0.12, cornerHeight: u * 0.12, transform: nil))
            }
            drawLabel(label(for: i, action: action, layer: layer), in: top, color: legend)
        }
        ctx.restoreGState()
    }

    /// Keycap silhouette insets (left, top, right, bottom) and corner radius, from the layout's measured cap profile.
    private func capInsets(_ k: BoardGeometry.KeyShape? = nil) -> (l: CGFloat, t: CGFloat, r: CGFloat, b: CGFloat, radius: CGFloat) {
        let p = engine.layout.file.cap
        let ins = k?.cap.flatMap { $0.count == 4 ? $0 : nil } ?? p?.inset ?? [0.025, 0.025, 0.025, 0.025]
        let u = geo.unit, uh = geo.unitH
        return (CGFloat(ins[0]) * u, CGFloat(ins[min(1, ins.count - 1)]) * uh,
                CGFloat(ins[min(2, ins.count - 1)]) * u, CGFloat(ins[min(3, ins.count - 1)]) * uh,
                CGFloat(p?.radius ?? 0.2) * u)
    }

    /// Main keycap rectangle (for legends) and corner radius in key-local coordinates.
    private func capShape(_ k: BoardGeometry.KeyShape) -> (CGRect, CGFloat) {
        let c = capInsets(k)
        let rect = CGRect(x: -k.size.width / 2 + c.l, y: -k.size.height / 2 + c.t,
                          width: k.size.width - c.l - c.r, height: k.size.height - c.t - c.b)
        return (rect, min(c.radius, rect.width / 2, rect.height / 2))
    }

    /// Full keycap outline (stepped keys included), grown by `grow` on every side.
    private func capOutline(_ k: BoardGeometry.KeyShape, grow: CGFloat = 0, radius: CGFloat? = nil) -> CGPath {
        let c = capInsets(k)
        return k.outline(left: c.l - grow, top: c.t - grow, right: c.r - grow, bottom: c.b - grow,
                         radius: max(0, radius ?? (c.radius + grow)))
    }

    private func fill(_ ctx: CGContext, _ path: CGPath) {
        ctx.addPath(path)
        ctx.fillPath()
    }

    private func drawKey(_ ctx: CGContext, _ i: Int) {
        let k = geo.keys[i]
        let spec = engine.layout.keys[i]
        let style = engine.layout.style(k.group)
        let u = geo.unit
        let layer = engine.displayLayer
        let action = engine.action(for: i, layer: layer)

        let physical = engine.physicalKeys.contains(i)
        let virtual = engine.virtualKeys.contains(i)
        var latch: KeyboardEngine.Latch?
        switch action {
        case .modifier(let m): latch = engine.latched[m]
        case .layer(let n, _):
            if engine.oneShotLayer == n { latch = .oneShot }
            if engine.lockedLayer == n { latch = .locked }
        default: break
        }
        let d = depth(i)
        let sink = max(d, 0)

        ctx.saveGState()
        ctx.concatenate(k.transform)

        let g = u * 0.045
        let cap = CGRect(x: -k.size.width / 2 + g, y: -k.size.height / 2 + g,
                         width: k.size.width - 2 * g, height: k.size.height - 2 * g)
        let capPath = k.outline(inset: g, radius: u * 0.17)
        let side = spec.color.flatMap { NSColor(hex: $0)?.shadow(withLevel: 0.12) } ?? color(style.key, "#d8d8d8")
        let top = spec.color.flatMap { NSColor(hex: $0) } ?? color(style.keyTop, "#ececec")

        ctx.saveGState()
        if sink < 0.98 {
            ctx.setShadow(offset: CGSize(width: 0, height: -u * 0.03 * (1 - sink)), blur: u * 0.06 * (1 - sink * 0.7),
                          color: NSColor.black.withAlphaComponent(0.45 * (1 - sink)).cgColor)
        }
        ctx.setFillColor(side.cgColor)
        fill(ctx, capPath)
        ctx.restoreGState()

        let press = u * 0.045 * d
        let inset = u * 0.09
        let topRect = CGRect(x: cap.minX + inset, y: cap.minY + u * 0.05 + press,
                             width: cap.width - 2 * inset, height: cap.height - u * 0.18)
        let topPath = k.outline(left: g + inset, top: g + u * 0.05 + press, right: g + inset,
                                bottom: g + u * 0.13 - press, radius: u * 0.13)
        let topBounds = topPath.boundingBoxOfPath
        if let grad = CGGradient(colorsSpace: nil, colors: [top.highlight(withLevel: 0.12)!.cgColor, top.cgColor] as CFArray,
                                 locations: [0, 1]) {
            ctx.saveGState()
            ctx.addPath(topPath)
            ctx.clip()
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: topBounds.minY), end: CGPoint(x: 0, y: topBounds.maxY), options: [])
            ctx.restoreGState()
        }

        var accent: NSColor?
        if physical { accent = physicalAccent } else if virtual || latch == .locked { accent = virtualAccent }
        if let accent {
            ctx.setFillColor(accent.withAlphaComponent(physical || virtual ? 0.6 * max(sink, 0.35) : 0.35).cgColor)
            fill(ctx, capPath)
        } else if sink > 0.01, let fading = travelAccent(i) {
            ctx.setFillColor(fading.withAlphaComponent(0.6 * sink).cgColor)
            fill(ctx, capPath)
        }
        if latch != nil || physical {
            ctx.setStrokeColor((physical ? physicalAccent : virtualAccent).cgColor)
            ctx.setLineWidth(max(1.5, u * 0.045))
            ctx.addPath(k.outline(inset: g + u * 0.02, radius: u * 0.15))
            ctx.strokePath()
        }

        let legend = accent != nil ? NSColor.white : color(spec.legend ?? style.legend, "#333333")
        if legends { drawLabel(label(for: i, action: action, layer: layer), in: topRect, color: legend) }

        if spec.homing == true {
            ctx.setFillColor(legend.withAlphaComponent(0.45).cgColor)
            let r = u * 0.022, y = topRect.maxY - u * 0.1
            for dx in [-1.0, 0, 1.0] {
                ctx.fillEllipse(in: CGRect(x: topRect.midX + dx * u * 0.07 - r, y: y - r, width: 2 * r, height: 2 * r))
            }
        }

        ctx.restoreGState()
    }

    private func label(for i: Int, action: KeyAction, layer: Int) -> KeyLabel {
        if let custom = engine.layout.customLabel(key: i, layer: layer) { return .text(custom) }
        let shift = engine.shiftActive
        switch action {
        case .noop:
            return .text("")
        case .modifier(let m):
            return .text(m.symbol)
        case .layer(let n, _):
            return .text(engine.layout.layerShort(n))
        case .media(let k):
            return .symbol(k.symbolName)
        case .key(let code, let mods):
            if mods.isEmpty {
                guard KeyCodes.printable.contains(code) else { return .text(KeyCodes.name(for: code)) }
                var s = labels.character(for: code, shift: shift) ?? KeyCodes.fallbackChars[code] ?? KeyCodes.name(for: code)
                if engine.capsLock, !shift { s = s.uppercased() }
                return .text(s)
            }
            if mods.allSatisfy({ $0.kind == .lshift }), KeyCodes.printable.contains(code),
               let c = labels.character(for: code, shift: true) {
                return .text(c)
            }
            let prefix = mods.sorted { $0.sortOrder < $1.sortOrder }.map(\.symbol).joined()
            let base = KeyCodes.printable.contains(code)
                ? (labels.character(for: code, shift: false) ?? KeyCodes.name(for: code)).uppercased()
                : KeyCodes.name(for: code)
            return .text(prefix + base)
        }
    }

    private func drawLabel(_ label: KeyLabel, in rect: CGRect, color: NSColor) {
        let u = geo.unit
        switch label {
        case .text(let s):
            guard !s.isEmpty else { return }
            let size: CGFloat = s.count <= 1 ? u * 0.3 : (s.count <= 3 ? u * 0.22 : u * 0.17)
            let font = NSFont.systemFont(ofSize: size, weight: .medium)
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            para.lineBreakMode = .byClipping
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
            let str = NSAttributedString(string: s, attributes: attrs)
            let h = str.size().height
            str.draw(in: CGRect(x: rect.minX, y: rect.midY - h / 2 - u * 0.02, width: rect.width, height: h))
        case .symbol(let name):
            let config = NSImage.SymbolConfiguration(pointSize: u * 0.24, weight: .medium)
                .applying(.init(paletteColors: [color]))
            guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) else { return }
            let s = img.size
            img.draw(in: CGRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2 - u * 0.02, width: s.width, height: s.height),
                     from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }

    /// A wheel seen from above: its surface (from the photo, or drawn knurls) slides across the short side,
    /// wrapping around, with cylinder shading so the seam stays hidden at the edges.
    private func drawRoller(_ ctx: CGContext, rect: CGRect, size: CGSize, angle: CGFloat, pressed: Bool,
                            surface: (CGContext) -> Void) {
        let vertical = size.width >= size.height
        let span = vertical ? size.height : size.width
        // Only the middle of the wheel is repeated: its shaded rims would show as seams
        let band = vertical ? rect.insetBy(dx: 0, dy: span * 0.25) : rect.insetBy(dx: span * 0.25, dy: 0)
        let period = span * 0.5
        let travel = (angle / (.pi / 8)) * span * 0.28
        let offset = travel - (travel / period).rounded(.down) * period
        let clip = CGPath(roundedRect: rect, cornerWidth: min(size.width, size.height) * 0.3,
                          cornerHeight: min(size.width, size.height) * 0.3, transform: nil)
        ctx.saveGState()
        ctx.addPath(clip)
        ctx.clip()
        for i in -1...3 {
            let start = (vertical ? rect.minY : rect.minX) + offset + CGFloat(i - 1) * period
            let shift = start - (vertical ? band.minY : band.minX)
            ctx.saveGState()
            ctx.translateBy(x: vertical ? 0 : shift, y: vertical ? shift : 0)
            ctx.addRect(band)
            ctx.clip()
            surface(ctx)
            ctx.restoreGState()
        }
        let shade = [NSColor.black.withAlphaComponent(0.45), NSColor.black.withAlphaComponent(0),
                     NSColor.black.withAlphaComponent(0), NSColor.black.withAlphaComponent(0.45)].map(\.cgColor)
        if let g = CGGradient(colorsSpace: nil, colors: shade as CFArray, locations: [0, 0.3, 0.7, 1]) {
            let a = vertical ? CGPoint(x: rect.midX, y: rect.minY) : CGPoint(x: rect.minX, y: rect.midY)
            let b = vertical ? CGPoint(x: rect.midX, y: rect.maxY) : CGPoint(x: rect.maxX, y: rect.midY)
            ctx.drawLinearGradient(g, start: a, end: b, options: [])
        }
        ctx.restoreGState()
        if pressed {
            ctx.setStrokeColor(physicalAccent.cgColor)
            ctx.setLineWidth(max(1.5, geo.unit * 0.04))
            ctx.addPath(clip)
            ctx.strokePath()
        }
    }

    private func drawEncoder(_ ctx: CGContext, _ j: Int) {
        let e = geo.encoders[j]
        let spec = engine.layout.encoders[j]
        if let rect = e.rollerRect, let size = e.roller {
            let pressed = engine.virtualEncoders.contains(j) || engine.physicalEncoders.contains(j)
            let silver = (spec.style ?? "black") == "silver"
            drawRoller(ctx, rect: rect, size: size, angle: engine.encoderAngles[j] ?? 0, pressed: pressed) { ctx in
                ctx.setFillColor((silver ? NSColor(white: 0.72, alpha: 1) : NSColor(white: 0.12, alpha: 1)).cgColor)
                ctx.fill(rect.insetBy(dx: -size.width, dy: -size.height))
                ctx.setStrokeColor((silver ? NSColor(white: 0.5, alpha: 1) : NSColor(white: 0.3, alpha: 1)).cgColor)
                ctx.setLineWidth(max(1, geo.unit * 0.015))
                let vertical = size.width >= size.height
                let step = (vertical ? size.height : size.width) / 6
                for i in -12...12 {
                    let d = CGFloat(i) * step
                    if vertical {
                        ctx.move(to: CGPoint(x: rect.minX, y: rect.midY + d))
                        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + d))
                    } else {
                        ctx.move(to: CGPoint(x: rect.midX + d, y: rect.minY))
                        ctx.addLine(to: CGPoint(x: rect.midX + d, y: rect.maxY))
                    }
                }
                ctx.strokePath()
            }
            return
        }
        let silver = (spec.style ?? "black") == "silver"
        let pressed = engine.virtualEncoders.contains(j) || engine.physicalEncoders.contains(j)
        let r = e.radius * (pressed ? 0.94 : 1)
        let rect = CGRect(x: e.center.x - r, y: e.center.y - r, width: 2 * r, height: 2 * r)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -geo.unit * 0.03), blur: geo.unit * 0.08,
                      color: NSColor.black.withAlphaComponent(0.5).cgColor)
        ctx.setFillColor((silver ? NSColor(white: 0.62, alpha: 1) : NSColor(white: 0.06, alpha: 1)).cgColor)
        ctx.fillEllipse(in: rect)
        ctx.restoreGState()

        let inner = silver ? [NSColor(white: 0.86, alpha: 1), NSColor(white: 0.7, alpha: 1)]
                           : [NSColor(white: 0.2, alpha: 1), NSColor(white: 0.08, alpha: 1)]
        if let grad = CGGradient(colorsSpace: nil, colors: inner.map(\.cgColor) as CFArray, locations: [0, 1]) {
            ctx.saveGState()
            ctx.addEllipse(in: rect.insetBy(dx: r * 0.06, dy: r * 0.06))
            ctx.clip()
            ctx.drawRadialGradient(grad, startCenter: CGPoint(x: e.center.x - r * 0.25, y: e.center.y - r * 0.3), startRadius: 0,
                                   endCenter: e.center, endRadius: r, options: [.drawsAfterEndLocation])
            ctx.restoreGState()
        }

        let a = (engine.encoderAngles[j] ?? 0) - .pi / 2
        ctx.setStrokeColor((silver ? NSColor(white: 0.35, alpha: 1) : NSColor(white: 0.75, alpha: 1)).cgColor)
        ctx.setLineWidth(max(1.5, geo.unit * 0.04))
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: e.center.x + cos(a) * r * 0.5, y: e.center.y + sin(a) * r * 0.5))
        ctx.addLine(to: CGPoint(x: e.center.x + cos(a) * r * 0.82, y: e.center.y + sin(a) * r * 0.82))
        ctx.strokePath()

        if pressed {
            ctx.setStrokeColor(physicalAccent.cgColor)
            ctx.setLineWidth(max(1.5, geo.unit * 0.04))
            ctx.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
        }
    }

    private func drawIndicator(_ ctx: CGContext) {
        let layout = engine.layout
        guard engine.displayLayer != 0 else { return }
        var parts: [String] = []
        if engine.displayLayer != 0 {
            parts.append(layout.layerShort(engine.displayLayer))
            if engine.lockedLayer != nil, engine.previewLayer == nil { parts.append("•") }
        }
        let text = parts.joined(separator: " ")
        let u = geo.unit
        let font = NSFont.systemFont(ofSize: u * 0.19, weight: .semibold)
        let str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white])
        let s = str.size()
        let pill = CGRect(x: geo.contentRect.midX - s.width / 2 - u * 0.12, y: geo.contentRect.minY + u * 0.05,
                          width: s.width + u * 0.24, height: s.height + u * 0.06)
        let active = engine.displayLayer != 0
        ctx.setFillColor((active ? virtualAccent : NSColor(white: 0.15, alpha: 0.85)).cgColor)
        fill(ctx, CGPath(roundedRect: pill, cornerWidth: pill.height / 2, cornerHeight: pill.height / 2, transform: nil))
        str.draw(at: CGPoint(x: pill.minX + u * 0.12, y: pill.minY + u * 0.03))
    }

    // MARK: Indicator lights

    private func ledOn(_ kind: String) -> Bool {
        switch kind {
        case "caps": engine.capsLock
        case "power": true
        default: false
        }
    }

    /// Lit indicators: a glowing light where the board has one, else the caps key's own cap glows.
    private func drawLeds(_ ctx: CGContext) {
        var leds = engine.layout.leds
        if !leds.contains(where: { $0.kind == "caps" }) { leds.append(LedSpec(kind: "caps", key: "capslock")) }
        for (rect, spec) in geo.leds where ledOn(spec.kind) {
            drawLight(ctx, rect: rect, color: color(spec.color, "#ffffff"))
        }
        for spec in leds where spec.key != nil && ledOn(spec.kind) {
            guard let code = KeyCodes.byName[spec.key ?? ""] else { continue }
            let glow = spec.style == "glow"
            let tint = color(spec.color, glow ? "#ffffff" : "#3be05a")
            for i in geo.keys.indices {
                guard case .key(code, _) = engine.action(for: i, layer: 0) else { continue }
                let k = geo.keys[i]
                ctx.saveGState()
                ctx.concatenate(k.transform)
                ctx.translateBy(x: 0, y: depth(i) * geo.unit * 0.05)
                if glow {
                    ctx.addPath(capOutline(k))
                    ctx.setFillColor(tint.withAlphaComponent(0.28).cgColor)
                    ctx.setShadow(offset: .zero, blur: geo.unit * 0.25, color: tint.withAlphaComponent(0.9).cgColor)
                    ctx.fillPath()
                } else {
                    let (cap, _) = capShape(k)
                    let d = geo.unit * 0.07
                    drawLight(ctx, rect: CGRect(x: cap.maxX - geo.unit * 0.16 - d / 2, y: cap.minY + geo.unit * 0.14 - d / 2,
                                                width: d, height: d), color: tint)
                }
                ctx.restoreGState()
            }
        }
    }

    private func drawLight(_ ctx: CGContext, rect: CGRect, color c: NSColor) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let glow = max(rect.width, rect.height) * 1.8 + geo.unit * 0.04
        ctx.saveGState()
        let colors = [c.withAlphaComponent(0.6).cgColor, c.withAlphaComponent(0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: glow, options: [])
        }
        let r = min(rect.width, rect.height) / 2
        ctx.setFillColor(c.cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.fillPath()
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.7).cgColor)
        let core = rect.insetBy(dx: rect.width * 0.28, dy: rect.height * 0.28)
        ctx.addPath(CGPath(roundedRect: core, cornerWidth: min(core.width, core.height) / 2,
                           cornerHeight: min(core.width, core.height) / 2, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
    }

    private func color(_ hex: String?, _ fallback: String) -> NSColor {
        NSColor(hex: hex ?? fallback) ?? NSColor(hex: fallback)!
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let a = s.count == 8 ? CGFloat(v & 0xFF) / 255 : 1
        let rgb = s.count == 8 ? v >> 8 : v
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: a)
    }
}

/// Clock strings in the user's locale and 12/24-hour preference.
final class ClockFormat {
    static let shared = ClockFormat()
    private var cache: [String: DateFormatter] = [:]
    private var is24h: Bool?

    func reset() {
        cache.removeAll()
        is24h = nil
    }

    var uses24h: Bool {
        if let v = is24h { return v }
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .autoupdatingCurrent) ?? ""
        let v = !pattern.contains("a")
        is24h = v
        return v
    }

    func text(_ format: String, _ date: Date) -> String? {
        switch format {
        case "time": return formatter(uses24h ? "HH:mm" : "h:mm").string(from: date)
        case "hour": return formatter(uses24h ? "HH" : "hh").string(from: date)
        case "minute": return formatter("mm").string(from: date)
        case "ampm": return uses24h ? nil : formatter("a").string(from: date).lowercased()
        case "date":
            let pattern = DateFormatter.dateFormat(fromTemplate: "EEEMMMd", options: 0, locale: .autoupdatingCurrent) ?? "EEE, MMM d"
            return formatter(pattern).string(from: date)
        default: return nil
        }
    }

    private func formatter(_ pattern: String) -> DateFormatter {
        if let f = cache[pattern] { return f }
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = pattern
        cache[pattern] = f
        return f
    }

    static func weight(_ name: String?) -> NSFont.Weight {
        switch name {
        case "ultralight": .ultraLight
        case "thin": .thin
        case "light": .light
        case "medium": .medium
        case "semibold": .semibold
        case "bold": .bold
        default: .regular
        }
    }
}
