import Foundation
import Testing
@testable import RadioCore

private func fixtureText() throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/fcc-seattle.txt")
    return try String(contentsOf: url, encoding: .utf8)
}

private func licence(_ call: String, class stationClass: String = "C", distance: Double,
                     kilowatts: Double = 10, frequency: Double = 95.5) -> Licence {
    Licence(callSign: call, city: "Town", stationClass: stationClass,
            frequency: frequency, kilowatts: kilowatts, distance: distance)
}

@Test func searchURLCarriesRadiusAndDegreesMinutesSeconds() {
    let query = fccSearchURL(Place(latitude: 47.606, longitude: -122.332)).absoluteString
    for part in ["dist=100", "dlat2=47&mlat2=36&slat2=36", "NS=N",
                 "dlon2=122&mlon2=19&slon2=48", "EW=W", "serv=FM", "list=4"] {
        #expect(query.contains(part), "missing \(part) in \(query)")
    }
}

@Test func searchURLFollowsTheSigns() {
    let query = fccSearchURL(Place(latitude: -33.87, longitude: 151.21)).absoluteString
    #expect(query.contains("NS=S"))
    #expect(query.contains("EW=E"))
    #expect(query.contains("dlat2=33&mlat2=52&slat2=12"))
}

@Test func searchURLCarriesRoundedSecondsIntoMinutes() {
    // 47.5999 rounds to 47.60: exactly 36 minutes, no seconds.
    let query = fccSearchURL(Place(latitude: 47.5999, longitude: -122.3333)).absoluteString
    #expect(query.contains("dlat2=47&mlat2=36&slat2=0"))
    // 59.999 rounds to 60.00: the seconds carry all the way into the degrees.
    let carried = fccSearchURL(Place(latitude: 59.999, longitude: 10)).absoluteString
    #expect(carried.contains("dlat2=60&mlat2=0&slat2=0"))
}

@Test func placeRoundsToTheNearestHundredth() {
    #expect(Place(latitude: 47.6062, longitude: -122.3321) == Place(latitude: 47.61, longitude: -122.33))
}

@Test func placeRoundsWhenDecoded() throws {
    let json = #"{"latitude":47.6062,"longitude":-122.3321}"#
    let place = try JSONDecoder().decode(Place.self, from: Data(json.utf8))
    #expect(place == Place(latitude: 47.61, longitude: -122.33))
    let again = try JSONDecoder().decode(Place.self, from: JSONEncoder().encode(place))
    #expect(again == place)
}

@Test func cacheKeyUsesATenthOfADegreeGrid() {
    #expect(Place(latitude: 47.606, longitude: -122.332).cacheKey == "47.6,-122.3")
    #expect(Place(latitude: 47.62, longitude: -122.34).cacheKey == "47.6,-122.3")
}

@Test func cacheKeyNeverShowsNegativeZero() {
    let south = Place(latitude: -0.04, longitude: 0.04).cacheKey
    let north = Place(latitude: 0.04, longitude: -0.04).cacheKey
    #expect(south == north)
    #expect(!south.contains("-"))
}

@Test func fixtureParsesSeattleStations() throws {
    let all = licences(fromFCC: try fixtureText())
    let kexp = try #require(all.first { $0.callSign == "KEXP-FM" })
    #expect(kexp.frequency == 90.3)
    #expect(kexp.stationClass == "C3")
    #expect(kexp.city == "Seattle")
    #expect(kexp.baseCall == "KEXP")
    #expect(kexp.distance < 5)
    #expect(kexp.kilowatts == 4.7)
    let kaos = try #require(all.first { $0.callSign == "KAOS" })
    #expect(kaos.stationClass == "A")
    #expect((75...85).contains(kaos.distance))
}

@Test func onlyLicensedRowsAppearOnceEach() throws {
    let all = licences(fromFCC: try fixtureText())
    // The fixture holds STA and MOD rows for these calls; KQXI has two STA rows and one LIC.
    #expect(all.filter { $0.callSign == "KQXI" }.count == 1)
    #expect(all.filter { $0.callSign == "KLSY" }.count == 1)
    #expect(all.first { $0.callSign == "KLSY" }?.kilowatts == 28)
    #expect(all.first { $0.callSign == "KJET" }?.stationClass == "C3")
    let reach = stationsInReach(all)
    #expect(Set(reach.map(\.callSign)).count == reach.count)
}

@Test func reachDropsStationsBeyondTheirClass() throws {
    let calls = stationsInReach(licences(fromFCC: try fixtureText())).map(\.callSign)
    #expect(calls.contains("KEXP-FM"))
    #expect(!calls.contains("KAOS"))
}

@Test func rankIsDistanceOverClassReach() {
    #expect(abs(licence("A", class: "C", distance: 29.57).rank - 0.32) < 0.005)
    #expect(abs(licence("B", class: "D", distance: 9.27).rank - 0.927) < 0.005)
    #expect(abs(licence("C", class: "C2", distance: 18.25).rank - 0.351) < 0.005)
}

@Test func unknownClassIsNeverInReach() {
    let odd = licence("KODD", class: "Z", distance: 1)
    #expect(odd.rank == .infinity)
    #expect(stationsInReach([odd]).isEmpty)
}

@Test func nearerInProportionComesFirst() {
    let ordered = stationsInReach([
        licence("KDEE", class: "D", distance: 9.27),
        licence("KSEE", class: "C2", distance: 18.25),
        licence("KCEE", class: "C", distance: 29.57)
    ])
    #expect(ordered.map(\.callSign) == ["KCEE", "KSEE", "KDEE"])
}

@Test func equalRankPrefersPowerThenLowerFrequency() {
    let ordered = stationsInReach([
        licence("KLOW", distance: 46, kilowatts: 10, frequency: 90.1),
        licence("KBIG", distance: 46, kilowatts: 50, frequency: 99.9),
        licence("KHIGH", distance: 46, kilowatts: 10, frequency: 101.1)
    ])
    #expect(ordered.map(\.callSign) == ["KBIG", "KLOW", "KHIGH"])
}

@Test func fixtureOrdersKZOKBeforeKMIH() throws {
    let calls = stationsInReach(licences(fromFCC: try fixtureText())).map(\.callSign)
    let zok = try #require(calls.firstIndex(of: "KZOK-FM"))
    let mih = try #require(calls.firstIndex(of: "KMIH"))
    #expect(zok < mih)
}

@Test func oneLicencePerCallKeepsTheNearestRank() {
    let kept = stationsInReach([
        licence("KDUP", distance: 80),
        licence("KDUP", distance: 20)
    ])
    #expect(kept.count == 1)
    #expect(kept.first?.distance == 20)
}

@Test func badInputGivesNothing() throws {
    #expect(licences(fromFCC: "").isEmpty)
    #expect(licences(fromFCC: "<html>busy</html>").isEmpty)
    let line = try #require(try fixtureText().split(separator: "\n").first { $0.contains("KEXP-FM") })
    let cut = String(line.prefix(120))
    #expect(licences(fromFCC: cut).isEmpty)
    let noDistance = String(line).replacingOccurrences(of: " km ", with: "    ")
    #expect(licences(fromFCC: noDistance).isEmpty)
}
