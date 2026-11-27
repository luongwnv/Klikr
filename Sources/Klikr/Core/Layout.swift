import CoreGraphics
import Foundation
import ImageIO

struct LayoutSpacing: Codable { var x: Double; var y: Double }

struct LayerInfo: Codable { var name: String; var short: String? }

struct GroupStyle: Codable {
    var key: String?
    var keyTop: String?
    var legend: String?
    var `case`: String?
    var plate: String?
    var splitShift: Double?
}

struct KeySpec: Codable {
    var id: String
    var group: String?
    var x: Double
    var y: Double
    var w: Double?
    var h: Double?
    /// Second rectangle for stepped keys such as ISO Enter (KLE x2/y2/w2/h2, relative to x/y).
    var x2: Double?
    var y2: Double?
    var w2: Double?
    var h2: Double?
    var r: Double?
    var homing: Bool?
    var actions: [String?]?
    var labels: [String?]?
    var color: String?
    var legend: String?
    /// Printed legend on the skin photo does not match this key's function.
    var remap: Bool?
}

/// Encoder x/y is the knob center, not its top-left corner.
struct EncoderSpec: Codable {
    var id: String
    var group: String?
    var x: Double
    var y: Double
    var d: Double?
    var style: String?
    var ccw: String?
    var cw: String?
    var press: String?
}

/// Rectangle in layout units: frosted cover, or an opaque panel (screen, controller) when `color` is set.
struct CoverSpec: Codable {
    var group: String?
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var color: String?
    var r: Double?
}

/// Photo of one group, placed at x/y/w/h in layout units. Image path is relative to the layout file.
/// One line of a live screen. y is the cap-height midline and size the font size, as fractions of the screen height.
/// format: time, date, hour, minute, ampm (follows the system 12/24-hour setting and locale).
struct DisplayLine: Codable {
    var format: String
    var size: Double
    var y: Double
    var x: Double?
    var align: String?
    var color: String?
    var weight: String?
}

/// Indicator light printed on the board, lit from live state. Either a light at (x, y) of size w x h
/// (layout units, centre), or with `key` set, the glow of that key's cap (per-key RGB boards).
struct LedSpec: Codable, Hashable {
    var group: String?
    var kind: String
    var x: Double?
    var y: Double?
    var w: Double?
    var h: Double?
    var key: String?
    /// With `key`: "glow" lights the whole cap (per-key RGB boards), otherwise a small light sits in its corner.
    var style: String?
    var color: String?
}

/// Screen area in layout units that shows the live system clock.
struct DisplaySpec: Codable {
    var group: String?
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var lines: [DisplayLine]
}

/// Keycap silhouette in the skin photo: insets from the key cell [left, top, right, bottom] and corner radius, in key units.
struct CapProfile: Codable {
    var inset: [Double]?
    var radius: Double?
}

struct SkinSpec: Codable, Hashable {
    var group: String?
    var image: String
    var x: Double
    var y: Double
    var w: Double
    var h: Double
}

/// The same board photographed in another colour; its skins replace the default ones.
struct ColorwaySpec: Codable, Hashable {
    var id: String
    var name: String
    var swatch: String?
    var skins: [SkinSpec]
    /// Indicator lights measured on this colourway's photo, when they sit differently from the default one.
    var leds: [LedSpec]?
}

struct LayoutFile: Codable {
    var name: String
    var spacing: LayoutSpacing?
    var layers: [LayerInfo]?
    var groups: [String: GroupStyle]?
    var keys: [KeySpec]
    var encoders: [EncoderSpec]?
    var covers: [CoverSpec]?
    var cases: [CoverSpec]?
    var skins: [SkinSpec]?
    var colorways: [ColorwaySpec]?
    /// The skin photo already shows legends, so base-layer labels are not drawn over it.
    var skinLegends: Bool?
    /// Printed legends of remapped keys were wiped off the skin, so their labels need no cover.
    var remapCleaned: Bool?
    var displays: [DisplaySpec]?
    var leds: [LedSpec]?
    var cap: CapProfile?
}

struct EncoderActions {
    var ccw: KeyAction?
    var cw: KeyAction?
    var press: KeyAction?
}

struct Layout {
    let id: String
    let file: LayoutFile
    let keyActions: [[KeyAction?]]
    let encoderActions: [EncoderActions]
    let skinImages: [SkinImage?]
    private let directory: URL?

    init(id: String, file: LayoutFile, directory: URL? = nil) {
        self.id = id
        self.file = file
        self.directory = directory
        skinImages = (file.skins ?? []).map { spec in
            directory.flatMap { SkinImage(url: $0.appendingPathComponent(spec.image)) }
        }
        keyActions = file.keys.map { ($0.actions ?? []).map(KeyAction.parse) }
        encoderActions = (file.encoders ?? []).map {
            EncoderActions(ccw: KeyAction.parse($0.ccw), cw: KeyAction.parse($0.cw), press: KeyAction.parse($0.press))
        }
    }

    var name: String { file.name }
    var keys: [KeySpec] { file.keys }
    var encoders: [EncoderSpec] { file.encoders ?? [] }
    var covers: [CoverSpec] { file.covers ?? [] }
    var skins: [SkinSpec] { file.skins ?? [] }
    var cases: [CoverSpec] { file.cases ?? [] }
    var displays: [DisplaySpec] { file.displays ?? [] }
    var leds: [LedSpec] { file.leds ?? [] }
    var hasSkin: Bool { skinImages.contains { $0 != nil } }
    var colorways: [ColorwaySpec] { file.colorways ?? [] }
    /// Colourway whose photos are currently loaded (the first one unless switched).
    var colorwayID: String? { colorways.first { $0.skins == skins }?.id }

    /// Same layout showing another colourway's photos; self when the id is unknown or already active.
    func withColorway(_ id: String?) -> Layout {
        guard let id, id != colorwayID, let cw = colorways.first(where: { $0.id == id }) else { return self }
        var f = file
        f.skins = cw.skins
        if let leds = cw.leds { f.leds = leds }
        return Layout(id: self.id, file: f, directory: directory)
    }

    var layerCount: Int {
        max(file.layers?.count ?? 1, keyActions.map(\.count).max() ?? 1, 1)
    }

    func layerShort(_ n: Int) -> String {
        guard let layers = file.layers, n < layers.count else { return "L\(n)" }
        return layers[n].short ?? layers[n].name
    }

    func style(_ group: String?) -> GroupStyle {
        file.groups?[group ?? ""] ?? GroupStyle()
    }

    func customLabel(key: Int, layer: Int) -> String? {
        guard let labels = keys[key].labels, layer < labels.count else { return nil }
        return labels[layer]
    }
}

enum LayoutStore {
    static var userDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Klikr/layouts", isDirectory: true)
    }

    /// Custom layouts saved while the app was still called Keyfun.
    static var legacyUserDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Keyfun/layouts", isDirectory: true)
    }

    static func searchDirectories() -> [URL] {
        var dirs: [URL] = []
        if let r = Bundle.main.resourceURL { dirs.append(r.appendingPathComponent("layouts")) }
        dirs.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("layouts"))
        dirs.append(URL(fileURLWithPath: PreLogin.supportDir).appendingPathComponent("layouts"))
        dirs.append(legacyUserDirectory)
        dirs.append(userDirectory)
        return dirs
    }

    static func load() -> (layouts: [Layout], errors: [String]) {
        var byID: [String: Layout] = [:]
        var errors: [String] = []
        var seen = Set<String>()
        for dir in searchDirectories() {
            let std = dir.standardizedFileURL.path
            guard seen.insert(std).inserted else { continue }
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for url in files where url.pathExtension.lowercased() == "json" {
                do {
                    let file = try JSONDecoder().decode(LayoutFile.self, from: Data(contentsOf: url))
                    let id = url.deletingPathExtension().lastPathComponent
                    byID[id] = Layout(id: id, file: file, directory: url.deletingLastPathComponent())
                } catch {
                    errors.append("\(url.lastPathComponent): \(error)")
                }
            }
        }
        return (byID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, errors)
    }
}

/// Decoded skin photo plus a coarse alpha map used to hit-test the keyboard outline.
final class SkinImage {
    let image: CGImage
    private let alpha: [UInt8]
    private let aw: Int
    private let ah: Int

    init?(url: URL) {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        image = img
        let aw = max(1, img.width / 4), ah = max(1, img.height / 4)
        self.aw = aw
        self.ah = ah
        var rgba = [UInt8](repeating: 0, count: aw * ah * 4)
        rgba.withUnsafeMutableBytes { raw in
            if let ctx = CGContext(data: raw.baseAddress, width: aw, height: ah, bitsPerComponent: 8, bytesPerRow: aw * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                ctx.draw(img, in: CGRect(x: 0, y: 0, width: aw, height: ah))
            }
        }
        let buf = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
        alpha = buf
    }

    /// u, v in 0...1 from the image's top-left corner.
    func isOpaque(u: CGFloat, v: CGFloat) -> Bool {
        guard (0..<1).contains(u), (0..<1).contains(v) else { return false }
        // Bitmap memory stores the top row first
        let x = Int(u * CGFloat(aw)), y = Int(v * CGFloat(ah))
        return alpha[min(ah - 1, y) * aw + min(aw - 1, x)] > 127
    }
}
