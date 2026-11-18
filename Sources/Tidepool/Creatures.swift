import Foundation

enum Mood { case calm, happy, sleepy, startled, eating }

/// Everything a creature needs to draw one frame of itself.
/// Sprites are drawn facing right in a 48x48 box; the caller mirrors.
struct Pose {
    var t = 0.0          // wall-clock seconds, for ambient motion
    var cycle = 0.0      // locomotion phase, advances faster when moving
    var move = 0.0       // 0...1 how hard it is swimming / walking
    var mood = Mood.calm
    var lookX = 0, lookY = 0   // pupil offset, -1...1
    var blink = false
    var special = 0.0    // 0...1 signature trick amount
}

struct Traits {
    var speed: Double        // cruising speed, points per second
    var agility: Double      // how quickly it changes direction
    var curiosity: Double    // chance it comes to look at the cursor
    var sleepiness: Double   // chance it dozes off between swims
    var floor = false        // walks along the bottom of the screen
}

enum Species: String, CaseIterable, Identifiable {
    case puffer, octopus, jelly, crab, axolotl, turtle
    case shark, dolphin, seal, whale, clownfish, betta

    var id: String { rawValue }

    var name: String {
        switch self {
        case .puffer: return "Pip"
        case .octopus: return "Inky"
        case .jelly: return "Mochi"
        case .crab: return "Pinch"
        case .axolotl: return "Lottie"
        case .turtle: return "Moss"
        case .shark: return "Finn"
        case .dolphin: return "Echo"
        case .seal: return "Biscuit"
        case .whale: return "Bloop"
        case .clownfish: return "Tango"
        case .betta: return "Velvet"
        }
    }

    var kind: String {
        switch self {
        case .puffer: return "Pufferfish"
        case .octopus: return "Octopus"
        case .jelly: return "Moon Jelly"
        case .crab: return "Crab"
        case .axolotl: return "Axolotl"
        case .turtle: return "Sea Turtle"
        case .shark: return "Shark"
        case .dolphin: return "Dolphin"
        case .seal: return "Seal"
        case .whale: return "Whale"
        case .clownfish: return "Clownfish"
        case .betta: return "Betta Fish"
        }
    }

    var blurb: String {
        switch self {
        case .puffer: return "Cheerful and a little dramatic. Puffs right up when poked."
        case .octopus: return "Clever and nosy. Jets off in a cloud of ink."
        case .jelly: return "A dreamy drifter that glows when it's delighted."
        case .crab: return "Scuttles along the bottom of your screen, clacking for attention."
        case .axolotl: return "Always smiling. Trails your cursor like a puppy."
        case .turtle: return "Unhurried and nap-prone. Tucks into its shell."
        case .shark: return "Patrols the screen looking tough. Mostly wants snacks."
        case .dolphin: return "Fast, friendly and a show-off. Leaps for applause."
        case .seal: return "A roly-poly napper that balances a ball on its nose."
        case .whale: return "Huge, gentle and slow. Sends up a happy spout."
        case .clownfish: return "Small and zippy. Gets the zoomies when poked."
        case .betta: return "Elegant and a bit vain. Fans out its flowing fins."
        }
    }

    var trickName: String {
        switch self {
        case .puffer: return "Puff Up"
        case .octopus: return "Ink Jet"
        case .jelly: return "Glow"
        case .crab: return "Claw Clack"
        case .axolotl: return "Frill Flare"
        case .turtle: return "Shell Tuck"
        case .shark: return "Chomp"
        case .dolphin: return "Leap"
        case .seal: return "Ball Bounce"
        case .whale: return "Spout"
        case .clownfish: return "Zoomies"
        case .betta: return "Fin Flare"
        }
    }

    var trickMood: Mood {
        switch self {
        case .puffer, .octopus: return .startled
        case .jelly, .axolotl: return .happy
        case .dolphin, .seal, .whale, .clownfish: return .happy
        case .crab, .turtle, .shark, .betta: return .calm
        }
    }

    var traits: Traits {
        switch self {
        case .puffer: return Traits(speed: 70, agility: 2.4, curiosity: 0.5, sleepiness: 0.3)
        case .octopus: return Traits(speed: 85, agility: 2.8, curiosity: 0.8, sleepiness: 0.25)
        case .jelly: return Traits(speed: 42, agility: 1.4, curiosity: 0.2, sleepiness: 0.5)
        case .crab: return Traits(speed: 95, agility: 5.0, curiosity: 0.45, sleepiness: 0.3, floor: true)
        case .axolotl: return Traits(speed: 78, agility: 2.6, curiosity: 0.95, sleepiness: 0.3)
        case .turtle: return Traits(speed: 46, agility: 1.6, curiosity: 0.3, sleepiness: 0.9)
        case .shark: return Traits(speed: 95, agility: 2.0, curiosity: 0.6, sleepiness: 0.15)
        case .dolphin: return Traits(speed: 105, agility: 3.0, curiosity: 0.85, sleepiness: 0.2)
        case .seal: return Traits(speed: 70, agility: 2.4, curiosity: 0.7, sleepiness: 0.6)
        case .whale: return Traits(speed: 38, agility: 1.0, curiosity: 0.3, sleepiness: 0.5)
        case .clownfish: return Traits(speed: 80, agility: 3.5, curiosity: 0.5, sleepiness: 0.25)
        case .betta: return Traits(speed: 50, agility: 2.0, curiosity: 0.4, sleepiness: 0.35)
        }
    }

    func draw(_ c: PixelCanvas, _ p: Pose) {
        switch self {
        case .puffer: drawPuffer(c, p)
        case .octopus: drawOctopus(c, p)
        case .jelly: drawJelly(c, p)
        case .crab: drawCrab(c, p)
        case .axolotl: drawAxolotl(c, p)
        case .turtle: drawTurtle(c, p)
        case .shark: drawShark(c, p)
        case .dolphin: drawDolphin(c, p)
        case .seal: drawSeal(c, p)
        case .whale: drawWhale(c, p)
        case .clownfish: drawClownfish(c, p)
        case .betta: drawBetta(c, p)
        }
    }
}

/// Eases a trick in, holds it, and eases it back out.
func trickRamp(_ t: Double, _ dur: Double) -> Double {
    let a = min(1, t / 0.22), b = min(1, max(0, dur - t) / 0.45)
    let v = max(0, min(a, b))
    return v * v * (3 - 2 * v)
}

// MARK: - Shared face parts

private let white: Color = rgb(0xFFFFFF)
private let blush: Color = rgb(0xFF8FA3)

/// Standard eye: a 3x4 dark eye with a glint. `x, y` is its top-left.
private func drawEye(_ c: PixelCanvas, _ x: Int, _ y: Int, _ p: Pose, _ ink: Color, small: Bool = false) {
    let wide = small ? 2 : 3, tall = small ? 3 : 4
    if p.mood == .sleepy {
        if small {
            c.set(x, y + 2, ink); c.set(x + 1, y + 2, ink)
        } else {
            c.set(x, y + 2, ink); c.set(x + 1, y + 3, ink); c.set(x + 2, y + 2, ink)
        }
        return
    }
    if p.mood == .happy || p.mood == .eating {
        if small {
            c.set(x, y + 1, ink); c.set(x + 1, y, ink); c.set(x + 2, y + 1, ink)
        } else {
            c.set(x, y + 2, ink); c.set(x + 1, y + 1, ink); c.set(x + 2, y + 2, ink)
        }
        return
    }
    if p.blink {
        for i in 0..<wide { c.set(x + i, y + (small ? 1 : 2), ink) }
        return
    }
    if p.mood == .startled {
        for dy in -1..<tall { for dx in -1...wide { c.set(x + dx, y + dy, white) } }
        c.set(x + wide / 2, y + 1, ink)
        if !small { c.set(x + wide / 2, y + 2, ink) }
        return
    }
    let lx = small ? 0 : p.lookX, ly = small ? 0 : p.lookY
    for dy in 0..<tall { for dx in 0..<wide { c.set(x + lx + dx, y + ly + dy, ink) } }
    c.set(x + lx + (p.lookX > 0 ? wide - 1 : 0), y + ly, white)
}

// MARK: - Pip the pufferfish

private func drawPuffer(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x5A3413)
    let body = Pal(base: rgb(0xF7C64A), light: rgb(0xFFE38A), dark: rgb(0xE0A030))
    let belly = rgb(0xFFF4D6), bellyShade = rgb(0xF0DDB0), fin = rgb(0xF29A45)
    let puff = p.special
    let jiggle = sin(p.t * 20) * 0.5 * puff * (1 - puff) * 3
    let br = sin(p.t * 2.6) * 0.35
    let rx = 9.0 + 4.5 * puff + br + jiggle, ry = 7.5 + 5.0 * puff - br + jiggle
    let cx = 25.0, cy = 24.0

    let wag = sin(p.cycle * 5) * (1.2 + 1.8 * p.move) * (1 - 0.6 * puff)
    let tx = cx - rx + 1.5
    c.poly([(tx, cy - 2), (tx - 6.5, cy - 4.5 + wag), (tx - 4.5, cy + wag * 0.6),
            (tx - 6.5, cy + 4.5 + wag), (tx, cy + 2)], fin)
    c.poly([(cx - 5, cy - ry + 1.5), (cx - 2.5, cy - ry - 2.5), (cx + 1.5, cy - ry + 1.5)], fin)

    c.ellipse(cx, cy, rx, ry) { x, y, nx, ny in
        if ny > 0.2 + 0.25 * nx * nx { return ny > 0.72 ? bellyShade : belly }
        if ny < -0.6 { return body.light }
        if ny < 0.05 && nx < 0.2 && (x * 5 + y * 9) % 13 == 0 { return body.dark }
        return body.base
    }
    if puff > 0.4 {
        for i in 0..<14 {
            let a = Double(i) / 14 * 2 * Double.pi + 0.2
            c.set(Int(floor(cx + cos(a) * (rx + 0.9))), Int(floor(cy + sin(a) * (ry + 0.9))), body.dark)
        }
    }
    c.outline(ink)

    // Pectoral fin flutters on top of the body.
    let flap = abs(sin(p.cycle * 6))
    c.ellipse(cx - 2.5, cy + 1.5, 2.6, 1.2 + flap * 1.4) { _, _, _, ny in ny > 0.2 ? rgb(0xD97A2B) : fin }

    var q = p
    if puff > 0.3 { q.mood = .startled }
    let ex = Int((cx + rx * 0.42).rounded()) - 1, ey = Int((cy - ry * 0.4).rounded()) - 1
    drawEye(c, ex, ey, q, ink)

    let mx = Int((cx + rx).rounded()) - 2, my = Int((cy + ry * 0.22).rounded())
    switch q.mood {
    case .startled:
        c.set(mx - 1, my, ink); c.set(mx - 1, my + 1, ink)
    case .happy:
        c.set(mx - 1, my, ink); c.set(mx, my, ink); c.set(mx - 2, my - 1, ink)
        c.set(ex - 1, ey + 5, blush); c.set(ex, ey + 5, blush)
    case .eating:
        c.set(mx, my, ink); c.set(mx - 1, my, ink)
        if sin(p.t * 16) > 0 { c.set(mx, my + 1, ink); c.set(mx - 1, my + 1, ink) }
    default:
        c.set(mx, my, rgb(0xD9603F)); c.set(mx - 1, my, rgb(0xD9603F))
    }
}

// MARK: - Inky the octopus

private func drawOctopus(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x5B2338)
    let pal = Pal(base: rgb(0xF27F93), light: rgb(0xFFAFB5), dark: rgb(0xCF5A78))
    let pulse = sin(p.cycle * 2.5)
    let cx = 24.0, cy = 19.5 - pulse * 0.5
    let rx = 9.0 - pulse * 0.6, ry = 8.0 + pulse * 0.6

    for i in 0..<6 {
        let k = Double(i) - 2.5
        let bx = cx + k * 2.9
        var lx = bx, ly = cy + 4
        for s in 1...9 {
            let f = Double(s) / 9
            let spread = k * f * (1.0 + 0.7 * pulse + 2.0 * p.special)
            let wave = sin(p.cycle * 4 + Double(i) * 1.3 - f * 3.5) * (0.4 + 1.3 * f)
            let x = bx + spread + wave
            let y = cy + 4 + Double(s) * (1.55 - 0.2 * pulse)
            c.line(lx, ly, x, y, 1.35 - 0.55 * f, s > 6 ? pal.dark : pal.base)
            lx = x
            ly = y
        }
    }
    c.blob(cx, cy, rx, ry, pal)
    c.outline(ink)

    var q = p
    if p.special > 0.3 { q.mood = .startled }
    let ey = Int(cy.rounded()) - 2
    drawEye(c, 19, ey, q, ink)
    drawEye(c, 26, ey, q, ink)
    let my = ey + 5
    switch q.mood {
    case .startled:
        for dx in 0...1 { for dy in 0...1 { c.set(23 + dx, my + dy, ink) } }
    case .happy:
        c.set(22, my, ink); c.set(23, my + 1, ink); c.set(24, my + 1, ink); c.set(25, my, ink)
        c.set(17, my, blush); c.set(18, my, blush); c.set(29, my, blush); c.set(30, my, blush)
    case .eating:
        let open = sin(p.t * 16) > 0
        c.set(23, my, ink); c.set(24, my, ink)
        if open { c.set(23, my + 1, ink); c.set(24, my + 1, ink) }
    default:
        c.set(23, my, ink); c.set(24, my, ink)
    }
}

// MARK: - Mochi the moon jelly

private func drawJelly(_ c: PixelCanvas, _ p: Pose) {
    let g = p.special
    let base = rgb(mixHex(0xC3B1FF, 0x8CF5FF, g), 228)
    let light = rgb(mixHex(0xE8DEFF, 0xE6FFFF, g), 242)
    let rim = rgb(mixHex(0xA58BF5, 0x4FD8F0, g), 240)
    let ink = rgb(mixHex(0x4B3A8C, 0x1D6F8C, g))
    let tent = rgb(mixHex(0x8C6FE0, 0x3CC8E8, g))
    let arm = rgb(mixHex(0xFFB8E0, 0xFFE0F5, g))
    let ph = p.cycle * 2.2
    let pulse = sin(ph)
    let cx = 24.0, cy = 21.0
    let rx = 9.5 - pulse * 1.3, ry = 8.5 + pulse * 0.9
    let bottom = Int(cy) + 2

    c.ellipse(cx, cy, rx, ry) { _, y, nx, ny in
        if y > bottom { return nil }
        if y == bottom { return rim }
        return (ny < -0.5 && nx < 0.35) ? light : base
    }
    c.outline(ink)

    // Trailing tentacles lag behind the bell's pulse.
    for i in 0..<5 {
        let k = Double(i) - 2
        let bx = cx + k * (rx - 2) / 2.2
        var lx = bx, ly = Double(bottom) + 1.5
        for s in 1...11 {
            let f = Double(s) / 11
            let x = bx + sin(ph - f * 4 + Double(i) * 0.8) * (0.3 + 1.6 * f) + k * 0.4 * f * pulse
            let y = Double(bottom) + 1.5 + Double(s) * (1.15 - 0.2 * pulse)
            c.line(lx, ly, x, y, 0.5, tent)
            lx = x
            ly = y
        }
    }
    for side in [-1.0, 1.0] {
        for s in 1...6 {
            let f = Double(s) / 6
            let x = cx + side * 1.6 + sin(ph - f * 3 + side) * 1.2 * f
            c.disc(x, Double(bottom) + 1.5 + Double(s) * 1.1, 1.15 - 0.45 * f, arm)
        }
    }
    if g > 0.3 { c.outline(rgb(0x8CF5FF, UInt32(120 * g)), diagonal: true) }

    let ey = Int(cy) - 5
    drawEye(c, 19, ey, p, ink)
    drawEye(c, 26, ey, p, ink)
    let my = ey + 5
    c.set(17, my, blush); c.set(18, my, blush); c.set(29, my, blush); c.set(30, my, blush)
    if p.mood == .happy || p.mood == .eating {
        c.set(22, my - 1, ink); c.set(23, my, ink); c.set(24, my, ink); c.set(25, my - 1, ink)
    } else if p.mood != .sleepy {
        c.set(23, my, ink); c.set(24, my, ink)
    }
}

// MARK: - Pinch the crab

private func drawCrab(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x4A1620)
    let pal = Pal(base: rgb(0xEC5B43), light: rgb(0xFF9070), dark: rgb(0xBF3B33))
    let walking = p.move > 0.08
    let step = p.cycle * 7
    let bobY = walking ? abs(sin(step)) * 1.0 : (sin(p.t * 2.2) > 0.6 ? 0.6 : 0)
    let cx = 24.0, cy = 28.0 - bobY - p.special * 1.5

    for side in [-1.0, 1.0] {
        for j in 0..<3 {
            let ph = step + Double(j) * 2.1 + (side > 0 ? Double.pi : 0)
            let lift = walking ? max(0, sin(ph)) * 1.6 : 0
            let hx = cx + side * (3.0 + Double(j) * 2.5), hy = cy + 2.5
            let kx = hx + side * (3.0 + Double(j) * 1.0), ky = cy + 3.5 - lift * 0.5
            let fx = kx + side * (0.5 + Double(j) * 0.5) + (walking ? cos(ph) * 0.8 : 0)
            let fy = 37.4 - lift
            c.line(hx, hy, kx, ky, 0.5, pal.dark)
            c.line(kx, ky, fx, fy, 0.5, pal.dark)
        }
    }

    for side in [-1.0, 1.0] {
        let wave = p.mood == .happy ? sin(p.t * 9 + (side > 0 ? 0 : Double.pi)) * 1.8 : 0
        let raise = 4.5 * p.special + wave + (p.mood == .startled ? 3 : 0)
        let sx = cx + side * 7.5, sy = cy - 1.5
        let ex = cx + side * 12.5, ey = cy - 5.0 - raise
        c.line(sx, sy, ex, ey, 1.1, pal.base)
        let kx = ex + side * 0.5, ky = ey - 2.5
        c.blob(kx, ky, 3.3, 3.1, pal)
        let open: Bool
        if p.special > 0.2 {
            open = sin(p.t * 18) > 0
        } else if p.mood == .eating {
            open = sin(p.t * 12) > 0
        } else {
            open = sin(p.t * 1.3 + side * 1.5) > 0.93
        }
        let nxp = Int(floor(kx)), top = Int(floor(ky - 3.1))
        if open {
            for (d, hw) in [1, 1, 1, 0, 0].enumerated() {
                for w in -hw...hw { c.set(nxp + w, top + d, 0) }
            }
        } else {
            for d in 0..<3 { c.set(nxp, top + d, 0) }
        }
    }

    c.blob(cx, cy, 9.0, 6.0, pal)
    let closed = p.blink || p.mood == .sleepy || p.mood == .happy || p.mood == .eating
    for side in [-1.0, 1.0] {
        let sxk = cx + side * 4.5
        c.line(sxk, cy - 5, sxk, cy - 8.5, 0.9, pal.base)
        c.disc(sxk, cy - 10, 2.4, closed ? pal.light : white)
    }
    c.outline(ink)

    let by = Int((cy - 10).rounded()) - 1
    for (i, bx) in [19, 28].enumerated() {
        if closed {
            if p.mood == .happy || p.mood == .eating {
                c.set(bx - 1, by + 1, ink); c.set(bx, by, ink); c.set(bx + 1, by + 1, ink)
            } else {
                for dx in -1...1 { c.set(bx + dx, by + 1, ink) }
            }
        } else if p.mood == .startled {
            c.set(bx, by + 1, ink)
        } else {
            let x0 = (i == 0 ? bx : bx - 1) + p.lookX
            for dx in 0...1 { for dy in 0...1 { c.set(x0 + dx, by + dy + max(0, p.lookY), ink) } }
        }
    }
    let my = Int(cy.rounded()) + 1
    if p.mood == .happy || p.mood == .eating {
        c.set(22, my, ink); c.set(23, my + 1, ink); c.set(24, my + 1, ink); c.set(25, my, ink)
        c.set(18, my, rgb(0xFFB0A0)); c.set(19, my, rgb(0xFFB0A0))
        c.set(28, my, rgb(0xFFB0A0)); c.set(29, my, rgb(0xFFB0A0))
    } else {
        c.set(23, my, ink); c.set(24, my, ink)
    }
}

// MARK: - Lottie the axolotl

private func drawAxolotl(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x7A3550)
    let pal = Pal(base: rgb(0xFFBFD0), light: rgb(0xFFDDE6), dark: rgb(0xF59AB5))
    let fin = rgb(0xFF9DBB), gill = rgb(0xEA4F80), gillTip = rgb(0xFF86A8)
    let sw = p.cycle * 4.5
    let amp = 0.7 + 1.6 * p.move

    for pass in 0..<2 {
        for s in 0...12 {
            let f = Double(s) / 12
            let x = 22.0 - Double(s) * 1.25
            let y = 27.5 + sin(sw - f * 4.2) * amp * f
            let r = 3.3 - 2.5 * f
            if pass == 0 {
                c.disc(x, y - 1.0 - 0.8 * sin(f * Double.pi), r + 0.6, fin)
            } else {
                c.disc(x, y, r, f > 0.5 ? pal.dark : pal.base)
            }
        }
    }
    let pad = sin(sw) * 1.2
    c.line(20, 29.5, 21 + pad, 32.5, 0.8, pal.dark)
    c.line(14, 29.5, 13 - pad, 32, 0.8, pal.dark)

    let flare = p.special
    for side in [-1.0, 1.0] {
        for j in 0..<3 {
            let th = 0.55 + Double(j) * 0.6 + sin(p.t * 3 + Double(j) * 1.2 + side) * 0.12 - flare * 0.1
            let len = 4.6 + 2.4 * flare + (j == 1 ? 0.8 : 0)
            let bx = 28.0 + side * 6.0, by = 21.5 + Double(j) * 0.8
            let ex = bx + side * sin(th) * len, ey = by - cos(th) * len
            c.line(bx, by, ex, ey, 0.95, gill)
            c.set(Int(floor(ex)), Int(floor(ey)), gillTip)
        }
    }
    c.blob(28, 22.5, 7.5, 6.0, pal)
    c.outline(ink)

    // Small, wide-set beady eyes.
    for bx in [23, 31] {
        let y = 21
        if p.mood == .sleepy || p.blink {
            c.set(bx, y + 1, ink); c.set(bx + 1, y + 1, ink)
        } else if p.mood == .happy || p.mood == .eating || flare > 0.3 {
            c.set(bx - 1, y + 1, ink); c.set(bx, y, ink); c.set(bx + 1, y, ink); c.set(bx + 2, y + 1, ink)
        } else if p.mood == .startled {
            for dx in -1...2 { for dy in -1...2 { c.set(bx + dx, y + dy, white) } }
            c.set(bx, y, ink); c.set(bx + 1, y, ink)
        } else {
            for dx in 0...1 { for dy in 0...1 { c.set(bx + p.lookX + dx, y + p.lookY + dy, ink) } }
            c.set(bx + p.lookX, y + p.lookY, white)
        }
    }
    c.set(21, 24, blush); c.set(22, 24, blush); c.set(33, 24, blush); c.set(34, 24, blush)
    let grin = p.mood == .happy || flare > 0.3 || (p.mood == .eating && sin(p.t * 16) > 0)
    for x in 25...30 { c.set(x, 25, ink) }
    c.set(24, 24, ink); c.set(31, 24, ink)
    if grin { for x in 26...29 { c.set(x, 26, rgb(0xE85A7A)) } }
}

// MARK: - Moss the sea turtle

private func drawTurtle(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x1F4030)
    let shell = Pal(base: rgb(0x58A86C), light: rgb(0x86CF8E), dark: rgb(0x3A7D55))
    let skin = Pal(base: rgb(0xA5DBA0), light: rgb(0xC9EFC0), dark: rgb(0x79BD88))
    let rimC = rgb(0xEBDCA2)
    let hide = p.special
    let out = 1 - hide
    let sw = p.cycle * 3

    if out > 0.3 { c.disc(13.0 + 2 * hide, 25.5, 1.2, skin.dark) }
    let ba = 2.3 + 0.35 * sin(sw + 1)
    if out > 0.15 { c.line(17, 26, 17 + cos(ba) * 6 * out, 26 + sin(ba) * 6 * out, 1.3, skin.dark) }

    let fa = 1.75 + 0.6 * sin(sw)
    let fl = 9.5 * out
    if fl > 1.5 {
        let fx = 28.0, fy = 26.0
        c.line(fx, fy, fx + cos(fa) * fl, fy + sin(fa) * fl, 1.6, skin.base)
        c.disc(fx + cos(fa) * fl * 0.55, fy + sin(fa) * fl * 0.55, 2.1, skin.base)
    }

    let hx = 34.0 - 7.5 * hide, hy = 21.5 + sin(p.t * 2) * 0.3
    let headOut = hide < 0.8
    if headOut {
        c.line(29, 23, hx, hy + 0.5, 1.9, skin.base)
        c.blob(hx, hy, 4.0, 3.5, skin)
    }

    let scx = 22.5, scy = 22.5, srx = 9.5, sry = 6.8
    let top = Int(floor(scy - sry))
    c.ellipse(scx, scy, srx, sry) { x, y, _, ny in
        if ny > 0.5 { return rimC }
        let yy = y - top, row = yy / 4
        if yy % 4 == 3 || (x + row * 3) % 6 == 0 { return shell.dark }
        return ny < -0.45 ? shell.light : shell.base
    }
    c.outline(ink)

    if headOut {
        let ex = Int(hx.rounded()), ey = Int(hy.rounded()) - 2
        drawEye(c, ex, ey, p, ink, small: true)
        let mx = Int((hx + 4).rounded()) - 2
        if p.mood == .happy || p.mood == .eating {
            c.set(mx - 1, ey + 4, ink); c.set(mx, ey + 4, ink); c.set(mx + 1, ey + 3, ink)
            c.set(ex - 1, ey + 4, blush)
        } else {
            c.set(mx, ey + 4, ink); c.set(mx + 1, ey + 4, ink)
        }
    } else {
        // Peeking out from inside the shell.
        c.ellipse(29.5, 22.0, 2.2, 2.0) { _, _, _, _ in ink }
        if !p.blink { c.set(28, 21, white); c.set(30, 21, white) }
    }
}

// MARK: - Shared tail for the bigger swimmers

/// A forked tail fin whose root sits at (tx, ty).
private func drawFluke(_ c: PixelCanvas, _ tx: Double, _ ty: Double, _ wag: Double,
                       up: Double, down: Double, _ col: Color) {
    c.poly([(tx + 1.5, ty - 1), (tx - 4.5, ty - up + wag), (tx - 1.5, ty),
            (tx - 4.5, ty + down + wag), (tx + 1.5, ty + 1)], col)
}

// MARK: - Finn the shark

private func drawShark(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x26323D)
    let pal = Pal(base: rgb(0x7E97AD), light: rgb(0xA9BDCC), dark: rgb(0x5C7389))
    let belly = rgb(0xF2F6F8), bellyShade = rgb(0xD5DEE5)
    let wag = sin(p.cycle * 5) * (1.0 + 1.6 * p.move)
    let cx = 26.0, cy = 24.0

    for s in 0...5 {
        let f = Double(s) / 5
        c.disc(17.0 - Double(s) * 1.3, cy + wag * f * 0.6, 3.0 - 1.6 * f, pal.base)
    }
    drawFluke(c, 10.5, cy + wag * 0.6, wag * 0.4, up: 7, down: 5, pal.dark)
    c.poly([(21, cy - 4.5), (22.5, cy - 11.5), (28.5, cy - 4.5)], pal.dark)
    let flap = sin(p.cycle * 3)
    c.poly([(25, cy + 3), (21.5, cy + 9 + flap), (29.5, cy + 3.5)], pal.dark)
    c.ellipse(cx, cy, 12, 5.6) { _, _, nx, ny in
        if ny > 0.2 - 0.25 * nx { return ny > 0.7 ? bellyShade : belly }
        return ny < -0.55 ? pal.light : pal.base
    }
    c.outline(ink)

    for gx in [27, 29] { for gy in 21...23 { c.set(gx, gy, pal.dark) } }
    drawEye(c, 32, 20, p, ink, small: true)
    let chomp = p.special > 0.2 ? sin(p.t * 14) > 0 : (p.mood == .eating && sin(p.t * 16) > 0)
    if chomp {
        for x in 31...35 {
            c.set(x, 25, x % 2 == 0 ? white : rgb(0x8A2F3A))
            c.set(x, 26, rgb(0x8A2F3A))
            c.set(x, 27, x % 2 == 1 ? white : rgb(0x8A2F3A))
        }
    } else {
        for x in 31...36 { c.set(x, 26, ink) }
        if p.mood == .happy || p.special > 0.2 {
            c.set(30, 25, ink)
            c.set(32, 27, white); c.set(34, 27, white)
        }
    }
}

// MARK: - Echo the dolphin

private func drawDolphin(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x1F3A57)
    let pal = Pal(base: rgb(0x6FA8D6), light: rgb(0x9CC8EA), dark: rgb(0x4C86B8))
    let belly = rgb(0xEAF4FB)
    let wag = sin(p.cycle * 5) * (1.0 + 1.8 * p.move + 1.5 * p.special)
    let cx = 25.0, cy = 23.5

    for s in 0...6 {
        let f = Double(s) / 6
        c.disc(17.5 - Double(s) * 1.3, cy + 0.5 + f + wag * f * 0.7, 3.2 - 2.0 * f, pal.base)
    }
    drawFluke(c, 9.0, cy + 1.5 + wag * 0.7, wag * 0.3, up: 4, down: 4, pal.dark)
    c.poly([(21.5, cy - 4.5), (21, cy - 10.5), (23, cy - 9.5), (27.5, cy - 4.5)], pal.dark)
    let flap = sin(p.cycle * 3)
    c.poly([(26, cy + 3), (23, cy + 8.5 + flap), (30, cy + 3.5)], pal.dark)
    c.ellipse(36.5, cy + 1.5, 3.2, 1.7) { _, _, _, ny in ny > 0.1 ? belly : pal.base }
    c.ellipse(cx, cy, 11, 5.6) { _, _, nx, ny in
        if ny > 0.3 - 0.2 * nx { return belly }
        return ny < -0.55 ? pal.light : pal.base
    }
    c.outline(ink)

    drawEye(c, 31, 21, p, ink, small: true)
    for x in 35...38 { c.set(x, 25, ink) }
    c.set(34, 24, ink)
    if p.mood == .eating && sin(p.t * 16) > 0 { for x in 36...38 { c.set(x, 26, ink) } }
    if p.mood == .happy { c.set(30, 25, blush); c.set(31, 25, blush) }
}

// MARK: - Biscuit the seal

private func drawSeal(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x39414D)
    let pal = Pal(base: rgb(0xB9C0C9), light: rgb(0xDDE2E7), dark: rgb(0x8E97A3))
    let belly = rgb(0xECEFF2)
    let wag = sin(p.cycle * 5) * (0.8 + 1.6 * p.move)

    drawFluke(c, 12.0, 26.0 + wag * 0.5, wag * 0.5, up: 4, down: 4, pal.dark)
    for s in 0...5 {
        let f = Double(s) / 5
        c.disc(18.0 - Double(s) * 1.2, 25.5 + wag * f * 0.4, 4.6 - 2.4 * f, pal.base)
    }
    let flap = sin(p.cycle * 3)
    c.poly([(25, 28), (22.5, 33.5 + flap), (29.5, 29)], pal.dark)

    // Trick prop: a beach ball bouncing on the nose.
    if p.special > 0.15 {
        let bounce = abs(sin(p.t * 7)) * 6 * p.special
        c.ellipse(36.5, 14.0 - bounce, 3.3, 3.3) { _, _, nx, ny in
            if nx < -0.2 && ny < -0.2 { return white }
            return abs(nx) < 0.33 ? rgb(0xFFF1C9) : (nx < 0 ? rgb(0xE8483F) : rgb(0x3F8FE8))
        }
    }
    c.ellipse(23, 25.5, 9.5, 5.5) { x, y, _, ny in
        if ny > 0.35 { return belly }
        if ny < 0.1 && (x * 7 + y * 3) % 11 == 0 { return pal.dark }
        return ny < -0.6 ? pal.light : pal.base
    }
    c.blob(31.5, 21.5, 5.5, 5.0, pal)
    c.ellipse(36, 23, 2.3, 1.9) { _, _, _, _ in pal.light }
    c.outline(ink)

    drawEye(c, 30, 19, p, ink)
    c.set(37, 22, ink); c.set(38, 22, ink)
    c.set(34, 23, pal.dark); c.set(34, 25, pal.dark)
    if p.mood == .happy || p.mood == .eating {
        c.set(35, 24, ink); c.set(36, 25, ink); c.set(37, 24, ink)
        c.set(28, 24, blush); c.set(29, 24, blush)
    } else {
        c.set(36, 24, ink)
    }
}

// MARK: - Bloop the whale

private func drawWhale(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x1B2D55)
    let pal = Pal(base: rgb(0x4F7FD0), light: rgb(0x7FA8EC), dark: rgb(0x3761A8))
    let belly = rgb(0xDCE9FA), groove = rgb(0xB4CBEE)
    let wag = sin(p.cycle * 3.5) * (0.8 + 1.4 * p.move)
    let cx = 26.0, cy = 24.5

    for s in 0...6 {
        let f = Double(s) / 6
        c.disc(15.0 - Double(s) * 1.3, cy - 1 - f * 3.0 + wag * f * 0.6, 4.2 - 2.6 * f, pal.base)
    }
    drawFluke(c, 7.0, cy - 4.0 + wag * 0.6, wag * 0.3, up: 4, down: 3.5, pal.dark)
    let flap = sin(p.cycle * 2.5)
    c.poly([(25, cy + 5), (22, cy + 10.5 + flap), (29, cy + 5.5)], pal.dark)
    c.ellipse(cx, cy, 12.5, 8.2) { x, _, nx, ny in
        if ny > 0.3 - 0.15 * nx { return (x % 3 == 0 && nx > -0.5) ? groove : belly }
        return ny < -0.6 ? pal.light : pal.base
    }
    c.outline(ink)

    c.set(26, 17, pal.dark); c.set(27, 17, pal.dark)
    drawEye(c, 33, 23, p, ink, small: true)
    for x in 32...36 { c.set(x, 28, ink) }
    c.set(37, 27, ink)
    if p.mood == .eating && sin(p.t * 16) > 0 { for x in 33...36 { c.set(x, 29, ink) } }
    if p.mood == .happy || p.special > 0.3 { c.set(30, 27, blush); c.set(31, 27, blush) }
}

// MARK: - Tango the clownfish

private func drawClownfish(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x3A1A0E)
    let pal = Pal(base: rgb(0xFF8A2B), light: rgb(0xFFB05E), dark: rgb(0xE06A12))
    let edge = rgb(0x2A1A14)
    let wag = sin(p.cycle * 6) * (1.2 + 2.0 * p.move + 1.5 * p.special)
    let cx = 26.0, cy = 24.0, rx = 9.0, ry = 6.2

    c.ellipse(cx - rx - 2.0, cy + wag * 0.6, 3.6, 4.0) { _, _, nx, _ in nx < -0.45 ? edge : pal.base }
    c.ellipse(cx - 1, cy - ry, 5, 2.4) { _, _, _, ny in ny < -0.3 ? edge : pal.dark }
    c.ellipse(cx - 2, cy + ry - 0.5, 3, 2.2) { _, _, _, ny in ny > 0.3 ? edge : pal.dark }
    c.ellipse(cx, cy, rx, ry) { _, _, nx, ny in
        for bc in [-0.72, -0.14, 0.32] {
            let d = abs(nx - bc + ny * ny * 0.1)
            if d < 0.1 { return white }
            if d < 0.17 { return edge }
        }
        return ny < -0.6 ? pal.light : (ny > 0.6 ? pal.dark : pal.base)
    }
    c.outline(ink)

    let flap = abs(sin(p.cycle * 6))
    c.ellipse(cx + 0.2, cy + 2.0, 1.6, 1.0 + flap * 1.2) { _, _, _, _ in pal.dark }
    drawEye(c, 31, 21, p, ink)
    if p.mood == .happy || p.mood == .eating {
        c.set(32, 26, ink); c.set(33, 26, ink); c.set(31, 25, ink)
    } else {
        c.set(33, 26, ink)
    }
}

// MARK: - Velvet the betta

private func drawBetta(_ c: PixelCanvas, _ p: Pose) {
    let ink = rgb(0x2A1E5C)
    let pal = Pal(base: rgb(0x4B5BD6), light: rgb(0x7E8BF0), dark: rgb(0x3440A8))
    let finA = rgb(0xD64BB8), finB = rgb(0xF08AD8), finTip = rgb(0xFFC4EC)
    let fl = p.special
    let cx = 29.0, cy = 24.0

    // Each fin is a fan of rays that ripple from root to tip.
    func fan(_ bx: Double, _ by: Double, _ center: Double, _ spread: Double, _ len: Double, _ n: Int) {
        for i in 0..<n {
            let u = Double(i) / Double(n - 1) - 0.5
            let a = center + u * spread * (1 + 0.35 * fl)
            let L = len * (1 + 0.3 * fl) * (1 - 0.3 * abs(u))
            var lx = bx, ly = by
            for s in 1...6 {
                let f = Double(s) / 6
                let aa = a + sin(p.cycle * 3 - f * 2.5 + Double(i) * 0.6) * 0.2 * f
                let x = bx + cos(aa) * L * f, y = by + sin(aa) * L * f
                c.line(lx, ly, x, y, 1.0, f > 0.8 ? finTip : (i % 2 == 0 ? finA : finB))
                lx = x
                ly = y
            }
        }
    }
    fan(23.5, cy, Double.pi, 1.9, 12, 9)
    fan(27, cy - 3, -Double.pi * 0.62, 0.9, 7, 5)
    fan(27, cy + 3, Double.pi * 0.62, 0.9, 7.5, 5)
    c.blob(cx, cy, 7, 4.3, pal)
    c.outline(ink)

    drawEye(c, 31, 22, p, ink)
    if p.mood == .happy || p.mood == .eating {
        c.set(34, 26, ink); c.set(35, 25, ink)
        c.set(30, 26, blush)
    } else {
        c.set(35, 25, ink)
    }
}
