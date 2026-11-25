import Foundation
import Testing
@testable import RadioCore

private func station(_ call: String, _ mhz: Double) -> Station {
    Station(callSign: call, name: "\(call) Name", licenceCity: "\(call) City", frequency: mhz,
            streamURL: URL(string: "https://example.com/\(call)")!)
}

// Seattle's only station sits mid-dial, where a first launch settles. Chicago has one low and one
// at 100.1, so nothing is locked mid-dial and a position can rest beside a mark.
private let file = StationFile(generated: "test", cities: [
    City(id: "seattle", name: "Seattle", key: "SEA", stations: [station("KSEA", 98.0)]),
    City(id: "chicago", name: "Chicago", key: "CHI", stations: [station("WCHI", 90.1), station("WLOW", 100.1)]),
])

private let here = City(id: hereID, name: hereName, key: "HERE", stations: [])

/// Where Chicago's 100.1 sits on its dial.
private func chicagoMark(_ call: String) -> Double {
    var radio = Radio(file: file)
    radio.selectCity("chicago")
    return radio.scale.marks.first { $0.station.callSign == call }!.position
}

/// A radio that opened as on a first launch: Seattle, needle settled on KSEA, switched off.
private func expectFirstLaunch(_ radio: Radio) {
    let fresh = Radio(file: file)
    #expect(radio.cityID == "seattle")
    #expect(radio.position == fresh.position)
    #expect(radio.tuning.locked?.callSign == "KSEA")
    #expect(!radio.powerOn)
}

// MARK: - The order

@Test func hereIsTheFirstBandAndTheRadioStillStartsOnTheFirstCity() {
    let radio = Radio(file: file, here: true)
    #expect(radio.cities == [here] + file.cities)
    #expect(radio.cities.map(\.key) == ["HERE", "SEA", "CHI"])
    expectFirstLaunch(radio)
    #expect(radio.hereStatus == .idle)
    #expect(!radio.isScanning)
}

@Test func withoutHereTheOrderIsTheFilesOwn() {
    #expect(Radio(file: file).cities.map(\.id) == ["seattle", "chicago"])
}

// MARK: - Opening where it was left

@Test func opensOnTheRememberedBandSettledOnTheStationOff() {
    let mark = chicagoMark("WLOW")
    let beside = mark + 0.004                                // inside the station's zone, off its mark
    let radio = Radio(file: file, here: true, band: "chicago", position: beside)
    #expect(radio.cityID == "chicago")
    #expect(radio.tuning.locked?.callSign == "WLOW")
    #expect(radio.position == mark)
    #expect(radio.tuning.needle == mark)
    #expect(!radio.powerOn)
    #expect(radio.wheel == 0)
}

@Test func opensInStaticWhereItWasLeft() {
    let radio = Radio(file: file, band: "chicago", position: 0.9)
    #expect(radio.cityID == "chicago")
    #expect(radio.tuning.locked == nil)
    #expect(radio.position == 0.9)
}

@Test(arguments: [0.0, 1.0])
func opensAtEitherEnd(position: Double) {
    #expect(Radio(file: file, band: "chicago", position: position).position == position)
}

@Test func opensOnHereWhereItWasLeftWithNothingFoundYet() {
    let radio = Radio(file: file, here: true, band: hereID, position: 0.3)
    #expect(radio.cityID == hereID)
    #expect(radio.position == 0.3)
    #expect(radio.scale.marks.isEmpty)
    #expect(radio.tuning.locked == nil)
    #expect(radio.hereStatus == .idle)
    #expect(!radio.isScanning)
    #expect(!radio.powerOn)
}

@Test func aBandNotInThisBuildOpensAsAFirstLaunch() {
    expectFirstLaunch(Radio(file: file, band: hereID, position: 0.3))       // HERE left out
    expectFirstLaunch(Radio(file: file, here: true, band: "atlantis", position: 0.3))
    expectFirstLaunch(Radio(file: file, here: true, band: "", position: 0.3))
    expectFirstLaunch(Radio(file: file, here: true, band: "atlantis", position: nil))
}

@Test(arguments: [Double.nan, .infinity, -.infinity, -0.1, 1.5, .greatestFiniteMagnitude])
func aPositionThatIsNotOnTheDialOpensMidDial(position: Double) {
    let radio = Radio(file: file, here: true, band: "chicago", position: position)
    #expect(radio.cityID == "chicago")
    #expect(radio.position == 0.5)
    let seattle = Radio(file: file, band: "seattle", position: position)
    expectFirstLaunch(seattle)
}

@Test func aBandWithNoPositionOpensMidDial() {
    let radio = Radio(file: file, here: true, band: "chicago", position: nil)
    #expect(radio.cityID == "chicago")
    #expect(radio.position == 0.5)
}

@Test func nothingRememberedIsAFirstLaunch() {
    expectFirstLaunch(Radio(file: file, here: true, band: nil, position: 0.3))
    expectFirstLaunch(Radio(file: file, here: true, band: nil, position: nil))
    expectFirstLaunch(Radio(file: file, band: nil, position: nil))
}

@Test func anEmptyFileStillOpensOnHereWhenItWasLeftThere() {
    #expect(Radio(file: .empty, here: true, band: hereID, position: 0.2).cityID == hereID)
    #expect(Radio(file: .empty, here: true, band: "seattle", position: 0.2).cityID == "")
}

// MARK: - What to remember

@Test func theBandAndNeedleAreWhatIsRemembered() {
    var radio = Radio(file: file, here: true)
    #expect(radio.remembered == Remembered(band: "seattle", position: radio.position))
    radio.selectCity("chicago")
    radio.tune(toPosition: 0.8)
    #expect(radio.remembered == Remembered(band: "chicago", position: 0.8))
    radio.togglePower()                                       // power is never remembered
    #expect(radio.remembered == Remembered(band: "chicago", position: 0.8))
}

@Test func nothingIsRememberedWhileHeresSweepMovesTheNeedle() {
    var radio = Radio(file: file, here: true)
    radio.selectCity(hereID)
    radio.setScanning(true)
    radio.tune(toPosition: 0.7)
    #expect(radio.remembered == nil)
    radio.setScanning(false)
    #expect(radio.remembered == Remembered(band: hereID, position: 0.7))
}

@Test func nothingIsRememberedWithNoBand() {
    #expect(Radio(file: .empty).remembered == nil)
}

@Test func whatIsRememberedOpensTheRadioThereAgain() throws {
    var radio = Radio(file: file, here: true)
    radio.selectCity("chicago")
    radio.tune(toPosition: chicagoMark("WLOW"))
    let left = try #require(radio.remembered)
    let reopened = Radio(file: file, here: true, band: left.band, position: left.position)
    #expect(reopened.cityID == "chicago")
    #expect(reopened.position == radio.position)
    #expect(reopened.tuning.locked?.callSign == "WLOW")
}
