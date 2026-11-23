import SwiftUI

/// A ridged thumbwheel seen edge on, half hidden behind the plate's right edge: the visible rim
/// is a tall rounded bar whose ridges roll with its value. Drag up to raise the value; one wheel
/// height of drag moves it by `span`. A touch that barely moves is a tap.
///
/// The wheel owns its gesture, so a touch keeps driving the wheel it started on wherever the
/// finger goes.
struct WheelView: View {
    /// 0...1.
    let value: Double
    /// How much of the 0...1 range one wheel height of drag covers.
    let span: Double
    /// A new value while dragging.
    let onChange: (Double) -> Void
    /// The finger lifted after a drag, with the value the drag's momentum would carry it to.
    let onRelease: (_ predicted: Double) -> Void
    /// A tap, and whether it landed on the upper half.
    let onTap: (_ upperHalf: Bool) -> Void

    /// Where the current touch began and the value then. Keyed by the touch's start location,
    /// so a touch whose gesture was cancelled never leaks into the next one.
    @State private var dragStart: DragStart?

    private struct DragStart { let location: CGPoint; let value: Double }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            rim(size: size)
                .contentShape(Rectangle())
                .gesture(drag(height: size.height))
        }
        .accessibilityElement()
    }

    // MARK: - Drawing

    /// The rim: a cylinder seen side on. Ridges sit evenly round it, so they crowd together and
    /// fade toward the top and bottom where the surface turns away; the ends are shaded.
    private func rim(size: CGSize) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 0.32 * size.width,
                                           bottomLeadingRadius: 0.32 * size.width,
                                           bottomTrailingRadius: 2, topTrailingRadius: 2)
        return Canvas { context, canvas in
            let radius = canvas.height / 2
            let pitch: CGFloat = 7                                 // ridge spacing round the rim
            let travel = CGFloat(value / span) * canvas.height     // surface moved by the value
            let phase = travel.truncatingRemainder(dividingBy: pitch)
            let arc = CGFloat.pi * radius
            var u = phase < 0 ? phase + pitch : phase
            while u < arc {
                let theta = u / radius - .pi / 2                 // -pi/2 at the bottom, pi/2 at the top
                let y = radius - radius * sin(theta)
                let facing = cos(theta)
                if facing > 0.08 {
                    let inset = 0.16 * canvas.width
                    let line = Path(CGRect(x: inset, y: y - 0.75, width: canvas.width - inset - 3, height: 1.5))
                    context.fill(line, with: .color(Face.ink.opacity(0.55 * Double(facing))))
                }
                u += pitch
            }
        }
        .background(Face.shade)
        .overlay {
            LinearGradient(stops: [.init(color: Face.ink.opacity(0.22), location: 0),
                                   .init(color: Face.ink.opacity(0), location: 0.3),
                                   .init(color: Face.ink.opacity(0), location: 0.7),
                                   .init(color: Face.ink.opacity(0.22), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .clipShape(shape)
        .overlay(shape.stroke(Face.ink.opacity(0.35), lineWidth: 1))
        .overlay(alignment: .trailing) {
            // The plate's edge, which the rest of the wheel sits behind.
            Rectangle().fill(Face.ink).frame(width: 2)
        }
    }

    // MARK: - Touch

    private func drag(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard height > 0 else { return }
                if dragStart?.location != drag.startLocation {        // a new touch
                    dragStart = DragStart(location: drag.startLocation, value: value)
                }
                guard let start = dragStart?.value else { return }
                onChange(start - Double(drag.translation.height / height) * span)
            }
            .onEnded { drag in
                defer { dragStart = nil }
                guard height > 0, let start = dragStart?.value,
                      dragStart?.location == drag.startLocation else { return }
                if hypot(drag.translation.width, drag.translation.height) < 6 {
                    onTap(drag.location.y < height / 2)
                } else {
                    onRelease(start - Double(drag.predictedEndTranslation.height / height) * span)
                }
            }
    }
}
