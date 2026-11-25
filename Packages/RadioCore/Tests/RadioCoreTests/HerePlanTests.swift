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

private let allStatuses: [HereStatus] = [.idle, .finding, .ready, .empty, .locationOff]

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
    #expect(plan.searches(on: .returned, status: .locationOff, isSearching: false))
    #expect(plan.searches(on: .returned, status: .empty, isSearching: false))
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
    for status in [HereStatus.idle, .finding, .empty, .locationOff] {
        #expect(HerePlan.status(onStartFrom: status) == .finding)
    }
}

// MARK: - Cancelling

@Test func cancellingClearsTheStationsOnlyWhileFinding() {
    for isSearching in [true, false] {
        var plan = HerePlan()
        #expect(plan.cancel(status: .finding, isSearching: isSearching) == .idle)
        for status in [HereStatus.idle, .ready, .empty, .locationOff] {
            var plan = HerePlan()
            #expect(plan.cancel(status: status, isSearching: isSearching) == nil)
        }
    }
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
    let (place, next) = plan.arrive(at: nextCell, at: now) { $0 == home ? dial("Home") : dial("Next") }
    #expect(place == home)
    #expect(next == .show(dial("Home"), lookUpTown: false))
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
    let answer = searched(at: home).noPlace(.unavailable, at: now) { asked.append($0); return dial() }
    #expect(answer == .show(dial()))
    #expect(asked == [home])
}

@Test func noFixWithoutAKeptDialSaysWhy() {
    #expect(HerePlan().noPlace(.unavailable, at: now) { _ in dial() } == .clear(.empty))
    #expect(HerePlan().noPlace(.refused, at: now) { _ in dial() } == .clear(.locationOff))
    #expect(searched(at: home).noPlace(.unavailable, at: now) { _ in nil } == .clear(.empty))
    #expect(searched(at: home).noPlace(.unavailable, at: now) { _ in dial(savedAt: daysAgo(8)) } == .clear(.empty))
}

@Test func locationRefusedNeverShowsAKeptDial() {
    #expect(searched(at: home).noPlace(.refused, at: now) { _ in dial() } == .clear(.locationOff))
}

@Test func noFixLeavesTheLastPlace() {
    let plan = searched(at: home)
    _ = plan.noPlace(.unavailable, at: now) { _ in nil }
    #expect(plan.lastPlace == home)
}

// MARK: - What a hunt, a name and a refresh keep

@Test func aHuntThatFindsNothingIsEmptyAndKeepsNothing() {
    #expect(HerePlan.hunted([], at: now) == .empty)
}

@Test func aHuntThatFindsStationsKeepsThemAtOnceWithNoTown() {
    for count in [1, 16] {
        let found = HereDial(town: hereName, stations: stations(count), savedAt: now)
        #expect(HerePlan.hunted(stations(count), at: now) == .found(found))
    }
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

// MARK: - Whose the needle is

@Test func aChoiceGivesTheNeedleBackUnlessAFingerHasIt() {
    #expect(!HerePlan.needleIsTaken(on: .chosen, wheelIsHeld: false, wasTaken: false))
    #expect(!HerePlan.needleIsTaken(on: .chosen, wheelIsHeld: false, wasTaken: true))
    #expect(HerePlan.needleIsTaken(on: .chosen, wheelIsHeld: true, wasTaken: false))
    #expect(HerePlan.needleIsTaken(on: .chosen, wheelIsHeld: true, wasTaken: true))
}

@Test func aReturnKeepsATakenNeedle() {
    #expect(!HerePlan.needleIsTaken(on: .returned, wheelIsHeld: false, wasTaken: false))
    #expect(HerePlan.needleIsTaken(on: .returned, wheelIsHeld: false, wasTaken: true))
    #expect(HerePlan.needleIsTaken(on: .returned, wheelIsHeld: true, wasTaken: false))
    #expect(HerePlan.needleIsTaken(on: .returned, wheelIsHeld: true, wasTaken: true))
}
