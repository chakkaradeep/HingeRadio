import SwiftUI
import RadioCore

/// A four-position slide switch for the cities, with each city's key printed under its
/// position. Tapping a position slides the knob there. VoiceOver reads it as a picker.
struct BandSwitch: View {
    let model: RadioModel
    let em: CGFloat

    /// The height of the slot the knob runs in.
    static func track(em: CGFloat) -> CGFloat { max(26, 0.7 * em) }

    var body: some View {
        let cities = model.radio.cities
        let selected = cities.firstIndex { $0.id == model.radio.cityID } ?? 0
        let size = Face.printed(em: em)
        let track = Self.track(em: em)
        GeometryReader { proxy in
            let slot = proxy.size.width / CGFloat(max(cities.count, 1))
            ZStack(alignment: .topLeading) {
                // The slot the knob runs in, with a notch at each position.
                Capsule()
                    .fill(Face.shade)
                    .overlay(Capsule().strokeBorder(Face.ink.opacity(0.25), lineWidth: 1))
                    .frame(height: track)
                ForEach(cities.indices, id: \.self) { index in
                    Circle()
                        .fill(Face.ink.opacity(0.3))
                        .frame(width: 4, height: 4)
                        .position(x: slot * (CGFloat(index) + 0.5), y: track / 2)
                }
                RoundedRectangle(cornerRadius: track / 2 - 3)
                    .fill(Face.ink)
                    .overlay {
                        // Grip lines on the knob.
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle().fill(Face.face.opacity(0.5)).frame(width: 1, height: 0.45 * track)
                            }
                        }
                    }
                    .frame(width: min(slot - 8, 1.6 * track), height: track - 6)
                    .position(x: slot * (CGFloat(selected) + 0.5), y: track / 2)
                ForEach(cities.indices, id: \.self) { index in
                    Text(cities[index].key.uppercased())
                        .printed(size: size)
                        .foregroundStyle(index == selected ? Face.ink : Face.muted)
                        .lineLimit(1)
                        .fixedSize()
                        .position(x: slot * (CGFloat(index) + 0.5), y: track + 0.45 * track + size / 2)
                }
                // One tap area per position, the full height of the switch.
                HStack(spacing: 0) {
                    ForEach(cities) { city in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { model.selectCity(city.id) }
                    }
                }
            }
        }
        .frame(height: max(44, 1.45 * track + size * 1.2))
        .animation(.spring(duration: 0.25, bounce: 0.15), value: model.radio.cityID)
        .accessibilityRepresentation {
            Picker("Band", selection: Binding(get: { model.radio.cityID },
                                              set: { model.selectCity($0) })) {
                ForEach(cities) { city in
                    Text(city.name).tag(city.id)
                }
            }
        }
    }
}
