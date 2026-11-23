/// Where the tape should come to rest after a release.
/// Returns `position` when the release is slower than `minFlick`; otherwise the mark nearest
/// `predicted`, or `predicted` clamped to 0...1 when there are no marks.
public func flickTarget(from position: Double, predicted: Double, marks: [Double], minFlick: Double = 0.03) -> Double {
    guard !predicted.isNaN, abs(predicted - position) >= minFlick else { return position }
    guard let nearest = marks.min(by: { abs($0 - predicted) < abs($1 - predicted) }) else {
        return min(1, max(0, predicted))
    }
    return nearest
}

/// The nearest mark strictly above `position`, or nil when there is none. From exactly on a
/// mark this is the next one along.
public func nextMark(above position: Double, marks: [Double]) -> Double? {
    marks.filter { $0 > position + 1e-9 }.min()
}

/// The nearest mark strictly below `position`, or nil when there is none.
public func nextMark(below position: Double, marks: [Double]) -> Double? {
    marks.filter { $0 < position - 1e-9 }.max()
}
