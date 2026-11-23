import SwiftUI
import RadioCore

/// The lower half, a pocket radio's front: the speaker grille with the band switch under it on
/// the left, and on the right the volume wheel above the tuning wheel, each with its printed
/// scale and name beside it.
struct PlateView: View {
    let model: RadioModel
    let em: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = Face.printed(em: em)
        HStack(alignment: .top, spacing: 1.1 * em) {
            VStack(alignment: .leading, spacing: 0.9 * em) {
                GrilleView(em: em)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(alignment: .top, spacing: 0.6 * em) {
                    Text("BAND")
                        .printed(size: size)
                        .foregroundStyle(Face.muted)
                        .frame(height: BandSwitch.track(em: em))
                        .accessibilityHidden(true)
                    BandSwitch(model: model, em: em)
                }
            }
            VStack(alignment: .trailing, spacing: max(48, 1.25 * em)) {
                volume(size: size)
                    .frame(height: max(92, 2.4 * em))
                tuning(size: size)
                    .frame(minHeight: 180, maxHeight: .infinity)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(EdgeInsets(top: 1 * em, leading: 1.1 * em, bottom: 1 * em, trailing: 1.1 * em))
        .foregroundStyle(Face.ink)
    }

    private var wheelWidth: CGFloat { max(46, 1.25 * em) }

    // MARK: - Volume

    private func volume(size: CGFloat) -> some View {
        let radio = model.radio
        return HStack(spacing: 0.3 * em) {
            caption("VOLUME", size: size)
            scale(top: "ON", bottom: "OFF", fraction: radio.wheel, click: Radio.wheelOnFrom,
                  lit: radio.powerOn, size: size)
            WheelView(value: radio.wheel, span: 1,
                      onChange: { model.setWheel($0) },
                      onRelease: { _ in },
                      onTap: { _ in model.togglePower() })
                .frame(width: wheelWidth)
                .accessibilityLabel("Volume")
                .accessibilityValue(radio.powerOn ? "\(Int((radio.wheel * 100).rounded())) percent" : "Off")
                .accessibilityHint("Double-tap to switch on or off.")
                .accessibilityAction { model.togglePower() }
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: model.setWheel(model.wheel + 0.1)
                    case .decrement: model.setWheel(model.wheel - 0.1)
                    @unknown default: break
                    }
                }
        }
    }

    // MARK: - Tuning

    private func tuning(size: CGFloat) -> some View {
        let radio = model.radio
        return HStack(spacing: 0.3 * em) {
            caption("TUNING", size: size)
            scale(top: "108", bottom: "88", fraction: radio.tuning.needle, click: nil,
                  lit: radio.powerOn, size: size)
            WheelView(value: model.position, span: 0.25,
                      onChange: { model.tune(toPosition: $0) },
                      onRelease: { predicted in
                          let target = flickTarget(from: model.position, predicted: predicted,
                                                   marks: model.radio.liveMarkPositions)
                          if target != model.position {
                              move(to: target)
                          } else {
                              model.settleOnLockedStation()           // a slow release: no glide
                          }
                      },
                      onTap: { upperHalf in step(up: upperHalf) })
                .frame(width: wheelWidth)
                .accessibilityLabel("Tuning")
                .accessibilityValue(tuningValue)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: step(up: true)
                    case .decrement: step(up: false)
                    @unknown default: break
                    }
                }
        }
    }

    /// The station name and frequency when a station is locked, otherwise the frequency.
    private var tuningValue: String {
        let frequency = String(format: "%.1f megahertz", model.radio.tuning.frequency)
        guard let station = model.radio.tuning.locked else { return frequency }
        return "\(station.name), \(frequency)"
    }

    /// To the next station up or down the band, dead ones included so each can be reached.
    private func step(up: Bool) {
        let marks = model.radio.scale.marks.map(\.position)
        let needle = model.radio.tuning.needle
        let target = up ? nextMark(above: needle, marks: marks) : nextMark(below: needle, marks: marks)
        if let target { move(to: target) }
    }

    /// Glides, or jumps when Reduce Motion is on.
    private func move(to target: Double) {
        if reduceMotion { model.tune(toPosition: target) } else { model.glide(toPosition: target) }
    }

    // MARK: - Printing

    private func caption(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .printed(size: size)
            .foregroundStyle(Face.muted)
            .fixedSize()
            .accessibilityHidden(true)
    }

    /// A short upright scale beside a wheel: words at each end, a rule, an optional tick where the
    /// wheel clicks, and a dot showing where the wheel is (orange while the radio is on).
    private func scale(top: String, bottom: String, fraction: Double, click: Double?,
                       lit: Bool, size: CGFloat) -> some View {
        let dot = max(9, 0.26 * em)
        return HStack(spacing: 0.25 * em) {
            VStack(alignment: .trailing) {
                Text(top).printed(size: size)
                Spacer(minLength: 0)
                Text(bottom).printed(size: size)
            }
            .foregroundStyle(Face.ink)
            .frame(width: 2.6 * size, alignment: .trailing)
            GeometryReader { proxy in
                let travel = proxy.size.height - dot
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Face.ink.opacity(0.3))
                        .frame(width: 1.5)
                        .padding(.vertical, dot / 2)
                    if let click {
                        Rectangle()
                            .fill(Face.ink.opacity(0.6))
                            .frame(width: dot, height: 1.5)
                            .offset(y: dot / 2 + (1 - click) * travel)
                    }
                    Circle()
                        .fill(lit ? Face.needle : Face.muted)
                        .frame(width: dot, height: dot)
                        .offset(y: (1 - fraction) * travel)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .frame(width: dot)
        }
        .padding(.vertical, 0.1 * em)
        .accessibilityHidden(true)
    }
}
