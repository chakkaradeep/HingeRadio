import SwiftUI
import RadioCore

/// The base: speaker grille, city keys, frequency readout and power button.
struct PlateView: View {
    let model: RadioModel
    let em: CGFloat

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 1.1 * em) {
                grille
                    .frame(width: proxy.size.height * 0.55, height: proxy.size.height * 0.55)
                VStack(alignment: .leading, spacing: 0.7 * em) {
                    keys
                    readout
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(EdgeInsets(top: 1 * em, leading: 1.1 * em, bottom: 1 * em, trailing: 1.1 * em))
        .foregroundStyle(Face.ink)
    }

    // MARK: - Grille

    /// Dots on a 0.5 em grid, clipped to a circle.
    private var grille: some View {
        let pitch = 0.5 * em
        let radius = 0.085 * em
        return Canvas { context, size in
            let columns = Int(size.width / pitch)
            let rows = Int(size.height / pitch)
            let originX = (size.width - CGFloat(columns) * pitch) / 2 + pitch / 2
            let originY = (size.height - CGFloat(rows) * pitch) / 2 + pitch / 2
            var dots = Path()
            for row in 0..<rows {
                for column in 0..<columns {
                    let center = CGPoint(x: originX + CGFloat(column) * pitch, y: originY + CGFloat(row) * pitch)
                    dots.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
                }
            }
            context.fill(dots, with: .color(Face.ink))
        }
        .clipShape(Circle())
        .opacity(0.8)
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
            powerButton
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 0.25 * em }
        }
    }

    private var powerButton: some View {
        let size = 2.1 * em
        return Button {
            model.togglePower()
        } label: {
            Circle()
                .fill(Face.shade)
                .background(Circle().fill(Color.black.opacity(0.2)).offset(y: 0.16 * em))
                .overlay(Circle().fill(model.radio.powerOn ? Face.lamp : Face.muted).padding(size * 0.32))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Power")
        .accessibilityAddTraits(model.radio.powerOn ? .isSelected : [])
    }
}
