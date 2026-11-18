import AppKit

let canvasSide = 64   // sprite box (48) plus an 8px margin for particles

private enum PKind { case bubble, heart, zzz, ink, sparkle, bang, crumb, drop }

private struct Particle {
    var kind: PKind
    var x: Double, y: Double, vx: Double, vy: Double
    var life: Double
    var age = 0.0
    var seed = Double.random(in: 0..<1)
}

final class PetController: NSObject {
    enum State { case idle, wander, curious, happy, trick, dragged, tossed, sleep, chase, eat, flee, greet }

    let species: Species
    let layer: CALayer
    /// True while the cursor is on this pet (or it is being held), so clicks should be caught.
    private(set) var wantsMouse = false
    /// Being dragged or flying through the air: worth full frame rate.
    var isHandled: Bool { state == .dragged || state == .tossed || mouseIsDown }
    private let canvas = PixelCanvas(canvasSide, canvasSide)
    private var mask = [Bool](repeating: false, count: canvasSide * canvasSide)
    private(set) var scale: Double

    // Centre of the pet in screen coordinates (points, y up).
    var x = 0.0, y = 0.0
    private var vx = 0.0, vy = 0.0
    private(set) var facing = 1.0

    private(set) var state = State.idle
    private var stateTime = 0.0, stateDur = 2.0
    private var targetX = 0.0, targetY = 0.0
    private weak var food: Food?

    private var clock = Double.random(in: 0..<10)
    private var cycle = 0.0, move = 0.0
    private var lastFrame = -1
    private var particles: [Particle] = []
    private var blinkAt = 2.0, blinkUntil = 0.0
    private var bubbleTimer = 2.0, emitTimer = 0.0, emitted = 0
    private var curiousCooldown = 6.0
    private var awake = 0.0
    private let phase = Double.random(in: 0..<6)

    private var mouseIsDown = false, dragging = false, menuOpen = false, paused = false

    // Friends, perches, looks and speech.
    private(set) var socialCooldown = Double.random(in: 10...25)
    private var fleeCooldown = 0.0
    private var perchID: CGWindowID?
    private var perchRect: CGRect?
    private var ignorePerchUntil = 0.0, jumping = false, prevY = 0.0
    private var lastRender = -1.0, bob = 0
    private var lastOrigin = NSPoint(x: -1e9, y: -1e9)
    /// True while a crab needs up-to-date window positions (standing on one, or in the air).
    var wantsFreshWindows: Bool { perchID != nil || (species.traits.floor && state == .tossed) }
    private var recolor = Recolor(Variant(name: ""))
    private var bubble: SpeechBubble?
    var isSociable: Bool { state == .idle || state == .wander }
    private var downX = 0.0, downY = 0.0, offX = 0.0, offY = 0.0
    private var throwVX = 0.0, throwVY = 0.0
    private var strokeDist = 0.0, strokeTime = 0.0, lastMX = 0.0, lastMY = 0.0

    init(species: Species, scale: Double) {
        self.species = species
        self.scale = scale
        layer = makeSpriteLayer(side: 64 * scale)
        super.init()
        reloadLook()
        let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let pad = 40 * scale
        x = Double.random(in: (vf.minX + pad)...(max(vf.minX + pad + 1, vf.maxX - pad)))
        y = species.traits.floor
            ? vf.minY + 14 * scale
            : Double.random(in: (vf.minY + pad)...(max(vf.minY + pad + 1, vf.maxY - pad)))
        // Arrive with a little splash of bubbles and a hello.
        for _ in 0..<5 {
            emit(.bubble, Double.random(in: -10...10), Double.random(in: -6...8),
                 vy: -Double.random(in: 10...18), life: 1.2)
        }
        enter(.happy, 1.2)
    }

    func show() {
        layer.isHidden = false
    }
    func hide() {
        layer.isHidden = true
        wantsMouse = false
        bubble?.hide()
    }

    func remove() {
        layer.removeFromSuperlayer()
        bubble?.hide()
    }

    var alpha: Double {
        get { Double(layer.opacity) }
        set { if abs(Double(layer.opacity) - newValue) > 0.004 { layer.opacity = Float(newValue) } }
    }

    func reloadLook() {
        recolor = Recolor(species.variants[species.variantIndex])
        lastFrame = -1
    }

    func say(_ text: String, seconds: Double = 5) {
        if bubble == nil { bubble = SpeechBubble() }
        bubble?.show(text, seconds: seconds)
    }

    /// Swim over to the cursor and deliver a message.
    /// Perk up and announce something (used for notifications).
    func react(_ text: String) {
        guard state != .dragged else { return }
        awake = 0
        enter(.happy, 1.6)
        emit(.bang, 10, -17, vy: -5, life: 0.8)
        say(text, seconds: 7)
    }

    func remind(_ text: String) {
        guard state != .dragged else { return }
        awake = 0
        enter(.curious, 10)
        say(text, seconds: 9)
    }

    func setScale(_ s: Double) {
        scale = s
        layer.bounds = CGRect(x: 0, y: 0, width: 64 * s, height: 64 * s)
    }

    // MARK: Interactions

    func pet() {
        guard state != .dragged, state != .trick else { return }
        awake = 0
        enter(.happy, 1.4)
    }

    func trick() {
        guard state != .dragged else { return }
        awake = 0
        enter(.trick, species == .turtle ? 3.2 : 2.6)
        switch species {
        case .octopus:
            vx = -facing * 300
            vy = 90
        case .puffer:
            for _ in 0..<5 {
                emit(.bubble, Double.random(in: -12...12), Double.random(in: -8...8),
                     vy: -Double.random(in: 8...16), life: 1.1)
            }
        case .shark:
            vx = facing * 280
        case .dolphin:
            vx = facing * 170
        default: break
        }
    }

    func nap() {
        guard state != .dragged else { return }
        enter(.sleep, Double.random(in: 40...80))
    }

    func wake() {
        if state == .sleep {
            awake = 0
            enter(.idle, 1.5)
        }
    }

    func mouseDown(_ e: NSEvent) {
        let m = NSEvent.mouseLocation
        mouseIsDown = true
        dragging = false
        downX = m.x
        downY = m.y
        offX = x - downX
        offY = y - downY
    }

    func mouseUp(_ e: NSEvent) {
        let wasDragging = dragging
        release()
        if !wasDragging {
            if e.clickCount >= 2 { trick() } else { pet() }
        }
    }

    private func release() {
        guard mouseIsDown else { return }
        mouseIsDown = false
        if dragging {
            dragging = false
            let sp = hypot(throwVX, throwVY), cap = 1500.0
            let k = sp > cap ? cap / sp : 1
            vx = throwVX * k
            vy = throwVY * k
            enter(.tossed, 1.6)
        }
    }

    func showMenu(_ e: NSEvent, in view: NSView) {
        let menu = NSMenu()
        let head = NSMenuItem(title: "\(species.displayName) the \(species.kind)", action: nil, keyEquivalent: "")
        head.isEnabled = false
        menu.addItem(head)
        menu.addItem(.separator())
        func add(_ title: String, _ sel: Selector, _ target: AnyObject) {
            let it = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            it.target = target
            menu.addItem(it)
        }
        add("Pet", #selector(menuPet), self)
        add(species.trickName, #selector(menuTrick), self)
        add("Drop a Snack", #selector(menuFeed), self)
        add(state == .sleep ? "Wake Up" : "Take a Nap", #selector(menuNap), self)
        menu.addItem(.separator())
        add("Rename…", #selector(menuRename), self)
        let colourItem = NSMenuItem(title: "Colour", action: nil, keyEquivalent: "")
        let colourMenu = NSMenu()
        for (i, v) in species.variants.enumerated() {
            let it = NSMenuItem(title: v.name, action: #selector(menuVariant(_:)), keyEquivalent: "")
            it.target = self
            it.tag = i
            it.state = i == species.variantIndex ? .on : .off
            colourMenu.addItem(it)
        }
        colourItem.submenu = colourMenu
        menu.addItem(colourItem)
        menu.addItem(.separator())
        add("Send \(species.displayName) Home", #selector(menuRemove), self)
        add("Choose Pets…", #selector(AppDelegate.showPicker), AppDelegate.shared)
        menuOpen = true
        NSMenu.popUpContextMenu(menu, with: e, for: view)
        menuOpen = false
    }

    @objc private func menuPet() { pet() }
    @objc private func menuTrick() { trick() }
    @objc private func menuFeed() {
        AppDelegate.shared.dropFood(x: x + Double.random(in: -50...50), y: y + 70 * scale)
    }
    @objc private func menuNap() { if state == .sleep { wake() } else { nap() } }
    @objc private func menuRename() { AppDelegate.shared.rename(species) }
    @objc private func menuVariant(_ sender: NSMenuItem) { AppDelegate.shared.setVariant(species, sender.tag) }
    @objc private func menuRemove() { AppDelegate.shared.setActive(species, false) }

    // MARK: Simulation

    private func enter(_ s: State, _ dur: Double = 0) {
        state = s
        stateTime = 0
        stateDur = dur
        emitTimer = 0
        emitted = 0
    }

    private func screen() -> NSScreen {
        let p = NSPoint(x: x, y: y)
        return NSScreen.screens.first { $0.frame.contains(p) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    func hit(_ m: NSPoint) -> Bool {
        let f = NSRect(x: lastOrigin.x, y: lastOrigin.y, width: 64 * scale, height: 64 * scale)
        guard !layer.isHidden, f.contains(m) else { return false }
        let px = Int((m.x - f.minX) / scale), py = canvasSide - 1 - Int((m.y - f.minY) / scale)
        for dy in -2...2 {
            for dx in -2...2 {
                let X = px + dx, Y = py + dy
                if X >= 0 && X < canvasSide && Y >= 0 && Y < canvasSide && mask[Y * canvasSide + X] {
                    return true
                }
            }
        }
        return false
    }

    private func steer(_ tx: Double, _ ty: Double, _ speed: Double, _ dt: Double) {
        let tr = species.traits
        let dx = tx - x, dy = tr.floor ? 0 : ty - y
        let d = hypot(dx, dy)
        guard d > 0.5 else { return }
        let sp = speed * min(1, d / 70 + 0.12)
        let k = 1 - exp(-tr.agility * dt)
        vx += (dx / d * sp - vx) * k
        vy += (dy / d * sp - vy) * k
    }

    private func slow(_ dt: Double, _ rate: Double = 3) {
        let k = exp(-rate * dt)
        vx *= k
        vy *= k
    }

    private func rnd(_ a: Double, _ b: Double) -> Double { b > a ? Double.random(in: a...b) : a }

    private func pickTarget(_ b: NSRect) {
        let tr = species.traits
        if tr.floor {
            targetX = rnd(max(b.minX, x - 500), min(b.maxX, x + 500))
            targetY = y
            return
        }
        if AppDelegate.shared.edgesOnly {
            let band = 0.16 * min(b.width, b.height)
            switch Int.random(in: 0..<4) {
            case 0:
                targetX = rnd(b.minX, b.minX + band)
                targetY = rnd(b.minY, b.maxY)
            case 1:
                targetX = rnd(b.maxX - band, b.maxX)
                targetY = rnd(b.minY, b.maxY)
            case 2:
                targetX = rnd(b.minX, b.maxX)
                targetY = rnd(b.minY, b.minY + band)
            default:
                targetX = rnd(b.minX, b.maxX)
                targetY = rnd(b.maxY - band, b.maxY)
            }
        } else {
            targetX = rnd(max(b.minX, x - 650), min(b.maxX, x + 650))
            targetY = rnd(max(b.minY, y - 400), min(b.maxY, y + 400))
        }
    }

    /// Focus / pause: hold perfectly still, eyes closed, and let every click pass through.
    func tickPaused(dt: Double) {
        if !paused {
            paused = true
            mouseIsDown = false
            dragging = false
            vx = 0
            vy = 0
            particles.removeAll()
            lastFrame = -1
            bubble?.hide()
        }
        wantsMouse = false
        clock += dt * 0.35
        let frame = Int(clock * 15)
        if frame != lastFrame {
            lastFrame = frame
            render(Pose(t: clock, cycle: cycle, move: 0, mood: .sleepy))
        }
    }

    func tick(dt: Double, mouse: NSPoint, mouseSpeed: Double) {
        if paused {
            paused = false
            enter(.idle, 1.0)
        }
        clock += dt
        stateTime += dt
        let tr = species.traits
        let app = AppDelegate.shared!
        let vf = app.visibleFrame(atX: x, y: y)
        var b = vf.insetBy(dx: min(15 * scale, vf.width / 4), dy: min(15 * scale, vf.height / 4))
        let night = app.isNight
        var floorY = vf.minY + 14 * scale
        // Standing on a window: ride along with it, and fall if it goes away.
        if tr.floor, let pid = perchID {
            if let w = app.frontWindow, w.id == pid, validPerch(w.rect, vf), state != .dragged {
                if let last = perchRect, abs(last.width - w.rect.width) < 1 { x += w.rect.minX - last.minX }
                perchRect = w.rect
                floorY = w.rect.maxY + 14 * scale
                let lo = max(b.minX, w.rect.minX + 10 * scale), hi = min(b.maxX, w.rect.maxX - 10 * scale)
                if hi > lo { b = NSRect(x: lo, y: b.minY, width: hi - lo, height: b.height) }
            } else {
                perchID = nil
                perchRect = nil
                if state != .dragged {
                    vx = 0
                    vy = 0
                    jumping = false
                    enter(.tossed, 4)
                }
            }
        }
        let mx = Double(mouse.x), my = Double(mouse.y)
        let dMouse = hypot(mx - x, my - y)

        // Only catch clicks on the creature itself; everything else passes through.
        let over = hit(mouse)
        if mouseIsDown && NSEvent.pressedMouseButtons & 1 == 0 { release() }
        wantsMouse = over || mouseIsDown

        if mouseIsDown && !dragging && hypot(mx - downX, my - downY) > 4 {
            dragging = true
            perchID = nil
            perchRect = nil
            jumping = false
            throwVX = 0
            throwVY = 0
            enter(.dragged)
            emit(.bang, 10, -17, vy: -5, life: 0.7)
        }

        // Rubbing the cursor back and forth over a pet counts as petting.
        if over && !mouseIsDown {
            strokeDist += hypot(mx - lastMX, my - lastMY)
            strokeTime += dt
            if strokeDist > 260 {
                strokeDist = 0
                strokeTime = 0
                if state == .idle || state == .wander || state == .curious || state == .sleep { pet() }
            } else if strokeTime > 1.6 {
                strokeDist = 0
                strokeTime = 0
            }
        } else {
            strokeDist = 0
            strokeTime = 0
        }
        lastMX = mx
        lastMY = my

        var mood = Mood.calm
        var special = 0.0, hop = 0.0
        var lookAt: (Double, Double)? = dMouse < 380 ? (mx, my) : nil

        switch state {
        case .idle, .wander:
            awake += dt
            curiousCooldown -= dt
            if state == .idle {
                slow(dt)
            } else {
                let d = hypot(targetX - x, tr.floor ? 0 : targetY - y)
                let meander = tr.floor ? 0 : sin(clock * 0.8 + phase) * 30
                steer(targetX, targetY + meander, tr.speed * (night ? 0.7 : 1), dt)
                if d < 45 || stateTime > stateDur { enter(.idle, Double.random(in: 1.5...5)) }
            }
            if let f = app.nearestFood(x, y) {
                food = f
                enter(.chase)
            } else if curiousCooldown < 0 && !over {
                curiousCooldown = Double.random(in: 6...14)
                if dMouse < 340 && dMouse > 60 && mouseSpeed < 250
                    && Double.random(in: 0..<1) < tr.curiosity {
                    enter(.curious, Double.random(in: 4...8))
                }
            } else if state == .idle && stateTime > stateDur {
                // After dark everyone tires sooner and sleeps longer.
                if app.napTime || (awake > (night ? 30 : 90)
                    && Double.random(in: 0..<1) < tr.sleepiness * (night ? 0.7 : 0.25)) {
                    enter(.sleep, Double.random(in: 30...75) * (night ? 2 : 1))
                } else if tr.floor && tryPerchHop(vf) {
                    // hopping on or off a window
                } else {
                    pickTarget(b)
                    visitFriend(b)
                    enter(.wander, 25)
                }
            }
            socialise(dt, app)
            bubbleTimer -= dt
            if bubbleTimer < 0 {
                bubbleTimer = Double.random(in: 2.5...6)
                emit(.bubble, facing * 9, -3, vy: -Double.random(in: 9...14), life: 1.3)
            }

        case .curious:
            let dx = x - mx, dy = y - my
            let d = max(1, hypot(dx, dy)), R = 26 * scale + 24
            steer(mx + dx / d * R, my + dy / d * R, tr.speed * 1.15, dt)
            if abs(vx) < 14 { facing = mx > x ? 1 : -1 }
            lookAt = (mx, my)
            if let f = app.nearestFood(x, y) {
                food = f
                enter(.chase)
            } else if stateTime > stateDur || dMouse > 700 {
                enter(.idle, Double.random(in: 1...3))
            }

        case .happy:
            slow(dt)
            mood = .happy
            hop = abs(sin(stateTime * 9)) * 1.5 * scale * max(0, 1 - stateTime / stateDur)
            while emitted < 3 && stateTime > Double(emitted) * 0.28 {
                emit(.heart, Double.random(in: -8...8), -13, vy: -11, life: 1.0)
                emitted += 1
            }
            if stateTime > stateDur { enter(.idle, Double.random(in: 1...3)) }

        case .trick:
            special = trickRamp(stateTime, stateDur)
            mood = species.trickMood
            slow(dt, 1.8)
            emitTimer -= dt
            switch species {
            case .puffer:
                vy += 30 * dt
            case .octopus:
                if emitTimer <= 0 && stateTime < 1.0 {
                    emitTimer = 0.07
                    emit(.ink, -facing * 2 + Double.random(in: -3...3), 4 + Double.random(in: -3...3),
                         vx: Double.random(in: -5...5), vy: Double.random(in: -4...4), life: 1.1)
                }
            case .jelly:
                if emitTimer <= 0 {
                    emitTimer = 0.14
                    emit(.sparkle, Double.random(in: -16...16), Double.random(in: -16...10), vy: -3, life: 0.6)
                }
            case .crab:
                hop = abs(sin(stateTime * 12)) * 0.8 * scale * special
                if emitTimer <= 0 {
                    emitTimer = 0.25
                    let side: Double = emitted % 2 == 0 ? -1 : 1
                    emitted += 1
                    emit(.sparkle, side * 13, -14, vy: -4, life: 0.35)
                }
            case .axolotl:
                if emitTimer <= 0 {
                    emitTimer = 0.3
                    emitted += 1
                    emit(emitted % 3 == 0 ? .heart : .sparkle,
                         Double.random(in: -14...14), Double.random(in: -16 ... -6), vy: -8, life: 0.8)
                }
            case .turtle:
                vy -= 12 * dt
            case .shark:
                break
            case .dolphin:
                // One big arcing leap, with a splash at each end.
                let u = min(1, stateTime / 1.3)
                hop = sin(u * Double.pi) * 30 * scale
                if (emitted == 0) || (emitted == 1 && u >= 1) {
                    emitted += 1
                    for _ in 0..<5 {
                        emit(.drop, Double.random(in: -10...10), 6, vx: Double.random(in: -14...14),
                             vy: -Double.random(in: 14...26), life: 0.7)
                    }
                }
            case .seal:
                break
            case .whale:
                if emitTimer <= 0 && special > 0.5 {
                    emitTimer = 0.05
                    emit(.drop, facing * 2 + Double.random(in: -1...1), -9, vx: Double.random(in: -9...9),
                         vy: -Double.random(in: 22...34), life: 0.9)
                }
            case .clownfish:
                if emitTimer <= 0 && stateTime < stateDur - 0.6 {
                    emitTimer = 0.32
                    emitted += 1
                    vx = (emitted % 2 == 0 ? -1 : 1) * Double.random(in: 300...420)
                    vy = Double.random(in: -220...220)
                }
            case .betta:
                if emitTimer <= 0 && special > 0.5 {
                    emitTimer = 0.3
                    emit(.sparkle, Double.random(in: -18...10), Double.random(in: -16...14), vy: -3, life: 0.5)
                }
            }
            if stateTime > stateDur { enter(.idle, Double.random(in: 1...2.5)) }

        case .dragged:
            let nx = mx + offX, ny = my + offY
            if dt > 0 {
                throwVX = throwVX * 0.75 + (nx - x) / dt * 0.25
                throwVY = throwVY * 0.75 + (ny - y) / dt * 0.25
            }
            if abs(throwVX) > 60 { facing = throwVX > 0 ? 1 : -1 }
            x = nx
            y = ny
            vx = 0
            vy = 0
            mood = .startled
            lookAt = nil

        case .flee:
            mood = .startled
            lookAt = nil
            if species == .puffer { special = trickRamp(stateTime, stateDur) }
            steer(targetX, targetY, tr.speed * 2.8, dt)
            if stateTime > stateDur { enter(.idle, Double.random(in: 1...2)) }

        case .greet:
            slow(dt)
            mood = .happy
            hop = abs(sin(stateTime * 8)) * scale * max(0, 1 - stateTime / stateDur)
            if emitted == 0 && stateTime > 0.35 {
                emitted = 1
                emit(.heart, facing * 6, -13, vy: -11, life: 1.0)
            }
            if stateTime > stateDur { enter(.idle, Double.random(in: 1...3)) }

        case .tossed:
            if jumping { mood = .happy } else if stateTime < 0.5 { mood = .startled }
            if tr.floor {
                vy -= 2000 * dt
                if !jumping { slow(dt, 1.0) }
                // Land on top of the frontmost window if we fall onto it.
                if vy < 0, perchID == nil, clock > ignorePerchUntil, let w = app.frontWindow,
                   validPerch(w.rect, vf), x > w.rect.minX + 6 * scale, x < w.rect.maxX - 6 * scale {
                    let py = w.rect.maxY + 14 * scale
                    if prevY >= py && y <= py {
                        y = py
                        floorY = py
                        vx = 0
                        vy = 0
                        jumping = false
                        perchID = w.id
                        perchRect = w.rect
                        enter(.idle, 1)
                    }
                }
                if state == .tossed && y <= floorY && vy < 0 {
                    y = floorY
                    jumping = false
                    if vy < -300 {
                        vy = -vy * 0.3
                    } else {
                        vy = 0
                        enter(.idle, 1)
                    }
                }
            } else {
                slow(dt, 2.6)
                if hypot(vx, vy) < 25 || stateTime > stateDur { enter(.idle, Double.random(in: 1...2)) }
            }

        case .sleep:
            slow(dt)
            mood = .sleepy
            lookAt = nil
            emitTimer -= dt
            if emitTimer <= 0 {
                emitTimer = 1.3
                emit(.zzz, facing * 7, -11, vx: facing * 3, vy: -7, life: 1.8)
            }
            if !app.napTime && stateTime > stateDur {
                awake = 0
                enter(.idle, 2)
            }

        case .chase:
            if let f = food, !f.eaten, !f.expired {
                steer(f.x, f.y, tr.speed * 1.9, dt)
                lookAt = (f.x, f.y)
                if hypot(f.x - x, f.y - y) < 14 * scale {
                    f.eaten = true
                    enter(.eat, 1.3)
                }
            } else {
                enter(.idle, 1)
            }

        case .eat:
            slow(dt)
            mood = .eating
            emitTimer -= dt
            if emitTimer <= 0 && stateTime < 1.0 {
                emitTimer = 0.18
                emit(.crumb, facing * 10 + Double.random(in: -2...2), 2,
                     vx: Double.random(in: -6...6), vy: Double.random(in: 4...10), life: 0.5)
            }
            if stateTime > stateDur {
                emit(.heart, 0, -13, vy: -11, life: 1.0)
                awake = 0
                enter(.idle, 2)
            }
        }

        // Moon jellies glow softly at night.
        if night && species == .jelly && state != .sleep { special = max(special, 0.55) }

        // Integrate.
        prevY = y
        if state != .dragged {
            var mult = 1.0
            if state != .tossed && state != .trick {
                // Jellies and octopuses move in pulses, in time with their animation.
                if species == .jelly { mult = 0.45 + 1.1 * max(0, cos(cycle * 2.2)) }
                if species == .octopus { mult = 0.6 + 0.8 * max(0, cos(cycle * 2.5)) }
            }
            if menuOpen { mult = 0 }
            x += vx * mult * dt
            y += vy * mult * dt
            if tr.floor && state != .tossed { y += (floorY - y) * min(1, 12 * dt) }
            let minY = tr.floor ? floorY : Double(b.minY)
            if x < b.minX { x = b.minX; vx = abs(vx) * 0.5 }
            if x > b.maxX { x = b.maxX; vx = -abs(vx) * 0.5 }
            if y < minY { y = minY; vy = abs(vy) * 0.5 }
            if y > b.maxY { y = b.maxY; vy = -abs(vy) * 0.5 }
            if state != .curious && abs(vx) > 12 { facing = vx > 0 ? 1 : -1 }
        }

        let effort = state == .dragged ? 1.0 : min(1, hypot(vx, vy) / tr.speed)
        move += (effort - move) * min(1, 8 * dt)
        cycle += dt * (1 + 1.5 * move)

        if clock > blinkAt {
            blinkUntil = clock + 0.14
            blinkAt = clock + Double.random(in: 2...6)
        }

        // Sprite frames tick at 15 fps for a hand-animated feel (fewer when resting or
        // asleep, to save CPU); the window itself glides more smoothly.
        let fps = state == .sleep ? 5.0 : (state == .idle && move < 0.05 && particles.isEmpty ? 10.0 : 15.0)
        let frame = Int(clock * fps)
        if frame != lastFrame {
            lastFrame = frame
            stepParticles(lastRender < 0 ? 1.0 / 15 : min(0.3, clock - lastRender))
            lastRender = clock
            var pose = Pose(t: clock, cycle: cycle, move: move, mood: mood)
            pose.special = special
            pose.blink = clock < blinkUntil
            if let (lx, ly) = lookAt {
                let sx = lx - x > 24 ? 1 : (lx - x < -24 ? -1 : 0)
                pose.lookX = sx * Int(facing)
                pose.lookY = ly - y > 40 ? -1 : (ly - y < -40 ? 1 : 0)
            } else if move > 0.3 {
                pose.lookX = 1
            }
            // The gentle bob is drawn inside the sprite (whole pixels), so a pet that is
            // hovering in place never has to move its window.
            let bobAmp = tr.floor || state == .dragged ? 0.0 : (state == .sleep ? 0.6 : 1.0)
            bob = Int((sin(clock * 1.7 + phase) * bobAmp).rounded())
            render(pose)
        }

        let side = 64 * scale
        let oxp = x - side / 2, oyp = y - side / 2 + hop
        let o = NSPoint(x: (oxp * 2).rounded() / 2, y: (oyp * 2).rounded() / 2)
        if o != lastOrigin || layer.superlayer == nil {
            lastOrigin = o
            // Live in the overlay of whichever screen we're on.
            let ov = app.overlay(atX: x, y: y)
            if layer.superlayer !== ov.root { ov.root.addSublayer(layer) }
            layer.position = CGPoint(x: o.x - ov.frame.minX, y: o.y - ov.frame.minY)
        }
        bubble?.update(x: x, y: y + 15 * scale + hop, alpha: alpha)
    }

    // MARK: Friends and perches

    private func validPerch(_ r: CGRect, _ vf: NSRect) -> Bool {
        r.width >= 200 && r.maxY <= vf.maxY - 36 * scale && r.maxY >= vf.minY + 50 * scale
            && r.maxX > vf.minX + 60 && r.minX < vf.maxX - 60
    }

    /// Crabs sometimes jump up onto the frontmost window, or hop back down.
    private func tryPerchHop(_ vf: NSRect) -> Bool {
        let app = AppDelegate.shared!
        if perchID != nil {
            guard Double.random(in: 0..<1) < 0.25 else { return false }
            perchID = nil
            perchRect = nil
            ignorePerchUntil = clock + 2
            vx = facing * 110
            vy = 380
            jumping = true
            enter(.tossed, 5)
            return true
        }
        guard app.perching, let w = app.frontWindow, validPerch(w.rect, vf),
              Double.random(in: 0..<1) < 0.35 else { return false }
        let lo = max(w.rect.minX + 14 * scale, vf.minX + 20 * scale)
        let hi = min(w.rect.maxX - 14 * scale, vf.maxX - 20 * scale)
        guard hi > lo else { return false }
        let tx = min(max(x + Double.random(in: -150...150), lo), hi)
        let py = w.rect.maxY + 14 * scale, g = 2000.0, over = 20.0
        guard abs(tx - x) < 800, py > y + 20 else { return false }
        vy = (2 * g * (py - y + over)).squareRoot()
        let t = vy / g + (2 * over / g).squareRoot()
        vx = (tx - x) / t
        jumping = true
        enter(.tossed, 6)
        return true
    }

    /// Sometimes head for another pet instead of a random spot; small fish school together.
    private func visitFriend(_ b: NSRect) {
        guard !species.traits.floor else { return }
        let others = AppDelegate.shared.pets.filter { $0 !== self && !$0.species.traits.floor && $0.state != .sleep }
        var pool = others
        var chance = 0.3
        if species.isSmallFish {
            let school = others.filter { $0.species.isSmallFish }
            if !school.isEmpty {
                pool = school
                chance = 0.65
            }
        }
        guard Double.random(in: 0..<1) < chance, let o = pool.randomElement() else { return }
        targetX = min(max(o.x - o.facing * 28 * scale + Double.random(in: -20...20), b.minX), b.maxX)
        targetY = min(max(o.y + Double.random(in: -25...25), b.minY), b.maxY)
    }

    private func socialise(_ dt: Double, _ app: AppDelegate) {
        socialCooldown -= dt
        fleeCooldown -= dt
        guard state == .idle || state == .wander else { return }
        for o in app.pets where o !== self {
            let dx = x - o.x, dy = y - o.y, d = max(1, hypot(dx, dy))
            // Small fish bolt when the shark gets close.
            if species.isSmallFish && o.species == .shark && d < 55 * scale && fleeCooldown <= 0 && o.state != .sleep {
                fleeCooldown = 10
                targetX = x + dx / d * 400
                targetY = y + dy / d * 250
                emit(.bang, 10, -17, vy: -5, life: 0.7)
                enter(.flee, 1.5)
                return
            }
            if d < 30 * scale && socialCooldown <= 0 && o.socialCooldown <= 0 && o.isSociable {
                greet(o)
                o.greet(self)
                return
            }
            // Keep a little personal space so sprites don't stack.
            if !species.traits.floor && !o.species.traits.floor && d < 24 * scale {
                vx += dx / d * 60 * dt
                vy += dy / d * 60 * dt
            }
        }
    }

    func greet(_ o: PetController) {
        socialCooldown = Double.random(in: 40...70)
        facing = o.x > x ? 1 : -1
        let playful: Set<Species> = [.dolphin, .seal]
        if playful.contains(species) && playful.contains(o.species) {
            trick()   // these two show off for each other
        } else {
            enter(.greet, 1.8)
        }
    }

    // MARK: Drawing

    private func render(_ pose: Pose) {
        canvas.clear()
        canvas.ox = 8
        canvas.oy = 8 + bob
        species.draw(canvas, pose)
        recolor.apply(canvas)
        if facing < 0 { canvas.mirror() }
        for i in mask.indices { mask[i] = canvas.px[i] >> 24 > 0 }
        canvas.ox = 0
        canvas.oy = 0
        drawParticles()
        DisplayColor.apply(canvas)
        layer.contents = canvas.makeImage(space: DisplayColor.space)
    }

    private func emit(_ kind: PKind, _ dx: Double, _ dy: Double, vx: Double = 0, vy: Double = 0, life: Double) {
        guard particles.count < 60 else { return }
        particles.append(Particle(kind: kind, x: 32 + dx, y: 32 + dy, vx: vx, vy: vy, life: life))
    }

    private func stepParticles(_ dt: Double) {
        for i in particles.indices {
            particles[i].age += dt
            if particles[i].kind == .bubble {
                particles[i].vx = sin(particles[i].age * 5 + particles[i].seed * 6) * 4
            }
            if particles[i].kind == .drop { particles[i].vy += 70 * dt }
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
        }
        particles.removeAll { $0.age >= $0.life }
    }

    private func drawParticles() {
        for p in particles {
            let f = p.age / p.life
            let a = UInt32(255 * min(1, (1 - f) / 0.3))
            let x = Int(p.x.rounded()), y = Int(p.y.rounded())
            switch p.kind {
            case .bubble:
                let map: [Character: Color] = ["o": rgb(0x6FC3F0, a), "W": rgb(0xFFFFFF, a), "-": rgb(0xD6F1FF, a * 150 / 255)]
                if p.seed < 0.45 {
                    canvas.stamp(["Wo", "oo"], x, y, map)
                } else {
                    canvas.stamp([".oo.", "oW-o", "o--o", ".oo."], x - 1, y - 1, map)
                }
            case .heart:
                canvas.stamp([".x.x.", "xWxxx", "xxxxx", ".xxx.", "..x.."], x - 2, y - 2,
                             ["x": rgb(0xFF5C8A, a), "W": rgb(0xFFD0DC, a)])
            case .zzz:
                let map: [Character: Color] = ["x": rgb(0x6C8CFF, a)]
                if f < 0.4 {
                    canvas.stamp(["xxx", ".x.", "xxx"], x, y, map)
                } else {
                    canvas.stamp(["xxxx", "..x.", ".x..", "xxxx"], x, y - 1, map)
                }
            case .ink:
                canvas.discBlend(p.x, p.y, 1.5 + 4 * f, rgb(0x2A1B3D, UInt32(190 * (1 - f))))
            case .sparkle:
                let col = p.seed < 0.5 ? rgb(0xFFE45C, a) : rgb(0xFFFFFF, a)
                if Int(p.age * 10) % 2 == 0 {
                    canvas.stamp([".x.", "xxx", ".x."], x - 1, y - 1, ["x": col])
                } else {
                    canvas.stamp(["..x..", ".....", "x.x.x", ".....", "..x.."], x - 2, y - 2, ["x": col])
                }
            case .bang:
                canvas.stamp(["xx", "xx", "xx", "..", "xx"], x, y, ["x": rgb(0xFF4D4D, a)])
            case .crumb:
                canvas.blend(x, y, rgb(0xD9843F, a))
            case .drop:
                canvas.blend(x, y, rgb(0xFFFFFF, a))
                canvas.blend(x, y + 1, rgb(0x8FD3F4, a))
            }
        }
    }
}

// MARK: - Food

final class Food {
    let layer: CALayer
    var x: Double, y: Double
    var eaten = false
    private var resting = 0.0, age = 0.0
    private let floorY: Double, side: Double
    private let seed = Double.random(in: 0..<6)

    var expired: Bool { resting > 18 }

    init(x: Double, y: Double, scale: Double) {
        self.x = x
        self.y = y
        side = 8 * scale
        floorY = AppDelegate.shared.visibleFrame(atX: x, y: y).minY + 5 * scale
        layer = makeSpriteLayer(side: side)
        let c = PixelCanvas(8, 8)
        c.ellipse(4, 4, 2.6, 2.6) { _, _, nx, ny in
            ny > 0.35 ? rgb(0xB5652B) : (ny < -0.3 && nx < 0.2 ? rgb(0xF7B777) : rgb(0xD9843F))
        }
        c.outline(rgb(0x5A3413))
        layer.contents = c.makeImage()
        place()
    }

    private func place() {
        let ov = AppDelegate.shared.overlay(atX: x, y: y)
        if layer.superlayer !== ov.root { ov.root.addSublayer(layer) }
        layer.position = CGPoint(x: ((x - side / 2) * 2).rounded() / 2 - ov.frame.minX,
                                 y: ((y - side / 2) * 2).rounded() / 2 - ov.frame.minY)
    }

    func tick(_ dt: Double, opacity: Double) {
        age += dt
        if y > floorY {
            y = max(floorY, y - 55 * dt)
            x += sin(age * 2.2 + seed) * 16 * dt
            place()
        } else {
            resting += dt
        }
        layer.opacity = Float((resting > 16 ? max(0, 1 - (resting - 16) / 2) : 1) * opacity)
    }

    func remove() { layer.removeFromSuperlayer() }
}
