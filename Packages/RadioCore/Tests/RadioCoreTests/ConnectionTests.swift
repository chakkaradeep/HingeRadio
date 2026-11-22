import Testing
import Foundation
@testable import RadioCore

private func station(_ call: String) -> Station {
    Station(callSign: call, name: "\(call) Name", licenceCity: "\(call) City", frequency: 98.0,
            streamURL: URL(string: "https://example.com/\(call)")!)
}

private let a = station("AAAA"), b = station("BBBB"), c = station("CCCC")

/// A connection with `a` connected at 0.24 and reported playing at 1.
private func playingA() -> Connection {
    var connection = Connection()
    connection.want(a, at: 0)
    #expect(connection.tick(at: 0.24) == .connect(a))
    connection.playerReported(a, playing: true, at: 1)
    return connection
}

@Test func sweepingConnectsOnlyTheLast() {
    var connection = Connection()
    connection.want(a, at: 0)
    connection.want(b, at: 0.1)
    connection.want(c, at: 0.2)
    #expect(connection.tick(at: 0.3) == .none)
    #expect(connection.tick(at: 0.45) == .connect(c))
    #expect(connection.connected == c)
}

@Test func holdsThenDrops() {
    var connection = playingA()
    connection.want(nil, at: 10)
    #expect(connection.tick(at: 15.9) == .none)
    #expect(connection.connected == a)
    #expect(connection.tick(at: 16) == .disconnect)
    #expect(connection.connected == nil)
}

@Test func returningWithinHoldKeepsIt() {
    var connection = playingA()
    connection.want(nil, at: 10)
    connection.want(a, at: 12)
    #expect(connection.tick(at: 20) == .none)
    #expect(connection.connected == a)
}

@Test func neverStartingFails() {
    var connection = Connection()
    connection.want(a, at: 0)
    #expect(connection.tick(at: 0.24) == .connect(a))
    #expect(connection.tick(at: 12.2) == .none)
    #expect(connection.tick(at: 12.25) == .fail(a))
    #expect(connection.connected == nil)
    #expect(connection.tick(at: 13) == .none)   // the wanted station is forgotten, so no reconnect
}

@Test func stallAfterPlayingFails() {
    var connection = playingA()
    connection.playerReported(a, playing: false, at: 5)
    #expect(connection.tick(at: 16.9) == .none)
    #expect(connection.tick(at: 17) == .fail(a))
    #expect(connection.connected == nil)
}

@Test func resetForgetsPending() {
    var pending = Connection()
    pending.want(a, at: 0)
    #expect(pending.reset() == .none)
    #expect(pending.tick(at: 1) == .none)
    #expect(pending.connected == nil)

    var connecting = Connection()
    connecting.want(a, at: 0)
    #expect(connecting.tick(at: 0.24) == .connect(a))
    #expect(connecting.reset() == .disconnect)
    #expect(connecting.connected == nil)
    #expect(connecting.tick(at: 13) == .none)
    connecting.playerReported(a, playing: true, at: 14)
    #expect(connecting.connected == nil)
    #expect(connecting.tick(at: 30) == .none)
}
