import CoreGraphics
import Foundation

/// 0xAARRGGBB, 0 = fully transparent.
typealias Color = UInt32

@inline(__always) func rgb(_ hex: UInt32, _ a: UInt32 = 255) -> Color {
    (min(a, 255) << 24) | (hex & 0xFFFFFF)
}

func mixHex(_ a: UInt32, _ b: UInt32, _ f: Double) -> UInt32 {
    func ch(_ s: UInt32) -> UInt32 {
        let x = Double((a >> s) & 0xFF), y = Double((b >> s) & 0xFF)
        return UInt32(x + (y - x) * max(0, min(1, f)))
    }
    return (ch(16) << 16) | (ch(8) << 8) | ch(0)
}

struct Pal {
    let base: Color, light: Color, dark: Color
}

/// A tiny software canvas. Everything in the app is drawn here at 1:1 and
/// scaled up with nearest-neighbour filtering so pixels stay crisp.
final class PixelCanvas {
    let w: Int, h: Int
    var px: [Color]
    var ox = 0, oy = 0

    init(_ w: Int, _ h: Int) {
        self.w = w
        self.h = h
        px = Array(repeating: 0, count: w * h)
    }

    func clear() {
        for i in px.indices { px[i] = 0 }
    }

    @inline(__always) func set(_ x: Int, _ y: Int, _ c: Color) {
        let X = x + ox, Y = y + oy
        if X >= 0 && X < w && Y >= 0 && Y < h { px[Y * w + X] = c }
    }

    func blend(_ x: Int, _ y: Int, _ c: Color) {
        let X = x + ox, Y = y + oy
        guard X >= 0 && X < w && Y >= 0 && Y < h else { return }
        let a = Double(c >> 24) / 255
        if a <= 0 { return }
        let i = Y * w + X
        let d = px[i]
        let da = Double(d >> 24) / 255
        let oa = a + da * (1 - a)
        func ch(_ s: UInt32) -> UInt32 {
            let sc = Double((c >> s) & 0xFF), dc = Double((d >> s) & 0xFF)
            return UInt32((sc * a + dc * da * (1 - a)) / oa)
        }
        px[i] = (UInt32(oa * 255) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0)
    }

    func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double,
                 _ shader: (Int, Int, Double, Double) -> Color?) {
        guard rx > 0, ry > 0 else { return }
        let x0 = Int(floor(cx - rx)), x1 = Int(ceil(cx + rx))
        let y0 = Int(floor(cy - ry)), y1 = Int(ceil(cy + ry))
        for y in y0...y1 {
            for x in x0...x1 {
                let nx = (Double(x) + 0.5 - cx) / rx, ny = (Double(y) + 0.5 - cy) / ry
                if nx * nx + ny * ny <= 1, let c = shader(x, y, nx, ny) { set(x, y, c) }
            }
        }
    }

    func disc(_ cx: Double, _ cy: Double, _ r: Double, _ c: Color) {
        ellipse(cx, cy, r, r) { _, _, _, _ in c }
    }

    func discBlend(_ cx: Double, _ cy: Double, _ r: Double, _ c: Color) {
        let x0 = Int(floor(cx - r)), x1 = Int(ceil(cx + r))
        let y0 = Int(floor(cy - r)), y1 = Int(ceil(cy + r))
        for y in y0...y1 {
            for x in x0...x1 {
                let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
                if dx * dx + dy * dy <= r * r { blend(x, y, c) }
            }
        }
    }

    /// Three-tone shaded blob: light band on top, dark band underneath.
    func blob(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ p: Pal) {
        ellipse(cx, cy, rx, ry) { _, _, nx, ny in
            let k = ny * 0.9 - nx * 0.15
            return k > 0.5 ? p.dark : (k < -0.55 ? p.light : p.base)
        }
    }

    func line(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ r: Double, _ c: Color) {
        let n = Int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in 0...n {
            let f = Double(i) / Double(n)
            let x = x0 + (x1 - x0) * f, y = y0 + (y1 - y0) * f
            if r <= 0.6 {
                set(Int(floor(x)), Int(floor(y)), c)
            } else {
                disc(x, y, r, c)
            }
        }
    }

    func poly(_ pts: [(Double, Double)], _ c: Color) {
        guard pts.count >= 3 else { return }
        let xs = pts.map { $0.0 }, ys = pts.map { $0.1 }
        let x0 = Int(floor(xs.min()!)), x1 = Int(ceil(xs.max()!))
        let y0 = Int(floor(ys.min()!)), y1 = Int(ceil(ys.max()!))
        for y in y0...y1 {
            for x in x0...x1 {
                let px = Double(x) + 0.5, py = Double(y) + 0.5
                var inside = false
                var j = pts.count - 1
                for i in 0..<pts.count {
                    let (xi, yi) = pts[i], (xj, yj) = pts[j]
                    if (yi > py) != (yj > py), px < (xj - xi) * (py - yi) / (yj - yi) + xi {
                        inside.toggle()
                    }
                    j = i
                }
                if inside { set(x, y, c) }
            }
        }
    }

    /// Paint a 1px outline around everything opaque drawn so far.
    func outline(_ c: Color, diagonal: Bool = false) {
        var out = px
        for y in 0..<h {
            for x in 0..<w where px[y * w + x] >> 24 == 0 {
                var hit = false
                for dy in -1...1 where !hit {
                    for dx in -1...1 where !(dx == 0 && dy == 0) {
                        if !diagonal && dx != 0 && dy != 0 { continue }
                        let X = x + dx, Y = y + dy
                        if X >= 0 && X < w && Y >= 0 && Y < h && px[Y * w + X] >> 24 > 127 {
                            hit = true
                            break
                        }
                    }
                }
                if hit { out[y * w + x] = c }
            }
        }
        px = out
    }

    func mirror() {
        for y in 0..<h {
            let row = y * w
            for x in 0..<(w / 2) { px.swapAt(row + x, row + w - 1 - x) }
        }
    }

    func stamp(_ rows: [String], _ x: Int, _ y: Int, _ map: [Character: Color]) {
        for (dy, row) in rows.enumerated() {
            for (dx, ch) in row.enumerated() {
                if let c = map[ch] { blend(x + dx, y + dy, c) }
            }
        }
    }

    func makeImage(scale s: Int = 1, space: CGColorSpace = PixelCanvas.colorSpace) -> CGImage {
        // Pixels are handed over as premultiplied BGRA (little-endian ARGB words), the
        // format Core Animation uses natively, so no per-frame conversion is needed.
        let W = w * s, H = h * s
        var data = [UInt32](repeating: 0, count: W * H)
        data.withUnsafeMutableBufferPointer { out in
            px.withUnsafeBufferPointer { src in
                for y in 0..<h {
                    for x in 0..<w {
                        var c = src[y * w + x]
                        let a = c >> 24
                        if a == 0 { continue }
                        if a != 255 {
                            let r = ((c >> 16) & 0xFF) * a / 255, g = ((c >> 8) & 0xFF) * a / 255, b = (c & 0xFF) * a / 255
                            c = (a << 24) | (r << 16) | (g << 8) | b
                        }
                        if s == 1 {
                            out[y * W + x] = c
                        } else {
                            for sy in 0..<s {
                                let row = (y * s + sy) * W + x * s
                                for sx in 0..<s { out[row + sx] = c }
                            }
                        }
                    }
                }
            }
        }
        let bytes = data.withUnsafeBufferPointer { Data(buffer: $0) }
        let provider = CGDataProvider(data: bytes as CFData)!
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        return CGImage(
            width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
            space: space, bitmapInfo: info,
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
}
