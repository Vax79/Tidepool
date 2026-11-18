import AppKit
import ApplicationServices

enum NotifyMode: String {
    case off
    case badges    // watch Dock badge counts: no permission, no message text
    case banners   // read notification banners: needs Accessibility permission
}

/// Notices new notifications in one of two ways and reports a short line of
/// text for a pet to say. macOS offers no official API for this, so both
/// approaches are best-effort.
final class NotificationWatcher {
    var onEvent: ((String) -> Void)?

    private var mode = NotifyMode.off
    private var timer: Timer?

    // Badge mode
    private var badges: [String: Int] = [:]
    private var badgesPrimed = false
    private var badgeBusy = false
    private let queue = DispatchQueue(label: "tidepool.badges", qos: .utility)

    // Banner mode
    private var seenBanners: Set<String> = []
    private var bannersPrimed = false

    func setMode(_ m: NotifyMode) {
        mode = m
        timer?.invalidate()
        timer = nil
        badges = [:]
        badgesPrimed = false
        seenBanners = []
        bannersPrimed = false
        guard m != .off else { return }
        let t = Timer(timeInterval: m == .badges ? 5 : 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.mode == .badges { self.pollBadges() } else { self.pollBanners() }
        }
        t.tolerance = m == .badges ? 1 : 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: Dock badges

    /// Reads each running app's Dock badge with the system `lsappinfo` tool and
    /// reports when a count goes up. The first pass only records a baseline.
    private func pollBadges() {
        guard !badgeBusy else { return }
        let me = Bundle.main.bundleIdentifier
        let apps: [(id: String, name: String)] = NSWorkspace.shared.runningApplications.compactMap {
            guard $0.activationPolicy == .regular, let id = $0.bundleIdentifier, id != me else { return nil }
            return (id, $0.localizedName ?? id)
        }
        badgeBusy = true
        queue.async { [weak self] in
            var now: [String: Int] = [:]
            for app in apps { now[app.id] = Self.badgeCount(app.id) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.badgeBusy = false
                guard self.mode == .badges else { return }
                if self.badgesPrimed {
                    for app in apps {
                        let old = self.badges[app.id] ?? 0, new = now[app.id] ?? 0
                        if new > old {
                            let d = new - old
                            self.onEvent?(d == 1 ? "Something new in \(app.name)!" : "\(d) new things in \(app.name)!")
                            break   // one announcement per pass is plenty
                        }
                    }
                }
                self.badges = now
                self.badgesPrimed = true
            }
        }
    }

    private static func badgeCount(_ bundleID: String) -> Int {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/lsappinfo")
        p.arguments = ["info", "-only", "StatusLabel", "-app", bundleID]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return 0 }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        // Output looks like: "StatusLabel"={ "label"="3" }
        guard let out = String(data: data, encoding: .utf8),
              let r = out.range(of: "\"label\"=\"") else { return 0 }
        let label = out[r.upperBound...].prefix { $0 != "\"" }
        if label.isEmpty { return 0 }
        return Int(label.filter { $0.isNumber }) ?? 1   // a dot or other mark counts as one
    }

    // MARK: Banners (Accessibility)

    /// Looks at Notification Center's on-screen banners through the Accessibility
    /// API and reports the text of any that weren't there a second ago.
    private func pollBanners() {
        guard AXIsProcessTrusted(),
              let nc = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first
        else { return }
        let app = AXUIElementCreateApplication(nc.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.25)
        var current: [String] = []
        for w in Self.children(app, kAXWindowsAttribute) {
            var banners: [AXUIElement] = []
            Self.findBanners(w, 0, &banners)
            if banners.isEmpty { banners = [w] }
            for b in banners {
                var texts: [String] = []
                Self.collectText(b, 0, &texts)
                let line = texts.prefix(2).joined(separator: ": ")
                if !line.isEmpty { current.append(line) }
            }
        }
        let fresh = current.filter { !seenBanners.contains($0) }
        seenBanners = Set(current)
        // Opening the Notification Centre sidebar reveals a whole list at once; stay quiet for that.
        if bannersPrimed, let first = fresh.first, fresh.count <= 2 {
            onEvent?(first.count > 72 ? String(first.prefix(71)) + "…" : first)
        }
        bannersPrimed = true
    }

    private static func children(_ el: AXUIElement, _ attr: String) -> [AXUIElement] {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &ref) == .success else { return [] }
        return ref as? [AXUIElement] ?? []
    }

    private static func string(_ el: AXUIElement, _ attr: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &ref) == .success else { return nil }
        return ref as? String
    }

    private static func findBanners(_ el: AXUIElement, _ depth: Int, _ out: inout [AXUIElement]) {
        guard depth < 7, out.count < 12 else { return }
        if let sub = string(el, kAXSubroleAttribute),
           sub == "AXNotificationCenterBanner" || sub == "AXNotificationCenterAlert" {
            out.append(el)
            return
        }
        for c in children(el, kAXChildrenAttribute) { findBanners(c, depth + 1, &out) }
    }

    private static func collectText(_ el: AXUIElement, _ depth: Int, _ out: inout [String]) {
        guard depth < 7, out.count < 4 else { return }
        if string(el, kAXRoleAttribute) == (kAXStaticTextRole as String),
           let v = string(el, kAXValueAttribute)?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
            out.append(v)
        }
        for c in children(el, kAXChildrenAttribute) { collectText(c, depth + 1, &out) }
    }
}
