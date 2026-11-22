import Testing
import Foundation
@testable import RadioCore

private func stationJSON(_ f: Double) -> String {
    """
    {"callSign":"S\(f)","name":"Station \(f)","licenceCity":"Seattle","frequency":\(f),"streamURL":"https://example.com/\(f)"}
    """
}

private func fileData(_ frequencies: [Double], city: String = "seattle") -> Data {
    let stations = frequencies.map(stationJSON).joined(separator: ",")
    return Data("""
    {"generated":"2026-11-22","cities":[{"id":"\(city)","name":"Seattle","key":"\(city)","stations":[\(stations)]}]}
    """.utf8)
}

@Test func loadsValidFile() throws {
    let file = try StationFile.load(from: fileData([90.3, 98.0]))
    #expect(file.cities.count == 1)
    #expect(file.cities[0].stations.count == 2)
    #expect(file.cities[0].stations[1].frequency == 98.0)
}

@Test func rejectsDuplicateFrequency() {
    #expect(throws: StationFileError.duplicateFrequency(city: "seattle", frequency: 90.3)) {
        try StationFile.load(from: fileData([90.3, 90.3]))
    }
}

@Test func rejectsSeventeenStations() {
    let freqs = (0..<17).map { 88.1 + Double($0) * 0.2 }
    #expect(throws: StationFileError.tooManyStations(city: "seattle", count: 17)) {
        try StationFile.load(from: fileData(freqs))
    }
}

@Test func rejectsOutOfBand() {
    #expect(throws: StationFileError.outOfBand(city: "seattle", callSign: "S87.4")) {
        try StationFile.load(from: fileData([87.4, 90.3]))
    }
}

@Test func rejectsUnsorted() {
    #expect(throws: StationFileError.unsorted(city: "seattle")) {
        try StationFile.load(from: fileData([98.0, 90.3]))
    }
}

@Test func allowsCityWithNoStations() throws {
    let file = try StationFile.load(from: fileData([]))
    #expect(file.cities[0].stations.isEmpty)
}
