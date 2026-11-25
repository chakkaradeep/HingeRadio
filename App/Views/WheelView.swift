import SwiftUI

/// A ridged thumbwheel seen edge on: a tall rounded rim whose ridges roll with its value. Drag
/// up to raise the value, by an amount set by its `gearing`. Nothing turns until a
/// touch has moved `slop` from where it began. A touch that never got that far is a tap if it
/// lifts within `tapSlop` of where it began, and otherwise does nothing.
///
/// The wheel owns its gesture, so a touch keeps driving the wheel it started on wherever the
/// finger goes.
struct WheelView: View {
    /// 0...1.
    let value: Double
    /// How much of the 0...1 range a drag covers.
    let gearing: Gearing
    /// The value between two ridges: the step a tick marks, so each tick is a ridge going past.
    let ridge: Double
    /// A finger came down on the wheel (before any slop): a real wheel stops under the thumb.
    var onTouchDown: () -> Void = {}
    /// That finger left, or the system took the touch away.
    var onTouchUp: () -> Void = {}
    /// A new value while dragging.
    let onChange: (Double) -> Void
    /// The finger lifted after a drag, with the value the drag's momentum would carry it to.
    let onRelease: (_ predicted: Double) -> Void
    /// A tap, and whether it landed on the upper half.
    let onTap: (_ upperHalf: Bool) -> Void
    /// How far from its start, in points, a touch may lift and still be a tap (at most `slop`).
    var tapSlop: CGFloat = slop

    /// How far a touch must move, in points, before it turns the wheel.
    static let slop: CGFloat = 6

    /// The current drag, set once the touch has moved past `slop`: which touch it is (by its
    /// start location), the value then, and the vertical translation then, so the wheel turns
    /// from where it is rather than jumping by the slop.
    @State private var drag: Drag?
    /// The start of the touch already reported to `onTouchDown`.
    @State private var downAt: CGPoint?
    /// True while a finger is down. It resets by itself when the system cancels the gesture,
    /// which clears `drag` so no stale drag outlives its touch.
    @GestureState private var touching = false

    /// How far a drag turns the wheel.
    enum Gearing {
        /// One wheel height of drag covers this much of 0...1, whatever the height.
        case perHeight(Double)
        /// One point of drag covers this much of 0...1, whatever the height.
        case perPoint(Double)

        func perPoint(height: CGFloat) -> Double {
            switch self {
            case .perHeight(let span): height > 0 ? span / Double(height) : 0
            case .perPoint(let step): step
            }
        }
    }

    private struct Drag: Equatable { let location: CGPoint; let value: Double; let anchor: CGFloat }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            rim(size: size)
                .contentShape(Rectangle())
                .gesture(gesture(height: size.height))
        }
        .onChange(of: touching) { _, down in
            if !down { touchEnded() }
        }
        .onDisappear { touchEnded() }        // a fold can take the wheel from under the finger
        .accessibilityElement()
    }

    // MARK: - Drawing

    /// The rim: a cylinder seen side on. Ridges sit evenly round it, so they crowd together and
    /// fade toward the top and bottom where the surface turns away; the ends are shaded.
    private func rim(size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 0.4 * size.width, style: .continuous)
        return Canvas { context, canvas in
            let radius = canvas.height / 2
            let perPoint = gearing.perPoint(height: canvas.height)
            guard perPoint > 0 else { return }
            let pitch = max(3, CGFloat(ridge / perPoint))          // one tick step of travel
            let travel = CGFloat(value / perPoint)                 // surface moved by the value
            let phase = travel.truncatingRemainder(dividingBy: pitch)
            let arc = CGFloat.pi * radius
            var u = phase < 0 ? phase + pitch : phase
            while u < arc {
                let theta = u / radius - .pi / 2                 // -pi/2 at the bottom, pi/2 at the top
                let y = radius - radius * sin(theta)
                let facing = cos(theta)
                if facing > 0.08 {
                    let inset = 0.14 * canvas.width
                    let line = Path(CGRect(x: inset, y: y - 0.75, width: canvas.width - 2 * inset, height: 1.5))
                    context.fill(line, with: .color(Face.ink.opacity(0.55 * Double(facing))))
                }
                u += pitch
            }
        }
        .background(Face.shade)
        .overlay {
            LinearGradient(stops: [.init(color: Face.ink.opacity(0.24), location: 0),
                                   .init(color: Face.ink.opacity(0), location: 0.3),
                                   .init(color: Face.ink.opacity(0), location: 0.7),
                                   .init(color: Face.ink.opacity(0.24), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Face.ink.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Touch

    private func touchEnded() {
        if downAt != nil { onTouchUp() }
        drag = nil
        downAt = nil
    }

    private func gesture(height: CGFloat) -> some Gesture {
        let perPoint = gearing.perPoint(height: height)
        return DragGesture(minimumDistance: 0)
            .updating($touching) { _, down, _ in down = true }
            .onChanged { touch in
                guard height > 0 else { return }
                if downAt != touch.startLocation {
                    downAt = touch.startLocation
                    onTouchDown()
                }
                if drag?.location != touch.startLocation {
                    // Not yet a drag for this touch: wait until it passes the slop.
                    guard hypot(touch.translation.width, touch.translation.height) >= Self.slop else { return }
                    drag = Drag(location: touch.startLocation, value: value, anchor: touch.translation.height)
                }
                guard let drag else { return }
                onChange(drag.value - Double(touch.translation.height - drag.anchor) * perPoint)
            }
            .onEnded { touch in
                defer { drag = nil }
                guard height > 0 else { return }
                if let drag, drag.location == touch.startLocation {
                    onRelease(drag.value
                              - Double(touch.predictedEndTranslation.height - drag.anchor) * perPoint)
                } else if hypot(touch.translation.width, touch.translation.height) <= tapSlop {
                    onTap(touch.location.y < height / 2)
                }
            }
    }
}
