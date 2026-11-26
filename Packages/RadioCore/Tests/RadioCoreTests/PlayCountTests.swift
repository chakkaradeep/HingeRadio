import Foundation
import Testing
@testable import RadioCore

private func station(_ call: String, id: String? = "id-\(UUID().uuidString)") -> Station {
    Station(callSign: call, name: call, licenceCity: "Town", frequency: 98.1,
            streamURL: URL(string: "https://example.com/\(call)")!, radioBrowserID: id)
}

@Test func aStationCountsWhenItStartsPlaying() {
    let kexp = station("KEXP")
    var count = PlayCount()
    #expect(count.report(.connecting, of: kexp, onHere: true) == nil)
    #expect(count.report(.playing, of: kexp, onHere: true) == kexp.radioBrowserID)
}

@Test func aStallOrAnotherReportOfTheSameStartDoesNotCountAgain() {
    let kexp = station("KEXP")
    var count = PlayCount()
    #expect(count.report(.playing, of: kexp, onHere: true) != nil)
    #expect(count.report(.playing, of: kexp, onHere: true) == nil)
    #expect(count.report(.connecting, of: kexp, onHere: true) == nil)      // a stall
    #expect(count.report(.playing, of: kexp, onHere: true) == nil)         // and it comes back
}

@Test func aRetryAfterAnErrorIsNotANewStart() {
    // The player reports connecting while it loads the station again, never idle.
    let kexp = station("KEXP")
    var count = PlayCount()
    #expect(count.report(.playing, of: kexp, onHere: true) != nil)
    #expect(count.report(.connecting, of: kexp, onHere: true) == nil)
    #expect(count.report(.playing, of: kexp, onHere: true) == nil)
}

@Test func aStationLeftAndChosenAgainCountsAgain() {
    let kexp = station("KEXP")
    var count = PlayCount()
    #expect(count.report(.playing, of: kexp, onHere: true) != nil)
    #expect(count.report(.idle, of: nil, onHere: true) == nil)
    #expect(count.report(.connecting, of: kexp, onHere: true) == nil)
    #expect(count.report(.playing, of: kexp, onHere: true) == kexp.radioBrowserID)
}

@Test func aStationReachedFromAnotherCountsEachTime() {
    let kexp = station("KEXP"), kuow = station("KUOW")
    var count = PlayCount()
    #expect(count.report(.playing, of: kexp, onHere: true) == kexp.radioBrowserID)
    #expect(count.report(.playing, of: kuow, onHere: true) == kuow.radioBrowserID)
    #expect(count.report(.playing, of: kexp, onHere: true) == kexp.radioBrowserID)
}

@Test func nothingCountsOffTheHereBand() {
    let kexp = station("KEXP")
    var count = PlayCount()
    #expect(count.report(.playing, of: kexp, onHere: false) == nil)
    // Counted nowhere, so choosing HERE next, with the same station playing, still counts.
    #expect(count.report(.playing, of: kexp, onHere: true) == kexp.radioBrowserID)
}

@Test func aStationWithoutAnIdCountsForNothing() {
    let fromNPR = station("KUOW", id: nil)
    var count = PlayCount()
    #expect(count.report(.playing, of: fromNPR, onHere: true) == nil)
    #expect(count.report(.playing, of: nil, onHere: true) == nil)
}
