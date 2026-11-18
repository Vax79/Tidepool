import AppKit
import AVFoundation
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

final class TankModel: ObservableObject {
    @Published var active: Set<Species> = []
    @Published var revision = 0   // bumped when a name or colour changes
    var onToggle: ((Species) -> Void)?
    var onRename: ((Species) -> Void)?
    var onVariant: ((Species, Int) -> Void)?
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var shared: AppDelegate!

    let model = TankModel()
    private(set) var pets: [PetController] = []
    private var foods: [Food] = []
    private var overlays: [Overlay] = []
    private var statusItem: NSStatusItem!
    private var pickerWindow: NSWindow?
    private var timer: Timer?
    private var last = CACurrentMediaTime()
    private var lastMouse = NSEvent.mouseLocation
    private var mouseSpeed = 0.0
    private var fade = 1.0
    private var hidden = false
    private(set) var napTime = false
    private var manualPause = false

    /// The frontmost ordinary window of another app, in AppKit screen coordinates.
    private(set) var frontWindow: (id: CGWindowID, rect: CGRect)?
    private var windowPoll = 0.0
    private(set) var isNight = false
    private var clockPoll = 0.0
    private var activeTime = 0.0
    private var inputPoll = 0.0, idleAny = 0.0, idleKey = 99.0
    private var suspended = false
    private var skipTick = false
    var smoothMotion: Bool { flag("smoothMotion", default: false) }
    private let watcher = NotificationWatcher()
    private lazy var voice = AVSpeechSynthesizer()
    var notifyMode: NotifyMode { NotifyMode(rawValue: defaults.string(forKey: "notifyMode") ?? "") ?? .off }
    var speakAloud: Bool { flag("speakAloud", default: false) }

    private let defaults = UserDefaults.standard

    var scale: Int {
        let v = defaults.integer(forKey: "scale")
        return v == 0 ? 3 : v
    }
    var opacity: Double {
        let v = defaults.double(forKey: "opacity")
        return v == 0 ? 1 : max(0.15, min(1, v))
    }
    private func flag(_ key: String, default d: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? d : defaults.bool(forKey: key)
    }
    var edgesOnly: Bool { flag("edgesOnly", default: false) }
    var fadeTyping: Bool { flag("fadeTyping", default: true) }
    var perching: Bool { flag("perching", default: true) }
    var dayNight: Bool { flag("dayNight", default: true) }
    /// Minutes of continuous work before a pet suggests a break; 0 = off.
    var breakMinutes: Int {
        defaults.object(forKey: "breakMinutes") == nil ? 45 : defaults.integer(forKey: "breakMinutes")
    }

    private func rebuildOverlays() {
        overlays.forEach { $0.close() }
        overlays = NSScreen.screens.map { Overlay(screen: $0) }
        if hidden { overlays.forEach { $0.close() } }
        screenCache = []
        DisplayColor.refresh()
    }

    /// The overlay for the screen containing a point (or the first screen as a fallback).
    func overlay(atX x: Double, y: Double) -> Overlay {
        let p = NSPoint(x: x, y: y)
        return overlays.first { $0.frame.contains(p) } ?? overlays[0]
    }

    /// The topmost pet whose drawn pixels are under a screen point.
    func pet(at p: NSPoint) -> PetController? { pets.last { $0.hit(p) } }

    func applicationDidFinishLaunching(_ note: Notification) {
        rebuildOverlays()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.rebuildOverlays() }
        buildMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.statusIcon()
        statusItem.button?.toolTip = "Tidepool"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        model.onToggle = { [weak self] s in
            guard let self else { return }
            self.setActive(s, !self.model.active.contains(s))
        }
        model.onRename = { [weak self] s in self?.rename(s) }
        model.onVariant = { [weak self] s, i in self?.setVariant(s, i) }

        // Control-Option shortcuts that work from any app.
        Hotkeys.register(id: 1, key: kVK_ANSI_S) { [weak self] in
            let m = NSEvent.mouseLocation
            self?.dropFood(x: m.x, y: m.y)
        }
        Hotkeys.register(id: 2, key: kVK_ANSI_H) { [weak self] in self?.toggleHidden() }
        Hotkeys.register(id: 3, key: kVK_ANSI_P) { [weak self] in self?.togglePause() }

        let saved = defaults.stringArray(forKey: "active")
        let firstRun = saved == nil
        for s in (saved ?? [Species.puffer.rawValue]).compactMap(Species.init(rawValue:)) {
            setActive(s, true)
        }
        if firstRun || pets.isEmpty { showPicker() }

        watcher.onEvent = { [weak self] text in self?.announce(text) }
        watcher.setMode(notifyMode)

        // Do nothing at all while the display sleeps or another user is switched in.
        let wc = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            wc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in self?.suspended = true }
        }
        for n in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            wc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in self?.suspended = false }
        }

        let t = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        t.tolerance = 0.002
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPicker()
        return false
    }

    // MARK: Pets

    func setActive(_ s: Species, _ on: Bool) {
        if on {
            guard !pets.contains(where: { $0.species == s }) else { return }
            let p = PetController(species: s, scale: Double(scale))
            pets.append(p)
            if !hidden { p.show() }
        } else {
            pets.filter { $0.species == s }.forEach { $0.remove() }
            pets.removeAll { $0.species == s }
        }
        model.active = Set(pets.map { $0.species })
        defaults.set(pets.map { $0.species.rawValue }, forKey: "active")
    }

    func setVariant(_ s: Species, _ i: Int) {
        s.setVariantIndex(i)
        pets.first { $0.species == s }?.reloadLook()
        model.revision += 1
    }

    func rename(_ s: Species) {
        let alert = NSAlert()
        alert.messageText = "Rename \(s.displayName) the \(s.kind)"
        alert.informativeText = "Leave it empty to go back to \(s.name)."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 230, height: 24))
        field.stringValue = s.displayName
        field.placeholderString = s.name
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = String(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        s.setCustomName(name.isEmpty ? nil : name)
        model.revision += 1
        pets.first { $0.species == s }?.say("Call me \(s.displayName)!", seconds: 4)
    }

    /// Screen geometry, refreshed once a second rather than asked for by every pet every frame.
    private var screenCache: [(frame: NSRect, visible: NSRect)] = []
    private var screenPoll = 0.0

    func visibleFrame(atX x: Double, y: Double) -> NSRect {
        let p = NSPoint(x: x, y: y)
        if let s = screenCache.first(where: { $0.frame.contains(p) }) { return s.visible }
        return screenCache.first?.visible ?? NSScreen.screens[0].visibleFrame
    }

    func nearestFood(_ x: Double, _ y: Double) -> Food? {
        var best: Food?
        var bestD = 1600.0
        for f in foods where !f.eaten && !f.expired {
            let d = hypot(f.x - x, f.y - y)
            if d < bestD {
                bestD = d
                best = f
            }
        }
        return best
    }

    func dropFood(x: Double, y: Double) {
        guard !hidden, !manualPause, foods.count < 12 else { return }
        foods.append(Food(x: x, y: y, scale: Double(scale)))
    }

    private func queryFrontWindow() -> (id: CGWindowID, rect: CGRect)? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        let me = Int(getpid())
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        for w in list {
            guard (w[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  (w[kCGWindowOwnerPID as String] as? NSNumber)?.intValue != me,
                  ((w[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0.1,
                  let id = (w[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let bd = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: bd as CFDictionary),
                  r.width >= 200, r.height >= 100 else { continue }
            return (id, CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height))
        }
        return nil
    }

    private static let breakLines = [
        "You've been busy a while. Quick stretch?",
        "Time to rest your eyes for a minute?",
        "Water break? I'll wait here.",
        "Nice work! How about a short break?",
    ]

    private func remindBreak() {
        guard !hidden, !manualPause, let p = pets.filter({ $0.state != .dragged }).randomElement() else { return }
        p.remind(Self.breakLines.randomElement()!)
    }

    /// A pet perks up and says `text`; optionally it is also read aloud.
    private func announce(_ text: String) {
        guard !hidden, !manualPause, !suspended else { return }
        let awake = pets.filter { $0.state != .dragged && $0.state != .sleep }
        guard let p = awake.randomElement() ?? pets.randomElement() else { return }
        p.react(text)
        if speakAloud { voice.speak(AVSpeechUtterance(string: text)) }
    }

    @objc private func tick() {
        // Every on-screen change makes the system redraw, so by default pets update 30
        // times a second. Holding or tossing a pet, or "Smoother Motion", uses all 60.
        skipTick.toggle()
        if skipTick && !smoothMotion && !pets.contains(where: { $0.isHandled }) { return }
        let now = CACurrentMediaTime()
        let dt = min(0.05, now - last)
        last = now
        guard dt > 0, !suspended else { return }
        let mouse = NSEvent.mouseLocation
        let sp = hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y) / dt
        mouseSpeed += (sp - mouseSpeed) * min(1, 6 * dt)
        lastMouse = mouse

        // Break reminders: count time at the keyboard/mouse; three idle minutes resets it.
        // (Input idle times are sampled four times a second, not every frame.)
        inputPoll -= dt
        if inputPoll <= 0 {
            inputPoll = 0.25
            idleAny = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
            idleKey = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        }
        let idle = idleAny
        if idle > 180 { activeTime = 0 } else if idle < 60 { activeTime += dt }
        if breakMinutes > 0 && activeTime > Double(breakMinutes) * 60 {
            activeTime = 0
            remindBreak()
        }
        guard !hidden else { return }

        screenPoll -= dt
        if screenPoll <= 0 || screenCache.isEmpty {
            screenPoll = 1
            var list = NSScreen.screens.map { (frame: $0.frame, visible: $0.visibleFrame) }
            // Keep the main screen first so off-screen pets fall back to it.
            if let m = NSScreen.main, let i = list.firstIndex(where: { $0.frame == m.frame }), i != 0 { list.swapAt(0, i) }
            screenCache = list
        }
        clockPoll -= dt
        if clockPoll <= 0 {
            clockPoll = 30
            let hour = Calendar.current.component(.hour, from: Date())
            isNight = dayNight && (hour >= 21 || hour < 6)
        }
        windowPoll -= dt
        if windowPoll <= 0 {
            // Asking the system for the window list is costly, so only do it for crabs,
            // and only often while one is standing on a window or in mid-air.
            let crabs = pets.filter { $0.species.traits.floor }
            windowPoll = crabs.contains { $0.wantsFreshWindows } ? 0.2 : 1.0
            frontWindow = (perching && !crabs.isEmpty && !manualPause) ? queryFrontWindow() : nil
        }

        // Go ghostly while the user is typing so pets never cover the words.
        let targetFade = (fadeTyping && idleKey < 1.2) ? 0.3 : 1.0
        fade += (targetFade - fade) * min(1, (targetFade < fade ? 8 : 3) * dt)

        for p in pets {
            p.alpha = fade * opacity
            if manualPause { p.tickPaused(dt: dt) } else { p.tick(dt: dt, mouse: mouse, mouseSpeed: mouseSpeed) }
        }
        for o in overlays { o.setCapture(o.frame.contains(mouse) && pets.contains { $0.wantsMouse }) }
        if manualPause { return }
        for f in foods { f.tick(dt, opacity: opacity) }
        foods.filter { $0.eaten || $0.expired }.forEach { $0.remove() }
        foods.removeAll { $0.eaten || $0.expired }
    }

    // MARK: Menus

    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Tidepool", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        main.addItem(fileItem)
        // An Edit menu so cut/copy/paste work in the rename field.
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func add(_ title: String, _ sel: Selector, on: Bool? = nil, key: String = "", flag: String? = nil,
                 to m: NSMenu? = nil) -> NSMenuItem {
            let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            it.target = self
            if !key.isEmpty { it.keyEquivalentModifierMask = [.control, .option] }
            if let on { it.state = on ? .on : .off }
            it.representedObject = flag
            (m ?? menu).addItem(it)
            return it
        }
        if manualPause {
            let head = NSMenuItem(title: "Paused", action: nil, keyEquivalent: "")
            head.isEnabled = false
            menu.addItem(head)
            menu.addItem(.separator())
        }
        _ = add("Choose Pets…", #selector(showPicker))
        let petsItem = NSMenuItem(title: "Pets", action: nil, keyEquivalent: "")
        let petsMenu = NSMenu()
        for s in Species.allCases {
            _ = add("\(s.displayName) the \(s.kind)", #selector(togglePet(_:)), on: model.active.contains(s),
                    flag: s.rawValue, to: petsMenu)
        }
        petsItem.submenu = petsMenu
        menu.addItem(petsItem)
        menu.addItem(.separator())
        // The shortcuts shown here are global: they work while any app is in front.
        _ = add("Drop a Snack at Cursor", #selector(dropSnack), key: "s")
        _ = add(napTime ? "Wake Everyone" : "Nap Time", #selector(toggleNap))
        _ = add(hidden ? "Show Pets" : "Hide Pets", #selector(toggleHidden), key: "h")
        _ = add("Pause Pets", #selector(togglePause), on: manualPause, key: "p")
        menu.addItem(.separator())
        menu.addItem(opacityItem())
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for (title, v) in [("Small", 2), ("Medium", 3), ("Large", 4)] {
            let it = add(title, #selector(setSize(_:)), on: scale == v, to: sizeMenu)
            it.tag = v
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)
        menu.addItem(.separator())
        _ = add("Stay Near Screen Edges", #selector(toggleFlag(_:)), on: edgesOnly, flag: "edgesOnly")
        _ = add("Smoother Motion (Uses More Energy)", #selector(toggleFlag(_:)), on: smoothMotion, flag: "smoothMotion")
        _ = add("Fade While I Type", #selector(toggleFlag(_:)), on: fadeTyping, flag: "fadeTyping")
        _ = add("Crabs Perch on Windows", #selector(toggleFlag(_:)), on: perching, flag: "perching")
        _ = add("Day and Night Behaviour", #selector(toggleFlag(_:)), on: dayNight, flag: "dayNight")
        let breakItem = NSMenuItem(title: "Break Reminders", action: nil, keyEquivalent: "")
        let breakMenu = NSMenu()
        for (title, v) in [("Off", 0), ("Every 20 Minutes", 20), ("Every 30 Minutes", 30),
                           ("Every 45 Minutes", 45), ("Every Hour", 60)] {
            let it = add(title, #selector(setBreak(_:)), on: breakMinutes == v, to: breakMenu)
            it.tag = v
        }
        breakMenu.addItem(.separator())
        _ = add("Preview a Reminder", #selector(previewBreak), to: breakMenu)
        breakItem.submenu = breakMenu
        menu.addItem(breakItem)
        let noteItem = NSMenuItem(title: "Notification Reactions", action: nil, keyEquivalent: "")
        let noteMenu = NSMenu()
        for (title, m) in [("Off", NotifyMode.off), ("Dock Badge Counts", .badges), ("Banner Text (Accessibility)", .banners)] {
            _ = add(title, #selector(setNotifyMode(_:)), on: notifyMode == m, flag: m.rawValue, to: noteMenu)
        }
        noteMenu.addItem(.separator())
        if notifyMode == .banners && !AXIsProcessTrusted() {
            _ = add("Grant Accessibility Access…", #selector(grantAccessibility), to: noteMenu)
        }
        _ = add("Read Aloud", #selector(toggleFlag(_:)), on: speakAloud, flag: "speakAloud", to: noteMenu)
        _ = add("Preview a Reaction", #selector(previewNotify), to: noteMenu)
        noteItem.submenu = noteMenu
        menu.addItem(noteItem)
        _ = add("Launch at Login", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Tidepool", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func togglePet(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let s = Species(rawValue: raw) else { return }
        setActive(s, !model.active.contains(s))
    }

    @objc func showPicker() {
        if pickerWindow == nil {
            let host = NSHostingController(rootView: PickerView(model: model))
            let w = NSWindow(contentViewController: host)
            w.title = "Tidepool"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.setContentSize(host.view.fittingSize)
            w.center()
            pickerWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        pickerWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func dropSnack() {
        // From the menu the cursor is up in the menu bar, so the snack sinks from the top.
        let m = NSEvent.mouseLocation
        let scr = NSScreen.screens.first { $0.frame.contains(m) } ?? NSScreen.main ?? NSScreen.screens[0]
        dropFood(x: m.x, y: min(m.y, scr.visibleFrame.maxY - 6))
    }

    @objc private func toggleNap() {
        napTime.toggle()
        pets.forEach { napTime ? $0.nap() : $0.wake() }
    }

    @objc private func toggleHidden() {
        hidden.toggle()
        pets.forEach { hidden ? $0.hide() : $0.show() }
        overlays.forEach { hidden ? $0.close() : $0.panel.orderFrontRegardless() }
        if hidden {
            foods.forEach { $0.remove() }
            foods.removeAll()
        }
    }

    @objc private func togglePause() {
        manualPause.toggle()
        statusItem.button?.appearsDisabled = manualPause
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        defaults.set(sender.tag, forKey: "scale")
        pets.forEach { $0.setScale(Double(sender.tag)) }
    }

    @objc private func toggleFlag(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        defaults.set(sender.state != .on, forKey: key)
        clockPoll = 0
    }

    @objc private func setBreak(_ sender: NSMenuItem) {
        defaults.set(sender.tag, forKey: "breakMinutes")
        activeTime = 0
    }

    @objc private func previewBreak() { remindBreak() }

    @objc private func setNotifyMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let m = NotifyMode(rawValue: raw) else { return }
        defaults.set(m.rawValue, forKey: "notifyMode")
        watcher.setMode(m)
        if m == .banners && !AXIsProcessTrusted() { grantAccessibility() }
    }

    /// Shows the system prompt that sends the user to Privacy & Security > Accessibility.
    @objc private func grantAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    @objc private func previewNotify() {
        announce(notifyMode == .banners ? "Sam: Lunch at one?" : "Something new in Mail!")
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nMoving Tidepool into your Applications folder and trying again usually fixes this."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    /// A live slider inside the menu; pets update as it is dragged.
    private func opacityItem() -> NSMenuItem {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 28))
        let label = NSTextField(labelWithString: "Opacity")
        label.font = NSFont.menuFont(ofSize: 0)
        label.frame = NSRect(x: 24, y: 5, width: 62, height: 18)
        let slider = NSSlider(value: opacity, minValue: 0.2, maxValue: 1, target: self,
                              action: #selector(opacityChanged(_:)))
        slider.isContinuous = true
        slider.controlSize = .small
        slider.frame = NSRect(x: 88, y: 4, width: 146, height: 20)
        v.addSubview(label)
        v.addSubview(slider)
        let item = NSMenuItem()
        item.view = v
        return item
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        defaults.set(sender.doubleValue, forKey: "opacity")
    }

    /// A little pixel fish for the menu bar, as a template image.
    static func statusIcon() -> NSImage {
        let c = PixelCanvas(16, 16)
        let k = rgb(0x000000)
        c.poly([(5.5, 8), (1, 4), (1, 12)], k)
        c.ellipse(9.5, 8, 5.5, 4) { _, _, _, _ in k }
        c.set(11, 6, 0)
        c.set(12, 6, 0)
        let img = NSImage(cgImage: c.makeImage(scale: 2), size: NSSize(width: 16, height: 16))
        img.isTemplate = true
        return img
    }
}
