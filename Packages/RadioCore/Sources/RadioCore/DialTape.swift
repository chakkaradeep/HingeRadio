/// A dial laid out as a tape that is as long as its station names need. Between two neighbouring
/// marks the tape keeps the band's own spacing on the glass, or the room their names need,
/// whichever is more; when the names crowd, the tape grows longer than the glass and slides.
public struct DialTape: Sendable, Equatable {
    private struct Anchor: Sendable, Equatable {
        let position: Double
        let at: Double
    }

    /// Band position to tape coordinate, in increasing order: dial start, each mark, dial end.
    private let anchors: [Anchor]
    private let view: Double

    /// The tape's length in points.
    public let length: Double

    /// `positions` are the marks' positions (0...1) in dial order, `rooms` the room each mark's
    /// name needs along the dial (points), `view` the glass's usable length (points).
    ///
    /// Callers must give positions that are strictly increasing and inside 0...1, and one room
    /// per position (extra values in the longer array are ignored), as `DialScale`'s marks always are.
    public init(positions: [Double], rooms: [Double], view: Double) {
        var anchors = [Anchor(position: 0, at: 0)]
        var at = 0.0
        var last = (position: 0.0, room: 0.0)
        for (position, room) in zip(positions, rooms) {
            at += max((position - last.position) * view, (last.room + room) / 2)
            anchors.append(Anchor(position: position, at: at))
            last = (position, room)
        }
        at += max((1 - last.position) * view, last.room / 2)
        anchors.append(Anchor(position: 1, at: at))
        self.anchors = anchors
        self.view = view
        length = at
    }

    /// Where a band position falls along the tape, in points from 88's end; clamped to `0...length`.
    public func coordinate(_ position: Double) -> Double {
        let p = min(max(position, 0), 1)
        guard let upper = anchors.firstIndex(where: { $0.position >= p }), upper > 0 else { return 0 }
        let a = anchors[upper - 1], b = anchors[upper]
        guard b.position > a.position else { return b.at }
        return a.at + (p - a.position) / (b.position - a.position) * (b.at - a.at)
    }

    /// How far the tape has slid: none when it fits the glass; otherwise enough to hold the
    /// needle in the middle, stopping at either end.
    public func offset(needle: Double) -> Double {
        guard length > view else { return 0 }
        return min(max(coordinate(needle) - view / 2, 0), length - view)
    }
}
