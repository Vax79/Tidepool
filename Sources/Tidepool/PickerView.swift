import SwiftUI

private func hex(_ v: UInt32) -> SwiftUI.Color {
    SwiftUI.Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

struct PickerView: View {
    @ObservedObject var model: TankModel
    private let cols = Array(repeating: GridItem(.fixed(200), spacing: 12), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Tidepool")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Twelve sea creatures. Pick a companion for your desktop, or a few.")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 30)
            .padding(.bottom, 20)

            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(Species.allCases) { s in
                        CreatureCard(species: s, isOn: model.active.contains(s), name: s.displayName,
                                     variant: s.variantIndex, toggle: { model.onToggle?(s) },
                                     rename: { model.onRename?(s) }, pick: { model.onVariant?(s, $0) })
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 2)
            }
            .frame(height: 560)

            HStack(spacing: 20) {
                hint("cursorarrow.click", "Click to pet")
                hint("cursorarrow.click.2", "Double-click for a trick")
                hint("hand.draw", "Drag to carry")
                hint("contextualmenu.and.cursorarrow", "Right-click for more")
                hint("keyboard", "⌃⌥S drops a snack anywhere")
            }
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .frame(width: 884)
    }

    private func hint(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}

private struct CreatureCard: View {
    let species: Species
    let isOn: Bool
    let name: String
    let variant: Int
    let toggle: () -> Void
    let rename: () -> Void
    let pick: (Int) -> Void
    @State private var hover = false
    @State private var trickStart: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [hex(0xA9E2F5), hex(0x4C9BD3)], startPoint: .top, endPoint: .bottom)
                Rectangle().fill(hex(0xEAD9A8)).frame(height: 20)
                Rectangle().fill(hex(0xD6C28A)).frame(height: 4)
                SpritePreview(species: species, variant: variant, excited: hover, trickStart: trickStart)
                    .offset(y: 6)
            }
            .frame(height: 116)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { trickStart = Date() }
            .help("Click to see \(name)'s trick: \(species.trickName)")

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(name)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                Text(species.kind)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(-1)
                Spacer(minLength: 0)
                Button(action: rename) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .controlSize(.small)
                .help("Rename \(name)")
            }
            HStack(spacing: 6) {
                ForEach(Array(species.variants.enumerated()), id: \.offset) { i, v in
                    Circle()
                        .fill(hex(Recolor(v).map(rgb(species.swatch)) & 0xFFFFFF))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(SwiftUI.Color.primary.opacity(i == variant ? 0.9 : 0.15),
                                                       lineWidth: i == variant ? 2 : 1))
                        .contentShape(Circle())
                        .onTapGesture { pick(i) }
                        .help(v.name)
                }
                Text(species.variants[variant].name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
            Text(species.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
                .fixedSize(horizontal: false, vertical: true)

            if isOn {
                Button(action: toggle) {
                    Label("On Desktop", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Send \(name) home")
            } else {
                Button(action: toggle) {
                    Label("Add to Desktop", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.large)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SwiftUI.Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isOn ? SwiftUI.Color.accentColor : SwiftUI.Color(nsColor: .separatorColor), lineWidth: isOn ? 2 : 1)
        )
        .onHover { hover = $0 }
    }
}

/// A live, animated sprite, drawn with the same code as the desktop pets.
private struct SpritePreview: View {
    let species: Species
    let variant: Int
    let excited: Bool
    let trickStart: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 15.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
            let trick = trickStart.map { tl.date.timeIntervalSince($0) } ?? 99
            // Pre-scaled 6x and shown at @2x, so every sprite pixel lands on whole screen pixels.
            Image(decorative: render(t, trick), scale: 2)
                .interpolation(.none)
                .frame(width: 144, height: 144)
                .offset(y: species.traits.floor ? 0 : (sin(t * 1.7) * 3).rounded())
        }
    }

    private func render(_ t: Double, _ trick: Double) -> CGImage {
        let move = excited ? 0.8 : 0.25
        var p = Pose(t: t, cycle: t * (1 + 1.5 * move), move: species.traits.floor && !excited ? 0 : move)
        p.blink = t.truncatingRemainder(dividingBy: 3.4) < 0.14
        p.mood = excited ? .happy : .calm
        let dur = species == .turtle ? 3.2 : 2.6
        if trick < dur {
            p.special = trickRamp(trick, dur)
            p.mood = species.trickMood
        }
        let c = PixelCanvas(48, 48)
        species.draw(c, p)
        Recolor(species.variants[variant]).apply(c)
        return c.makeImage(scale: 6)
    }
}
