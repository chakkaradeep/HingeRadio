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
            lamp(display.lamp, size: 0.75 * size)
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

    private func lamp(_ lamp: Lamp, size: CGFloat) -> some View {
        let colour: Color? = switch lamp {
        case .off: nil
        case .seeking: Face.needle
        case .locked: Face.lamp
        }
        return Circle()
            .fill(colour ?? Face.shade)
            .overlay(Circle().strokeBorder(Color.black.opacity(colour == nil ? 0.2 : 0), lineWidth: 1))
            .shadow(color: colour ?? .clear, radius: 0.3 * em)
            .frame(width: size, height: size)
    }

    // MARK: - Glass

    private var glass: some View {
        let inset = 0.7 * em
        return GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack(alignment: .topLeading) {
                // The scale reaches into the side insets so the end numbers are not cut off.
                scale(width: width, height: height, inset: inset)
                    .padding(.horizontal, -inset)
                marks(width: width, height: height)
                Capsule()
                    .fill(Face.needle)
                    .frame(width: 2, height: height * 0.92)
                    .offset(x: model.radio.tuning.needle * width - 1, y: height * 0.04)
            }
        }
        .dragTuning(into: model)
        .padding(.horizontal, inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Face.shade, in: RoundedRectangle(cornerRadius: 0.7 * em))
        .clipShape(RoundedRectangle(cornerRadius: 0.7 * em))
    }

    /// A tick at each whole MHz from 88 to 108, taller with a number every 4 MHz.
    /// Where the stretched scale squeezes two numbers together, the later one is left out.
    private func scale(width: CGFloat, height: CGFloat, inset: CGFloat) -> some View {
        let dialScale = model.radio.scale
        let numberSize = 0.62 * em
        let numberGap = 2.6 * numberSize      // three monospaced digits plus a space
        return Canvas { context, _ in
            var lastNumberX = -CGFloat.infinity
            for mhz in 88...108 {
                let major = mhz % 4 == 0
                let x = inset + dialScale.position(forFrequency: Double(mhz)) * width
                let tickHeight = height * (major ? 0.26 : 0.14)
                let tickBottom = height * (1 - 0.34)
                context.fill(Path(CGRect(x: x - 0.5, y: tickBottom - tickHeight, width: 1, height: tickHeight)),
                             with: .color(Face.ink.opacity(major ? 0.9 : 0.45)))
                if major, x - lastNumberX >= numberGap {
                    lastNumberX = x
                    let number = Text("\(mhz)")
                        .font(.system(size: numberSize, design: .monospaced))
                        .foregroundStyle(Face.muted)
                    context.draw(number, at: CGPoint(x: x, y: height * (1 - 0.08)), anchor: .bottom)
                }
            }
        }
    }

    /// One dot per mark: orange for the candidate, struck through when dead. No labels; not tappable.
    private func marks(width: CGFloat, height: CGFloat) -> some View {
        let dot = 0.4 * em
        let candidate = model.radio.powerOn ? model.radio.tuning.candidate?.callSign : nil
        return ForEach(model.radio.scale.marks, id: \.station.callSign) { mark in
            let dead = model.radio.dead.contains(mark.station.callSign)
            Circle()
                .fill(mark.station.callSign == candidate ? Face.needle : Face.ink)
                .frame(width: dot, height: dot)
                .overlay {
                    if dead {
                        Rectangle().fill(Face.ink).frame(width: dot * 2, height: 1.5)
                    }
                }
                .opacity(dead ? 0.3 : 1)
                .position(x: mark.position * width, y: height * 0.16)
        }
        .allowsHitTesting(false)
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
