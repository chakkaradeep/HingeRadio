import SwiftUI
import RadioCore

/// The dial magnified three times, sliding under a fixed pointer. Each station shows its call sign
/// and frequency; hatching marks the static between stations. Drag it, flick it, or tap a station.
struct TapeView: View {
    let model: RadioModel
    let em: CGFloat

    /// The dial position under the pointer when the current touch began; nil between touches.
    @State private var dragStart: Double?

    var body: some View {
        let inset = 0.7 * em
        GeometryReader { proxy in
            // The dial's scale spans the view less its inset; the tape is three times that.
            let tapeWidth = 3 * max(proxy.size.width - 2 * inset, 0)
            ZStack {
                tape(size: proxy.size, tapeWidth: tapeWidth)
                    .mask(fade)
                pointer(height: proxy.size.height)
            }
            .contentShape(Rectangle())
            .gesture(drag(width: proxy.size.width, tapeWidth: tapeWidth))
        }
        .frame(minHeight: max(60, 2.6 * em), maxHeight: .infinity)
        .background(Face.shade, in: RoundedRectangle(cornerRadius: 0.7 * em))
        .clipShape(RoundedRectangle(cornerRadius: 0.7 * em))
        .opacity(model.radio.powerOn ? 1 : 0.35)
        .accessibilityElement()
        .accessibilityLabel("Tuning")
        .accessibilityValue(String(format: "%.1f megahertz", model.radio.tuning.frequency))
    }

    // MARK: - Drawing

    private func tape(size: CGSize, tapeWidth: CGFloat) -> some View {
        let scale = model.radio.scale
        let needle = model.radio.tuning.needle
        let config = DialConfig()
        let zoneHalf = config.lockWidth / 2 / (config.maxAngle - config.minAngle) * tapeWidth
        let centre = size.width / 2
        let height = size.height
        let x = { (q: Double) in centre + (q - needle) * tapeWidth }
        let underPointer = model.radio.powerOn ? model.radio.tuning.candidate?.callSign : nil
        let callSize = 0.8 * em
        let frequencySize = 0.6 * em
        return Canvas { context, _ in
            // Hatching across the whole tape, with each station's zone left clear.
            var gaps = Path(CGRect(x: x(0), y: 0, width: x(1) - x(0), height: height))
            for mark in scale.marks {
                gaps = gaps.subtracting(Path(CGRect(x: x(mark.position) - zoneHalf, y: 0,
                                                    width: 2 * zoneHalf, height: height)))
            }
            var hatch = Path()
            let spacing = 0.45 * em
            var start = x(0) - height
            while start < x(1) {
                hatch.move(to: CGPoint(x: start, y: height))
                hatch.addLine(to: CGPoint(x: start + height, y: 0))
                start += spacing
            }
            context.drawLayer { layer in
                layer.clip(to: gaps)
                layer.stroke(hatch, with: .color(Face.ink.opacity(0.16)), lineWidth: 1)
            }

            // A short tick at each whole MHz along the bottom edge.
            for mhz in 88...108 {
                let tickX = x(scale.position(forFrequency: Double(mhz)))
                let tickHeight = height * 0.12
                context.fill(Path(CGRect(x: tickX - 0.5, y: height - tickHeight, width: 1, height: tickHeight)),
                             with: .color(Face.ink.opacity(0.55)))
            }

            // Each station: call sign over its frequency, centred on its mark. All call signs share
            // one size, the largest at which no two neighbours run together.
            let marks = scale.marks
            let widths = marks.map {
                context.resolve(Self.callText($0.station.callSign, size: callSize, dead: false, colour: Face.ink))
                    .measure(in: size).width
            }
            var fit: CGFloat = 1
            for i in marks.indices.dropFirst() {
                let room = CGFloat(marks[i].position - marks[i - 1].position) * tapeWidth - 0.4 * em
                let need = (widths[i] + widths[i - 1]) / 2
                if need > 0 { fit = min(fit, max(room, 0) / need) }
            }
            for mark in marks {
                let markX = x(mark.position)
                guard markX > -3 * em, markX < size.width + 3 * em else { continue }
                let station = mark.station
                let dead = model.radio.dead.contains(station.callSign)
                let current = station.callSign == underPointer
                let call = context.resolve(Self.callText(station.callSign, size: callSize * fit, dead: dead,
                                                         colour: current ? Face.needle : Face.ink))
                let frequency = context.resolve(
                    Text(String(format: "%.1f", station.frequency))
                        .font(.system(size: frequencySize, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(current ? Face.needle : Face.muted))
                context.opacity = dead ? 0.35 : 1
                context.draw(call, at: CGPoint(x: markX, y: height * 0.44), anchor: .bottom)
                context.draw(frequency, at: CGPoint(x: markX, y: height * 0.50), anchor: .top)
                context.opacity = 1
            }
        }
        .frame(width: size.width, height: height)
        .allowsHitTesting(false)
    }

    /// The call sign in bold, without its "-FM" suffix, which says nothing on an FM tape.
    private static func callText(_ callSign: String, size: CGFloat, dead: Bool, colour: Color) -> Text {
        let short = callSign.hasSuffix("-FM") ? String(callSign.dropLast(3)) : callSign
        return Text(short)
            .font(.system(size: size, weight: .bold))
            .strikethrough(dead)
            .foregroundStyle(colour)
    }

    /// Fixed in the centre, over the tape: a notched line from each edge, broken where the
    /// labels sit so the station under it stays readable.
    private func pointer(height: CGFloat) -> some View {
        let notch = 0.45 * em
        return VStack(spacing: 0) {
            Triangle().fill(Face.needle).frame(width: notch, height: 0.6 * notch)
            Rectangle().fill(Face.needle).frame(width: 2, height: max(0, 0.28 * height - 0.6 * notch))
            Spacer(minLength: 0)
            Rectangle().fill(Face.needle).frame(width: 2, height: max(0, 0.28 * height - 0.6 * notch))
            Triangle().fill(Face.needle).frame(width: notch, height: 0.6 * notch)
                .rotationEffect(.degrees(180))
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }

    /// The tape fades out toward both edges.
    private var fade: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0),
                               .init(color: .black, location: 0.18),
                               .init(color: .black, location: 0.82),
                               .init(color: .clear, location: 1)],
                       startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Touch

    /// Drag to slide the tape (left moves up the band); a fast release flicks on to a station;
    /// a touch that barely moves is a tap and glides to the station nearest it.
    private func drag(width: CGFloat, tapeWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard tapeWidth > 0 else { return }
                let start = dragStart ?? model.position
                if dragStart == nil { dragStart = start }
                model.tune(toPosition: start - drag.translation.width / tapeWidth)
            }
            .onEnded { drag in
                defer { dragStart = nil }
                guard tapeWidth > 0, let start = dragStart else { return }
                let marks = model.radio.scale.marks.map(\.position)
                let target: Double
                if hypot(drag.translation.width, drag.translation.height) < 6 {
                    let tapped = model.radio.tuning.needle + (drag.location.x - width / 2) / tapeWidth
                    guard let nearest = marks.min(by: { abs($0 - tapped) < abs($1 - tapped) }) else { return }
                    target = nearest
                } else {
                    target = flickTarget(from: model.position,
                                         predicted: start - drag.predictedEndTranslation.width / tapeWidth,
                                         marks: marks)
                }
                if target != model.position { model.glide(toPosition: target) }
            }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
