import AppKit

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Routes clicks on the overlay to whichever pet is under the cursor.
final class OverlayView: NSView {
    private weak var grabbed: PetController?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        grabbed = AppDelegate.shared.pet(at: NSEvent.mouseLocation)
        grabbed?.mouseDown(event)
    }

    override func mouseUp(with event: NSEvent) {
        grabbed?.mouseUp(event)
        grabbed = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        AppDelegate.shared.pet(at: NSEvent.mouseLocation)?.showMenu(event, in: self)
    }
}

/// One transparent, click-through, never-focused window covering a whole screen.
/// Every pet, snack and speech bubble on that screen is a layer inside it, so
/// moving them costs almost nothing (moving real windows is expensive).
final class Overlay {
    let panel: PetPanel
    let view = OverlayView()
    let frame: NSRect

    var root: CALayer { view.layer! }

    init(screen: NSScreen) {
        frame = screen.frame
        panel = PetPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        view.wantsLayer = true
        panel.contentView = view
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
    }

    /// Catch clicks only while the cursor is actually on a pet.
    func setCapture(_ on: Bool) {
        if panel.ignoresMouseEvents == on { panel.ignoresMouseEvents = !on }
    }

    func close() { panel.orderOut(nil) }
}

/// A layer that never animates implicitly and keeps pixels hard-edged.
func makeSpriteLayer(side: Double) -> CALayer {
    let l = CALayer()
    l.anchorPoint = .zero
    l.bounds = CGRect(x: 0, y: 0, width: side, height: side)
    l.magnificationFilter = .nearest
    l.minificationFilter = .nearest
    l.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(),
                 "opacity": NSNull(), "hidden": NSNull(), "onOrderIn": NSNull(), "onOrderOut": NSNull()]
    return l
}

/// Converts sprite colours to the display's own colour space once (cached), so the
/// system doesn't have to colour-convert every frame of every pet.
enum DisplayColor {
    private static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    private(set) static var space: CGColorSpace = srgb
    private static var cache: [Color: Color] = [:]

    static func refresh() {
        cache = [:]
        if let s = NSScreen.main?.colorSpace?.cgColorSpace, s.model == .rgb {
            space = s
        } else {
            space = srgb
        }
    }

    static func apply(_ c: PixelCanvas) {
        for i in c.px.indices where c.px[i] >> 24 != 0 { c.px[i] = map(c.px[i]) }
    }

    private static func map(_ c: Color) -> Color {
        if let m = cache[c] { return m }
        var out = c
        let comps = [CGFloat((c >> 16) & 0xFF) / 255, CGFloat((c >> 8) & 0xFF) / 255, CGFloat(c & 0xFF) / 255, 1]
        if let src = CGColor(colorSpace: srgb, components: comps),
           let dst = src.converted(to: space, intent: .defaultIntent, options: nil),
           let k = dst.components, k.count >= 3 {
            func u(_ v: CGFloat) -> UInt32 { UInt32(max(0, min(255, (v * 255).rounded()))) }
            out = (c & 0xFF00_0000) | (u(k[0]) << 16) | (u(k[1]) << 8) | u(k[2])
        }
        cache[c] = out
        return out
    }
}
