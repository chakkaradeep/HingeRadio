import SwiftUI
import RadioCore

/// The base: city keys, frequency readout and power button, with the tape below.
struct PlateView: View {
    let model: RadioModel
    let em: CGFloat

    var body: some View {
        VStack(spacing: 0.9 * em) {
            HStack(alignment: .center, spacing: 1.1 * em) {
                keys
                    .frame(maxWidth: .infinity)
                readout
                    .frame(maxWidth: .infinity)
            }
            TapeView(model: model, em: em)
        }
        .padding(EdgeInsets(top: 1 * em, leading: 1.1 * em, bottom: 1 * em, trailing: 1.1 * em))
        .foregroundStyle(Face.ink)
    }

    // MARK: - Keys

    private var keys: some View {
        let size = 0.56 * em
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 0.3 * em), GridItem(.flexible())],
                         spacing: 0.4 * em) {
            ForEach(model.radio.cities) { city in
                let pressed = city.id == model.radio.cityID
                Button {
                    model.selectCity(city.id)
                } label: {
                    Text(city.key.uppercased())
                        .font(.system(size: size, weight: .bold))
                        .tracking(0.06 * size)
                        .foregroundStyle(pressed ? Face.face : Face.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 0.75 * size)
                        .padding(.bottom, 0.55 * size)
                        .background(pressed ? Face.ink : Face.shade, in: RoundedRectangle(cornerRadius: 0.35 * size))
                        .background(
                            RoundedRectangle(cornerRadius: 0.35 * size)
                                .fill(Color.black.opacity(pressed ? 0 : 0.18))
                                .offset(y: 0.2 * size)
                        )
                        .offset(y: pressed ? 0.15 * size : 0)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(pressed ? .isSelected : [])
            }
        }
    }

    // MARK: - Readout and power

    private var readout: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0.4 * em) {
            Text(String(format: "%.1f", model.radio.tuning.frequency))
                .font(.system(size: 1.6 * em, weight: .medium))
                .monospacedDigit()
                .tracking(-0.02 * 1.6 * em)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)
            Text("MHz")
                .font(.system(size: 0.66 * em, weight: .bold))
                .tracking(0.1 * 0.66 * em)
                .foregroundStyle(Face.muted)
                .fixedSize()
            Spacer(minLength: 0)
            PowerButton(model: model, size: 2.1 * em)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 0.25 * em }
        }
    }
}
