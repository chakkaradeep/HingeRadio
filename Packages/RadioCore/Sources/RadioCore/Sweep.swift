import Foundation

/// The needle's path while HERE's stations are looked for, like an old radio's scan: back to the
/// bottom of the dial, then up it at a steady rate, over and over.
public struct Sweep: Sendable {
    /// Seconds from the bottom of the dial to the top.
    public static let lap = 4.0
    /// Seconds for the needle to come back down the whole dial.
    public static let returnTime = 0.35

    public struct Step: Sendable, Equatable {
        public let position: Double
        /// On the way back down, when nothing is searched and no ridge ticks.
        public let isReturning: Bool
    }

    private let start: Double

    /// `start` is the dial position (0...1) the needle is at.
    public init(from start: Double) { self.start = start }

    /// Where the needle is `elapsed` seconds in.
    public func step(at elapsed: Double) -> Step {
        let firstReturn = Self.returnTime * start
        if elapsed < firstReturn { return returning(from: start, progress: elapsed / firstReturn) }
        let inCycle = max(0, elapsed - firstReturn).truncatingRemainder(dividingBy: Self.lap + Self.returnTime)
        if inCycle < Self.lap { return Step(position: inCycle / Self.lap, isReturning: false) }
        return returning(from: 1, progress: (inCycle - Self.lap) / Self.returnTime)
    }

    /// Eased at both ends.
    private func returning(from top: Double, progress: Double) -> Step {
        let t = min(1, max(0, progress))
        return Step(position: top * (1 - t * t * (3 - 2 * t)), isReturning: true)
    }
}
