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

public extension NowPlaying {
    /// The same card, paused (playback rate 0).
    var paused: NowPlaying { NowPlaying(title: title, artist: artist, album: album, isPlaying: false) }
}

public extension Radio {
    /// Nil while the power is off. Title: the shown name of the station being played (`station`,
    /// the candidate, so a station whose name shows in its fade zone is named too); else "No
    /// signal" when the station under the needle is dead; else the locked station's shown name;
    /// else "Between stations" (also throughout HERE's sweep, which shows no station). Artist: that
    /// station's frequency and licence city, or between stations the needle's frequency. Album: the
    /// band's name, HERE's town on HERE. Playing whenever the radio is live, as a radio plays
    /// static and a station tuning in; paused only while held (switched on but suspended, by an
    /// interruption), so the lock screen's play resumes it and its pause switches off.
    var nowPlaying: NowPlaying? {
        guard powerOn else { return nil }
        let album = cities.first { $0.id == cityID }?.name ?? ""
        func card(_ title: String, _ station: Station) -> NowPlaying {
            NowPlaying(title: title, artist: String(format: "%.1f MHz · %@", station.frequency, station.licenceCity),
                       album: album, isPlaying: isLive)
        }
        if let station { return card(station.shownName, station) }
        if !isScanningHere, let candidate = tuning.candidate, dead.contains(candidate.callSign) {
            return card("No signal", candidate)
        }
        if let locked = lockToShow { return card(locked.shownName, locked) }
        return NowPlaying(title: "Between stations", artist: String(format: "%.1f MHz", tuning.frequency),
                          album: album, isPlaying: isLive)
    }

    /// What the lock screen and Control Center show: `nowPlaying` while the power is on. Off, the
    /// card `kept` when the radio was switched off from afar (the lock screen's pause, or the
    /// headphones going), paused, so its play can switch the radio back on; else nothing.
    func lockScreen(kept: NowPlaying?) -> NowPlaying? {
        powerOn ? nowPlaying : kept?.paused
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
