import SwiftUI
import RadioCore

extension View {
    /// Feeds each hinge change into the model: the angle in degrees and the status,
    /// or `nil, nil` when the phone has no hinge.
    func hingeReadings(into model: RadioModel) -> some View {
        onHingeChange { _, context in
            guard let hinge = context.hinge else {
                model.hinge(angle: nil, status: nil)
                return
            }
            let status: HingeStatus = hinge.status == .closed ? .closed
                : hinge.status == .fullyOpen ? .fullyOpen : .partiallyOpen
            model.hinge(angle: hinge.angle.degrees, status: status)
        }
    }

    /// A horizontal drag across this view tunes the dial: `x / width`, clamped by the model.
    func dragTuning(into model: RadioModel) -> some View {
        modifier(DragTuning(model: model))
    }
}

private struct DragTuning: ViewModifier {
    let model: RadioModel
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                guard width > 0 else { return }
                model.tune(toPosition: drag.location.x / width)
            })
    }
}
