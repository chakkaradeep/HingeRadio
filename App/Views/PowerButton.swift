import SwiftUI

/// The round power button: a raised key with a green centre when on, grey when off.
struct PowerButton: View {
    let model: RadioModel
    /// Diameter in points.
    let size: CGFloat

    var body: some View {
        Button {
            model.togglePower()
        } label: {
            Circle()
                .fill(Face.shade)
                .background(Circle().fill(Color.black.opacity(0.2)).offset(y: 0.076 * size))
                .overlay(Circle().fill(model.radio.powerOn ? Face.lamp : Face.muted).padding(size * 0.32))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Power")
        .accessibilityAddTraits(model.radio.powerOn ? .isSelected : [])
    }
}
