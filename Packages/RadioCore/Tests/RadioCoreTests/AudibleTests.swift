import Testing
import Foundation
@testable import RadioCore

private func station(_ call: String) -> Station {
    Station(callSign: call, name: call, licenceCity: "Town", frequency: 98.0,
            streamURL: URL(string: "https://example.com/\(call)")!)
}

private let a = station("AAAA"), b = station("BBBB")

@Test func nothingWantedIsIdle() {
    #expect(audiblePlayback(reported: .playing, connected: a, wanted: nil) == .idle)
}

@Test func wantedAndConnectedAndPlayingIsPlaying() {
    #expect(audiblePlayback(reported: .playing, connected: a, wanted: a) == .playing)
}

@Test func playingAnotherStationIsConnecting() {
    #expect(audiblePlayback(reported: .playing, connected: a, wanted: b) == .connecting)
}

@Test func wantedAndConnectedButConnectingIsConnecting() {
    #expect(audiblePlayback(reported: .connecting, connected: a, wanted: a) == .connecting)
}
