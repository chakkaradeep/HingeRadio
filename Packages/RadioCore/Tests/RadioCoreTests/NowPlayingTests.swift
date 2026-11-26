import Foundation
import Testing
@testable import RadioCore

private let kexp = Station(callSign: "KEXP-FM", name: "KEXP", licenceCity: "Seattle", frequency: 90.3,
                           streamURL: URL(string: "https://example.com/kexp")!)
private let kpls = Station(callSign: "KPLS", name: "KPLS Radio", licenceCity: "West Fargo", frequency: 101.1,
                           streamURL: URL(string: "https://example.com/kpls")!)

private let file = StationFile(generated: "test", cities: [
    City(id: "seattle", name: "Seattle", key: "SEA", stations: [kexp]),
])

/// Switched on, the needle on `station`'s mark.
private func radioOn(_ station: Station = kexp, here: Bool = false) -> Radio {
    var radio = Radio(file: file, here: here)
    radio.togglePower()
    if let mark = radio.scale.marks.first(where: { $0.station == station }) {
        radio.tune(toPosition: mark.position)
    }
    return radio
}

@Test func nowPlayingIsNilWhileOff() {
    let radio = Radio(file: file)
    #expect(!radio.powerOn)
    #expect(radio.nowPlaying(playback: .idle) == nil)
    #expect(radio.nowPlaying(playback: .playing) == nil)
}

@Test func nowPlayingClearsWhenSwitchedOff() {
    var radio = radioOn()
    #expect(radio.nowPlaying(playback: .playing) != nil)
    radio.togglePower()
    #expect(radio.nowPlaying(playback: .idle) == nil)
}

@Test func nowPlayingShowsTheLockedStation() {
    let radio = radioOn()
    #expect(radio.tuning.locked == kexp)
    #expect(radio.nowPlaying(playback: .playing)
        == NowPlaying(title: "KEXP", artist: "90.3 MHz · Seattle", album: "Seattle", isPlaying: true))
}

@Test func nowPlayingWhileConnectingIsNotPlaying() {
    let radio = radioOn()
    let shown = radio.nowPlaying(playback: .connecting)
    #expect(shown?.title == "KEXP")
    #expect(shown?.isPlaying == false)
    #expect(radio.nowPlaying(playback: .idle)?.isPlaying == false)
}

@Test func nowPlayingBetweenStationsShowsTheNeedle() {
    var radio = radioOn()
    radio.tune(toPosition: 1)
    #expect(radio.tuning.locked == nil)
    #expect(radio.nowPlaying(playback: .idle)
        == NowPlaying(title: "Between stations", artist: "108.5 MHz", album: "Seattle", isPlaying: false))
    radio.tune(toPosition: 0.8)
    let expected = String(format: "%.1f MHz", radio.tuning.frequency)
    #expect(radio.nowPlaying(playback: .idle)?.artist == expected)
}

@Test func nowPlayingSaysNoSignalForADeadStation() {
    var radio = radioOn()
    radio.markDead(kexp.callSign)
    #expect(radio.nowPlaying(playback: .idle)
        == NowPlaying(title: "No signal", artist: "90.3 MHz · Seattle", album: "Seattle", isPlaying: false))
}

@Test func nowPlayingOnHereShowsTheTown() throws {
    var radio = Radio(file: file, here: true)
    radio.togglePower()
    radio.selectCity(hereID)
    radio.setHereStations([kpls], town: "Fargo")
    let mark = try #require(radio.scale.marks.first)
    radio.tune(toPosition: mark.position)
    #expect(radio.nowPlaying(playback: .playing)
        == NowPlaying(title: "KPLS Radio", artist: "101.1 MHz · West Fargo", album: "Fargo", isPlaying: true))
}

@Test func nowPlayingDuringHereSweepIsBetweenStations() throws {
    var radio = Radio(file: file, here: true)
    radio.togglePower()
    radio.selectCity(hereID)
    radio.setHereStations([kpls], town: "Fargo")
    let mark = try #require(radio.scale.marks.first)
    radio.tune(toPosition: mark.position)
    radio.setScanning(true)
    #expect(radio.isScanningHere)
    #expect(radio.nowPlaying(playback: .idle)
        == NowPlaying(title: "Between stations", artist: "101.1 MHz", album: "Fargo", isPlaying: false))
}

private let shown = NowPlaying(title: "Between stations", artist: "95.1 MHz", album: "Seattle", isPlaying: false)

@Test func nowPlayingWriteIsNeverDueForNoChange() {
    #expect(!nowPlayingWriteIsDue(last: nil, next: nil, lastWrite: nil, now: 0))
    #expect(!nowPlayingWriteIsDue(last: shown, next: shown, lastWrite: 0, now: 10))
}

@Test func nowPlayingWriteIsDueAtOnceForPowerAndTitleAlbumPlaying() {
    #expect(nowPlayingWriteIsDue(last: nil, next: shown, lastWrite: 5, now: 5))
    #expect(nowPlayingWriteIsDue(last: shown, next: nil, lastWrite: 5, now: 5))
    let station = NowPlaying(title: "KEXP", artist: "90.3 MHz · Seattle", album: "Seattle", isPlaying: false)
    #expect(nowPlayingWriteIsDue(last: shown, next: station, lastWrite: 5, now: 5))
    let otherBand = NowPlaying(title: shown.title, artist: shown.artist, album: "Fargo", isPlaying: false)
    #expect(nowPlayingWriteIsDue(last: shown, next: otherBand, lastWrite: 5, now: 5))
    let playing = NowPlaying(title: shown.title, artist: shown.artist, album: shown.album, isPlaying: true)
    #expect(nowPlayingWriteIsDue(last: shown, next: playing, lastWrite: 5, now: 5))
}

@Test func nowPlayingArtistAloneWaitsAQuarterSecond() {
    let moved = NowPlaying(title: shown.title, artist: "95.2 MHz", album: shown.album, isPlaying: false)
    #expect(nowPlayingWriteIsDue(last: shown, next: moved, lastWrite: nil, now: 5))
    #expect(!nowPlayingWriteIsDue(last: shown, next: moved, lastWrite: 5, now: 5.24))
    #expect(nowPlayingWriteIsDue(last: shown, next: moved, lastWrite: 5, now: 5.25))
}
