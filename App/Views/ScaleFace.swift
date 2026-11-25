import SwiftUI
import RadioCore

/// Ticks, numbers, station dots and the needle, filling its frame with a 0.7 em inset each side.
/// The dial glass on the top half draws the whole band with it.
struct ScaleFace: View {
    let model: RadioModel
    let em: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let inset = 0.7 * em
        GeometryReader { proxy in
            let width = max(proxy.size.width - 2 * inset, 0)
            let height = proxy.size.height
            ZStack(alignment: .topLeading) {
                scale(width: width, height: height, inset: inset)
                    .frame(width: proxy.size.width, height: height)
                marks(width: width, height: height, inset: inset)
                    .frame(width: proxy.size.width, height: height)
                Capsule()
                    .fill(Face.needle)
                    .frame(width: 2, height: height * 0.92)
                    .offset(x: inset + model.radio.tuning.needle * width - 1, y: height * 0.04)
            }
        }
    }

    /// A tick at each whole MHz from 88 to 108, taller with a number every 4 MHz.
    /// Where the stretched scale squeezes two numbers together, the later one is left out.
    private func scale(width: CGFloat, height: CGFloat, inset: CGFloat) -> some View {
        let dialScale = model.radio.scale
        let numberSize = 0.62 * em
        let numberGap = 2.6 * numberSize      // three monospaced digits plus a space
        return Canvas { context, _ in
            var lastNumberX = -CGFloat.infinity
            for mhz in 88...108 {
                let major = mhz % 4 == 0
                let x = inset + dialScale.position(forFrequency: Double(mhz)) * width
                let tickHeight = height * (major ? 0.26 : 0.14)
                let tickBottom = height * (1 - 0.34)
                context.fill(Path(CGRect(x: x - 0.5, y: tickBottom - tickHeight, width: 1, height: tickHeight)),
                             with: .color(Face.ink.opacity(major ? 0.9 : 0.45)))
                if major, x - lastNumberX >= numberGap {
                    lastNumberX = x
                    let number = Text("\(mhz)")
                        .font(.system(size: numberSize, design: .monospaced))
                        .foregroundStyle(Face.muted)
                    context.draw(number, at: CGPoint(x: x, y: height * (1 - 0.08)), anchor: .bottom)
                }
            }
        }
    }

    /// One dot per mark: orange for the candidate, struck through when dead. No labels; not tappable.
    /// As HERE's stations change, dots fade and grow in and slide to their new places (with Reduce
    /// Motion they only fade). Another band's dots are there at once: the id starts them afresh.
    private func marks(width: CGFloat, height: CGFloat, inset: CGFloat) -> some View {
        let dot = 0.4 * em
        let candidate = model.radio.powerOn ? model.radio.tuning.candidate?.callSign : nil
        let y = height * 0.16
        let full = width + 2 * inset
        return ZStack {
            ForEach(model.radio.scale.marks, id: \.station.callSign) { mark in
                let dead = model.radio.dead.contains(mark.station.callSign)
                let x = inset + mark.position * width
                Circle()
                    .fill(mark.station.callSign == candidate ? Face.needle : Face.ink)
                    .frame(width: dot, height: dot)
                    .overlay {
                        if dead {
                            Rectangle().fill(Face.ink).frame(width: dot * 2, height: 1.5)
                        }
                    }
                    .opacity(dead ? 0.3 : 1)
                    .position(x: x, y: y)
                    .animation(reduceMotion ? nil : Self.arrival, value: mark.position)
                    .transition(reduceMotion
                        ? AnyTransition.opacity
                        : .opacity.combined(with: .scale(scale: 0.01, anchor: UnitPoint(
                            x: full > 0 ? x / full : 0, y: 0.16))))
            }
        }
        .animation(Self.arrival, value: model.radio.scale.marks)
        .id(model.radio.cityID)
        .allowsHitTesting(false)
    }

    private static let arrival = Animation.easeOut(duration: 0.25)
}
