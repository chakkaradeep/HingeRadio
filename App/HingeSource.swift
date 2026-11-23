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
}
