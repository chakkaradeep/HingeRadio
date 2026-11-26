import SwiftUI
import UIKit
import RadioCore

/// The face for the phone fully open. The fold lies flat here, so the dial runs straight
/// across it: upright, the full height on the left; on its side, the full width along the top.
/// Tuning is the side wheel's, as on every other face; the dial only shows where the needle is,
/// with each station's call sign beside its dot.
struct FlatView: View {
    let model: RadioModel
    let about: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let insets = proxy.safeAreaInsets
            let em = Face.em(forWidth: min(size.width, size.height))
            if size.width > size.height {
                onItsSide(size: size, insets: insets, em: em)
            } else {
                upright(size: size, insets: insets, em: em)
            }
        }
        .foregroundStyle(Face.ink)
        .animation(.easeOut(duration: 0.3), value: model.radio.powerOn)
    }

    // MARK: - Upright

    private func upright(size: CGSize, insets: EdgeInsets, em: CGFloat) -> some View {
        let margin = 0.7 * em
        return HStack(alignment: .top, spacing: 1.1 * em) {
            TallDial(model: model, em: em, upright: true)
                .frame(width: 0.34 * size.width)
            VStack(alignment: .leading, spacing: 0.45 * em) {
                badge(em: em)
                cityLine(em: em)
                    .padding(.bottom, 0.3 * em)
                nameAndLine(em: em, nameSize: 1.45 * em, lines: 2)
                frequency(em: em, size: 2.1 * em)
                    .padding(.top, 0.2 * em)
                lamps(em: em)
                HStack(alignment: .top, spacing: 0.9 * em) {
                    GrilleView(em: em)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    SideWheels(model: model, em: em)
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 0.4 * em)
                BandSwitch(model: model, em: em)
                    .padding(.top, 0.3 * em)
            }
        }
        .padding(EdgeInsets(top: insets.top + margin, leading: insets.leading + margin,
                            bottom: insets.bottom + margin, trailing: insets.trailing + margin))
        .frame(width: size.width, height: size.height)
    }

    // MARK: - On its side

    /// The dial along the top; under it, as on the half-open plate and window: left of the fold
    /// the name, the speaker and the band switch under it; right of it the frequency over the
    /// lamps, and the wheels at the edge.
    private func onItsSide(size: CGSize, insets: EdgeInsets, em: CGFloat) -> some View {
        let margin = 0.7 * em
        let half = size.width / 2
        return VStack(spacing: 0.55 * em) {
            HStack(alignment: .firstTextBaseline) {
                badge(em: em)
                Spacer(minLength: 0)
                cityLine(em: em)
            }
            .padding(.horizontal, margin)
            TallDial(model: model, em: em, upright: false)
                .frame(height: 0.25 * size.height)
            // Each half keeps clear of the fold, the way the book face does.
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0.45 * em) {
                    nameAndLine(em: em, nameSize: 1.3 * em, lines: 1)
                    GrilleView(em: em)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 0.3 * em)
                    BandSwitch(model: model, em: em)
                }
                .padding(EdgeInsets(top: 0, leading: margin, bottom: 0, trailing: Face.foldClearance + margin))
                .frame(width: half - insets.leading - margin)
                HStack(alignment: .top, spacing: 0.9 * em) {
                    VStack(alignment: .trailing, spacing: 0.3 * em) {
                        frequency(em: em, size: 2.1 * em)
                        lamps(em: em)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    SideWheels(model: model, em: em)
                }
                .padding(EdgeInsets(top: 0, leading: Face.foldClearance + margin, bottom: 0, trailing: margin))
                .frame(width: half - insets.trailing - margin)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(EdgeInsets(top: insets.top + margin, leading: insets.leading + margin,
                            bottom: insets.bottom + margin, trailing: insets.trailing + margin))
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Parts

    private func badge(em: CGFloat) -> some View {
        BadgeView(height: 1.3 * em)
            .accessibilityElement()
            .accessibilityLabel("Hinge Radio")
            .accessibilityAction(named: "About the dial", about)
            .onLongPressGesture(perform: about)
    }

    /// The band, as on the flex header: the location arrow and the town on HERE.
    private func cityLine(em: CGFloat) -> some View {
        let size = 0.72 * em
        return HStack(alignment: .firstTextBaseline, spacing: 0.4 * size) {
            if let city = model.city, city.isHere {
                BandKey(city: city, size: Face.printed(em: em))
                    .foregroundStyle(Face.muted)
            }
            Text(model.city?.name.uppercased() ?? "")
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .font(.system(size: size, weight: .bold))
        .tracking(0.12 * size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.city?.spokenName ?? "")
    }

    /// The station's name with its line right under it. The block keeps the height of the longest
    /// name it allows, with any room left below the line, so nothing under it moves.
    private func nameAndLine(em: CGFloat, nameSize: CGFloat, lines: Int) -> some View {
        let display = model.display
        let subtitleSize = 0.74 * em
        let spacing = 0.15 * em
        let height = CGFloat(lines) * UIFont.systemFont(ofSize: nameSize, weight: .bold).lineHeight
            + spacing + UIFont.systemFont(ofSize: subtitleSize).lineHeight
        return VStack(alignment: .leading, spacing: spacing) {
            Text(display.title.isEmpty ? " " : display.title)
                .font(.system(size: nameSize, weight: .bold))
                .tracking(-0.02 * nameSize)
                .lineLimit(lines)
                .minimumScaleFactor(0.6)
            Text(display.subtitle.isEmpty ? " " : display.subtitle)
                .font(.system(size: subtitleSize))
                .foregroundStyle(Face.muted)
                .lineLimit(1)
        }
        .frame(height: height, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityHidden(display.title.isEmpty && display.subtitle.isEmpty)
    }

    private func frequency(em: CGFloat, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0.25 * em) {
            // Never on two lines: 107.1 shrinks to fit rather than wrap.
            Text(String(format: "%.1f", model.radio.tuning.frequency))
                .font(.system(size: size, weight: .medium))
                .monospacedDigit()
                .contentTransition(.identity)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("MHz")
                .printed(size: Face.printed(em: em))
                .foregroundStyle(Face.muted)
                .fixedSize()
        }
        .opacity(model.radio.powerOn ? 1 : 0.35)
        .accessibilityElement(children: .combine)
    }

    private func lamps(em: CGFloat) -> some View {
        LampPair(powerOn: model.radio.powerOn, display: model.display, lampSize: 0.42 * em, glow: 0.3 * em,
                 labelSize: Face.printed(em: em), spacing: 0.7 * em)
            .frame(height: 0.74 * em * 1.2)
    }
}

/// The dial glass drawn along the long side, each station's call sign beside its dot:
/// upright, 88 at the bottom and the names right of the dots; on its side, 88 on the left and the
/// names in one row above the dots.
///
/// The dial is a tape. Each station gets at least the room its name needs; where the band leaves
/// more, the tape keeps the band's own spacing. When the tape is longer than the glass, it slides
/// under a needle held in the middle (on its side, the fold), and stops at either end so 88 and
/// 108 sit at the glass's edges, where the needle goes on to them. Shows only: the side wheel
/// tunes.
struct TallDial: View {
    let model: RadioModel
    let em: CGFloat
    let upright: Bool

    var body: some View {
        let radio = model.radio
        let scale = radio.scale
        let marks = scale.marks
        let candidate = radio.powerOn ? radio.tuning.candidate?.callSign : nil
        let dead = radio.dead
        let needle = radio.tuning.needle
        let labelSize = max(12, 0.36 * em)
        let numberSize = max(13, 0.42 * em)
        let widths = marks.map { Self.nameWidth($0.station.callSign, labelSize: labelSize) }
        GeometryReader { proxy in
            let size = proxy.size
            let geometry = Geometry(size: size, inset: 0.9 * em, upright: upright, em: em, labelSize: labelSize)
            let view = geometry.length
            // The room each name needs along the dial: its height upright, its width on its side.
            let rooms = widths.map { Double(upright ? 1.3 * labelSize : $0 + 0.8 * em) }
            let tape = DialTape(positions: marks.map(\.position), rooms: rooms, view: Double(view))
            let offset = CGFloat(tape.offset(needle: needle))
            Canvas { context, _ in
                let along = { (position: Double) in geometry.along(CGFloat(tape.coordinate(position)) - offset) }
                let visible = { (point: CGFloat) in point > -2 * em && point < view + 4 * em }

                // Ticks every MHz, longer with a number every 4; a number too close to the last
                // one drawn is left out.
                var lastNumber = -CGFloat.infinity
                for mhz in 88...108 {
                    let major = mhz % 4 == 0
                    let point = along(scale.position(forFrequency: Double(mhz)))
                    guard visible(point) else { continue }
                    let tick = geometry.tick(at: point, length: major ? 0.55 * em : 0.3 * em)
                    context.fill(Path(tick), with: .color(Face.ink.opacity(major ? 0.85 : 0.4)))
                    if major, abs(point - lastNumber) >= 1.6 * numberSize {
                        lastNumber = point
                        let number = Text("\(mhz)")
                            .font(.system(size: numberSize, design: .monospaced))
                            .foregroundStyle(Face.muted)
                        let (at, anchor) = geometry.number(at: point)
                        context.draw(number, at: at, anchor: anchor)
                    }
                }

                // A dot and a name per station: the tape gives each its room.
                let dotSize = geometry.dotSize
                for (index, mark) in marks.enumerated() {
                    let point = along(mark.position)
                    guard visible(point) else { continue }
                    let isCandidate = mark.station.callSign == candidate
                    let isDead = dead.contains(mark.station.callSign)
                    let color = isCandidate ? Face.needle : Face.ink
                    var layer = context
                    layer.opacity = isDead ? 0.3 : 1
                    let center = geometry.dot(at: point)
                    layer.fill(Path(ellipseIn: CGRect(x: center.x - dotSize / 2, y: center.y - dotSize / 2,
                                                      width: dotSize, height: dotSize)), with: .color(color))
                    let name = layer.resolve(Text(mark.station.callSign)
                        .font(.system(size: labelSize, weight: .bold))
                        .tracking(0.04 * labelSize)
                        .foregroundStyle(color))
                    let (at, anchor) = geometry.label(at: point)
                    layer.draw(name, at: at, anchor: anchor)
                    if isDead {
                        layer.fill(Path(geometry.strike(at: point, width: widths[index])), with: .color(Face.ink))
                    }
                }

                // The needle.
                let needleRect = geometry.needle(at: along(needle))
                context.fill(Path(roundedRect: needleRect, cornerRadius: 1.25), with: .color(Face.needle))
            }
            .mask {
                // Where the tape goes on past the glass, its edge fades out.
                let fade = 2.8 * em / max(upright ? size.height : size.width, 1)
                let startFades = offset > 0.5
                let endFades = offset < CGFloat(tape.length) - view - 0.5
                LinearGradient(stops: [
                    .init(color: startFades ? .clear : .black, location: 0),
                    .init(color: .black, location: startFades ? fade : 0),
                    .init(color: .black, location: endFades ? 1 - fade : 1),
                    .init(color: endFades ? .clear : .black, location: 1),
                ], startPoint: upright ? .bottom : .leading, endPoint: upright ? .top : .trailing)
            }
        }
        .background(Face.shade, in: RoundedRectangle(cornerRadius: 0.7 * em))
        .clipShape(RoundedRectangle(cornerRadius: 0.7 * em))
        .opacity(model.radio.powerOn ? 1 : 0.35)
        .accessibilityHidden(true)
    }

    /// Each name's width at a label size, measured the first time it is asked for. It saves
    /// measuring names for the tape's rooms and the dead-station strike; drawing still lays out
    /// the visible text each frame.
    private static var nameWidths: [String: CGFloat] = [:]

    private static func nameWidth(_ callSign: String, labelSize: CGFloat) -> CGFloat {
        let key = "\(callSign)@\(labelSize)"
        if let width = nameWidths[key] { return width }
        let font = UIFont.systemFont(ofSize: labelSize, weight: .bold)
        let width = (callSign as NSString).size(withAttributes: [.font: font, .kern: 0.04 * labelSize]).width
        nameWidths[key] = width
        return width
    }

    /// Where things go along the dial and across it, upright or on its side.
    struct Geometry {
        let size: CGSize
        let inset: CGFloat
        let upright: Bool
        let em: CGFloat
        let labelSize: CGFloat

        var dotSize: CGFloat { 0.36 * em }
        /// The glass's length, less an inset at each end.
        var length: CGFloat { max((upright ? size.height : size.width) - 2 * inset, 0) }
        private var labelHeight: CGFloat { 1.2 * labelSize }
        /// Between a dot's edge and its name.
        private var labelGap: CGFloat { 0.3 * em }

        /// On the glass, for a distance along the tape from the glass's start (88's end).
        func along(_ distance: CGFloat) -> CGFloat {
            upright ? inset + length - distance : inset + distance
        }

        /// Across the dial. Upright: the ticks at the left edge, the numbers, then the dots and
        /// the names. On its side: the names, the dots, then the ticks with the numbers under them.
        private var dotAcross: CGFloat {
            upright ? tickBase + 2.6 * em : 0.5 * em + labelHeight + labelGap + dotSize / 2
        }
        /// Upright, where the ticks start; on its side, where the longest ticks end.
        private var tickBase: CGFloat {
            upright ? 0.5 * em : dotAcross + dotSize / 2 + 0.55 * em + 0.55 * em
        }

        func tick(at along: CGFloat, length: CGFloat) -> CGRect {
            upright ? CGRect(x: tickBase, y: along - 0.6, width: length, height: 1.2)
                    : CGRect(x: along - 0.6, y: tickBase - length, width: 1.2, height: length)
        }

        func number(at along: CGFloat) -> (CGPoint, UnitPoint) {
            upright ? (CGPoint(x: tickBase + 0.7 * em, y: along), .leading)
                    : (CGPoint(x: along, y: tickBase + 0.2 * em), .top)
        }

        func dot(at along: CGFloat) -> CGPoint {
            upright ? CGPoint(x: dotAcross, y: along) : CGPoint(x: along, y: dotAcross)
        }

        /// Upright, right of the dot; on its side, above it.
        func label(at along: CGFloat) -> (CGPoint, UnitPoint) {
            upright ? (CGPoint(x: dotAcross + dotSize / 2 + labelGap, y: along), .leading)
                    : (CGPoint(x: along, y: dotAcross - dotSize / 2 - labelGap), .bottom)
        }

        func strike(at along: CGFloat, width: CGFloat) -> CGRect {
            let (point, _) = label(at: along)
            return upright ? CGRect(x: point.x, y: along - 0.75, width: width, height: 1.5)
                           : CGRect(x: along - width / 2, y: point.y - labelHeight / 2 - 0.75, width: width, height: 1.5)
        }

        /// The needle. Upright, from the dial's edge to the dots; on its side, from the dots
        /// through the ticks and numbers.
        func needle(at along: CGFloat) -> CGRect {
            if upright {
                return CGRect(x: 0.2 * em, y: along - 1.25, width: dotAcross - 0.2 * em, height: 2.5)
            }
            let top = dotAcross + dotSize / 2 + 0.25 * em
            return CGRect(x: along - 1.25, y: top, width: 2.5, height: max(size.height - top - 0.35 * em, 0))
        }
    }
}
