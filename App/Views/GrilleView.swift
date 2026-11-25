import SwiftUI

/// The speaker grille: round holes on a square grid. The grid's spacing is stretched slightly
/// so the outer holes sit exactly on the frame's left and right edges; the top row sits on the
/// frame's top edge.
struct GrilleView: View {
    let em: CGFloat
    /// Below this height or width nothing is drawn: two or three rows of holes do not read as a
    /// speaker.
    var minimum: CGFloat = 0
    /// Smaller holes, closer together, for a narrow grille.
    var fine = false
    /// The bottom row sits on the frame's bottom edge instead of the top row on its top edge.
    var footed = false

    var body: some View {
        Canvas { context, size in
            let hole = fine ? 5 : max(6, 0.21 * em)
            let target = fine ? 11 : max(14, 0.48 * em)                 // the pitch the grid aims for
            guard size.width > max(hole, minimum), size.height > max(hole, minimum) else { return }
            let columns = max(2, Int(((size.width - hole) / target).rounded()) + 1)
            let pitch = (size.width - hole) / CGFloat(columns - 1)
            let rows = Int((size.height - hole) / pitch) + 1
            let top = footed ? size.height - hole - CGFloat(rows - 1) * pitch : 0
            var holes = Path()
            for row in 0..<rows {
                for column in 0..<columns {
                    holes.addEllipse(in: CGRect(x: CGFloat(column) * pitch,
                                                y: top + CGFloat(row) * pitch,
                                                width: hole, height: hole))
                }
            }
            context.fill(holes, with: .color(Face.ink.opacity(0.72)))
        }
        .accessibilityHidden(true)
    }
}
