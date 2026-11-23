import SwiftUI
import RadioCore
import os

/// The radio's side: the volume wheel that clicks on, above the tuning wheel, each with its name
/// printed over it and a short scale beside it. The same assembly on every face that has wheels
/// (the flex plate and the standby face). It fills the height it is given: the volume wheel keeps
/// its own height and the tuning wheel takes the rest.
///
/// The tuning wheel is geared by the point, not by its height, so a thumb movement tunes the same
/// amount on every face; a shorter wheel just covers less of the band.
struct SideWheels: View {
    let model: RadioModel
    let em: CGFloat

    /// How much of the band (0...1) one point of roll on the tuning wheel covers, on every face.
    /// The flex face's tuning wheel on the inner screen (233 pt, measured from the `WHEELS` log
    /// line) covered a quarter of the band by its height when the gearing was set per wheel;
    /// 1/932 keeps exactly that, so the whole band is 932 pt of roll.
    static let tuningBandPerPoint = 1.0 / 932
    /// The shortest the tuning wheel may be.
    static let tuningMinHeight: CGFloat = 140

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let log = Logger(subsystem: "HingeRadio", category: "wheels")

    var body: some View {
        let size = Face.printed(em: em)
        VStack(alignment: .trailing, spacing: captionGap) {
            caption("VOLUME", size: size)
            volume(size: size)
                .frame(height: volumeHeight)
            caption("TUNING", size: size)
                .padding(.top, wheelGap(size: size) - 2 * captionGap - captionHeight(size))
            tuning(size: size)
                .frame(minHeight: Self.tuningMinHeight, maxHeight: .infinity)
        }
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(Face.ink)
    }

    // MARK: - Measures

    private var wheelWidth: CGFloat { max(46, 1.25 * em) }
    /// One wheel height is the volume's whole travel, 0 to 1.
    private var volumeHeight: CGFloat { max(92, 2.4 * em) }
    /// Between a wheel's name and the wheel.
    private var captionGap: CGFloat { 0.2 * em }
    private func captionHeight(_ size: CGFloat) -> CGFloat { ceil(1.2 * size) }
    /// From the bottom of the volume wheel to the top of the tuning wheel: at least 44 pt, so a
    /// thumb on one never lands on the other. The tuning wheel's name sits in this gap.
    private func wheelGap(size: CGFloat) -> CGFloat {
        max(48, 1.25 * em, 2 * captionGap + captionHeight(size) + 0.6 * em)
    }

    // MARK: - Volume

    private func volume(size: CGFloat) -> some View {
        let radio = model.radio
        return HStack(spacing: 0.3 * em) {
            scale(top: "ON", bottom: "OFF", fraction: radio.wheel, click: Radio.wheelOnFrom,
                  lit: radio.powerOn, size: size)
            WheelView(value: radio.wheel, gearing: .perHeight(1), ridge: Radio.volumeRidge,
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
                    // From off, one step up switches on; a step down past the click switches off.
                    case .increment:
                        model.setWheel(model.radio.powerOn ? model.wheel + 0.1 : Radio.wheelOnFrom)
                    case .decrement:
                        let next = model.wheel - 0.1
                        model.setWheel(next < Radio.wheelOnFrom ? 0 : next)
                    @unknown default: break
                    }
                }
        }
    }

    // MARK: - Tuning

    private func tuning(size: CGFloat) -> some View {
        let radio = model.radio
        return HStack(spacing: 0.3 * em) {
            scale(top: "108", bottom: "88", fraction: radio.tuning.needle, click: nil,
                  lit: radio.powerOn, size: size)
            WheelView(value: model.position, gearing: .perPoint(Self.tuningBandPerPoint),
                      ridge: Radio.tuningRidge,
                      onTouchDown: { model.holdStill() },
                      onChange: { model.tune(toPosition: $0) },
                      onRelease: { predicted in
                          let target = flickTarget(from: model.position, predicted: predicted,
                                                   marks: model.radio.liveMarkPositions)
                          if target != model.position {
                              move(to: target)
                          } else {
                              model.settle(animated: !reduceMotion)  // a slow release eases onto the mark
                          }
                      },
                      onTap: { upperHalf in step(up: upperHalf) },
                      tapSlop: 4)                 // a nudge that is neither tap nor roll does nothing
                .frame(width: wheelWidth)
                .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { height in
                    let line = String(format: "WHEELS tuning %.0f pt, %.3f of the band", height,
                                      Double(height) * Self.tuningBandPerPoint)
                    log.notice("\(line, privacy: .public)")
                }
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

    /// The station name and its own frequency when a station is locked, otherwise the frequency
    /// under the needle.
    private var tuningValue: String {
        guard let station = model.radio.tuning.locked else {
            return String(format: "%.1f megahertz", model.radio.tuning.frequency)
        }
        return "\(station.name), " + String(format: "%.1f megahertz", station.frequency)
    }

    /// To the next station up or down the band (see `Radio.stepTarget`).
    private func step(up: Bool) { model.stepStation(up: up, animated: !reduceMotion) }

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
            .frame(height: captionHeight(size))
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
