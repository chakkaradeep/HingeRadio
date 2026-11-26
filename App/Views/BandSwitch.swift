import os
import RadioCore
import SwiftUI

/// A slide switch for the bands: HERE first, set apart from the four cities by a printed rule,
/// then the cities (four positions and no rule without HERE), with each band's key printed under
/// its position. Tapping a position slides the knob there; the rule takes no taps. VoiceOver
/// reads it as a picker in the same order, HERE with its town once that is known.
struct BandSwitch: View {
    let model: RadioModel
    let em: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The start of the touch already reported to `model.wake()`.
    @State private var downAt: CGPoint?

    private static let log = Logger(subsystem: "HingeRadio", category: "dial")

    /// The height of the slot the knob runs in.
    static func track(em: CGFloat) -> CGFloat { max(26, 0.7 * em) }

    /// The width kept between HERE and the cities for the rule.
    static func gap(em: CGFloat) -> CGFloat { max(12, 0.4 * em) }

    var body: some View {
        let cities = model.radio.cities
        let selected = cities.firstIndex { $0.id == model.radio.cityID } ?? 0
        let size = Face.printed(em: em)
        let track = Self.track(em: em)
        // The rule follows HERE when it leads other bands.
        let gap = cities.count > 1 && cities.first?.id == hereID ? Self.gap(em: em) : 0
        GeometryReader { proxy in
            let slot = max(proxy.size.width - gap, 0) / CGFloat(max(cities.count, 1))
            // The centre of position `index`: past the rule for every band after the first.
            let x = { (index: Int) in slot * (CGFloat(index) + 0.5) + (index > 0 ? gap : 0) }
            let labelY = track + 0.45 * track + size / 2
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
                        .position(x: x(index), y: track / 2)
                }
                if gap > 0 {
                    // The printed rule between HERE and the cities, as tall as the keys.
                    Rectangle()
                        .fill(Face.ink.opacity(0.35))
                        .frame(width: 1, height: 1.3 * size)
                        .position(x: slot + gap / 2, y: labelY)
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
                    .position(x: x(selected), y: track / 2)
                ForEach(cities.indices, id: \.self) { index in
                    BandKey(city: cities[index], size: size)
                        .foregroundStyle(index == selected ? Face.ink : Face.muted)
                        .lineLimit(1)
                        .fixedSize()
                        .position(x: x(index), y: labelY)
                }
                // One tap area per position, the full height of the switch; none on the rule.
                HStack(spacing: 0) {
                    ForEach(cities.indices, id: \.self) { index in
                        if index == 1, gap > 0 {
                            // The rule's own strip takes a tap and does nothing with it; left
                            // empty, a touch's area would reach the nearest band and choose it.
                            Color.clear
                                .frame(width: gap)
                                .contentShape(Rectangle())
                                .onTapGesture {}
                        }
                        Color.clear
                            .frame(width: slot)
                            .contentShape(Rectangle())
                            .onTapGesture { model.selectCity(cities[index].id, animated: !reduceMotion) }
                    }
                }
                // A finger coming down wakes the sound engine, so the band's click is not lost.
                .simultaneousGesture(DragGesture(minimumDistance: 0)
                    .onChanged { touch in
                        guard downAt != touch.startLocation else { return }
                        downAt = touch.startLocation
                        model.wake()
                    }
                    .onEnded { _ in downAt = nil })
            }
            .onGeometryChange(for: CGFloat.self) { _ in slot.rounded() } action: { slot in
                Self.log.notice("BAND \(cities.count) positions, \(slot, format: .fixed(precision: 0)) pt each")
            }
        }
        .frame(height: max(44, 1.45 * track + size * 1.2))
        .animation(.spring(duration: 0.25, bounce: 0.15), value: model.radio.cityID)
        .accessibilityRepresentation {
            Picker("Band", selection: Binding(get: { model.radio.cityID },
                                              set: { model.selectCity($0, animated: !reduceMotion) })) {
                ForEach(cities) { city in
                    Text(city.spokenName).tag(city.id)
                }
            }
        }
    }
}
