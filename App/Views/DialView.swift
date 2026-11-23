import SwiftUI
import RadioCore

/// The lid: name, city, signal bars, lamp, the dial glass, then the station window.
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
        .padding(EdgeInsets(top: 0.9 * em, leading: 1.1 * em, bottom: 0.8 * em, trailing: 1.1 * em))
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
            bars(display.bars, height: size)
            LampLight(lamp: display.lamp, size: 0.75 * size, glow: 0.3 * em)
        }
        .font(.system(size: size, weight: .bold))
        .tracking(0.12 * size)
    }

    private func bars(_ lit: Int, height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 0.16 * height) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < lit ? Face.ink : Face.shade)
                    .frame(width: 0.22 * height, height: height * [0.30, 0.48, 0.66, 0.84, 1.0][index])
            }
        }
        .frame(height: height, alignment: .bottom)
    }

    // MARK: - Glass

    private var glass: some View {
        ScaleFace(model: model, em: em)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Face.shade, in: RoundedRectangle(cornerRadius: 0.7 * em))
            .clipShape(RoundedRectangle(cornerRadius: 0.7 * em))
    }

    // MARK: - Window

    private func window(_ display: Display) -> some View {
        VStack(alignment: .leading, spacing: 0.1 * em) {
            Text(display.title)
                .font(.system(size: 1.25 * em, weight: .bold))
                .tracking(-0.01 * 1.25 * em)
            Text(display.subtitle)
                .font(.system(size: 0.74 * em))
                .foregroundStyle(Face.muted)
        }
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 3.2 * em, alignment: .top)
    }
}
