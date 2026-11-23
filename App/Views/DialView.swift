import SwiftUI
import RadioCore

/// The lid: name and city, the dial glass, then the station window with the frequency and the
/// tuned lamp.
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
                .opacity(model.radio.powerOn ? 1 : 0.35)
        }
        .padding(EdgeInsets(top: 0.9 * em, leading: 1.1 * em, bottom: 0.4 * em, trailing: 1.1 * em))
        .foregroundStyle(Face.ink)
        .animation(.easeOut(duration: 0.3), value: model.radio.powerOn)
    }

    // MARK: - Header

    private func header(_ display: Display) -> some View {
        let size = 0.72 * em
        return HStack(spacing: 0.6 * size) {
            Text("HINGE RADIO").lineLimit(1)
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

    /// The station name over the line under it; on the right the frequency over the tuned lamp.
    private func window(_ display: Display) -> some View {
        let printed = Face.printed(em: em)
        return HStack(alignment: .firstTextBaseline, spacing: 0.8 * em) {
            VStack(alignment: .leading, spacing: 0.1 * em) {
                Text(display.title)
                    .font(.system(size: 1.25 * em, weight: .bold))
                    .tracking(-0.01 * 1.25 * em)
                    .minimumScaleFactor(0.75)
                Text(display.subtitle)
                    .font(.system(size: 0.74 * em))
                    .foregroundStyle(Face.muted)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 0.1 * em) {
                HStack(alignment: .firstTextBaseline, spacing: 0.25 * em) {
                    Text(String(format: "%.1f", model.radio.tuning.frequency))
                        .font(.system(size: 1.25 * em, weight: .medium))
                        .monospacedDigit()
                    Text("MHz")
                        .printed(size: printed)
                        .foregroundStyle(Face.muted)
                }
                HStack(spacing: 0.3 * em) {
                    LampLight(lamp: display.lamp, size: 0.42 * em, glow: 0.25 * em)
                    Text("TUNED")
                        .printed(size: printed)
                        .foregroundStyle(display.lamp == .off ? Face.muted : Face.ink)
                }
                .frame(height: 0.74 * em * 1.2)
                .accessibilityHidden(true)
            }
            .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}
