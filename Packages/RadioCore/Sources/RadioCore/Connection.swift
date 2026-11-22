import Foundation

/// When to connect to, drop and give up on a station. Timing rules only; no audio.
///
/// A wanted station connects once it has been wanted for `settle` without a change. After
/// `want(nil)` the connection is kept for `hold`. `.fail` comes `failAfter` after connecting
/// with no sound, or `failAfter` after sound stops; it also drops the connection and, when the
/// failed station is the wanted one, forgets it. A player error gets one fresh `.connect` of
/// the same station; a second error before any sound is a `.fail`. Reports about a station that
/// is not connected are ignored.
/// Times are seconds on any steady clock; the app uses `ProcessInfo.systemUptime`.
public struct Connection: Sendable {
    public enum Action: Sendable, Equatable { case none, connect(Station), disconnect, fail(Station) }

    public private(set) var connected: Station?

    private let settle: TimeInterval, hold: TimeInterval, failAfter: TimeInterval
    private var wanted: Station?
    private var wantedSince: TimeInterval = 0
    private var leftAt: TimeInterval?          // set while holding a connection nobody wants
    private var playing = false
    private var silentSince: TimeInterval = 0  // when the connected station connected or went quiet
    private var errors = 0                     // player errors since connecting or last sound

    public init(settle: TimeInterval = 0.24, hold: TimeInterval = 6, failAfter: TimeInterval = 12) {
        self.settle = settle
        self.hold = hold
        self.failAfter = failAfter
    }

    public mutating func want(_ station: Station?, at time: TimeInterval) {
        guard station != wanted else { return }   // the settle wait is not restarted
        wanted = station
        wantedSince = time
        if station == nil {
            if connected != nil, leftAt == nil { leftAt = time }
        } else if station == connected {
            leftAt = nil
        }
    }

    public mutating func playerReported(_ station: Station, playing: Bool, at time: TimeInterval) {
        guard station == connected, playing != self.playing else { return }
        self.playing = playing
        if playing { errors = 0 } else { silentSince = time }
    }

    /// The player gave up on the connected station. The first error since connecting or since
    /// the last sound asks for the station to be loaded afresh; the second is a `.fail`.
    /// A retry does not restart the `failAfter` clock unless the station was playing.
    public mutating func playerErrored(_ station: Station, at time: TimeInterval) -> Action {
        guard station == connected else { return .none }
        errors += 1
        if errors > 1 { return fail(station) }
        if playing {
            playing = false
            silentSince = time
        }
        return .connect(station)
    }

    /// `.disconnect` if anything was connected; forgets pending work either way.
    public mutating func reset() -> Action {
        let wasConnected = connected != nil
        drop()
        wanted = nil
        return wasConnected ? .disconnect : .none
    }

    /// At most one action per call.
    public mutating func tick(at time: TimeInterval) -> Action {
        if let station = connected, !playing, time - silentSince >= failAfter {
            return fail(station)
        }
        if connected != nil, let leftAt, time - leftAt >= hold {
            drop()
            return .disconnect
        }
        if let station = wanted, station != connected, time - wantedSince >= settle {
            connected = station
            playing = false
            errors = 0
            silentSince = time
            leftAt = nil
            return .connect(station)
        }
        return .none
    }

    private mutating func fail(_ station: Station) -> Action {
        drop()
        if wanted == station { wanted = nil }
        return .fail(station)
    }

    private mutating func drop() {
        connected = nil
        playing = false
        errors = 0
        leftAt = nil
    }
}
