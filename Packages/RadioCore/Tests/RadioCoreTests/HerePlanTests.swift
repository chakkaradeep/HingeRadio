import Foundation
import Testing
@testable import RadioCore

private func stations(_ count: Int) -> [Station] {
    (0..<count).map { index in
        let call = "K\(index)"
        return Station(callSign: call, name: "\(call) Name", licenceCity: "Seattle", frequency: 88.1 + Double(index),
                       streamURL: URL(string: "https://example.com/\(call)")!)
    }
}

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 24 * 3600) }

private func dial(_ town: String = "Ballard", count: Int = 8, savedAt: Date = daysAgo(1)) -> HereDial {
    HereDial(town: town, stations: stations(count), savedAt: savedAt)
}

private let home = Place(latitude: 47.61, longitude: -122.33)
private let nextCell = Place(latitude: 47.71, longitude: -122.43)       // a neighbouring cell
private let farAway = Place(latitude: 47.81, longitude: -122.33)        // two cells north

private let allStatuses: [HereStatus] = [.idle, .finding, .ready, .empty, .locationOff,
                                          .noPosition, .noConnection, .outsideUS]
/// The statuses a search ends on without a dial.
private let withoutADial: [HereStatus] = [.empty, .locationOff, .noPosition, .noConnection, .outsideUS]

/// A plan whose last search was cut short.
private func cutShort() -> HerePlan {
    var plan = HerePlan()
    plan.begin()
    _ = plan.cancel(status: .finding, isSearching: true)
    return plan
}

/// A plan that last showed or hunted at `place`.
private func searched(at place: Place) -> HerePlan {
    var plan = HerePlan()
    _ = plan.arrive(at: place, at: now) { _ in nil }
    return plan
}

/// What a plan shows with no position, leaving the plan given as it was.
private func noPlace(_ plan: HerePlan, _ error: LocatorError, at date: Date,
                     kept: (Place) -> HereDial?) -> HerePlan.NoPlace {
    var plan = plan
    return plan.noPlace(error, at: date, kept: kept)
}

// MARK: - Whether to search

@Test func choosingHereSearchesUnlessOneRuns() {
    for status in allStatuses {
        #expect(HerePlan().searches(on: .chosen, status: status, isSearching: false))
        #expect(!HerePlan().searches(on: .chosen, status: status, isSearching: true))
        #expect(cutShort().searches(on: .chosen, status: status, isSearching: false))
    }
}

@Test func aReturnSearchesOnlyWhenTheLastWasCutShortOrEndedWithoutADial() {
    let plan = HerePlan()
    for status in withoutADial {
        #expect(plan.searches(on: .returned, status: status, isSearching: false))
    }
    #expect(!plan.searches(on: .returned, status: .ready, isSearching: false))
    #expect(!plan.searches(on: .returned, status: .idle, isSearching: false))
    #expect(!plan.searches(on: .returned, status: .finding, isSearching: false))
    for status in allStatuses {
        #expect(cutShort().searches(on: .returned, status: status, isSearching: false))
    }
}

@Test func aReturnNeverSearchesWhileOneRuns() {
    for status in allStatuses {
        #expect(!HerePlan().searches(on: .returned, status: status, isSearching: true))
        #expect(!cutShort().searches(on: .returned, status: status, isSearching: true))
    }
}

@Test func aNewSearchIsNoLongerCutShort() {
    var plan = cutShort()
    #expect(plan.wasCancelled)
    plan.begin()
    #expect(!plan.wasCancelled)
    #expect(!plan.searches(on: .returned, status: .ready, isSearching: false))
}

@Test func aSearchShowsFindingUnlessADialIsReady() {
    #expect(HerePlan.status(onStartFrom: .ready) == nil)
    for status in [HereStatus.idle, .finding] + withoutADial {
        #expect(HerePlan.status(onStartFrom: status) == .finding)
    }
}

// MARK: - Cancelling

@Test func cancellingClearsTheStationsOnlyWhileFinding() {
    for isSearching in [true, false] {
        var plan = HerePlan()
        #expect(plan.cancel(status: .finding, isSearching: isSearching) == .idle)
        for status in [HereStatus.idle, .ready] + withoutADial {
            var plan = HerePlan()
            #expect(plan.cancel(status: status, isSearching: isSearching) == nil)
        }
    }
}

/// Going to the background while one of the stations found so far plays: the part of the dial
/// stays, so the listener keeps the station; the search still counts as cut short.
@Test func cancellingKeepsAPartOfADialWhoseStationPlays() {
    var plan = HerePlan()
    #expect(plan.cancel(status: .finding, isSearching: true, playing: true) == nil)
    #expect(plan.wasCancelled)
    #expect(plan.searches(on: .returned, status: .finding, isSearching: false))
    var notPlaying = HerePlan()
    #expect(notPlaying.cancel(status: .finding, isSearching: true, playing: false) == .idle)
}

@Test func cancellingMarksTheSearchCutShortOnlyIfOneRan() {
    var idle = HerePlan()
    _ = idle.cancel(status: .finding, isSearching: false)
    #expect(!idle.wasCancelled)
    #expect(!idle.searches(on: .returned, status: .ready, isSearching: false))

    var running = HerePlan()
    _ = running.cancel(status: .ready, isSearching: true)
    #expect(running.wasCancelled)
}

@Test func cancellingWithNothingRunningKeepsAnEarlierCutShort() {
    var plan = cutShort()
    _ = plan.cancel(status: .idle, isSearching: false)
    #expect(plan.wasCancelled)
}

@Test func cancellingForgetsNoPlace() {
    var plan = searched(at: home)
    _ = plan.cancel(status: .finding, isSearching: true)
    #expect(plan.lastPlace == home)
}

// MARK: - Which place a fix counts as

@Test func withNoLastPlaceAFixIsItsOwnPlace() {
    var plan = HerePlan()
    var asked: [Place] = []
    let (place, next) = plan.arrive(at: home, at: now) { asked.append($0); return $0 == home ? dial() : nil }
    #expect(place == home)
    #expect(next == .show(dial(), lookUpTown: false))
    #expect(asked == [home])
    #expect(plan.lastPlace == home)
}

@Test func aFixNearTheLastPlaceWithAKeptDialCountsAsTheLastPlace() {
    var plan = searched(at: home)
    var asked: [Place] = []
    let (place, next) = plan.arrive(at: nextCell, at: now) { asked.append($0); return $0 == home ? dial("Home") : dial("Next") }
    #expect(place == home)
    #expect(next == .show(dial("Home"), lookUpTown: false))
    #expect(asked == [home])             // the fix's own cell is never read
    #expect(plan.lastPlace == home)      // the wobble does not move it
}

@Test func aFixNearTheLastPlaceWithNoKeptDialThereIsItsOwnPlace() {
    var near = searched(at: home)
    let (place, next) = near.arrive(at: nextCell, at: now) { $0 == nextCell ? dial("Next") : nil }
    #expect(place == nextCell)
    #expect(next == .show(dial("Next"), lookUpTown: false))
    #expect(near.lastPlace == nextCell)

    var bare = searched(at: home)
    let (other, hunt) = bare.arrive(at: nextCell, at: now) { _ in nil }
    #expect(other == nextCell)
    #expect(hunt == .hunt)
    #expect(bare.lastPlace == nextCell)
}

@Test func aFixFarAwayIsItsOwnPlaceEvenWithADialKeptAtTheLast() {
    var plan = searched(at: home)
    let (place, next) = plan.arrive(at: farAway, at: now) { $0 == home ? dial("Home") : nil }
    #expect(place == farAway)
    #expect(next == .hunt)
    #expect(plan.lastPlace == farAway)
}

@Test func aKeptDialNoLongerUsableIsNotKept() {
    let old = dial("Home", savedAt: daysAgo(8))
    let edge = dial("Home", savedAt: now.addingTimeInterval(-HereDial.lifetime))

    var near = searched(at: home)
    let (place, next) = near.arrive(at: nextCell, at: now) { $0 == home ? old : nil }
    #expect(place == nextCell)
    #expect(next == .hunt)

    var same = HerePlan()
    #expect(same.arrive(at: home, at: now) { _ in old }.next == .hunt)
    #expect(same.arrive(at: home, at: now) { _ in edge }.next == .hunt)
    let young = dial("Home", savedAt: now.addingTimeInterval(1 - HereDial.lifetime))
    #expect(same.arrive(at: home, at: now) { _ in young }.next == .show(young, lookUpTown: false))
}

// MARK: - What a kept dial leads to

@Test func aKeptDialIsShownAndNamedOnlyIfItHasNoTown() {
    var plan = HerePlan()
    #expect(plan.arrive(at: home, at: now) { _ in dial(hereName) }.next == .show(dial(hereName), lookUpTown: true))
    #expect(plan.arrive(at: home, at: now) { _ in dial("Seattle") }.next == .show(dial("Seattle"), lookUpTown: false))
    #expect(plan.arrive(at: home, at: now) { _ in nil }.next == .hunt)
}

@Test func aKeptDialDueARefreshIsStillShownFirst() {
    var plan = HerePlan()
    let due = dial(count: 16, savedAt: daysAgo(2))
    #expect(due.needsRefresh(at: now))
    #expect(plan.arrive(at: home, at: now) { _ in due }.next == .show(due, lookUpTown: false))
}

// MARK: - No fix

@Test func noFixShowsTheLastPlacesKeptDialWhenThePositionIsUnavailable() {
    var asked: [Place] = []
    let answer = noPlace(searched(at: home), .unavailable, at: now) { asked.append($0); return dial() }
    #expect(answer == .show(dial()))
    #expect(asked == [home])
}

/// No fix in time (the locator's time limit gives `.unavailable` too) is not "no stations": HERE
/// says it cannot find where it is.
@Test func noFixWithoutAKeptDialSaysWhy() {
    #expect(noPlace(HerePlan(), .unavailable, at: now) { _ in dial() } == .clear(.noPosition))
    #expect(noPlace(HerePlan(), .refused, at: now) { _ in dial() } == .clear(.locationOff))
    #expect(noPlace(searched(at: home), .unavailable, at: now) { _ in nil } == .clear(.noPosition))
    #expect(noPlace(searched(at: home), .unavailable, at: now) { _ in dial(savedAt: daysAgo(8)) } == .clear(.noPosition))
}

@Test func locationRefusedNeverShowsAKeptDial() {
    #expect(noPlace(searched(at: home), .refused, at: now) { _ in dial() } == .clear(.locationOff))
}

@Test func locationRefusedNeverReadsTheKeptDials() {
    var asked: [Place] = []
    var searchedPlan = searched(at: home)
    _ = searchedPlan.noPlace(.refused, at: now) { asked.append($0); return dial() }
    var openedPlan = HerePlan(lastPlace: home)
    _ = openedPlan.noPlace(.refused, at: now) { asked.append($0); return dial() }
    #expect(asked.isEmpty)
}

@Test func locationRefusedForgetsTheLastPlace() {
    var plan = searched(at: home)
    _ = plan.noPlace(.refused, at: now) { _ in dial() }
    #expect(plan.lastPlace == nil)
    #expect(plan.noPlace(.unavailable, at: now) { _ in dial() } == .clear(.noPosition))   // nothing left to show
}

@Test func noFixInTimeKeepsTheLastPlace() {
    var plan = searched(at: home)
    _ = plan.noPlace(.unavailable, at: now) { _ in nil }
    #expect(plan.lastPlace == home)
}

// MARK: - Opening on HERE

@Test func openingOnHereShowsTheLastPlacesKeptDialAtOnce() {
    var asked: [Place] = []
    var plan = HerePlan(lastPlace: home)
    #expect(plan.lastPlace == home)
    #expect(plan.opening(at: now, refused: false) { asked.append($0); return dial("Home") } == dial("Home"))
    #expect(asked == [home])
    #expect(plan.lastPlace == home)
}

@Test func openingOnHereWithNoLastPlaceShowsNothingAndReadsNothing() {
    var asked: [Place] = []
    var fresh = HerePlan()
    #expect(fresh.opening(at: now, refused: false) { asked.append($0); return dial() } == nil)
    var none = HerePlan(lastPlace: nil)
    #expect(none.opening(at: now, refused: false) { asked.append($0); return dial() } == nil)
    #expect(asked.isEmpty)
}

@Test func openingOnHereShowsNoDialTooOldToShow() {
    var plan = HerePlan(lastPlace: home)
    #expect(plan.opening(at: now, refused: false) { _ in nil } == nil)
    #expect(plan.opening(at: now, refused: false) { _ in dial(savedAt: daysAgo(8)) } == nil)
    #expect(plan.opening(at: now, refused: false) { _ in dial(savedAt: now.addingTimeInterval(-HereDial.lifetime)) } == nil)
    let due = dial(count: 3, savedAt: daysAgo(2))           // due a refresh, still shown
    #expect(plan.opening(at: now, refused: false) { _ in due } == due)
}

@Test func openingOnHereWithLocationRefusedShowsNoDialReadsNothingAndForgetsThePlace() {
    var asked: [Place] = []
    var plan = HerePlan(lastPlace: home)
    #expect(plan.opening(at: now, refused: true) { asked.append($0); return dial() } == nil)
    #expect(asked.isEmpty)
    #expect(plan.lastPlace == nil)
    #expect(plan.noPlace(.unavailable, at: now) { asked.append($0); return dial() } == .clear(.noPosition))
    #expect(asked.isEmpty)
}

// MARK: - The kept last place is only its cell

private let samples = [home, nextCell, farAway, Place(latitude: 47.649, longitude: -122.351),
                       Place(latitude: 47.651, longitude: -122.249), Place(latitude: -33.86, longitude: 151.21),
                       Place(latitude: 0.04, longitude: -0.04), Place(latitude: -0.06, longitude: 0.05)]

@Test func aPlacesCellIsTheCentreOfItsTenthOfADegree() {
    #expect(home.cell == Place(latitude: 47.6, longitude: -122.3))
    #expect(Place(latitude: -0.04, longitude: 0.04).cell == Place(latitude: 0, longitude: 0))
    for place in samples {
        #expect(place.cell.cacheKey == place.cacheKey)
        #expect(place.cell.cell == place.cell)
    }
}

@Test func aCellIsNearTheSamePlacesAsThePlaceItCameFrom() {
    for place in samples {
        for other in samples {
            #expect(place.cell.isWithinOneCell(of: other) == place.isWithinOneCell(of: other))
        }
    }
}

@Test func aKeptCellHoldsAgainstAWobble() {
    var plan = HerePlan(lastPlace: home.cell)
    let (place, next) = plan.arrive(at: nextCell, at: now) { $0.cacheKey == home.cacheKey ? dial("Home") : nil }
    #expect(place == home.cell)
    #expect(next == .show(dial("Home"), lookUpTown: false))
}

@Test func aRememberedLastPlaceHoldsAgainstAWobble() {
    var plan = HerePlan(lastPlace: home)
    let (place, next) = plan.arrive(at: nextCell, at: now) { $0 == home ? dial("Home") : nil }
    #expect(place == home)
    #expect(next == .show(dial("Home"), lookUpTown: false))
}

@Test func aRememberedLastPlaceAnswersWhenNoFixComes() {
    var plan = HerePlan(lastPlace: home)
    #expect(plan.noPlace(.unavailable, at: now) { $0 == home ? dial() : nil } == .show(dial()))
}

// MARK: - What a hunt, a name and a refresh keep

@Test func aHuntThatFindsNothingSaysWhyAndKeepsNothing() {
    #expect(HerePlan.hunted(.noStreams, at: now) == .nothing(.empty))
    #expect(HerePlan.hunted(.noLicences, at: now) == .nothing(.outsideUS))
    #expect(HerePlan.hunted(.noConnection, at: now) == .nothing(.noConnection))
    #expect(HerePlan.hunted(.found([]), at: now) == .nothing(.empty))
}

@Test func aHuntThatFindsStationsKeepsThemAtOnceWithNoTown() {
    for count in [1, 16] {
        let found = HereDial(town: hereName, stations: stations(count), savedAt: now)
        #expect(HerePlan.hunted(.found(stations(count)), at: now) == .found(found))
    }
}

// MARK: - How a hunt ended

private let licence = Licence(callSign: "KAAA", city: "Seattle", stationClass: "C",
                              frequency: 90.3, kilowatts: 10, distance: 5)

@Test func aHuntThatCouldNotAskTheFCCHasNoConnection() {
    #expect(HuntOutcome(listed: nil, stations: []) == .noConnection)
    #expect(HuntOutcome.noConnection.status == .noConnection)
}

/// The FCC answered with no usable licence, as it does outside the US (and in London, where its
/// rows at 0 km are skipped).
@Test func aHuntWhoseFCCAnswerListedNoLicenceIsOutsideTheUS() {
    #expect(HuntOutcome(listed: [], stations: []) == .noLicences)
    #expect(HuntOutcome.noLicences.status == .outsideUS)
    let london = "|KRUA        |88.1  MHz |FM |201 |ND  |                    |A  |-  |LIC    |ANCHORAGE                |AK |US |"
        + "0000207895          |0.32   kW |0.32   kW |297.0   |297.0   |69007      |N |61 |20 |8.8   |W |149 |30 |56.2  |"
        + "UNIVERSITY OF ALASKA      |   0.00 km |   0.00 mi |  0.00 deg |619.   m|"
    #expect(HuntOutcome(listed: licences(fromFCC: london), stations: []) == .noLicences)
    let near = london.replacing("   0.00 km", with: "   0.01 km")
    #expect(HuntOutcome(listed: licences(fromFCC: near), stations: []) == .noStreams)
}

@Test func aHuntWithLicencesButNoStreamsFoundNoStationsHere() {
    #expect(HuntOutcome(listed: [licence], stations: []) == .noStreams)
    #expect(HuntOutcome.noStreams.status == .empty)
}

@Test func aHuntThatConfirmedStationsFoundThem() {
    #expect(HuntOutcome(listed: [licence], stations: stations(3)) == .found(stations(3)))
    #expect(HuntOutcome.found(stations(3)).status == .ready)
    #expect(HuntOutcome.found([]).status == .empty)
}

@Test func onlyAFoundHuntHasStations() {
    #expect(HuntOutcome.found(stations(2)).stations == stations(2))
    for outcome in [HuntOutcome.noConnection, .noLicences, .noStreams] {
        #expect(outcome.stations.isEmpty)
    }
}

/// Ruling P2: "No stations found here" and "HERE covers the US only" mean the FCC answered;
/// "No connection" and "Can't find where you are" do not.
@Test func onlyTheFCCsAnswerEndsInNoStationsOrOutsideTheUS() {
    #expect(HuntOutcome(listed: [], stations: []).status == .outsideUS)
    #expect(HuntOutcome(listed: [licence], stations: []).status == .empty)
    #expect(HuntOutcome(listed: nil, stations: []).status == .noConnection)
}

@Test func aTownNamesTheDialAndKeepsItsStationsAndAge() {
    let unnamed = dial(hereName, count: 5, savedAt: daysAgo(3))
    #expect(HerePlan.named(unnamed, town: nil) == nil)
    let named = HereDial(town: "Ballard", stations: stations(5), savedAt: daysAgo(3))
    #expect(HerePlan.named(unnamed, town: "Ballard") == named)
}

@Test func aRefreshKeepsItsStationsOnlyIfTheyMayReplaceTheDial() {
    let kept = dial("Ballard", count: 16, savedAt: daysAgo(2))
    #expect(HerePlan.refreshed(kept, by: [], at: now) == nil)
    #expect(HerePlan.refreshed(kept, by: stations(7), at: now) == nil)
    for count in [8, 16] {
        let fresh = HereDial(town: "Ballard", stations: stations(count), savedAt: now)
        #expect(HerePlan.refreshed(kept, by: stations(count), at: now) == fresh)
    }
    #expect(HerePlan.refreshed(dial(hereName, count: 2), by: stations(1), at: now)
            == HereDial(town: hereName, stations: stations(1), savedAt: now))
}

@Test func aShownDialIsRefreshedWhenItIsDue() {
    for (count, savedAt, due) in [(16, daysAgo(0.5), false), (16, daysAgo(1.01), true),
                                  (7, now.addingTimeInterval(-9 * 60), false), (7, now.addingTimeInterval(-11 * 60), true),
                                  (8, now.addingTimeInterval(-11 * 60), false), (8, now.addingTimeInterval(60), true)] {
        let shown = dial(count: count, savedAt: savedAt)
        #expect(HerePlan.refreshes(shown, at: now) == due)
    }
}

// MARK: - Whose the needle is

@Test func aChoiceGivesTheNeedleBackUnlessAFingerHasIt() {
    #expect(!HerePlan.needleIsTaken(on: .chosen, wheelIsHeld: false, wasTaken: false))
    #expect(!HerePlan.needleIsTaken(on: .chosen, wheelIsHeld: false, wasTaken: true))
    #expect(HerePlan.needleIsTaken(on: .chosen, wheelIsHeld: true, wasTaken: false))
    #expect(HerePlan.needleIsTaken(on: .chosen, wheelIsHeld: true, wasTaken: true))
}

@Test func aSearchAfterOpeningOnHereLeavesTheRememberedNeedle() {
    for wheelIsHeld in [false, true] {
        for wasTaken in [false, true] {
            #expect(HerePlan.needleIsTaken(on: .opened, wheelIsHeld: wheelIsHeld, wasTaken: wasTaken))
        }
    }
    // A later choice of HERE gives it back.
    #expect(!HerePlan.needleIsTaken(on: .chosen, wheelIsHeld: false, wasTaken: true))
}

@Test func openingOnHereSearchesUnlessOneRuns() {
    for status in allStatuses {
        #expect(HerePlan().searches(on: .opened, status: status, isSearching: false))
        #expect(!HerePlan().searches(on: .opened, status: status, isSearching: true))
        #expect(cutShort().searches(on: .opened, status: status, isSearching: false))
    }
}

@Test func aReturnKeepsATakenNeedle() {
    #expect(!HerePlan.needleIsTaken(on: .returned, wheelIsHeld: false, wasTaken: false))
    #expect(HerePlan.needleIsTaken(on: .returned, wheelIsHeld: false, wasTaken: true))
    #expect(HerePlan.needleIsTaken(on: .returned, wheelIsHeld: true, wasTaken: false))
    #expect(HerePlan.needleIsTaken(on: .returned, wheelIsHeld: true, wasTaken: true))
}
