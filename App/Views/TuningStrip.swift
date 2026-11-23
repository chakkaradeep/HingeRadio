import SwiftUI
import RadioCore

/// The scale on the lower half. Touching or dragging puts the needle under the finger.
struct TuningStrip: View {
    let model: RadioModel
    let em: CGFloat

    var body: some View {
        let inset = 0.7 * em
        GeometryReader { proxy in
            let span = proxy.size.width - 2 * inset
            ZStack(alignment: .topLeading) {
                ScaleFace(model: model, em: em)
                Circle()
                    .fill(Face.needle)
                    .overlay(Circle().strokeBorder(Face.face, lineWidth: 2))
                    .frame(width: 1.1 * em, height: 1.1 * em)
                    .position(x: inset + model.radio.tuning.needle * max(span, 0),
                              y: proxy.size.height * 0.5)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                guard span > 0 else { return }
                model.tune(toPosition: (drag.location.x - inset) / span)
            })
        }
        .frame(minHeight: max(60, 2.6 * em), maxHeight: .infinity)
        .background(Face.shade, in: RoundedRectangle(cornerRadius: 0.7 * em))
        .clipShape(RoundedRectangle(cornerRadius: 0.7 * em))
        .opacity(model.radio.powerOn ? 1 : 0.35)
        .accessibilityElement()
        .accessibilityLabel("Tuning")
        .accessibilityValue(String(format: "%.1f megahertz", model.radio.tuning.frequency))
    }
}
