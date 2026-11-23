import Testing
import Foundation
@testable import RadioCore

private func station(_ call: String, _ mhz: Double) -> Station {
    Station(callSign: call, name: call, licenceCity: "Town", frequency: mhz,
            streamURL: URL(string: "https://example.com/\(call)")!)
}

// Seattle's only station sits mid-dial; Chicago's sits where Seattle has static (position 0.625).
private let file = StationFile(generated: "test", cities: [
    City(id: "seattle", name: "Seattle", key: "seattle", stations: [station("KSEA", 98.0)]),
    City(id: "chicago", name: "Chicago", key: "chicago", stations: [station("WCHI", 100.6)]),
])

private let book = PoseInput(screen: .inner, landscape: true, angle: 110, status: .partiallyOpen)
private let shut = PoseInput(screen: .outer, landscape: false, angle: 0, status: .closed)

private func changed(_ radio: Radio, _ change: (inout Radio) -> Void) -> Feel? {
    var next = radio
    change(&next)
    return feel(from: radio, to: next)
}

@Test func nothingAtLaunchOrWithoutAChange() {
    let radio = Radio(file: file)
    #expect(feel(from: radio, to: radio) == nil)
    #expect(changed(radio) { $0.setSuspended(false) } == nil)    // the first scene-phase report
}

@Test func nothingOnAPoseChange() {
    var radio = Radio(file: file)
    radio.togglePower()
    #expect(changed(radio) { $0.setPose(book) } == nil)
    #expect(changed(radio) { $0.setPose(shut) } == nil)
}

@Test func nothingOnSuspendOrResume() {
    var radio = Radio(file: file)
    radio.togglePower()
    #expect(changed(radio) { $0.setSuspended(true) } == nil)
    radio.setSuspended(true)
    #expect(changed(radio) { $0.setSuspended(false) } == nil)
}

@Test func nothingWhenAStationIsMarkedDead() {
    var radio = Radio(file: file)
    radio.togglePower()
    #expect(changed(radio) { $0.markDead("KSEA") } == nil)
}

@Test func bandClickBeatsTheLockItBrings() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.625)
    #expect(radio.tuning.locked == nil)
    var next = radio
    next.selectCity("chicago")
    #expect(next.tuning.locked?.callSign == "WCHI")
    #expect(feel(from: radio, to: next) == .bandClick)
}

@Test func powerClickBeatsALock() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.625)
    #expect(changed(radio) { $0.setWheel(0.8); $0.tune(toPosition: 0.5) } == .powerClick)
    #expect(changed(radio) { $0.togglePower() } == .powerClick)
}

@Test func powerClickBeatsTheVolumeStop() {
    var radio = Radio(file: file)
    radio.setWheel(0.5)
    #expect(changed(radio) { $0.setWheel(0) } == .powerClick)
}

@Test func aNewLockClicksAndAReleaseDoesNot() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.625)
    #expect(changed(radio) { $0.tune(toPosition: 0.51) } == .lockClick(callSign: "KSEA"))
    radio.tune(toPosition: 0.51)
    #expect(changed(radio) { $0.tune(toPosition: 0.515) } != .lockClick(callSign: "KSEA"))   // held: no second click
    let release = changed(radio) { $0.tune(toPosition: 0.6) }
    #expect(release == .tuningTick)                                  // ridges passed, no click
}

@Test func stopBeatsTickAtTheEnds() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.99)
    #expect(changed(radio) { $0.tune(toPosition: 1) } == .tuningStop)
    radio.tune(toPosition: 1)
    #expect(changed(radio) { $0.tune(toPosition: 2) } == nil)        // already there: no second stop
    radio.tune(toPosition: 0.004)
    #expect(changed(radio) { $0.tune(toPosition: 0) } == .tuningStop)

    radio.setWheel(0.97)
    #expect(changed(radio) { $0.setWheel(1) } == .volumeStop)
    radio.setWheel(0.1)                                              // off
    #expect(changed(radio) { $0.setWheel(0) } == .volumeStop)
}

@Test func tuningTicksOnARidgeOnOrOff() {
    var radio = Radio(file: file)
    radio.tune(toPosition: 0.6)
    #expect(changed(radio) { $0.tune(toPosition: 0.61) } == .tuningTick)
    #expect(changed(radio) { $0.tune(toPosition: 0.6005) } == nil)  // inside one ridge
    radio.togglePower()
    #expect(changed(radio) { $0.tune(toPosition: 0.61) } == .tuningTick)
}

@Test func volumeTicksOnlyWhileOn() {
    var radio = Radio(file: file)
    #expect(changed(radio) { $0.setWheel(0.12) } == nil)             // off: passes 0.05 and 0.10 silently
    radio.setWheel(0.5)
    #expect(changed(radio) { $0.setWheel(0.56) } == .volumeTick)
    #expect(changed(radio) { $0.setWheel(0.52) } == nil)
}
