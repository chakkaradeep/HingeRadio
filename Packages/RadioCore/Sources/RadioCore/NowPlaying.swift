import Foundation

/// What the lock screen and Control Center show while the radio is on.
public struct NowPlaying: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let isPlaying: Bool

    public init(title: String, artist: String, album: String, isPlaying: Bool) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
    }
}

public extension Radio {
    /// Nil while the power is off. Title: "No signal" when the station under the needle is dead,
    /// else the locked station's shown name, else "Between stations" (also throughout HERE's sweep,
    /// which shows no station). Artist: the station's frequency and licence city, or between
    /// stations the needle's frequency. Album: the band's name, HERE's town on HERE. Playing only
    /// when `playback`, what can be heard, is `.playing`.
    func nowPlaying(playback: Playback) -> NowPlaying? {
        guard powerOn else { return nil }
        let album = cities.first { $0.id == cityID }?.name ?? ""
        let isPlaying = playback == .playing
        func station(_ title: String, _ station: Station) -> NowPlaying {
            NowPlaying(title: title, artist: String(format: "%.1f MHz · %@", station.frequency, station.licenceCity),
                       album: album, isPlaying: isPlaying)
        }
        if !isScanningHere, let candidate = tuning.candidate, dead.contains(candidate.callSign) {
            return station("No signal", candidate)
        }
        if let locked = lockToShow { return station(locked.shownName, locked) }
        return NowPlaying(title: "Between stations", artist: String(format: "%.1f MHz", tuning.frequency),
                          album: album, isPlaying: isPlaying)
    }
}

/// The least time between two Now Playing writes that change only the artist line (the needle's
/// frequency while it moves between stations).
public let nowPlayingArtistInterval: TimeInterval = 0.25

/// Whether `next` should be written now, `last` being what was last written at `lastWrite`
/// (seconds on any steady clock; nil before the first write). Never for no change. At once when
/// the power goes on or off (either is nil) or the title, album or playing state changes;
/// a change of the artist alone only once `nowPlayingArtistInterval` has passed since the last
/// write. The caller writes a held change later, so the last value always lands.
public func nowPlayingWriteIsDue(last: NowPlaying?, next: NowPlaying?, lastWrite: TimeInterval?,
                                 now: TimeInterval) -> Bool {
    guard next != last else { return false }
    guard let last, let next, let lastWrite else { return true }
    if next.title != last.title || next.album != last.album || next.isPlaying != last.isPlaying { return true }
    return now - lastWrite >= nowPlayingArtistInterval
}
