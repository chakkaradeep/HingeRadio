import Testing
import Foundation
@testable import RadioCore

private func station(_ call: String, _ mhz: Double) -> Station {
    Station(callSign: call, name: "\(call) Name", licenceCity: "\(call) City", frequency: mhz,
            streamURL: URL(string: "https://example.com/\(call)")!)
}

private let file = StationFile(generated: "test", cities: [
    City(id: "seattle", name: "Seattle", key: "seattle", stations: [station("KSEA", 98.0)]),
    City(id: "chicago", name: "Chicago", key: "chicago", stations: [station("WCHI", 90.1)]),
])

private func r(_ angle: Double, closed: Bool = false) -> HingeReading {
    HingeReading(angle: angle, isClosed: closed, time: 0)
}

@Test func startsOff() {
    var radio = Radio(file: file)
    radio.hinge(r(110))
    #expect(radio.station == nil)
    #expect(radio.display(playback: .idle).title == "Off")
}

@Test func powerOnPlaysLockedStation() {
    var radio = Radio(file: file)
    radio.hinge(r(110))
    radio.togglePower()
    #expect(radio.station?.frequency == 98.0)
}

@Test func closingSilencesAndReopeningResumes() {
    var radio = Radio(file: file)
    radio.hinge(r(110))
    radio.togglePower()
    radio.hinge(r(110, closed: true))
    #expect(radio.station == nil)
    radio.hinge(r(110))
    #expect(radio.station?.frequency == 98.0)
    #expect(radio.powerOn)
}

@Test func sliderAngleBelow45CountsAsClosed() {
    var radio = Radio(file: file)
    radio.hinge(r(40))
    #expect(radio.isClosed)
}

@Test func cityKeepsNeedle() {
    var radio = Radio(file: file)
    radio.hinge(r(110))
    radio.togglePower()
    radio.selectCity("chicago")
    #expect(radio.cityID == "chicago")
    #expect(radio.station == nil)
    #expect(abs(radio.tuning.needle - 0.5) < 1e-9)
    radio.selectCity("nowhere")
    #expect(radio.cityID == "chicago")
}

@Test func deadStationIsSilentButShown() {
    var radio = Radio(file: file)
    radio.hinge(r(110))
    radio.togglePower()
    radio.markDead("KSEA")
    #expect(radio.station == nil)
    #expect(radio.tuning.locked != nil)
    #expect(radio.display(playback: .connecting).subtitle == "No signal")
}

@Test func displayCopy() {
    var radio = Radio(file: file)
    radio.hinge(r(110))

    #expect(radio.display(playback: .idle) == Display(title: "Off", subtitle: "Switch on to listen", lamp: .off, bars: 0))

    radio.togglePower()
    #expect(radio.display(playback: .connecting)
            == Display(title: "KSEA Name", subtitle: "Tuning in", lamp: .seeking, bars: 0))
    #expect(radio.display(playback: .playing)
            == Display(title: "KSEA Name", subtitle: "KSEA City", lamp: .locked, bars: 5))

    radio.hinge(r(120))
    #expect(radio.display(playback: .idle) == Display(title: "· · ·", subtitle: "Static", lamp: .off, bars: 0))

    radio.hinge(r(110))
    radio.markDead("KSEA")
    #expect(radio.display(playback: .idle).subtitle == "No signal")

    radio.hinge(r(110, closed: true))
    #expect(radio.display(playback: .playing)
            == Display(title: "Closed", subtitle: "Open the phone to listen again.", lamp: .off, bars: 0))
}

@Test func emptyFileIsStaticOnly() {
    var radio = Radio(file: .empty)
    radio.togglePower()
    radio.hinge(r(110))
    #expect(radio.station == nil)
    #expect(radio.display(playback: .idle).title == "· · ·")
    #expect(radio.cityID == "")
}
