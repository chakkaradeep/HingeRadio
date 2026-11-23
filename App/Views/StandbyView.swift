import SwiftUI
import RadioCore

/// Book and tent: the station name, the line under it, the frequency, the lamp and the power button.
/// `twoPanels` splits them left and right of a vertical fold.
///
/// Sizes come from the screen's short side, so the name and the frequency stay the two biggest
/// things and read from across a room. It lays itself out from the size it is given, so the outer
/// screen looks right whichever way up it reports.
struct StandbyView: View {
    let model: RadioModel
    let twoPanels: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let insets = proxy.safeAreaInsets
            let metrics = Metrics(short: min(size.width, size.height))
            let margin = metrics.margin
            Group {
                if twoPanels {
                    // The panels split the whole screen, so the fold stays on the centre line;
                    // each keeps to the safe area on its outer edge and clear of the fold.
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: metrics.gap) {
                            name(metrics)
                            subtitleAndLamp(metrics)
                        }
                        .padding(EdgeInsets(top: insets.top + margin, leading: insets.leading + margin,
                                            bottom: insets.bottom + margin, trailing: Face.foldClearance + margin))
                        .frame(width: size.width / 2, height: size.height, alignment: .leading)
                        VStack(alignment: .leading, spacing: metrics.gap) {
                            frequency(metrics)
                            unitAndPower(metrics)
                        }
                        .padding(EdgeInsets(top: insets.top + margin, leading: Face.foldClearance + margin,
                                            bottom: insets.bottom + margin, trailing: insets.trailing + margin))
                        .frame(width: size.width / 2, height: size.height, alignment: .leading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: metrics.gap) {
                        name(metrics)
                        subtitleAndLamp(metrics)
                        Spacer(minLength: 0)
                        frequency(metrics)
                        unitAndPower(metrics)
                    }
                    .padding(singlePanelPadding(size: size, insets: insets, margin: margin))
                    .frame(width: size.width, height: size.height, alignment: .leading)
                }
            }
        }
        .foregroundStyle(Face.ink)
        .animation(.easeOut(duration: 0.3), value: model.radio.powerOn)
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
        var power: CGFloat { max(60, 0.12 * short) }
        var gap: CGFloat { 0.03 * short }
        var margin: CGFloat { 0.06 * short }
    }

    private func name(_ metrics: Metrics) -> some View {
        Text(model.display.title)
            .font(.system(size: metrics.name, weight: .bold))
            .tracking(-0.01 * metrics.name)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func subtitleAndLamp(_ metrics: Metrics) -> some View {
        HStack(alignment: .center, spacing: metrics.gap) {
            Text(model.display.subtitle)
                .font(.system(size: metrics.subtitle))
                .foregroundStyle(Face.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            LampLight(lamp: model.display.lamp, size: metrics.lamp, glow: 0.55 * metrics.lamp)
        }
    }

    private func frequency(_ metrics: Metrics) -> some View {
        Text(String(format: "%.1f", model.radio.tuning.frequency))
            .font(.system(size: metrics.frequency, weight: .medium))
            .monospacedDigit()
            .tracking(-0.02 * metrics.frequency)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .opacity(model.radio.powerOn ? 1 : 0.35)
    }

    private func unitAndPower(_ metrics: Metrics) -> some View {
        HStack(alignment: .center, spacing: metrics.gap) {
            Text("MHz")
                .font(.system(size: metrics.unit, weight: .bold))
                .tracking(0.1 * metrics.unit)
                .foregroundStyle(Face.muted)
                .opacity(model.radio.powerOn ? 1 : 0.35)
            Spacer(minLength: 0)
            PowerButton(model: model, size: metrics.power)
        }
    }
}
