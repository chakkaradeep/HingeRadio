import SwiftUI
import RadioCore

/// The lid: the badge and the city, the dial glass, then the station window with the frequency
/// and the power and tuned lamps.
struct DialView: View {
    let model: RadioModel
    let em: CGFloat

    var body: some View {
        let display = model.display
        VStack(alignment: .leading, spacing: 0.6 * em) {
            header(display)
            glass
                .opacity(model.radio.powerOn ? 1 : 0.35)
            window(display)
        }
        .padding(EdgeInsets(top: 0.9 * em, leading: 1.1 * em, bottom: 0.4 * em, trailing: 1.1 * em))
        .foregroundStyle(Face.ink)
        .animation(.easeOut(duration: 0.3), value: model.radio.powerOn)
    }

    // MARK: - Header

    private func header(_ display: Display) -> some View {
        let size = 0.72 * em
        return HStack(alignment: .firstTextBaseline, spacing: 0.6 * size) {
            BadgeView(height: 1.3 * em)
                .accessibilityElement()
                .accessibilityLabel("Hinge Radio")
            Spacer(minLength: 0)
            Text(model.city?.name.uppercased() ?? "")
                .lineLimit(1)
        }
        .font(.system(size: size, weight: .bold))
        .tracking(0.12 * size)
    }

    // MARK: - Glass

    private var glass: some View {
        ScaleFace(model: model, em: em)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Face.shade, in: RoundedRectangle(cornerRadius: 0.7 * em))
            .clipShape(RoundedRectangle(cornerRadius: 0.7 * em))
    }

    // MARK: - Window

    /// The station name over the line under it; on the right the frequency over the power and
    /// tuned lamps. Switched off, the name and the line are empty (the unlit power lamp says it),
    /// and keep their height so nothing moves.
    private func window(_ display: Display) -> some View {
        let printed = Face.printed(em: em)
        let on = model.radio.powerOn
        return HStack(alignment: .firstTextBaseline, spacing: 0.8 * em) {
            VStack(alignment: .leading, spacing: 0.1 * em) {
                Text(display.title.isEmpty ? " " : display.title)
                    .font(.system(size: 1.25 * em, weight: .bold))
                    .tracking(-0.01 * 1.25 * em)
                    .minimumScaleFactor(0.75)
                Text(display.subtitle.isEmpty ? " " : display.subtitle)
                    .font(.system(size: 0.74 * em))
                    .foregroundStyle(Face.muted)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityHidden(display.title.isEmpty)
            VStack(alignment: .trailing, spacing: 0.1 * em) {
                HStack(alignment: .firstTextBaseline, spacing: 0.25 * em) {
                    Text(String(format: "%.1f", model.radio.tuning.frequency))
                        .font(.system(size: 1.25 * em, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.identity)
                    Text("MHz")
                        .printed(size: printed)
                        .foregroundStyle(Face.muted)
                }
                .opacity(on ? 1 : 0.35)
                .accessibilityElement(children: .combine)
                LampPair(powerOn: on, display: display, lampSize: 0.42 * em, glow: 0.3 * em,
                         labelSize: printed, spacing: 0.7 * em)
                    .frame(height: 0.74 * em * 1.2)
            }
            .fixedSize()
        }
        .accessibilityElement(children: .contain)
    }
}
