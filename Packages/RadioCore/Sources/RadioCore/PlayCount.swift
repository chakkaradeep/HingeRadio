/// When a play of a station found by HERE is counted by Radio Browser, which asks for one count
/// each time a station is listened to.
///
/// A station counts once for each time it is chosen: not again when the stream stalls and comes
/// back, when the player retries after an error, or when the volume changes. It counts again only
/// after the player has gone silent (a station left, switched off, failed) or has played another
/// station in between.
public struct PlayCount: Sendable, Equatable {
    private var counted: Station?

    public init() {}

    /// What the player now reports, for the station it is connected to. Returns the Radio Browser
    /// id to report a play for, or nil when nothing is to be counted: the band is not HERE's, the
    /// station has no id, or this start was counted already.
    public mutating func report(_ playback: Playback, of station: Station?, onHere: Bool) -> String? {
        if playback == .idle { counted = nil }
        guard playback == .playing, onHere, let station, station != counted else { return nil }
        counted = station
        return station.radioBrowserID
    }
}
