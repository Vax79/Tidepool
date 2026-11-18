import AppKit
import Carbon.HIToolbox

// MARK: - Colour variants and names

/// A recolouring of a species: hue rotation, saturation / brightness scaling,
/// and an optional multiply tint (for the grey animals, where hue does nothing).
struct Variant {
    let name: String
    var hue = 0.0
    var sat = 1.0
    var val = 1.0
    var tint: UInt32? = nil

    var isDefault: Bool { hue == 0 && sat == 1 && val == 1 && tint == nil }
}

extension Species {
    var variants: [Variant] {
        switch self {
        case .puffer:
            return [Variant(name: "Sunny"), Variant(name: "Tangerine", hue: -22),
                    Variant(name: "Lime", hue: 55), Variant(name: "Bubblegum", hue: -75)]
        case .octopus:
            return [Variant(name: "Coral"), Variant(name: "Grape", hue: -60),
                    Variant(name: "Teal", hue: 190), Variant(name: "Sunset", hue: 30)]
        case .jelly:
            return [Variant(name: "Lavender"), Variant(name: "Rose", hue: 70),
                    Variant(name: "Mint", hue: -100), Variant(name: "Peach", hue: 130)]
        case .crab:
            return [Variant(name: "Red"), Variant(name: "Blue", hue: -150),
                    Variant(name: "Golden", hue: 35), Variant(name: "Purple", hue: -90)]
        case .axolotl:
            return [Variant(name: "Pink"), Variant(name: "Golden", hue: 65, sat: 1.3),
                    Variant(name: "Lilac", hue: -70), Variant(name: "Mint", hue: 170)]
        case .turtle:
            return [Variant(name: "Green"), Variant(name: "Teal", hue: 50),
                    Variant(name: "Olive", hue: -45, sat: 0.9), Variant(name: "Blue", hue: 90)]
        case .shark:
            return [Variant(name: "Reef Grey"), Variant(name: "Blue", tint: 0x9CC0FF),
                    Variant(name: "Sand", tint: 0xF2D6A2), Variant(name: "Midnight", val: 0.62, tint: 0xB0B8E0)]
        case .dolphin:
            return [Variant(name: "Sky"), Variant(name: "Pink", hue: 120),
                    Variant(name: "Slate", sat: 0.35), Variant(name: "Seafoam", hue: -45)]
        case .seal:
            return [Variant(name: "Silver"), Variant(name: "Cocoa", tint: 0xD9B38C),
                    Variant(name: "Snow", sat: 0.5, val: 1.15), Variant(name: "Charcoal", val: 0.6)]
        case .whale:
            return [Variant(name: "Blue"), Variant(name: "Midnight", sat: 0.8, val: 0.55),
                    Variant(name: "Grey", sat: 0.3), Variant(name: "Violet", hue: 50)]
        case .clownfish:
            return [Variant(name: "Orange"), Variant(name: "Tomato", hue: -18),
                    Variant(name: "Gold", hue: 22), Variant(name: "Pink", hue: -50)]
        case .betta:
            return [Variant(name: "Royal"), Variant(name: "Ember", hue: 130),
                    Variant(name: "Emerald", hue: -90), Variant(name: "Twilight", hue: 40)]
        }
    }

    /// The main body colour, used for the swatches in the picker.
    var swatch: UInt32 {
        switch self {
        case .puffer: return 0xF7C64A
        case .octopus: return 0xF27F93
        case .jelly: return 0xC3B1FF
        case .crab: return 0xEC5B43
        case .axolotl: return 0xFFBFD0
        case .turtle: return 0x58A86C
        case .shark: return 0x7E97AD
        case .dolphin: return 0x6FA8D6
        case .seal: return 0xB9C0C9
        case .whale: return 0x4F7FD0
        case .clownfish: return 0xFF8A2B
        case .betta: return 0x4B5BD6
        }
    }

    var isSmallFish: Bool { self == .puffer || self == .clownfish || self == .betta }

    var variantIndex: Int {
        let i = UserDefaults.standard.integer(forKey: "variant.\(rawValue)")
        return min(max(i, 0), variants.count - 1)
    }

    func setVariantIndex(_ i: Int) {
        UserDefaults.standard.set(i, forKey: "variant.\(rawValue)")
    }

    /// The user's own name for this pet, or the built-in one.
    var displayName: String {
        let s = UserDefaults.standard.string(forKey: "name.\(rawValue)") ?? ""
        return s.isEmpty ? name : s
    }

    func setCustomName(_ s: String?) {
        UserDefaults.standard.set(s ?? "", forKey: "name.\(rawValue)")
    }
}

/// Applies a Variant to drawn pixels. Sprites use few distinct colours, so results are cached.
final class Recolor {
    let variant: Variant
    private var cache: [Color: Color] = [:]

    init(_ v: Variant) { variant = v }

    func apply(_ c: PixelCanvas) {
        if variant.isDefault { return }
        for i in c.px.indices where c.px[i] >> 24 != 0 { c.px[i] = map(c.px[i]) }
    }

    func map(_ c: Color) -> Color {
        if let m = cache[c] { return m }
        var r = Double((c >> 16) & 0xFF) / 255, g = Double((c >> 8) & 0xFF) / 255, b = Double(c & 0xFF) / 255
        var out = c
        let mx0 = max(r, g, b), mn0 = min(r, g, b)
        let whiteish = mx0 > 0.88 && (mx0 - mn0) / max(mx0, 0.001) < 0.1
        if !whiteish {
            if let t = variant.tint {
                r *= Double((t >> 16) & 0xFF) / 255
                g *= Double((t >> 8) & 0xFF) / 255
                b *= Double(t & 0xFF) / 255
            }
            let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
            var h = 0.0
            if d > 0 {
                if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
                else if mx == g { h = (b - r) / d + 2 }
                else { h = (r - g) / d + 4 }
            }
            h = (h * 60 + variant.hue).truncatingRemainder(dividingBy: 360)
            if h < 0 { h += 360 }
            let s = min(1, (mx == 0 ? 0 : d / mx) * variant.sat)
            let v = min(1, mx * variant.val)
            let cc = v * s, xx = cc * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1)), m = v - cc
            let (r1, g1, b1): (Double, Double, Double)
            switch Int(h / 60) % 6 {
            case 0: (r1, g1, b1) = (cc, xx, 0)
            case 1: (r1, g1, b1) = (xx, cc, 0)
            case 2: (r1, g1, b1) = (0, cc, xx)
            case 3: (r1, g1, b1) = (0, xx, cc)
            case 4: (r1, g1, b1) = (xx, 0, cc)
            default: (r1, g1, b1) = (cc, 0, xx)
            }
            func u(_ x: Double) -> UInt32 { UInt32(max(0, min(255, (x + m) * 255))) }
            out = (c & 0xFF000000) | (u(r1) << 16) | (u(g1) << 8) | u(b1)
        }
        cache[c] = out
        return out
    }
}

// MARK: - Speech bubbles

private final class BubbleView: NSView {
    var text = NSAttributedString()
    static let tail: CGFloat = 7

    override func draw(_ dirtyRect: NSRect) {
        let ink = NSColor(srgbRed: 0.17, green: 0.17, blue: 0.23, alpha: 1)
        let body = NSRect(x: 1, y: Self.tail, width: bounds.width - 2, height: bounds.height - Self.tail - 1)
        let path = NSBezierPath(roundedRect: body, xRadius: 8, yRadius: 8)
        let mid = bounds.midX
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: mid - 6, y: Self.tail + 1))
        tail.line(to: NSPoint(x: mid, y: 1))
        tail.line(to: NSPoint(x: mid + 6, y: Self.tail + 1))
        NSColor(srgbRed: 1, green: 0.99, blue: 0.96, alpha: 1).setFill()
        ink.setStroke()
        path.lineWidth = 2
        tail.lineWidth = 2
        tail.stroke()
        path.stroke()
        path.fill()
        tail.fill()
        text.draw(in: body.insetBy(dx: 10, dy: 6))
    }
}

/// A small caption above a pet, drawn inside the screen overlay. Never takes clicks or focus.
final class SpeechBubble {
    private let view = BubbleView()
    private var until = 0.0
    private var visible = false

    init() { view.wantsLayer = true }

    func show(_ string: String, seconds: Double) {
        var font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        if let d = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: 12) { font = f }
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let text = NSAttributedString(string: string, attributes: [
            .font: font, .paragraphStyle: para,
            .foregroundColor: NSColor(srgbRed: 0.17, green: 0.17, blue: 0.23, alpha: 1),
        ])
        let box = text.boundingRect(with: NSSize(width: 190, height: 200), options: [.usesLineFragmentOrigin])
        view.text = text
        view.setFrameSize(NSSize(width: ceil(box.width) + 24, height: ceil(box.height) + 14 + BubbleView.tail))
        view.needsDisplay = true
        view.alphaValue = 0
        until = CACurrentMediaTime() + seconds
        visible = true
    }

    /// `x, y` is where the tail should point, in screen coordinates.
    func update(x: Double, y: Double, alpha: Double) {
        guard visible else { return }
        let left = until - CACurrentMediaTime()
        if left <= 0 {
            hide()
            return
        }
        let ov = AppDelegate.shared.overlay(atX: x, y: y)
        if view.superview !== ov.view { ov.view.addSubview(view) }
        let w = view.frame.width
        let ox = min(max(x - w / 2, ov.frame.minX + 4), ov.frame.maxX - w - 4)
        let o = NSPoint(x: (ox - ov.frame.minX).rounded(), y: (y - ov.frame.minY).rounded())
        if o != view.frame.origin { view.setFrameOrigin(o) }
        let a = min(1, left / 0.4) * alpha
        if abs(view.alphaValue - a) > 0.004 { view.alphaValue = a }
    }

    func hide() {
        visible = false
        view.removeFromSuperview()
    }
}

// MARK: - Global hotkeys

/// System-wide shortcuts via Carbon hot keys, which need no special permission.
enum Hotkeys {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var installed = false

    static func register(id: UInt32, key: Int, _ action: @escaping () -> Void) {
        if !installed {
            installed = true
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var hk = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
                let id = hk.id
                DispatchQueue.main.async { Hotkeys.handlers[id]?() }
                return noErr
            }, 1, &spec, nil, nil)
        }
        handlers[id] = action
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(key), UInt32(controlKey | optionKey),
                            EventHotKeyID(signature: OSType(0x5444_5050), id: id),
                            GetApplicationEventTarget(), 0, &ref)
    }
}
