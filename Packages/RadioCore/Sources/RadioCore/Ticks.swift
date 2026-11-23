import Foundation

/// How many step boundaries (whole multiples of `step`) a wheel passed moving from `from` to `to`.
/// Landing exactly on a boundary counts it; leaving a boundary does not count it again. The same
/// in either direction. 0 for no move, a non-finite value or a step that is not positive.
public func ticksCrossed(from: Double, to: Double, step: Double) -> Int {
    guard from.isFinite, to.isFinite, step.isFinite, step > 0, from != to else { return 0 }
    // In steps, with values a hair off a boundary (from floating-point division) snapped onto it.
    func steps(_ value: Double) -> Double {
        let x = value / step
        return abs(x - x.rounded()) < 1e-9 ? x.rounded() : x
    }
    let a = steps(from), b = steps(to)
    let count = to > from ? floor(b) - floor(a) : ceil(a) - ceil(b)
    return Int(count)
}
