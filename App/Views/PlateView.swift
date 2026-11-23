import SwiftUI

/// The lower half, a pocket radio's front: the speaker grille with the band switch under it on
/// the left, and on the right the side wheels (`SideWheels`): volume above tuning.
struct PlateView: View {
    let model: RadioModel
    let em: CGFloat

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
            SideWheels(model: model, em: em)
        }
        .padding(EdgeInsets(top: 0.4 * em, leading: 1.1 * em, bottom: 1 * em, trailing: 1.1 * em))
        .foregroundStyle(Face.ink)
    }
}
