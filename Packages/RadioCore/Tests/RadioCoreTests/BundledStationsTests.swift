import Foundation
import Testing
@testable import RadioCore

@Test func bundledStationsLoad() throws {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("App/Resources/Stations.json")
    let file = try StationFile.load(from: Data(contentsOf: url))
    #expect(file.cities.map(\.id) == ["seattle", "new-york", "chicago", "los-angeles"])
    for city in file.cities {
        #expect((8...16).contains(city.stations.count), "\(city.id) has \(city.stations.count)")
    }
}
