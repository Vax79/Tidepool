import AppKit
import ImageIO
import SwiftUI

/// Command-line helpers used by build.sh: the app icon and a sprite contact sheet.
enum DevTools {
    static func writePNG(_ image: CGImage, _ path: String) {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    /// Every species across a row of poses, for eyeballing the art.
    static func writeSheet(_ path: String) {
        var poses: [Pose] = []
        poses.append(Pose(t: 0.2, cycle: 0.2, move: 0.2))
        poses.append(Pose(t: 0.6, cycle: 1.1, move: 1, lookX: 1))
        poses.append(Pose(t: 1.0, cycle: 1.9, move: 1, lookX: -1, lookY: 1))
        poses.append(Pose(t: 1.3, cycle: 1.3, move: 0.3, mood: .happy))
        poses.append(Pose(t: 1.7, cycle: 1.7, move: 0, mood: .sleepy))
        poses.append(Pose(t: 2.0, cycle: 2.0, move: 1, mood: .startled))
        poses.append(Pose(t: 2.3, cycle: 2.3, move: 0, mood: .eating))
        var trickA = Pose(t: 2.6, cycle: 2.6, move: 0.2)
        trickA.special = 0.5
        poses.append(trickA)
        var trickB = Pose(t: 2.83, cycle: 2.9, move: 0.2)
        trickB.special = 1
        poses.append(trickB)

        let all = Species.allCases
        let sheet = PixelCanvas(48 * poses.count, 48 * all.count)
        for i in sheet.px.indices {
            let y = i / sheet.w
            sheet.px[i] = (y / 48) % 2 == 0 ? rgb(0x7FB7D9) : rgb(0xF2F2F2)
        }
        for (r, s) in all.enumerated() {
            for (col, pose) in poses.enumerated() {
                let c = PixelCanvas(48, 48)
                var p = pose
                if p.special > 0 { p.mood = s.trickMood }
                s.draw(c, p)
                for y in 0..<48 {
                    for x in 0..<48 where c.px[y * 48 + x] >> 24 > 0 {
                        sheet.blend(col * 48 + x, r * 48 + y, c.px[y * 48 + x])
                    }
                }
            }
        }
        writePNG(sheet.makeImage(scale: 4), path)
    }

    static func writeIcon(_ path: String) {
        let size = 1024
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        let rect = CGRect(x: 100, y: 100, width: 824, height: 824)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 186, cornerHeight: 186, transform: nil))
        ctx.clip()
        let colors = [CGColor(red: 0.62, green: 0.88, blue: 0.97, alpha: 1),
                      CGColor(red: 0.16, green: 0.47, blue: 0.80, alpha: 1)] as CFArray
        let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
        // Sandy floor.
        ctx.setFillColor(CGColor(red: 0.92, green: 0.85, blue: 0.66, alpha: 1))
        ctx.fill(CGRect(x: 100, y: 100, width: 824, height: 126))
        ctx.setFillColor(CGColor(red: 0.84, green: 0.76, blue: 0.54, alpha: 1))
        ctx.fill(CGRect(x: 100, y: 212, width: 824, height: 14))
        // Chunky pixel bubbles.
        let u = 14.0
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.75))
        for (bx, by, n) in [(742.0, 700.0, 3.0), (800.0, 600.0, 2.0), (700.0, 812.0, 2.0), (236.0, 760.0, 2.0)] {
            ctx.fill(CGRect(x: bx, y: by, width: u * n, height: u * n))
        }
        var pose = Pose(t: 0.4, cycle: 0.4, move: 0.6, mood: .happy)
        pose.special = 0.25
        let c = PixelCanvas(48, 48)
        Species.puffer.draw(c, pose)
        ctx.interpolationQuality = .none
        ctx.draw(c.makeImage(scale: 14), in: CGRect(x: 170, y: 190, width: 672, height: 672))
        if let img = ctx.makeImage() { writePNG(img, path) }
    }

    /// Renders the picker window to a PNG without needing screen-recording permission.
    static func snapshotPicker(_ path: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let model = TankModel()
        model.active = [.puffer, .crab]
        let host = NSHostingView(rootView: PickerView(model: model))
        let size = host.fittingSize
        let w = NSWindow(contentRect: NSRect(origin: NSPoint(x: -3000, y: -3000), size: size),
                         styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        w.contentView = host
        w.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        if let img = rep.cgImage { writePNG(img, path) }
    }

    /// Every species in each of its colour variants.
    static func writeVariants(_ path: String) {
        let all = Species.allCases
        let sheet = PixelCanvas(48 * 4, 48 * all.count)
        for i in sheet.px.indices { sheet.px[i] = (i / sheet.w / 48) % 2 == 0 ? rgb(0x7FB7D9) : rgb(0xF2F2F2) }
        for (r, s) in all.enumerated() {
            for (col, v) in s.variants.enumerated() {
                let c = PixelCanvas(48, 48)
                s.draw(c, Pose(t: 0.3, cycle: 0.3, move: 0.4))
                Recolor(v).apply(c)
                for y in 0..<48 {
                    for x in 0..<48 where c.px[y * 48 + x] >> 24 > 0 {
                        sheet.blend(col * 48 + x, r * 48 + y, c.px[y * 48 + x])
                    }
                }
            }
        }
        writePNG(sheet.makeImage(scale: 3), path)
    }
}
