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
    #expect(radio.display(playback: .idle).title == "")
}

@Test func wheelSwitchesOnAtTheClick() {
    var radio = Radio(file: file)
    #expect(!radio.powerOn)
    radio.setWheel(0.14)
    #expect(!radio.powerOn)
    #expect(radio.loudness == 0)
    radio.setWheel(0.15)
    #expect(radio.powerOn)
    #expect(abs(radio.loudness - 0.2) < 1e-9)
    radio.setWheel(1)
    #expect(abs(radio.loudness - 1) < 1e-9)
}

@Test func wheelClampsAndIgnoresNaN() {
    var radio = Radio(file: file)
    radio.setWheel(7)
    #expect(radio.wheel == 1)
    radio.setWheel(-3)
    #expect(radio.wheel == 0)
    radio.setWheel(0.5)
    radio.setWheel(.nan)
    #expect(radio.wheel == 0.5)
}

@Test func wheelOffSilences() {
    var radio = Radio(file: file)
    radio.setWheel(0.8)
    #expect(radio.station?.frequency == 98.0)
    radio.setWheel(0.1)
    #expect(radio.station == nil)
    #expect(!radio.isLive)
}

@Test func toggleReturnsToTheLastLoudness() {
    var radio = Radio(file: file)
    radio.togglePower()
    #expect(abs(radio.wheel - 0.6) < 1e-9)
    radio.setWheel(0.9)
    radio.togglePower()
    #expect(radio.wheel == 0)
    radio.togglePower()
    #expect(abs(radio.wheel - 0.9) < 1e-9)
}

@Test func shutKeepsPlaying() {
    var radio = Radio(file: file)
    radio.setWheel(0.8)
    radio.setPose(shut)
    #expect(radio.isLive)
    #expect(radio.station?.frequency == 98.0)
    #expect(radio.display(playback: .playing).title == "KSEA Name")
}

@Test func everyPosePlays() {
    var radio = Radio(file: file)
    radio.togglePower()
    for input in [flex, book, tent, flat, shut] {
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
        #expect(abs(radio.tuning.needle - 0.5175) < 1e-9)
    }
}

@Test func tuneMovesNeedleAndSnaps() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.5175)
    #expect(radio.tuning.locked?.frequency == 98.0)
    #expect(abs(radio.tuning.needle - 0.5175) < 1e-9)
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

    #expect(radio.display(playback: .idle) == Display(title: "", subtitle: "", lamp: .off, bars: 0))

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
    #expect(radio.display(playback: .playing).title == "KSEA Name")   // shut shows the station, as tent does
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
    radio.tune(toPosition: 0.5175)                 // locks, and the needle stays where it was tuned
    #expect(radio.position == 0.5175)
    #expect(abs(radio.tuning.needle - 0.5175) < 1e-9)
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
    #expect(abs(radio.tuning.needle - (111.4 - 70) / 80) < 1e-9)   // off the mark until settled
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

@Test func needleFollowsInsideTheZone() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.5175)                      // inside the 98.0 zone, off the mark
    #expect(radio.tuning.locked?.callSign == "KSEA")
    #expect(abs(radio.tuning.needle - 0.5175) < 1e-9)
    #expect(abs(radio.tuning.frequency - 98.0) < 0.5)
    #expect(radio.tuning.frequency != 98.0)
    radio.togglePower()
    #expect(radio.display(playback: .playing).title == "KSEA Name")   // still shows the station
}

@Test func settleTargetIsTheLockedMark() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.5175)
    #expect(radio.settleTarget == radio.scale.marks[0].position)
    radio.tune(toPosition: 0.625)
    #expect(radio.tuning.locked == nil)
    #expect(radio.settleTarget == nil)
    #expect(Radio(file: .empty).settleTarget == nil)
}

@Test func offShowsNoWords() {
    var radio = Radio(file: file)
    radio.togglePower()
    radio.togglePower()
    for pose in [flex, book, tent, shut] {
        radio.setPose(pose)
        let display = radio.display(playback: .idle)
        #expect(display.title.isEmpty)
        #expect(display.subtitle.isEmpty)
        #expect(display.lamp == .off)
    }
}
