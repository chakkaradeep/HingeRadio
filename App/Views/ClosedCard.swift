import SwiftUI

/// Shown for the shut and flat poses: the display's title and line under the app name.
struct ClosedCard: View {
    let model: RadioModel
    let em: CGFloat

    var body: some View {
        let display = model.display
        VStack(spacing: 0.5 * em) {
            Text("Hinge Radio")
                .font(.system(size: 1.6 * em, weight: .heavy))
                .tracking(-0.02 * 1.6 * em)
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
