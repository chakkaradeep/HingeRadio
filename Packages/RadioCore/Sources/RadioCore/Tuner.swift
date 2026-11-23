import Foundation

public struct TuningState: Sendable, Equatable {
    public var needle: Double         // 0...1; the dial position, locked or not
    public var frequency: Double      // MHz at the needle, for the readout
    public var locked: Station?
    public var candidate: Station?    // locked, or the one station being faded toward
    public var strength: Double       // 1 while locked, falling to 0 across fadeWidth outside the zone
    public var edgeDistance: Double   // dial units outside the nearest zone, 0 inside
}

/// Turns dial positions (in dial units, `minAngle...maxAngle`) into a needle position and a locked
/// station. The needle follows the dial on every move; a lock never pins it.
public struct Tuner: Sendable {
    public let scale: DialScale
    public private(set) var state: TuningState
    private let config: DialConfig

    public init(stations: [Station], config: DialConfig) {
        self.config = config
        scale = DialScale(stations: stations, config: config)
        state = TuningState(needle: 0, frequency: config.minFrequency, locked: nil,
                            candidate: nil, strength: 0, edgeDistance: 0)
    }

    @discardableResult
    public mutating func update(_ dial: Double) -> TuningState {
        let angle = dial
        guard !angle.isNaN else { return state }

        let halfZone = config.lockWidth / 2
        let nearest = scale.marks.min { abs($0.angle - angle) < abs($1.angle - angle) }
            .map { (mark: $0, distance: abs($0.angle - angle)) }

        // Hold the current lock until the dial leaves the zone by the release margin.
        var lockedMark: DialScale.Mark?
        if let current = state.locked,
           let mark = scale.marks.first(where: { $0.station.callSign == current.callSign }),
           abs(mark.angle - angle) <= halfZone + config.releaseMargin {
            lockedMark = mark
        } else if let nearest, nearest.distance <= halfZone {
            lockedMark = nearest.mark
        }

        let needle = scale.position(forAngle: angle)
        let frequency = scale.frequency(atPosition: needle)
        if let mark = lockedMark {
            state = TuningState(needle: needle, frequency: frequency,
                                locked: mark.station, candidate: mark.station,
                                strength: 1, edgeDistance: 0)
        } else {
            let edge = nearest.map { max(0, $0.distance - halfZone) } ?? 0
            let strength = nearest == nil ? 0 : max(0, 1 - edge / config.fadeWidth)
            state = TuningState(needle: needle, frequency: frequency,
                                locked: nil, candidate: strength > 0 ? nearest?.mark.station : nil,
                                strength: strength, edgeDistance: edge)
        }
        return state
    }
}
