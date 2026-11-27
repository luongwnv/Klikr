import CoreGraphics

/// Pixel geometry for a layout at a given scale. Layout units: x in key pitch, y in key pitch scaled by spacing.y/spacing.x.
struct BoardGeometry {
    struct KeyShape {
        var center: CGPoint
        var size: CGSize
        var angle: CGFloat
        var group: String
        /// Extra rectangle in key-local coordinates (ISO Enter and other stepped keys).
        var secondary: CGRect? = nil

        var transform: CGAffineTransform {
            CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
        }

        var primary: CGRect { CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height) }

        /// Key-local outline shrunk by per-side insets (negative grows it); stepped keys merge both rectangles.
        func outline(left l: CGFloat, top t: CGFloat, right r: CGFloat, bottom b: CGFloat, radius: CGFloat) -> CGPath {
            let rects = [primary] + (secondary.map { [$0] } ?? [])
            let paths = rects.map { c -> CGPath in
                let rect = CGRect(x: c.minX + l, y: c.minY + t, width: c.width - l - r, height: c.height - t - b)
                let rr = max(0, min(radius, rect.width / 2, rect.height / 2))
                return CGPath(roundedRect: rect, cornerWidth: rr, cornerHeight: rr, transform: nil)
            }
            if paths.count == 1 { return paths[0] }
            if #available(macOS 14.0, *) { return paths.dropFirst().reduce(paths[0]) { $0.union($1) } }
            let m = CGMutablePath()
            paths.forEach { m.addPath($0) }
            return m
        }

        func outline(inset: CGFloat, radius: CGFloat) -> CGPath {
            outline(left: inset, top: inset, right: inset, bottom: inset, radius: radius)
        }

        func path(inflate: CGFloat, radius: CGFloat) -> CGPath {
            var t = transform
            return outline(inset: -inflate, radius: radius).copy(using: &t) ?? outline(inset: -inflate, radius: radius)
        }

        func contains(_ p: CGPoint) -> Bool {
            let l = p.applying(transform.inverted())
            if primary.contains(l) { return true }
            return secondary?.contains(l) ?? false
        }
    }

    struct EncoderShape {
        var center: CGPoint
        var radius: CGFloat
        var group: String
    }

    struct CoverShape {
        var rect: CGRect
        var group: String
        var color: String?
        var radius: CGFloat
    }

    struct SkinShape {
        var rect: CGRect
        var group: String
        var image: SkinImage
    }

    let unit: CGFloat
    let unitH: CGFloat
    var keys: [KeyShape] = []
    var encoders: [EncoderShape] = []
    var covers: [CoverShape] = []
    var cases: [CoverShape] = []
    var skins: [SkinShape] = []
    var displays: [(rect: CGRect, spec: DisplaySpec)] = []
    var leds: [(rect: CGRect, spec: LedSpec)] = []
    var groups: [String] = []
    var size: CGSize = .zero
    var contentRect: CGRect = .zero

    var casePad: CGFloat { unit * 0.3 }
    var coverPad: CGFloat { unit * 0.12 }

    init(layout: Layout, scale: CGFloat, splitGap: CGFloat) {
        unit = 54 * scale
        let sx = layout.file.spacing?.x ?? 19.05
        let sy = layout.file.spacing?.y ?? 19.05
        unitH = unit * CGFloat(sy / sx)

        func shift(_ g: String) -> CGFloat { CGFloat(layout.style(g).splitShift ?? 0) * splitGap }
        func note(_ g: String) { if !groups.contains(g) { groups.append(g) } }

        for k in layout.keys {
            let g = k.group ?? ""
            note(g)
            let w = CGFloat(k.w ?? 1), h = CGFloat(k.h ?? 1)
            var secondary: CGRect?
            if let w2 = k.w2, let h2 = k.h2 {
                secondary = CGRect(x: (CGFloat(k.x2 ?? 0) - w / 2) * unit, y: (CGFloat(k.y2 ?? 0) - h / 2) * unitH,
                                   width: CGFloat(w2) * unit, height: CGFloat(h2) * unitH)
            }
            keys.append(KeyShape(
                center: CGPoint(x: (CGFloat(k.x) + w / 2 + shift(g)) * unit, y: (CGFloat(k.y) + h / 2) * unitH),
                size: CGSize(width: w * unit, height: h * unitH),
                angle: CGFloat(k.r ?? 0) * .pi / 180, group: g, secondary: secondary))
        }
        for e in layout.encoders {
            let g = e.group ?? ""
            note(g)
            encoders.append(EncoderShape(
                center: CGPoint(x: (CGFloat(e.x) + shift(g)) * unit, y: CGFloat(e.y) * unitH),
                radius: CGFloat(e.d ?? 1) / 2 * unit, group: g))
        }
        func rect(_ c: CoverSpec) -> CoverShape {
            let g = c.group ?? layout.keys.first?.group ?? ""
            return CoverShape(
                rect: CGRect(x: (CGFloat(c.x) + shift(g)) * unit, y: CGFloat(c.y) * unitH,
                             width: CGFloat(c.w) * unit, height: CGFloat(c.h) * unitH),
                group: g, color: c.color, radius: CGFloat(c.r ?? 0.1) * unit)
        }
        covers = layout.covers.map(rect)
        cases = layout.cases.map(rect)

        for (spec, image) in zip(layout.skins, layout.skinImages) {
            guard let image else { continue }
            let g = spec.group ?? ""
            skins.append(SkinShape(
                rect: CGRect(x: (CGFloat(spec.x) + shift(g)) * unit, y: CGFloat(spec.y) * unitH,
                             width: CGFloat(spec.w) * unit, height: CGFloat(spec.h) * unitH), group: g, image: image))
        }

        for d in layout.displays {
            let g = d.group ?? layout.keys.first?.group ?? ""
            displays.append((CGRect(x: (CGFloat(d.x) + shift(g)) * unit, y: CGFloat(d.y) * unitH,
                                    width: CGFloat(d.w) * unit, height: CGFloat(d.h) * unitH), d))
        }

        for l in layout.leds {
            guard let x = l.x, let y = l.y else { continue }
            let g = l.group ?? layout.keys.first?.group ?? ""
            let w = CGFloat(l.w ?? 0.08), h = CGFloat(l.h ?? l.w ?? 0.08)
            leds.append((CGRect(x: (CGFloat(x) - w / 2 + shift(g)) * unit, y: (CGFloat(y) - h / 2) * unitH,
                                width: w * unit, height: h * unitH), l))
        }

        var box = CGRect.null
        for sk in skins { box = box.union(sk.rect) }
        let casedGroups = Set(cases.map(\.group))
        for k in keys {
            box = box.union(k.path(inflate: casedGroups.contains(k.group) ? 0 : casePad, radius: 0).boundingBoxOfPath)
        }
        for e in encoders {
            let r = e.radius + (casedGroups.contains(e.group) ? 0 : casePad)
            box = box.union(CGRect(x: e.center.x - r, y: e.center.y - r, width: 2 * r, height: 2 * r))
        }
        for c in covers {
            let pad = casedGroups.contains(c.group) ? 0 : coverPad
            box = box.union(c.rect.insetBy(dx: -pad, dy: -pad))
        }
        for c in cases { box = box.union(c.rect) }
        if box.isNull { box = CGRect(x: 0, y: 0, width: unit, height: unit) }

        let margin = unit * 0.3
        let dx = margin - box.minX, dy = margin - box.minY
        for i in keys.indices { keys[i].center.x += dx; keys[i].center.y += dy }
        for i in encoders.indices { encoders[i].center.x += dx; encoders[i].center.y += dy }
        for i in covers.indices { covers[i].rect = covers[i].rect.offsetBy(dx: dx, dy: dy) }
        for i in cases.indices { cases[i].rect = cases[i].rect.offsetBy(dx: dx, dy: dy) }
        for i in skins.indices { skins[i].rect = skins[i].rect.offsetBy(dx: dx, dy: dy) }
        for i in displays.indices { displays[i].rect = displays[i].rect.offsetBy(dx: dx, dy: dy) }
        for i in leds.indices { leds[i].rect = leds[i].rect.offsetBy(dx: dx, dy: dy) }
        size = CGSize(width: ceil(box.width + 2 * margin), height: ceil(box.height + 2 * margin))
        contentRect = CGRect(x: margin, y: margin, width: box.width, height: box.height)
    }

    func keyIndex(at p: CGPoint) -> Int? {
        keys.indices.reversed().first { keys[$0].contains(p) }
    }

    func encoderHit(at p: CGPoint) -> (Int, KeyboardEngine.EncoderPart)? {
        for (j, e) in encoders.enumerated() {
            let dx = p.x - e.center.x, dy = p.y - e.center.y
            let dist = (dx * dx + dy * dy).squareRoot()
            guard dist <= e.radius else { continue }
            if dist < e.radius * 0.38 { return (j, .press) }
            return (j, dx < 0 ? .ccw : .cw)
        }
        return nil
    }

    func caseContains(_ p: CGPoint, photo: Bool) -> Bool {
        if photo, !skins.isEmpty {
            return skins.contains { s in
                s.rect.contains(p) && s.image.isOpaque(u: (p.x - s.rect.minX) / s.rect.width, v: (p.y - s.rect.minY) / s.rect.height)
            }
        }
        let casedGroups = Set(cases.map(\.group))
        if keys.contains(where: { $0.path(inflate: casedGroups.contains($0.group) ? 0 : casePad, radius: casePad).contains(p) }) {
            return true
        }
        if encoders.contains(where: { hypot(p.x - $0.center.x, p.y - $0.center.y) <= $0.radius + casePad }) { return true }
        if cases.contains(where: { $0.rect.contains(p) }) { return true }
        return covers.contains { $0.rect.insetBy(dx: -coverPad, dy: -coverPad).contains(p) }
    }
}
