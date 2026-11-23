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

private let flex = PoseInput(screen: .inner, landscape: false, angle: 110, status: .partiallyOpen)
private let book = PoseInput(screen: .inner, landscape: true, angle: 110, status: .partiallyOpen)
private let tent = PoseInput(screen: .outer, landscape: true, angle: 60, status: .closed)
private let flat = PoseInput(screen: .inner, landscape: false, angle: 180, status: .fullyOpen)
private let shut = PoseInput(screen: .outer, landscape: false, angle: 0, status: .closed)

@Test func startsOffMidDialInFlex() {
    let radio = Radio(file: file)
    #expect(radio.pose == .flex)
    #expect(abs(radio.tuning.needle - 0.5) < 1e-9)
    #expect(radio.station == nil)
    #expect(radio.display(playback: .idle).title == "Off")
}

@Test func shuttingSilencesAndReopeningResumes() {
    var radio = Radio(file: file)
    radio.togglePower()
    radio.setPose(shut)
    #expect(radio.station == nil)
    #expect(!radio.isLive)
    radio.setPose(flex)
    #expect(radio.station?.frequency == 98.0)
    #expect(radio.powerOn)
}

@Test func everyPoseButShutPlays() {
    var radio = Radio(file: file)
    radio.togglePower()
    for input in [flex, book, tent, flat] {
        radio.setPose(input)
        #expect(radio.isLive)
        #expect(radio.station?.frequency == 98.0)
    }
}

@Test func poseChangeKeepsNeedleAndLock() {
    var radio = Radio(file: file)
    radio.togglePower()
    radio.tune(toPosition: 0.5175)                      // inside the zone, off the mark
    for input in [book, tent, flat, flex] {
        radio.setPose(input)
        #expect(radio.tuning.locked?.frequency == 98.0)
        #expect(abs(radio.tuning.needle - 0.5) < 1e-9)
    }
}

@Test func tuneMovesNeedleAndSnaps() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.5175)
    #expect(radio.tuning.locked?.frequency == 98.0)
    #expect(abs(radio.tuning.needle - 0.5) < 1e-9)
    radio.tune(toPosition: 0.625)
    #expect(radio.tuning.locked == nil)
    #expect(abs(radio.tuning.needle - 0.625) < 1e-9)
}

@Test func tuneClampsAndIgnoresNaN() {
    var radio = Radio(file: file)
    radio.tune(toPosition: -1)
    #expect(radio.tuning.needle == 0)
    #expect(abs(radio.tuning.frequency - 87.5) < 1e-9)
    radio.tune(toPosition: 2)
    #expect(radio.tuning.needle == 1)
    radio.tune(toPosition: .nan)
    #expect(radio.tuning.needle == 1)
    radio.selectCity("chicago")                         // the not-a-number was never stored
    #expect(radio.tuning.needle == 1)
}

@Test func nanHingeAngleKeepsPose() {
    var radio = Radio(file: file)
    radio.setPose(shut)
    radio.setPose(PoseInput(screen: .inner, landscape: false, angle: .nan, status: .partiallyOpen))
    #expect(radio.pose == .shut)
}

@Test func powerOnPlaysLockedStation() {
    var radio = Radio(file: file)
    radio.togglePower()
    #expect(radio.station?.frequency == 98.0)
}

@Test func cityKeepsNeedle() {
    var radio = Radio(file: file)
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
    radio.togglePower()
    radio.markDead("KSEA")
    #expect(radio.station == nil)
    #expect(radio.tuning.locked != nil)
    #expect(radio.display(playback: .connecting).subtitle == "No signal")
}

@Test func displayCopy() {
    var radio = Radio(file: file)

    #expect(radio.display(playback: .idle) == Display(title: "Off", subtitle: "Switch on to listen", lamp: .off, bars: 0))

    radio.togglePower()
    #expect(radio.display(playback: .connecting)
            == Display(title: "KSEA Name", subtitle: "Tuning in", lamp: .seeking, bars: 0))
    #expect(radio.display(playback: .playing)
            == Display(title: "KSEA Name", subtitle: "KSEA City", lamp: .locked, bars: 5))

    radio.tune(toPosition: (120 - 70) / 80)
    #expect(radio.display(playback: .idle) == Display(title: "· · ·", subtitle: "Static", lamp: .off, bars: 0))

    radio.tune(toPosition: (110 - 70) / 80)
    radio.markDead("KSEA")
    #expect(radio.display(playback: .idle).subtitle == "No signal")

    radio.setPose(flat)
    #expect(radio.display(playback: .playing)
            == Display(title: "Fold me", subtitle: "Sit the phone half open to use the radio.", lamp: .off, bars: 0))
    radio.setPose(shut)
    #expect(radio.display(playback: .playing)
            == Display(title: "Closed", subtitle: "Open the phone to listen again.", lamp: .off, bars: 0))
    radio.setPose(book)
    #expect(radio.display(playback: .playing).subtitle == "No signal")   // book shows the station, as flex does
}

@Test func emptyFileIsStaticOnly() {
    var radio = Radio(file: .empty)
    radio.togglePower()
    #expect(radio.station == nil)
    #expect(radio.display(playback: .idle).title == "· · ·")
    #expect(radio.cityID == "")
}

@Test func suspendingSilencesAndResumingRestores() {
    var radio = Radio(file: file)
    radio.togglePower()
    #expect(radio.tuning.locked != nil)
    radio.setSuspended(true)
    #expect(radio.isSuspended)
    #expect(!radio.isLive)
    #expect(radio.station == nil)
    radio.setSuspended(false)
    #expect(radio.station?.frequency == 98.0)
    #expect(radio.powerOn)
}

@Test func partialBars() {
    var radio = Radio(file: file)
    radio.togglePower()
    radio.tune(toPosition: (120 - 70) / 80)                 // outside the zone, so the next readings are not held
    radio.tune(toPosition: (111.875 - 70) / 80)             // 1.5 past the mark plus half the fade
    #expect(radio.tuning.locked == nil)
    #expect(abs(radio.tuning.strength - 0.5) < 1e-9)
    #expect(radio.display(playback: .playing).bars == 3)
    radio.tune(toPosition: (112.175 - 70) / 80)
    #expect(abs(radio.tuning.strength - 0.1) < 1e-9)
    #expect(radio.display(playback: .playing).bars == 1)
}

@Test func positionIsTheRawTunedValue() {
    var radio = Radio(file: file)
    #expect(radio.position == 0.5)
    radio.tune(toPosition: 0.5175)                 // snaps the needle, not the position
    #expect(radio.position == 0.5175)
    #expect(abs(radio.tuning.needle - 0.5) < 1e-9)
    radio.tune(toPosition: 2)
    #expect(radio.position == 1)
    radio.tune(toPosition: .nan)
    #expect(radio.position == 1)
}

@Test func settlingMovesPositionOntoTheLockedMark() {
    var radio = Radio(file: file)
    radio.tune(toPosition: (120 - 70) / 80)                 // well outside, so nothing is held
    radio.tune(toPosition: (111.4 - 70) / 80)               // the edge of KSEA's zone: locks there
    #expect(radio.tuning.locked?.callSign == "KSEA")
    let mark = radio.scale.marks[0].position
    radio.settleOnLockedStation()
    #expect(radio.position == mark)
    #expect(radio.tuning.locked?.callSign == "KSEA")
    #expect(radio.tuning.needle == mark)
}

@Test func settlingWithNothingLockedKeepsPosition() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.625)
    #expect(radio.tuning.locked == nil)
    radio.settleOnLockedStation()
    #expect(radio.position == 0.625)
    #expect(radio.tuning.locked == nil)
}

@Test func liveMarksLeaveOutDeadStations() {
    let twoStations = StationFile(generated: "test", cities: [
        City(id: "seattle", name: "Seattle", key: "seattle", stations: [station("KAAA", 90.0), station("KBBB", 100.0)]),
    ])
    var radio = Radio(file: twoStations)
    #expect(radio.liveMarkPositions == radio.scale.marks.map(\.position))
    radio.markDead("KAAA")
    #expect(radio.liveMarkPositions == [radio.scale.marks[1].position])
}
