import SwiftUI
import UIKit
import RadioCore

/// Book, tent and shut: the station name, the line under it, the power and tuned lamps and the
/// frequency, with the side wheels (`SideWheels`) at the right edge, the same as on the flex
/// plate: volume (which is also power) above tuning. Switched off, the name and the line are
/// empty; the badge, low on the face, and the speaker grille stay. `twoPanels` splits them left
/// and right of a vertical fold, the wheels on the right.
///
/// Sizes come from the screen's short side, so the name and the frequency stay the two biggest
/// things and read from across a room. It lays itself out from the size it is given, so the outer
/// screen looks right whichever way up it reports.
struct StandbyView: View {
    let model: RadioModel
    let twoPanels: Bool

    /// The width the frequency has, beside the wheels.
    @State private var frequencySlot: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let insets = proxy.safeAreaInsets
            let metrics = Metrics(short: min(size.width, size.height))
            let margin = metrics.margin
            // The wheels' em, as flex works it out from the inner screen's width: the same
            // wheels there, a little smaller on the outer screen.
            let wheelsEm = Face.em(forWidth: metrics.short)
            Group {
                if twoPanels {
                    // The panels split the whole screen, so the fold stays on the centre line;
                    // each keeps to the safe area on its outer edge and clear of the fold. The
                    // wheels are centred top to bottom, and the name's and the frequency's cap
                    // tops sit on the same line as VOLUME's, so one top line runs across the fold.
                    let wheelsHeight = SideWheels.height(em: wheelsEm, tuning: Self.bookTuningHeight)
                    let top = max(insets.top + margin, (size.height - wheelsHeight) / 2)
                    // The grille, the badge and the tuning wheel end on one bottom line.
                    let wheels = min(wheelsHeight, size.height - top - insets.bottom - margin)
                    let panelBottom = size.height - top - wheels
                    let capLine = top + SideWheels.captionCapInset(em: wheelsEm)
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: metrics.gap) {
                            name(metrics)
                            subtitleAndLamp(metrics)
                            grille(em: wheelsEm, height: 0.21 * metrics.short)
                        }
                        .animation(.easeOut(duration: 0.3), value: model.radio.powerOn)
                        .padding(.top, capLine - Self.capInset(nameFont(size: metrics.name)))
                        .padding(EdgeInsets(top: 0, leading: insets.leading + margin,
                                            bottom: panelBottom, trailing: Face.foldClearance + margin))
                        .frame(width: size.width / 2, height: size.height, alignment: .topLeading)
                        HStack(alignment: .top, spacing: margin) {
                            VStack(alignment: .leading, spacing: metrics.gap) {
                                frequency(metrics)
                                unit(metrics)
                                Spacer(minLength: 0)
                                BadgeView(height: 0.11 * metrics.short)
                            }
                            .animation(.easeOut(duration: 0.3), value: model.radio.powerOn)
                            .padding(.top, capLine - top
                                     - Self.capInset(frequencyFont(size: frequencySize(metrics))))
                            SideWheels(model: model, em: wheelsEm, tuningMaxHeight: Self.bookTuningHeight)
                                .frame(height: wheels)
                        }
                        .padding(EdgeInsets(top: top, leading: Face.foldClearance + margin,
                                            bottom: panelBottom, trailing: insets.trailing + margin))
                        .frame(width: size.width / 2, height: size.height, alignment: .top)
                    }
                } else {
                    HStack(spacing: margin) {
                        VStack(alignment: .leading, spacing: metrics.gap) {
                            name(metrics)
                            subtitleAndLamp(metrics)
                            if size.width > size.height {
                                Spacer(minLength: 0)
                                frequencyAndGrille(metrics, em: wheelsEm)
                            } else {
                                grille(em: wheelsEm, height: 0.11 * metrics.short, fine: true)
                                frequency(metrics)
                            }
                            // An overlay, rising into the clear space under the figures, so the
                            // badge takes no height from the words.
                            unit(metrics)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(alignment: .bottomTrailing) { BadgeView(height: 0.12 * metrics.short) }
                        }
                        .animation(.easeOut(duration: 0.3), value: model.radio.powerOn)
                        SideWheels(model: model, em: wheelsEm)
                    }
                    .padding(singlePanelPadding(size: size, insets: insets, margin: margin))
                    .frame(width: size.width, height: size.height)
                }
            }
        }
        .foregroundStyle(Face.ink)
    }

    /// The book face's tuning wheel: a little taller than flex's, not the panel's full height.
    /// The gearing is per point, so this changes only how much of the band one height covers.
    private static let bookTuningHeight: CGFloat = 300

    /// The outer screen's camera sits in one corner, reaching about 66 pt in from both edges, and
    /// the safe area does not report it. Which corner depends on the way up, which is unreliable,
    /// so the single panel keeps both ends of its long side this far in.
    private static let cameraClearance: CGFloat = 80
    /// Where the wheels meet an end of the long side they keep further in, so the thumb rolling
    /// them (wider than the wheel) stays clear of the camera: about 38 pt between lens and wheel.
    private static let wheelCameraClearance: CGFloat = 104

    /// Landscape: the text keeps `cameraClearance` on the left, the wheels `wheelCameraClearance`
    /// on the right. Upright: the wheels run along the long side, so both its ends keep
    /// `wheelCameraClearance`, and the text lines up with them.
    private func singlePanelPadding(size: CGSize, insets: EdgeInsets, margin: CGFloat) -> EdgeInsets {
        size.width > size.height
            ? EdgeInsets(top: insets.top + margin, leading: max(insets.leading + margin, Self.cameraClearance),
                         bottom: insets.bottom + margin,
                         trailing: max(insets.trailing + margin, Self.wheelCameraClearance))
            : EdgeInsets(top: max(insets.top + margin, Self.wheelCameraClearance), leading: insets.leading + margin,
                         bottom: max(insets.bottom + margin, Self.wheelCameraClearance),
                         trailing: insets.trailing + margin)
    }

    /// From the top of a one-line text in `font` to its cap top.
    private static func capInset(_ font: UIFont) -> CGFloat { font.ascender - font.capHeight }

    /// Sizes from the screen's short side `s`.
    private struct Metrics {
        let short: CGFloat
        var name: CGFloat { 0.13 * short }
        var subtitle: CGFloat { 0.05 * short }
        var frequency: CGFloat { 0.22 * short }
        var unit: CGFloat { 0.05 * short }
        var lamp: CGFloat { 0.05 * short }
        var gap: CGFloat { 0.03 * short }
        var margin: CGFloat { 0.06 * short }
    }

    private func name(_ metrics: Metrics) -> some View {
        Text(model.display.title.isEmpty ? " " : model.display.title)
            .font(.system(size: metrics.name, weight: .bold))
            .tracking(-0.01 * metrics.name)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(model.display.title.isEmpty)
    }

    /// The line under the name, then the two lamps on a line of their own.
    private func subtitleAndLamp(_ metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.gap) {
            Text(model.display.subtitle.isEmpty ? " " : model.display.subtitle)
                .font(.system(size: metrics.subtitle))
                .foregroundStyle(Face.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityHidden(model.display.subtitle.isEmpty)
            LampPair(powerOn: model.radio.powerOn, display: model.display, lampSize: metrics.lamp,
                     glow: 0.6 * metrics.lamp, labelSize: max(13, 0.8 * metrics.unit), spacing: 1.4 * metrics.lamp)
        }
    }

    /// The speaker grille, the same size whatever the name, at the foot of the space left for it.
    /// Each face gives it the height a two-line name leaves.
    private func grille(em: CGFloat, height: CGFloat, fine: Bool = false) -> some View {
        GrilleView(em: em, minimum: Self.grilleMinimum, fine: fine, footed: true)
            .frame(maxWidth: .infinity, maxHeight: height)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .layoutPriority(-1)                 // the words take their height first
    }

    private static let grilleMinimum: CGFloat = 40

    /// On the long side: the frequency, with the grille as a tall strip in the width its widest
    /// reading leaves, standing on the figures' feet. An overlay, so it never pushes the words.
    private func frequencyAndGrille(_ metrics: Metrics, em: CGFloat) -> some View {
        let size = frequencySize(metrics)
        let left = frequencySlot - Self.frequencyWidthPerPoint * size - metrics.gap
        return frequency(metrics)
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .lastTextBaseline)) {
                GrilleView(em: em, minimum: Self.grilleMinimum, fine: true, footed: true)
                    .frame(width: max(0, left), height: 2 * frequencyFont(size: size).capHeight)
                    .alignmentGuide(.lastTextBaseline) { $0[.bottom] }
            }
    }

    /// The locked station's own frequency, else the needle's (flex's dial follows the needle). Its
    /// size is set from the widest reading, so it stays put across 100 MHz and fits beside the
    /// wheels.
    private func frequency(_ metrics: Metrics) -> some View {
        frequencyText(size: frequencySize(metrics))
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { frequencySlot = $0 }
    }

    /// The locked station's own frequency, otherwise the one under the needle, as it is while
    /// HERE's sweep passes its stations.
    private func frequencyText(size: CGFloat) -> some View {
        let tuning = model.radio.tuning
        let locked = model.radio.isScanning ? nil : tuning.locked
        return Text(String(format: "%.1f", locked?.frequency ?? tuning.frequency))
            .font(.system(size: size, weight: .medium))
            .monospacedDigit()
            .tracking(-0.02 * size)
            .contentTransition(.identity)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .opacity(model.radio.powerOn ? 1 : 0.35)
    }

    private func frequencySize(_ metrics: Metrics) -> CGFloat {
        let fitted = frequencySlot > 0 ? frequencySlot / Self.frequencyWidthPerPoint : metrics.frequency
        return min(metrics.frequency, fitted)
    }

    private func nameFont(size: CGFloat) -> UIFont { .systemFont(ofSize: size, weight: .bold) }
    private func frequencyFont(size: CGFloat) -> UIFont {
        .monospacedDigitSystemFont(ofSize: size, weight: .medium)
    }

    /// The width of the widest reading, "000.0", per point of font size.
    private static let frequencyWidthPerPoint: CGFloat = {
        let font = UIFont.monospacedDigitSystemFont(ofSize: 100, weight: .medium)
        let width = ("000.0" as NSString).size(withAttributes: [.font: font, .kern: -2]).width
        return ceil(width) / 100
    }()

    private func unit(_ metrics: Metrics) -> some View {
        Text("MHz")
            .font(.system(size: metrics.unit, weight: .bold))
            .tracking(0.1 * metrics.unit)
            .fixedSize()
            .foregroundStyle(Face.muted)
            .opacity(model.radio.powerOn ? 1 : 0.35)
    }
}
