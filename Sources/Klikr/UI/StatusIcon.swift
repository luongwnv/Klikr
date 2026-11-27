import AppKit
import CoreGraphics

/// Menu bar icon: one half of a column-staggered split keyboard with thumb cluster and controller.
enum StatusIcon {
    private struct Cap {
        var x: CGFloat
        var y: CGFloat
        var h: CGFloat = 1
        var angle: CGFloat = 0
    }

    private static let caps: [Cap] = {
        let stagger: [CGFloat] = [0.11, 0.22, 0.05, 0, 0.24, 0.46]
        var caps: [Cap] = []
        for (c, o) in stagger.enumerated() {
            for r in 0..<3 { caps.append(Cap(x: CGFloat(c), y: o + CGFloat(r))) }
        }
        caps.append(Cap(x: 3.3, y: 3.25))
        caps.append(Cap(x: 4.38, y: 3.42, angle: 12))
        caps.append(Cap(x: 5.5, y: 3.78, h: 1.25, angle: 30))
        return caps
    }()

    /// Menu bar icon: the real keyboard photo in grayscale (Support/MenuIcon*.png).
    static func image(height: CGFloat = 18) -> NSImage {
        bundled("MenuIcon", height: height, template: false) ?? drawn(height: height)
    }

    /// Single-colour version traced from the same photo, for tinted spots such as the settings header.
    static func template(height: CGFloat = 16) -> NSImage {
        bundled("MenuTemplate", height: height, template: true) ?? drawn(height: height)
    }

    private static func bundled(_ name: String, height: CGFloat, template: Bool) -> NSImage? {
        guard let img = Bundle.main.image(forResource: name), img.size.height > 0,
              let copy = img.copy() as? NSImage else { return nil }
        copy.size = NSSize(width: (img.size.width * height / img.size.height).rounded(), height: height)
        copy.isTemplate = template
        return copy
    }

    private static func drawn(height: CGFloat) -> NSImage {
        let minX: CGFloat = -0.55, minY: CGFloat = -0.55
        let unitsW: CGFloat = 7.4, unitsH: CGFloat = 5.0
        let u = height / unitsH
        let img = NSImage(size: NSSize(width: ceil(unitsW * u), height: height), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.scaleBy(x: u, y: u)
            ctx.translateBy(x: -minX, y: -minY)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setStrokeColor(NSColor.black.cgColor)

            for cap in caps {
                ctx.saveGState()
                ctx.translateBy(x: cap.x, y: cap.y)
                ctx.rotate(by: cap.angle * .pi / 180)
                let w: CGFloat = 0.84, h = cap.h - 0.16
                ctx.addPath(CGPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h),
                                   cornerWidth: 0.18, cornerHeight: 0.18, transform: nil))
                ctx.fillPath()
                ctx.restoreGState()
            }

            // Controller cover with its slanted lower edge, and the OLED inside it
            let mcu = CGMutablePath()
            mcu.move(to: CGPoint(x: 5.62, y: -0.05))
            mcu.addLine(to: CGPoint(x: 6.75, y: -0.05))
            mcu.addLine(to: CGPoint(x: 6.75, y: 2.9))
            mcu.addLine(to: CGPoint(x: 6.25, y: 3.35))
            mcu.addLine(to: CGPoint(x: 5.62, y: 2.55))
            mcu.closeSubpath()
            ctx.setLineWidth(0.22)
            ctx.setLineJoin(.round)
            ctx.addPath(mcu)
            ctx.strokePath()
            ctx.fill(CGRect(x: 5.95, y: 0.35, width: 0.45, height: 1.9))
            return true
        }
        img.isTemplate = true
        return img
    }
}

/// Status glyphs drawn on keyboard screens from live system state.
extension StatusIcon {
    static func isStatus(_ format: String) -> Bool {
        ["btdot", "bluetooth", "battery"].contains(format)
    }

    static func draw(_ line: DisplayLine, in rect: CGRect, ctx: CGContext, status: SystemStatus.Snapshot) {
        let h = rect.height * CGFloat(line.size)
        let cx = rect.minX + rect.width * CGFloat(line.x ?? 0.5)
        let cy = rect.minY + rect.height * CGFloat(line.y)
        let tint = NSColor(hex: line.color ?? "#ffffff") ?? .white
        ctx.saveGState()
        defer { ctx.restoreGState() }
        switch line.format {
        case "btdot":
            let color = status.keyboardConnected ? tint : NSColor(white: 0.55, alpha: 0.8)
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - h / 2, y: cy - h / 2, width: h, height: h))
        case "bluetooth":
            // Bluetooth rune: centre stem with two crossing chevrons
            let w = h * 0.5, top = cy - h / 2, bottom = cy + h / 2
            let left = cx - w / 2, right = cx + w / 2
            ctx.setStrokeColor(tint.withAlphaComponent(status.bluetoothOn ? 1 : 0.3).cgColor)
            ctx.setLineWidth(max(1, h * 0.11))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: CGPoint(x: left, y: top + h * 0.27))
            ctx.addLine(to: CGPoint(x: right, y: top + h * 0.73))
            ctx.addLine(to: CGPoint(x: cx, y: bottom))
            ctx.addLine(to: CGPoint(x: cx, y: top))
            ctx.addLine(to: CGPoint(x: right, y: top + h * 0.27))
            ctx.addLine(to: CGPoint(x: left, y: top + h * 0.73))
            ctx.strokePath()
        case "battery":
            guard let level = status.batteryLevel else { return }
            let bars = 5
            let barW = h * 0.32, gap = h * 0.24
            let total = CGFloat(bars) * barW + CGFloat(bars - 1) * gap
            var x: CGFloat
            switch line.align {
            case "right": x = cx - total
            case "left": x = cx
            default: x = cx - total / 2
            }
            let filled = max(1, Int((Double(level) / 100 * Double(bars)).rounded(.up)))
            let on: NSColor = level <= 20 ? .systemRed : (status.charging ? .systemGreen : tint)
            for i in 0..<bars {
                ctx.setFillColor((i < filled ? on : tint.withAlphaComponent(0.25)).cgColor)
                ctx.fill(CGRect(x: x, y: cy - h / 2, width: barW, height: h))
                x += barW + gap
            }
        default:
            break
        }
    }
}
