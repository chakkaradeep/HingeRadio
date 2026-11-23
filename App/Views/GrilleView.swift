import SwiftUI

/// The speaker grille: round holes on a square grid. The grid's spacing is stretched slightly
/// so the outer holes sit exactly on the frame's left and right edges; the top row sits on the
/// frame's top edge.
struct GrilleView: View {
    let em: CGFloat

    var body: some View {
        Canvas { context, size in
            let hole = max(6, 0.21 * em)
            let target = max(14, 0.48 * em)                 // the pitch the grid aims for
            guard size.width > hole, size.height > hole else { return }
            let columns = max(2, Int(((size.width - hole) / target).rounded()) + 1)
            let pitch = (size.width - hole) / CGFloat(columns - 1)
            let rows = Int((size.height - hole) / pitch) + 1
            var holes = Path()
            for row in 0..<rows {
                for column in 0..<columns {
                    holes.addEllipse(in: CGRect(x: CGFloat(column) * pitch,
                                                y: CGFloat(row) * pitch,
                                                width: hole, height: hole))
                }
            }
            context.fill(holes, with: .color(Face.ink.opacity(0.72)))
        }
        .accessibilityHidden(true)
    }
}
