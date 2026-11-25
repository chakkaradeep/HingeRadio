import SwiftUI

/// Shown for the flat pose: the display's title and line under the badge.
struct PoseCard: View {
    let model: RadioModel
    let em: CGFloat

    var body: some View {
        let display = model.display
        VStack(spacing: 0.5 * em) {
            BadgeView(height: 2.2 * em)
                .accessibilityElement()
                .accessibilityLabel("Hinge Radio")
            Text(display.title)
                .font(.system(size: 1.0 * em, weight: .bold))
                .padding(.top, 0.6 * em)
            Text(display.subtitle)
                .font(.system(size: 0.74 * em))
                .foregroundStyle(Face.muted)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Face.ink)
        .padding(1.1 * em)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
