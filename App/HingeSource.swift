import SwiftUI
import RadioCore

extension View {
    /// Feeds each hinge change into the model as a `HingeReading`.
    func hingeReadings(into model: RadioModel) -> some View {
        onHingeChange { _, context in
            guard let hinge = context.hinge else {
                model.hasHinge = false
                return
            }
            model.hasHinge = true
            model.hinge(HingeReading(angle: hinge.angle.degrees,
                                     isClosed: hinge.status == .closed,
                                     time: ProcessInfo.processInfo.systemUptime))
        }
    }

    /// On a device with no hinge, a horizontal drag across this view supplies the angle:
    /// `minAngle + x / width × (maxAngle − minAngle)`.
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
                let config = model.config
                let fraction = min(1, max(0, drag.location.x / width))
                model.hinge(HingeReading(angle: config.minAngle + fraction * (config.maxAngle - config.minAngle),
                                         isClosed: false,
                                         time: ProcessInfo.processInfo.systemUptime))
            }, isEnabled: !model.hasHinge)
    }
}
