import Foundation
import Testing
@testable import RadioCore

private func station(_ name: String, _ mhz: Double, call: String = "KABC-FM") -> Station {
    Station(callSign: call, name: name, licenceCity: "Town", frequency: mhz,
            streamURL: URL(string: "https://example.com/s")!)
}

@Test(arguments: [
    ("102.5 KZOK", 102.5, "KZOK"), ("WBGO Jazz 88.3", 88.3, "WBGO Jazz"), ("94.7 WLS", 94.7, "WLS"),
    ("103.5 KISS FM", 103.5, "KISS FM"), ("LAist 89.3", 89.3, "LAist"), ("Real 92.3", 92.3, "Real"),
    ("102.7 KIIS FM", 102.7, "KIIS FM"),
])
func shownNameDropsTheStationsOwnFrequency(name: String, mhz: Double, shown: String) {
    #expect(station(name, mhz).shownName == shown)
}

@Test(arguments: [
    ("Hot 97", 97.1), ("Z100", 100.3), ("Power 106", 105.9), ("KEXP", 90.3), ("Classical KING FM", 98.1),
    ("Jazz 90.3", 98.1), ("Mix 1102.5", 102.5), ("K102.5", 102.5), ("102.55 Max", 102.5),
])
func shownNameKeepsOtherNumbers(name: String, mhz: Double) {
    #expect(station(name, mhz).shownName == name)
}

@Test func shownNameClosesTheGapInTheMiddle() {
    #expect(station("Rock 95.5 Chicago", 95.5).shownName == "Rock Chicago")
}

@Test func shownNameFallsBackToTheCallSign() {
    #expect(station("94.7", 94.7, call: "WLS-FM").shownName == "WLS")
    #expect(station("94.7 FM", 94.7, call: "WLS-FM").shownName == "WLS")
}

@Test func displayShowsTheShortName() {
    let city = City(id: "c", name: "C", key: "C", stations: [station("94.7 WLS", 94.7)])
    var radio = Radio(file: StationFile(generated: "", cities: [city]))
    radio.setWheel(0.6)
    radio.tune(toPosition: radio.scale.marks[0].position)
    #expect(radio.display(playback: .playing).title == "WLS")
    #expect(radio.display(playback: .connecting).title == "WLS")
    radio.markDead("KABC-FM")
    #expect(radio.display(playback: .playing).title == "WLS")
}

@Test func noBundledStationRepeatsItsFrequency() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let url = root.appending(path: "../../../../App/Resources/Stations.json").standardizedFileURL
    let file = try StationFile.load(from: Data(contentsOf: url))
    for s in file.cities.flatMap(\.stations) {
        #expect(!s.shownName.contains(String(format: "%.1f", s.frequency)))
        #expect(!s.shownName.isEmpty)
    }
}

/// Names the way station directories write them, all at 94.7.
@Test(arguments: [
    ("WLS - 94.7", "WLS"), ("94.7: The Loop", "The Loop"), ("WLS (94.7)", "WLS"), ("WLS (94.7 FM)", "WLS"),
    ("94.7FM WLS", "WLS"), ("94.7/WLS", "WLS"), ("94.7-FM WLS", "WLS"), ("94.7 MHz WLS", "WLS"),
    ("WLS FM94.7", "WLS"), ("94.7 WLS 94.7", "WLS"), ("WLS - 94.7 - Chicago", "WLS Chicago"),
    ("(WLS 94.7)", "(WLS)"), ("KISS FM 94.7", "KISS FM"), ("94.7 & Co", "& Co"),
    ("(94.7)", "KABC"), ("94.7 MHz", "KABC"), ("94.7 - FM", "KABC"),
    ("94.7's Best", "94.7's Best"), ("94.7 fm", "KABC"),
])
func shownNameTidiesDirectoryNames(name: String, shown: String) {
    #expect(station(name, 94.7).shownName == shown)
}
