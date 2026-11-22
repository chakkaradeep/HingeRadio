#if targetEnvironment(simulator)
import SwiftUI

/// Simulator only: while showing, replaces hinge readings with the slider's angle.
struct DebugHingeSlider: View {
    let model: RadioModel
    let em: CGFloat

    var body: some View {
        let angle = model.debugAngle ?? model.angle
        HStack(spacing: 0.5 * em) {
            Slider(value: Binding(get: { angle }, set: { model.debugAngle = $0 }), in: 24...160, step: 0.5)
                .tint(Face.needle)
            Text(String(format: "%.1f° · %.1f MHz", angle, model.radio.tuning.frequency))
                .font(.system(size: 0.45 * em, design: .monospaced))
                .foregroundStyle(Face.muted)
                .fixedSize()
        }
        .padding(.horizontal, 1.1 * em)
        .padding(.vertical, 0.3 * em)
    }
}
#endif
