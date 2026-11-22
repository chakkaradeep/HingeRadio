import Testing
import Foundation
@testable import RadioCore

private func station(_ call: String, _ mhz: Double) -> Station {
    Station(callSign: call, name: call, licenceCity: "Town", frequency: mhz,
            streamURL: URL(string: "https://example.com/\(call)")!)
}

private func r(_ angle: Double) -> HingeReading {
    HingeReading(angle: angle, isClosed: false, time: 0)
}

private func makeTuner(_ stations: [Station] = [station("KAAA", 98.0)]) -> Tuner {
    Tuner(stations: stations, config: DialConfig())
}

@Test func locksAndSnaps() {
    var t = makeTuner()
    let s = t.update(r(111.4))
    #expect(s.locked?.frequency == 98.0)
    #expect(abs(s.needle - 0.5) < 1e-9)
    #expect(abs(s.frequency - 98.0) < 1e-9)
    #expect(s.strength == 1)
}

@Test func holdsWithinReleaseMargin() {
    var t = makeTuner()
    t.update(r(110))
    let s = t.update(r(111.9))
    #expect(s.locked?.frequency == 98.0)
}

@Test func releasesPastMargin() {
    var t = makeTuner()
    t.update(r(110))
    let s = t.update(r(112.1))
    #expect(s.locked == nil)
    #expect(abs(s.needle - 0.52625) < 1e-9)
    #expect(abs(s.strength - 0.2) < 1e-5)
    #expect(s.candidate?.frequency == 98.0)
}

@Test func approachDoesNotLockEarly() {
    var t = makeTuner()
    let s = t.update(r(111.9))
    #expect(s.locked == nil)
    #expect(abs(s.strength - 0.46667) < 1e-5)
}

@Test func staticBeyondFade() {
    var t = makeTuner()
    let s = t.update(r(113.0))
    #expect(s.strength == 0)
    #expect(s.candidate == nil)
    #expect(abs(s.edgeDistance - 1.5) < 1e-9)
}

@Test func neighboursNeverOverlap() {
    var t = makeTuner([station("KAAA", 98.0), station("KBBB", 98.2)])
    let marks = t.scale.marks
    let mid = (marks[0].angle + marks[1].angle) / 2
    let s = t.update(r(mid))
    #expect(s.strength < 1e-9)
    #expect(s.locked == nil)
}

@Test func badAnglesAreSafe() {
    var t = makeTuner()
    t.update(r(111.9))
    let before = t.state
    #expect(t.update(r(.nan)) == before)
    #expect(t.state == before)

    let low = t.update(r(-20))
    #expect(low.needle == 0)
    #expect(abs(low.frequency - 87.5) < 1e-9)

    #expect(t.update(r(400)).needle == 1)

    t.update(r(0))
    #expect(t.update(r(180)).needle == 1)
}

@Test func zoneEdgeIsInclusive() {
    var upper = makeTuner()
    #expect(upper.update(r(111.5)).locked?.frequency == 98.0)
    var lower = makeTuner()
    #expect(lower.update(r(108.5)).locked?.frequency == 98.0)
}
