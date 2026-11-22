import Foundation

public struct HingeReading: Sendable, Equatable {
    public var angle: Double        // degrees
    public var isClosed: Bool
    public var time: TimeInterval   // unused by the direct rule; kept for a later knob-style rule

    public init(angle: Double, isClosed: Bool, time: TimeInterval) {
        self.angle = angle
        self.isClosed = isClosed
        self.time = time
    }
}

public struct TuningState: Sendable, Equatable {
    public var needle: Double         // 0...1; rests on the mark while locked
    public var frequency: Double      // MHz for the readout
    public var locked: Station?
    public var candidate: Station?    // locked, or the one station being faded toward
    public var strength: Double       // 1 while locked, falling to 0 across fadeWidth outside the zone
    public var edgeDistance: Double   // degrees outside the nearest zone, 0 inside
}

/// Turns hinge angles into a needle position and a locked station.
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
    public mutating func update(_ reading: HingeReading) -> TuningState {
        let angle = reading.angle
        guard !angle.isNaN else { return state }

        let halfZone = config.lockWidth / 2
        let nearest = scale.marks.min { abs($0.angle - angle) < abs($1.angle - angle) }
            .map { (mark: $0, distance: abs($0.angle - angle)) }

        // Hold the current lock until the hinge leaves the zone by the release margin.
        var lockedMark: DialScale.Mark?
        if let current = state.locked,
           let mark = scale.marks.first(where: { $0.station.callSign == current.callSign }),
           abs(mark.angle - angle) <= halfZone + config.releaseMargin {
            lockedMark = mark
        } else if let nearest, nearest.distance <= halfZone {
            lockedMark = nearest.mark
        }

        if let mark = lockedMark {
            state = TuningState(needle: mark.position, frequency: mark.station.frequency,
                                locked: mark.station, candidate: mark.station,
                                strength: 1, edgeDistance: 0)
        } else {
            let needle = scale.position(forAngle: angle)
            let edge = nearest.map { max(0, $0.distance - halfZone) } ?? 0
            let strength = nearest == nil ? 0 : max(0, 1 - edge / config.fadeWidth)
            state = TuningState(needle: needle, frequency: scale.frequency(atPosition: needle),
                                locked: nil, candidate: strength > 0 ? nearest?.mark.station : nil,
                                strength: strength, edgeDistance: edge)
        }
        return state
    }
}
