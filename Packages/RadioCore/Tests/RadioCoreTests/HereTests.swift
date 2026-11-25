import Foundation
import Testing
@testable import RadioCore

private func station(_ call: String, _ mhz: Double) -> Station {
    Station(callSign: call, name: "\(call) Name", licenceCity: "\(call) City", frequency: mhz,
            streamURL: URL(string: "https://example.com/\(call)")!)
}

// Seattle's only station sits mid-dial, where every radio here starts.
private let file = StationFile(generated: "test", cities: [
    City(id: "seattle", name: "Seattle", key: "SEA", stations: [station("KSEA", 98.0)]),
    City(id: "chicago", name: "Chicago", key: "CHI", stations: [station("WCHI", 90.1)]),
])

/// Switched on, with HERE chosen and nothing found yet; the needle is mid-dial.
private func radioOnHere() -> Radio {
    var radio = Radio(file: file, here: true)
    radio.togglePower()
    radio.selectCity(hereID)
    return radio
}

private func changed(_ radio: Radio, _ change: (inout Radio) -> Void) -> Feel? {
    var next = radio
    change(&next)
    return feel(from: radio, to: next)
}

private func hereCity(_ radio: Radio) -> City? { radio.cities.first { $0.id == hereID } }

// MARK: - The band

@Test func withoutHereTheCitiesAreTheFilesOwn() {
    #expect(Radio(file: file).cities == file.cities)
    #expect(Radio(file: file, here: false).cities == file.cities)
}

@Test func launchNeverStartsOnHereEvenWithNoOtherCities() {
    #expect(Radio(file: .empty, here: true).cityID == "")
}

@Test func hereStationsMeanNothingWithoutTheBand() {
    var radio = Radio(file: file)
    radio.setHereStations([station("KHER", 98.0)], town: "Ballard")
    #expect(radio.cities == file.cities)
    #expect(radio.tuning.locked?.callSign == "KSEA")
}

// MARK: - Stations arriving

@Test func hereStationsOnAnotherBandChangeNothingOnItsDial() {
    var radio = Radio(file: file, here: true)
    radio.togglePower()
    let before = radio
    radio.setHereStations([station("KHER", 98.0), station("KLOW", 101.1)], town: "Ballard")
    #expect(radio.cityID == before.cityID)
    #expect(radio.position == before.position)
    #expect(radio.tuning == before.tuning)
    #expect(radio.scale.marks == before.scale.marks)
    #expect(radio.station == before.station)
    #expect(radio.display(playback: .playing) == before.display(playback: .playing))
    #expect(feel(from: before, to: radio) == nil)

    radio.selectCity(hereID)
    #expect(radio.station?.callSign == "KHER")
    #expect(hereCity(radio)?.name == "Ballard")
}

@Test func hereStationsOnHereRebuildTheDialUnderTheNeedle() {
    var radio = radioOnHere()
    radio.tune(toPosition: 0.51)
    #expect(radio.tuning.locked == nil)
    radio.setHereStations([station("KLOW", 90.1), station("KHER", 98.0)], town: "Ballard")
    #expect(radio.position == 0.51)
    #expect(radio.scale.marks.map(\.station.callSign) == ["KLOW", "KHER"])
    #expect(radio.tuning.locked?.callSign == "KHER")
    #expect(hereCity(radio)?.name == "Ballard")
    #expect(hereCity(radio)?.key == "HERE")
}

@Test func aMissingTownKeepsTheName() {
    var radio = radioOnHere()
    radio.setHereStations([], town: nil)
    #expect(hereCity(radio)?.name == "Here")
    radio.setHereStations([], town: "Ballard")
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    #expect(hereCity(radio)?.name == "Ballard")
}

@Test func freshHereStationsAreNoLongerDead() {
    var radio = radioOnHere()
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    radio.markDead("KHER")
    radio.markDead("WCHI")
    #expect(radio.station == nil)
    radio.setHereStations([station("KHER", 98.0), station("KLOW", 101.1)], town: nil)
    #expect(radio.station?.callSign == "KHER")
    #expect(radio.dead == ["WCHI"])                                  // only the ones it brings
}

@Test func aTownOnlyUpdateKeepsALockHeldOnlyByTheReleaseMargin() throws {
    var radio = radioOnHere()
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    let mark = try #require(radio.scale.marks.first)
    radio.tune(toPosition: mark.position)
    radio.tune(toPosition: mark.position + 1.75 / 80)                // past the zone, within the margin
    #expect(radio.tuning.locked?.callSign == "KHER")
    let tuning = radio.tuning

    radio.setHereStations([station("KHER", 98.0)], town: "Ballard")
    #expect(radio.tuning == tuning)
    #expect(hereCity(radio)?.name == "Ballard")
    radio.setHereStations([station("KHER", 98.0), station("KLOW", 90.1)].sorted { $0.frequency < $1.frequency },
                          town: nil)
    #expect(radio.tuning.locked == nil)                              // a rebuilt dial forgets the hold
}

@Test func aTownOnlyUpdateKeepsDeadStationsDead() {
    var radio = radioOnHere()
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    radio.markDead("KHER")
    radio.setHereStations([station("KHER", 98.0)], town: "Ballard")
    #expect(radio.dead == ["KHER"])
    #expect(radio.tuning.locked?.callSign == "KHER")
    #expect(radio.station == nil)
}

@Test func choosingHereAgainBringsItsDeadStationsBack() {
    var radio = radioOnHere()
    radio.setHereStations([station("KHER", 98.0)], town: "Ballard")
    radio.markDead("KHER")
    radio.markDead("WCHI")
    #expect(radio.station == nil)
    #expect(changed(radio) { $0.selectCity(hereID) } == nil)         // no click: the band did not change
    radio.selectCity(hereID)
    #expect(radio.dead == ["WCHI"])
    #expect(radio.station?.callSign == "KHER")
    #expect(hereCity(radio)?.name == "Ballard")
}

@Test func choosingAnotherBandAgainKeepsItsDeadStationsDead() {
    var radio = Radio(file: file, here: true)
    radio.togglePower()
    radio.markDead("KSEA")
    radio.selectCity("seattle")
    #expect(radio.dead == ["KSEA"])
}

@Test func theHeaderPrintsHEREBeforeTheTownOnlyOnceItIsKnown() {
    var radio = radioOnHere()
    #expect(hereCity(radio)?.headerKey == nil)              // "Here" alone says it already
    radio.setHereStations([], town: "Seattle")
    #expect(hereCity(radio)?.headerKey == "HERE")
    #expect(radio.cities.first { $0.id == "seattle" }?.headerKey == nil)
    #expect(radio.cities.first { $0.id == "chicago" }?.headerKey == nil)
}

@Test func theBandIsReadAloudWithItsTown() throws {
    var radio = radioOnHere()
    #expect(hereCity(radio)?.spokenName == "Here")
    radio.setHereStations([], town: "Seattle")
    #expect(hereCity(radio)?.spokenName == "Here, Seattle")
    radio.setHereStations([], town: hereName)
    #expect(hereCity(radio)?.spokenName == "Here")
    #expect(radio.cities.first { $0.id == "seattle" }?.spokenName == "Seattle")
}

@Test func choosingHereFromAnotherBandBringsItsDeadStationsBack() {
    var radio = radioOnHere()
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    radio.markDead("KHER")
    radio.markDead("WCHI")
    radio.selectCity("chicago")
    #expect(radio.dead == ["KHER", "WCHI"])
    radio.selectCity(hereID)
    #expect(radio.dead == ["WCHI"])
    #expect(radio.station?.callSign == "KHER")
}

@Test func hereStationsOnAnotherBandLeaveItsDeadStationDead() {
    var radio = Radio(file: file, here: true)
    radio.togglePower()
    radio.markDead("KSEA")
    radio.markDead("KHER")
    radio.setHereStations([station("KSEA", 98.0), station("KHER", 101.1)], town: nil)
    #expect(radio.display(playback: .idle).subtitle == "No signal")
    #expect(radio.dead == ["KSEA"])
}

@Test func losingTheLockedStationLeavesTheNeedleInStatic() {
    var radio = radioOnHere()
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    #expect(radio.station?.callSign == "KHER")
    radio.setHereStations([station("KLOW", 90.1)], town: nil)
    #expect(radio.position == 0.5)
    #expect(radio.tuning.locked == nil)
    #expect(radio.station == nil)
}

@Test func noHereStationsAtAllIsSafe() {
    var radio = radioOnHere()
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    radio.setHereStations([], town: nil)
    #expect(radio.scale.marks.isEmpty)
    #expect(radio.position == 0.5)
    #expect(radio.tuning.locked == nil)
    #expect(radio.station == nil)
    #expect(radio.settleTarget == nil)
    #expect(radio.stepTarget(up: true) == nil)
    radio.tune(toPosition: 0.7)
    #expect(radio.position == 0.7)
}

// MARK: - Scanning

@Test func scanningIsSilentAndTicksWithoutLockClicks() {
    var radio = radioOnHere()
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    #expect(radio.station?.callSign == "KHER")
    radio.setScanning(true)
    #expect(radio.station == nil)

    radio.tune(toPosition: 0.45)
    #expect(changed(radio) { $0.tune(toPosition: 0.5) } == .tuningTick)
    #expect(changed(radio) { $0.tune(toPosition: 0.46) } == .tuningTick)
    radio.setScanning(false)
    #expect(changed(radio) { $0.tune(toPosition: 0.5) } == .lockClick(callSign: "KHER"))
    radio.tune(toPosition: 0.5)
    #expect(radio.station?.callSign == "KHER")
}

@Test func scanningCountsOnlyWhileHereIsChosen() {
    var radio = Radio(file: file, here: true)
    radio.togglePower()
    let before = radio
    radio.setScanning(true)
    radio.setHere(status: .finding)
    #expect(radio.isScanning)
    #expect(radio.hereStatus == .finding)
    #expect(feel(from: before, to: radio) == nil)
    #expect(radio.station?.callSign == "KSEA")
    #expect(radio.display(playback: .playing) == before.display(playback: .playing))
    radio.tune(toPosition: 0.45)
    #expect(changed(radio) { $0.tune(toPosition: 0.5) } == .lockClick(callSign: "KSEA"))
}

@Test func scanningHereShowsNoLock() {
    var radio = radioOnHere()
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    #expect(radio.lockToShow?.callSign == "KHER")
    radio.setScanning(true)
    #expect(radio.tuning.locked?.callSign == "KHER")
    #expect(radio.lockToShow == nil)
    #expect(radio.isScanningHere)
    radio.setScanning(false)
    #expect(radio.lockToShow?.callSign == "KHER")
    radio.tune(toPosition: 0.2)
    #expect(radio.lockToShow == nil)
}

@Test func aScanLeftOnElsewhereHidesNoLock() {
    var radio = Radio(file: file, here: true)
    radio.setScanning(true)
    #expect(!radio.isScanningHere)
    #expect(radio.lockToShow?.callSign == "KSEA")
}

// MARK: - Feel

@Test func choosingHereClicksEvenWhileScanning() {
    var radio = Radio(file: file, here: true)
    radio.setScanning(true)
    #expect(changed(radio) { $0.selectCity(hereID) } == .bandClick)
}

@Test func aRefreshOfHereFeelsLikeNothing() {
    var radio = radioOnHere()
    // A station arrives under the needle, another replaces it, then all go.
    #expect(changed(radio) { $0.setHereStations([station("KHER", 98.0)], town: nil) } == nil)
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    #expect(changed(radio) { $0.setHereStations([station("KNEW", 98.0)], town: "Ballard") } == nil)
    #expect(changed(radio) { $0.setHereStations([], town: nil) } == nil)
    // Even when the needle moved in the same change.
    #expect(changed(radio) {
        $0.setHereStations([station("KNEW", 90.1)], town: nil)
        $0.tune(toPosition: 0.124)
    } == nil)
    #expect(changed(radio) {
        $0.setHereStations([station("KHER", 98.0)], town: "Ballard")
        $0.tune(toPosition: 1)
    } == nil)
}

@Test func hereStatusAndScanningFeelLikeNothing() {
    let radio = radioOnHere()
    #expect(changed(radio) { $0.setHere(status: .finding) } == nil)
    #expect(changed(radio) { $0.setScanning(true) } == nil)
}

@Test(arguments: [0.0, 1.0])
func aScanReachesTheEndsOfTheDialWithoutAStop(end: Double) {
    var radio = radioOnHere()
    radio.tune(toPosition: abs(end - 0.001))
    radio.setScanning(true)
    #expect(changed(radio) { $0.tune(toPosition: end) } != .tuningStop)
    radio.setScanning(false)                                         // the owner's own wheel
    #expect(changed(radio) { $0.tune(toPosition: end) } == .tuningStop)
}

@Test func aScanLeftOnElsewhereDoesNotSilenceTheStops() {
    var radio = Radio(file: file, here: true)
    radio.setScanning(true)
    #expect(changed(radio) { $0.tune(toPosition: 1) } == .tuningStop)
}

// MARK: - Display

@Test(arguments: [(HereStatus.finding, "Finding stations…"), (.empty, "No stations found here"),
                  (.locationOff, "Location is off"), (.ready, "Static"), (.idle, "Static")])
func hereSaysHowTheSearchIsGoing(status: HereStatus, subtitle: String) {
    var radio = radioOnHere()
    radio.setHere(status: status)
    #expect(radio.display(playback: .idle) == Display(title: "· · ·", subtitle: subtitle, lamp: .off, bars: 0))

    radio.setScanning(true)
    #expect(radio.display(playback: .idle)
            == Display(title: "· · ·", subtitle: "Finding stations…", lamp: .off, bars: 0))
    radio.setScanning(false)

    radio.togglePower()
    #expect(radio.display(playback: .idle) == Display(title: "", subtitle: "", lamp: .off, bars: 0))
    radio.setScanning(true)
    #expect(radio.display(playback: .idle) == Display(title: "", subtitle: "", lamp: .off, bars: 0))
    radio.setScanning(false)
    radio.togglePower()

    radio.selectCity("chicago")                                      // static mid-dial
    #expect(radio.display(playback: .idle) == Display(title: "· · ·", subtitle: "Static", lamp: .off, bars: 0))
}

@Test func aStationUnderTheNeedleShowsWhileHereIsStillFinding() {
    var radio = radioOnHere()
    radio.setHere(status: .finding)                                  // a cached dial refreshing
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    #expect(radio.display(playback: .playing).title == "KHER Name")
}

@Test func scanningHidesTheStationUnderTheNeedle() {
    var radio = radioOnHere()
    radio.setHereStations([station("KHER", 98.0)], town: nil)
    radio.setScanning(true)
    let finding = Display(title: "· · ·", subtitle: "Finding stations…", lamp: .off, bars: 0)
    #expect(radio.display(playback: .playing) == finding)
    radio.markDead("KHER")
    #expect(radio.display(playback: .idle) == finding)
}

// MARK: - Choosing the stations

private func found(_ call: String, _ mhz: Double, distance: Double = 10, kilowatts: Double = 10,
                   name: String? = nil) -> (Licence, StreamChoice, URL) {
    let url = URL(string: "https://example.com/\(call)")!
    return (Licence(callSign: call, city: "Town", stationClass: "C", frequency: mhz,
                    kilowatts: kilowatts, distance: distance),
            StreamChoice(name: name ?? call, urls: [url], radioBrowserID: nil), url)
}

@Test func aFoundStationTakesFromItsLicenceItsStreamAndTheProbe() {
    let licence = Licence(callSign: "KEXP-FM", city: "Seattle", stationClass: "C",
                          frequency: 90.3, kilowatts: 4.7, distance: 3)
    let offered = URL(string: "https://example.com/offered")!
    let probed = URL(string: "https://example.com/probed")!
    let choice = StreamChoice(name: "KEXP", urls: [offered, probed], radioBrowserID: "abc")
    #expect(hereStations([(licence, choice, probed)]) == [
        Station(callSign: "KEXP-FM", name: "KEXP", licenceCity: "Seattle", frequency: 90.3,
                streamURL: probed, homepage: nil, radioBrowserID: "abc"),
    ])
}

@Test func theSixteenMostLocalStayInDialOrder() {
    // Higher on the dial is closer, so the four lowest are cut.
    let all = (0..<20).map { found("K\($0)", 88.1 + Double($0), distance: Double(60 - $0)) }
    let chosen = hereStations(all.shuffled())
    #expect(chosen.map(\.callSign) == (4..<20).map { "K\($0)" })
}

@Test func tiesForTheSixteenGoToPowerThenTheLowerFrequency() {
    let sixteen = (0..<16).map { found("K\($0)", 90.1 + Double($0)) }
    let weak = found("KWEAK", 89.1, kilowatts: 1)
    #expect(!hereStations([weak] + sixteen).map(\.callSign).contains("KWEAK"))
    let low = found("KLOW", 89.1)
    let chosen = hereStations(sixteen + [low]).map(\.callSign)
    #expect(chosen.first == "KLOW")
    #expect(!chosen.contains("K15"))
}

@Test func oneStationPerFrequencyTheBetterRanked() {
    let near = found("KNEAR", 95.5, distance: 5)
    let far = found("KFAR", 95.5, distance: 50, kilowatts: 100)
    #expect(hereStations([far, near]).map(\.callSign) == ["KNEAR"])
    let alpha = found("KAAA", 95.5), beta = found("KBBB", 95.5)
    #expect(hereStations([beta, alpha]).map(\.callSign) == ["KAAA"])
}

@Test func oneStationPerCallSign() {
    #expect(hereStations([found("KDUP", 95.5, distance: 20), found("KDUP", 101.1, distance: 5)])
        .map(\.frequency) == [101.1])
}

@Test func aSharedFrequencyDoesNotCostAPlaceOnTheDial() {
    let sixteen = (0..<16).map { found("K\($0)", 90.1 + Double($0), distance: Double(10 + $0)) }
    let twin = found("KTWIN", 90.1, distance: 10.5)
    #expect(hereStations(sixteen + [twin]).map(\.callSign) == (0..<16).map { "K\($0)" })
}

@Test func stationsOffTheDialAreDropped() {
    let chosen = hereStations([found("KLOW", 87.4), found("KMIN", 87.5), found("KMAX", 108.5),
                               found("KHIGH", 108.6)])
    #expect(chosen.map(\.callSign) == ["KMIN", "KMAX"])
    #expect(hereStations([]).isEmpty)
}

// MARK: - The saved dial

private let savedAt = Date(timeIntervalSinceReferenceDate: 800_000_000.25)
private func stations(_ count: Int) -> [Station] { (0..<count).map { station("K\($0)", 90.1 + Double($0)) } }
private func dial(_ count: Int) -> HereDial { HereDial(town: "Ballard", stations: stations(count), savedAt: savedAt) }
private func hoursLater(_ hours: Double) -> Date { savedAt.addingTimeInterval(hours * 3600) }
private func minutesLater(_ minutes: Double) -> Date { hoursLater(minutes / 60) }

@Test func aSavedDialIsUsableForSevenDays() {
    #expect(dial(8).isUsable(at: savedAt))
    #expect(dial(8).isUsable(at: hoursLater(6 * 24 + 23)))
    #expect(!dial(8).isUsable(at: hoursLater(7 * 24)))
    #expect(!dial(8).isUsable(at: hoursLater(7 * 24 + 1)))
    #expect(HereDial.lifetime == 7 * 24 * 3600)
}

@Test func aSavedDialNeedsARefreshAfterADay() {
    #expect(!dial(8).needsRefresh(at: savedAt))
    #expect(!dial(8).needsRefresh(at: hoursLater(23)))
    #expect(!dial(8).needsRefresh(at: hoursLater(24)))
    #expect(dial(8).needsRefresh(at: hoursLater(25)))
    #expect(dial(16).needsRefresh(at: hoursLater(25)))
}

@Test func aThinDialNeedsARefreshAfterTenMinutes() {
    #expect(!dial(7).needsRefresh(at: savedAt))
    #expect(!dial(7).needsRefresh(at: minutesLater(9)))
    #expect(!dial(7).needsRefresh(at: minutesLater(10)))
    #expect(dial(7).needsRefresh(at: minutesLater(11)))
    #expect(dial(1).needsRefresh(at: minutesLater(11)))
    #expect(!dial(8).needsRefresh(at: minutesLater(11)))
}

@Test func aDialSavedInTheFutureIsUsableButNotFresh() {
    for count in [1, 8, 16] {
        #expect(dial(count).isUsable(at: hoursLater(-1)))
        #expect(dial(count).needsRefresh(at: hoursLater(-1)))
        #expect(dial(count).isUsable(at: hoursLater(-24 * 30)))
        #expect(dial(count).needsRefresh(at: hoursLater(-24 * 30)))
    }
}

@Test func aRefreshWithUnderHalfTheStationsNeverReplacesADial() {
    #expect(dial(16).mayBeReplaced(by: stations(16)))
    #expect(dial(16).mayBeReplaced(by: stations(8)))
    #expect(!dial(16).mayBeReplaced(by: stations(7)))
    #expect(dial(5).mayBeReplaced(by: stations(3)))
    #expect(!dial(5).mayBeReplaced(by: stations(2)))
    #expect(dial(1).mayBeReplaced(by: stations(1)))
    #expect(!dial(1).mayBeReplaced(by: []))
    #expect(!dial(0).mayBeReplaced(by: []))
}

@Test func aSavedDialSurvivesARoundTrip() throws {
    let again = try JSONDecoder().decode(HereDial.self, from: JSONEncoder().encode(dial(8)))
    #expect(again == dial(8))
}

// MARK: - Arriving on a station

@Test func withNothingLockedTheNeedleArrivesOnTheNearestLiveStation() {
    var radio = radioOnHere()
    radio.setHereStations([station("KLOW", 90.1), station("KMID", 101.1), station("KTOP", 107.7)], town: nil)
    #expect(radio.tuning.locked == nil)
    let marks = radio.scale.marks.map(\.position)
    #expect(radio.arrivalTarget == marks[1])
    radio.markDead("KMID")
    #expect(radio.arrivalTarget == marks.filter { $0 != marks[1] }.min { abs($0 - 0.5) < abs($1 - 0.5) })
}

@Test func aLockedStationIsWhereTheNeedleArrives() {
    var radio = radioOnHere()
    radio.setHereStations([station("KLOW", 90.1), station("KHER", 98.0)], town: nil)
    #expect(radio.tuning.locked?.callSign == "KHER")
    #expect(radio.arrivalTarget == radio.settleTarget)
    radio.markDead("KHER")
    #expect(radio.arrivalTarget == radio.settleTarget)
}

@Test func withNoLiveStationTheNeedleStaysPut() {
    var radio = radioOnHere()
    #expect(radio.arrivalTarget == nil)
    radio.setHereStations([station("KLOW", 90.1)], town: nil)
    radio.markDead("KLOW")
    #expect(radio.arrivalTarget == nil)
}
