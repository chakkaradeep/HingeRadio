import SwiftUI
import RadioCore

/// The signal lamp: grey when off, orange while seeking, green and glowing when locked.
struct LampLight: View {
    let lamp: Lamp
    let size: CGFloat
    /// The glow's blur radius when lit.
    let glow: CGFloat

    var body: some View {
        let colour: Color? = switch lamp {
        case .off: nil
        case .seeking: Face.needle
        case .locked: Face.lamp
        }
        Circle()
            .fill(colour ?? Face.shade)
            .overlay(Circle().strokeBorder(Color.black.opacity(colour == nil ? 0.2 : 0), lineWidth: 1))
            .shadow(color: colour ?? .clear, radius: glow)
            .frame(width: size, height: size)
    }
}
