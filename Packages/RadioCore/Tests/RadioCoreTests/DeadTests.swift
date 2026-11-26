import Foundation
import Testing
@testable import RadioCore

private func station(_ call: String, _ mhz: Double) -> Station {
    Station(callSign: call, name: "\(call) Name", licenceCity: "\(call) City", frequency: mhz,
            streamURL: URL(string: "https://example.com/\(call)")!)
}

// Two stations in Seattle, one in Chicago.
private let file = StationFile(generated: "test", cities: [
    City(id: "seattle", name: "Seattle", key: "SEA", stations: [station("KLOW", 90.1), station("KSEA", 98.0)]),
    City(id: "chicago", name: "Chicago", key: "CHI", stations: [station("WCHI", 90.1)]),
])

private let off = 0.95                           // between stations, high on the dial

private func mark(_ radio: Radio, _ call: String) -> Double {
    radio.scale.marks.first { $0.station.callSign == call }!.position
}

/// Switched on, with KSEA under the needle, marked dead at t = 0 and the needle moved off it.
private func radioWithKSEADead() -> Radio {
    var radio = Radio(file: file)
    radio.togglePower()
    radio.tune(toPosition: mark(radio, "KSEA"))
    radio.markDead("KSEA", at: 0)
    radio.tune(toPosition: off)
    return radio
}

@Test func aDeadStationIsNotTriedAgainWithinAMinute() {
    var radio = radioWithKSEADead()
    radio.tune(toPosition: mark(radio, "KSEA"))
    #expect(radio.retryDeadUnderNeedle(at: 59) == nil)
    #expect(radio.dead == ["KSEA"])
    #expect(radio.station == nil)
    #expect(radio.display(playback: .idle).subtitle == "No signal")
}

@Test func aDeadStationIsTriedAgainAfterAMinute() {
    var radio = radioWithKSEADead()
    radio.tune(toPosition: mark(radio, "KSEA"))
    #expect(radio.retryDeadUnderNeedle(at: 60) == "KSEA")
    #expect(radio.dead.isEmpty)
    #expect(radio.station?.callSign == "KSEA")
    #expect(radio.retryDeadUnderNeedle(at: 61) == nil)             // once: it is live now
}

@Test func onlyTheStationUnderTheNeedleIsTriedAgain() {
    var radio = radioWithKSEADead()
    radio.markDead("KLOW", at: 0)
    #expect(radio.tuning.candidate == nil)
    #expect(radio.retryDeadUnderNeedle(at: 1_000) == nil)            // between stations
    #expect(radio.dead == ["KSEA", "KLOW"])
    radio.tune(toPosition: mark(radio, "KSEA"))
    #expect(radio.retryDeadUnderNeedle(at: 1_000) == "KSEA")
    #expect(radio.dead == ["KLOW"])
}

@Test func markedDeadAgainTheMinuteStartsAfresh() {
    var radio = radioWithKSEADead()
    radio.tune(toPosition: mark(radio, "KSEA"))
    #expect(radio.retryDeadUnderNeedle(at: 60) == "KSEA")
    radio.markDead("KSEA", at: 72)                                  // failed again
    #expect(radio.retryDeadUnderNeedle(at: 100) == nil)
    #expect(radio.retryDeadUnderNeedle(at: 132) == "KSEA")
}

@Test func aRevivedStationIsRetriedOnlyOnItsOwnMinute() {
    // Brought back by choosing HERE, then dead again: the old time is forgotten.
    var radio = Radio(file: file, here: true)
    radio.togglePower()
    radio.selectCity(hereID)
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    radio.markDead("KHER", at: 0)
    radio.selectCity(hereID)
    #expect(radio.dead.isEmpty)
    #expect(radio.station?.callSign == "KHER")
    radio.markDead("KHER", at: 500)
    #expect(radio.retryDeadUnderNeedle(at: 540) == nil)
    #expect(radio.retryDeadUnderNeedle(at: 560) == "KHER")
}

@Test func theNetworkComingBackRevivesEveryDeadStation() {
    var radio = radioWithKSEADead()
    radio.markDead("KLOW", at: 150)
    radio.markDead("WCHI", at: 155)
    radio.reviveAllDead()
    #expect(radio.dead.isEmpty)
    radio.tune(toPosition: mark(radio, "KSEA"))
    #expect(radio.station?.callSign == "KSEA")
    #expect(radio.retryDeadUnderNeedle(at: 156) == nil)              // nothing left to retry
}

@Test func revivingIsNotFeltAndLeavesPowerAndSuspensionAlone() {
    var radio = radioWithKSEADead()
    radio.tune(toPosition: mark(radio, "KSEA"))
    radio.setSuspended(true)
    var next = radio
    #expect(next.retryDeadUnderNeedle(at: 60) == "KSEA")
    #expect(feel(from: radio, to: next) == nil)
    #expect(next.powerOn && next.isSuspended)
    var all = radio
    all.reviveAllDead()
    #expect(feel(from: radio, to: all) == nil)
    #expect(all.powerOn && all.isSuspended)
}
