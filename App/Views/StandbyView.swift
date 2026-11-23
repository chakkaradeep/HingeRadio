import SwiftUI
import UIKit
import RadioCore

/// Book, tent and shut: the station name, the line under it, the power and tuned lamps and the
/// frequency, with the side wheels (`SideWheels`) at the right edge, the same as on the flex
/// plate: volume (which is also power) above tuning. Switched off, the name and the line are
/// empty. `twoPanels` splits them left and right of a vertical fold, the wheels on the right.
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
            let wheels = SideWheels(model: model, em: Face.em(forWidth: metrics.short))
            Group {
                if twoPanels {
                    // The panels split the whole screen, so the fold stays on the centre line;
                    // each keeps to the safe area on its outer edge and clear of the fold.
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: metrics.gap) {
                            name(metrics)
                            subtitleAndLamp(metrics)
                        }
                        .animation(.easeOut(duration: 0.3), value: model.radio.powerOn)
                        .padding(EdgeInsets(top: insets.top + margin, leading: insets.leading + margin,
                                            bottom: insets.bottom + margin, trailing: Face.foldClearance + margin))
                        .frame(width: size.width / 2, height: size.height, alignment: .leading)
                        HStack(spacing: margin) {
                            VStack(alignment: .leading, spacing: metrics.gap) {
                                frequency(metrics)
                                unit(metrics)
                            }
                            .animation(.easeOut(duration: 0.3), value: model.radio.powerOn)
                            wheels
                        }
                        .padding(EdgeInsets(top: insets.top + margin, leading: Face.foldClearance + margin,
                                            bottom: insets.bottom + margin, trailing: insets.trailing + margin))
                        .frame(width: size.width / 2, height: size.height)
                    }
                } else {
                    HStack(spacing: margin) {
                        VStack(alignment: .leading, spacing: metrics.gap) {
                            name(metrics)
                            subtitleAndLamp(metrics)
                            Spacer(minLength: 0)
                            frequency(metrics)
                            unit(metrics)
                        }
                        .animation(.easeOut(duration: 0.3), value: model.radio.powerOn)
                        wheels
                    }
                    .padding(singlePanelPadding(size: size, insets: insets, margin: margin))
                    .frame(width: size.width, height: size.height)
                }
            }
        }
        .foregroundStyle(Face.ink)
    }

    /// The outer screen's camera sits in one corner, reaching about 66 pt in from both edges, and
    /// the safe area does not report it. Which corner depends on the way up, which is unreliable,
    /// so the single panel keeps both ends of its long side this far in.
    private static let cameraClearance: CGFloat = 80

    private func singlePanelPadding(size: CGSize, insets: EdgeInsets, margin: CGFloat) -> EdgeInsets {
        let end = Self.cameraClearance
        return size.width > size.height
            ? EdgeInsets(top: insets.top + margin, leading: max(insets.leading + margin, end),
                         bottom: insets.bottom + margin, trailing: max(insets.trailing + margin, end))
            : EdgeInsets(top: max(insets.top + margin, end), leading: insets.leading + margin,
                         bottom: max(insets.bottom + margin, end), trailing: insets.trailing + margin)
    }

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

    /// The frequency under the needle, as on the flex dial (the wheels tune here too). Its size
    /// is set from the widest reading, so it stays put while tuning across 100 MHz, and fits
    /// beside the wheels.
    private func frequency(_ metrics: Metrics) -> some View {
        let fitted = frequencySlot > 0 ? frequencySlot / Self.frequencyWidthPerPoint : metrics.frequency
        let size = min(metrics.frequency, fitted)
        return Text(String(format: "%.1f", model.radio.tuning.frequency))
            .font(.system(size: size, weight: .medium))
            .monospacedDigit()
            .tracking(-0.02 * size)
            .contentTransition(.identity)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .opacity(model.radio.powerOn ? 1 : 0.35)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { frequencySlot = $0 }
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
            .foregroundStyle(Face.muted)
            .opacity(model.radio.powerOn ? 1 : 0.35)
    }
}
