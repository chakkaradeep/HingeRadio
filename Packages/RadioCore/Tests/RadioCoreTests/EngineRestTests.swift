import Testing
import Foundation
@testable import RadioCore

@Test func liveNeverRests() {
    #expect(!engineMayRest(isLive: true, lastSound: nil, now: 100))
    #expect(!engineMayRest(isLive: true, lastSound: 0, now: 100))
}

@Test func offWithNoSoundRests() {
    #expect(engineMayRest(isLive: false, lastSound: nil, now: 0))
}

@Test func offRestsTwoSecondsAfterTheLastSound() {
    #expect(engineRestDelay == 2)
    #expect(!engineMayRest(isLive: false, lastSound: 10, now: 11.9))
    #expect(engineMayRest(isLive: false, lastSound: 10, now: 12))
}

private let station = Station(callSign: "AAAA", name: "AAAA Name", licenceCity: "AAAA City", frequency: 98.0,
                              streamURL: URL(string: "https://example.com/AAAA")!)

@Test func aFreshConnectionIsIdle() {
    #expect(Connection().isIdle)
}

@Test func aWantedStationIsWork() {
    var connection = Connection()
    connection.want(station, at: 0)
    #expect(!connection.isIdle)
    #expect(connection.tick(at: 0.24) == .connect(station))
    #expect(!connection.isIdle)
}

@Test func aHeldConnectionIsWork() {
    var connection = Connection()
    connection.want(station, at: 0)
    _ = connection.tick(at: 0.24)
    connection.want(nil, at: 1)
    #expect(!connection.isIdle)          // the hold timer is running
    #expect(connection.tick(at: 7) == .disconnect)
    #expect(connection.isIdle)
}

@Test func aResetConnectionIsIdle() {
    var connection = Connection()
    connection.want(station, at: 0)
    _ = connection.tick(at: 0.24)
    #expect(connection.reset() == .disconnect)
    #expect(connection.isIdle)
}
