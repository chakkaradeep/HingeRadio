import SwiftUI
import RadioCore

/// The tuned lamp: unlit when off or on static, a dim orange while tuning in, a steady glowing
/// orange when the station is playing. The line under the station name always says the same,
/// so the lamp is never the only signal.
struct LampLight: View {
    let lamp: Lamp
    let size: CGFloat
    /// The glow's blur radius when lit.
    let glow: CGFloat

    var body: some View {
        let lit: Double = switch lamp {
        case .off: 0
        case .seeking: 0.45
        case .locked: 1
        }
        Circle()
            .fill(Face.shade)
            .overlay(Circle().fill(Face.needle.opacity(lit)))
            .overlay(Circle().strokeBorder(Face.ink.opacity(lit == 0 ? 0.25 : 0), lineWidth: 1))
            .shadow(color: Face.needle.opacity(lamp == .locked ? 0.8 : 0), radius: glow)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
