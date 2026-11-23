import SwiftUI
import RadioCore

/// A small pilot lamp set into the face. Unlit, a pale recessed dot with a thin ring. Lit, a domed
/// lens: brightest just above centre, deeper at the rim, a pinpoint of reflection and a soft glow
/// on the face around it. `level` 0 is unlit, 1 fully lit, between is dim.
struct LampLight: View {
    let color: Color
    let level: Double
    let size: CGFloat
    /// The glow's blur radius at full light.
    let glow: CGFloat

    var body: some View {
        ZStack {
            // The recess: shaded, darker toward the top where the rim overhangs it.
            Circle()
                .fill(Face.shade)
                .overlay(
                    Circle().fill(LinearGradient(colors: [Face.ink.opacity(0.16), Face.ink.opacity(0)],
                                                 startPoint: .top, endPoint: .center))
                )
            // The lens.
            Circle()
                .fill(RadialGradient(colors: [color.mix(with: .white, by: 0.35), color, color.mix(with: Face.ink, by: 0.3)],
                                     center: UnitPoint(x: 0.42, y: 0.38),
                                     startRadius: 0, endRadius: 0.6 * size))
                .opacity(level)
            // A pinpoint of reflection, only on a lit lens.
            Ellipse()
                .fill(.white.opacity(0.7 * level))
                .frame(width: 0.3 * size, height: 0.2 * size)
                .offset(x: -0.14 * size, y: -0.2 * size)
                .blur(radius: 0.04 * size)
            Circle()
                .strokeBorder(Face.ink.opacity(0.28 - 0.12 * level), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .background {
            Circle()
                .fill(color.opacity(0.55 * level * level))
                .frame(width: size, height: size)
                .blur(radius: glow)
        }
        .accessibilityHidden(true)
    }
}

/// The two lamps with their printed names: POWER, red while the radio is on, and TUNED, green while
/// a station is playing and pulsing dimly green while it tunes in. VoiceOver reads each one.
struct LampPair: View {
    let powerOn: Bool
    let display: Display
    let lampSize: CGFloat
    let glow: CGFloat
    let labelSize: CGFloat
    var spacing: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: spacing) {
            lamp(name: "POWER", lit: powerOn) {
                LampLight(color: Face.lampRed, level: powerOn ? 1 : 0, size: lampSize, glow: glow)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Power")
            .accessibilityValue(powerOn ? "on" : "off")

            lamp(name: "TUNED", lit: display.lamp != .off) { tunedLamp }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(display.lamp == .locked ? "Tuned" : "Not tuned")
                .accessibilityValue(display.lamp == .locked ? display.title : "")
        }
        .animation(.easeOut(duration: 0.18), value: powerOn)
        .animation(.easeOut(duration: 0.25), value: display.lamp)
    }

    @ViewBuilder private var tunedLamp: some View {
        switch display.lamp {
        case .locked:
            LampLight(color: Face.lampGreen, level: 1, size: lampSize, glow: glow)
        case .seeking where !reduceMotion:
            // A slow dim breath while the station connects.
            TimelineView(.animation) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                LampLight(color: Face.lampGreen, level: 0.2 + 0.25 * (0.5 - 0.5 * cos(2 * .pi * phase)),
                          size: lampSize, glow: glow)
            }
        case .seeking:
            LampLight(color: Face.lampGreen, level: 0.35, size: lampSize, glow: glow)
        case .off:
            LampLight(color: Face.lampGreen, level: 0, size: lampSize, glow: glow)
        }
    }

    private func lamp(name: String, lit: Bool, @ViewBuilder light: () -> some View) -> some View {
        HStack(spacing: 0.55 * lampSize) {
            light()
            Text(name)
                .printed(size: labelSize)
                .foregroundStyle(lit ? Face.ink : Face.muted)
                .fixedSize()
        }
    }
}
