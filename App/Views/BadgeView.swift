import SwiftUI

/// The maker's badge: "Hinge" in script over an underline that ends in the orange needle, with
/// RADIO in small capitals. Artwork from `tools/build_badge.py`. VoiceOver skips it unless a face
/// gives it a label.
struct BadgeView: View {
    let height: CGFloat

    /// The letters' baseline, down from the artwork's top, over its height.
    private nonisolated static let baseline: CGFloat = 44.0 / 64

    var body: some View {
        Image("Badge")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .alignmentGuide(.firstTextBaseline) { $0.height * Self.baseline }
            .alignmentGuide(.lastTextBaseline) { $0.height * Self.baseline }
            .accessibilityHidden(true)
    }
}
