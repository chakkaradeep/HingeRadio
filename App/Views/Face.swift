import SwiftUI

/// Shared colours and sizes for the radio face. Colours are the same in light and dark mode.
enum Face {
    static let face = Color(hex: 0xF3F1EA)
    static let shade = Color(hex: 0xE4E1D8)
    static let ink = Color(hex: 0x161616)
    static let muted = Color(hex: 0x6A675F)
    static let needle = Color(hex: 0xFF5B1F)
    /// The power lamp, lit: a signal red, 4.4:1 against `face`.
    static let lampRed = Color(hex: 0xD7261E)
    /// The tuned lamp, lit: a signal green, 3.6:1 against `face`.
    static let lampGreen = Color(hex: 0x17913F)

    /// One em, as in the web mock: 5.8% of the screen half's width.
    static func em(forWidth width: CGFloat) -> CGFloat { width * 0.058 }

    /// The size of the small words printed on the plate (TUNING, BAND, the city keys): never
    /// under 13 pt.
    static func printed(em: CGFloat) -> CGFloat { max(13, 0.36 * em) }

    /// Clear band kept on each side of the fold line, in points.
    static let foldClearance: CGFloat = 14
}

extension Text {
    /// The plate's printed lettering: bold capitals, spaced out.
    func printed(size: CGFloat) -> some View {
        font(.system(size: size, weight: .bold)).tracking(0.12 * size)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
