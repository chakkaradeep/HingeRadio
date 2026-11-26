import Foundation

/// Why no position came: location is refused or switched off, or no fix came in time.
public enum LocatorError: Error, Sendable, Equatable { case refused, unavailable }

/// How a hunt for a place's stations ended, before anything is kept.
public enum HuntOutcome: Sendable, Equatable {
    /// The FCC's list could not be had: no connection, no answer in time, or not a proper answer.
    case noConnection
    /// The FCC answered, but listed no licence that could be used: what a place outside the US gets.
    case noLicences
    /// The FCC listed licences, but no station with a stream was found.
    case noStreams
    /// Stations with streams, as `hereStations` makes them (none counts as `noStreams`).
    case found([Station])

    /// From what the FCC listed, nil when it could not be asked or did not answer properly, and the
    /// stations confirmed among them. A station confirmed counts even with nothing listed.
    public init(listed: [Licence]?, stations: [Station]) {
        if !stations.isEmpty { self = .found(stations) }
        else if let listed { self = listed.isEmpty ? .noLicences : .noStreams }
        else { self = .noConnection }
    }

    /// The stations found; none for every other ending.
    public var stations: [Station] {
        if case .found(let stations) = self { stations } else { [] }
    }

    /// What HERE says after it: ready with stations, otherwise why there are none. `.empty` and
    /// `.outsideUS` mean the FCC answered; `.noConnection` that it did not.
    public var status: HereStatus {
        switch self {
        case .noConnection: .noConnection
        case .noLicences: .outsideUS
        case .noStreams: .empty
        case .found(let stations): stations.isEmpty ? .empty : .ready
        }
    }
}

/// HERE's search rules, and what they remember from one search to the next: when to search, what
/// cancelling clears, which kept dial counts as here, what shows without a position, what a hunt,
/// a town and a refresh keep, and whose the needle is. The app does the waiting, the cancelling and
/// the lookups, and checks after every wait that the search is still wanted.
public struct HerePlan: Sendable, Equatable {
    /// What starts a search.
    public enum Start: Sendable, Equatable {
        /// HERE was chosen.
        case chosen
        /// The radio opened on HERE and the app is now active (the last place's kept dial already
        /// showing, see `opening`). It searches as a choice does, but the needle stays where it
        /// was left.
        case opened
        /// The app came back from the background with HERE selected.
        case returned
    }

    /// What a search does once it knows its place.
    public enum Next: Sendable, Equatable {
        /// Show the kept dial; look up its town first when it has none.
        case show(HereDial, lookUpTown: Bool)
        /// Nothing is kept for the place: hunt for its stations.
        case hunt
    }

    /// What shows when no position came.
    public enum NoPlace: Sendable, Equatable {
        case show(HereDial)
        /// No stations, and this status.
        case clear(HereStatus)
    }

    /// What a hunt found.
    public enum Hunted: Sendable, Equatable {
        /// Nothing: HERE says why, with this status, and nothing is kept.
        case nothing(HereStatus)
        /// A dial to keep at once and show.
        case found(HereDial)
    }

    /// Whether the last search was cut short.
    public private(set) var wasCancelled = false
    /// The place of the last dial shown or hunted for.
    public private(set) var lastPlace: Place?
    /// When the last search ended with the FCC's answer but no dial ("No stations found here" or
    /// "HERE covers the US only"); nil once another search begins. Kept for this run only.
    public private(set) var foundNothingAt: Date?

    /// Seconds within which a search that found nothing is not repeated on a return: 10 minutes.
    public static let nothingFoundRestsFor: TimeInterval = 10 * 60

    /// `lastPlace` is the place (its cell) of the last dial shown or hunted for in an earlier run,
    /// if kept.
    public init(lastPlace: Place? = nil) { self.lastPlace = lastPlace }

    /// The dial to show at once when the radio opens on HERE, before any search: the one kept for
    /// the last place, while it may be shown. Nil with no last place; no other place is read. With
    /// location refused nothing is read or shown, and the last place is forgotten.
    public mutating func opening(at date: Date, refused: Bool, kept: (Place) -> HereDial?) -> HereDial? {
        if refused { lastPlace = nil }
        guard let lastPlace, let dial = kept(lastPlace), dial.isUsable(at: date) else { return nil }
        return dial
    }

    /// Whether to start a search: never while one runs. A choice always does; a return only when the
    /// last search was cut short or ended without a dial, and not within 10 minutes of one that found
    /// nothing where the FCC answered (`foundNothing`): the same search would find the same nothing.
    /// No connection or no position is tried again on every return.
    public func searches(on start: Start, status: HereStatus, isSearching: Bool, at date: Date = .now) -> Bool {
        guard !isSearching else { return false }
        switch start {
        case .chosen, .opened: return true
        case .returned:
            if let foundNothingAt, (0..<Self.nothingFoundRestsFor).contains(date.timeIntervalSince(foundNothingAt)) {
                return false
            }
            return wasCancelled || Self.endedWithoutADial.contains(status)
        }
    }

    /// The statuses a search ends on when it found no dial.
    private static let endedWithoutADial: [HereStatus] = [.locationOff, .empty, .noPosition,
                                                          .noConnection, .outsideUS]

    /// A search starts: it is no longer cut short, nor one that found nothing.
    public mutating func begin() {
        wasCancelled = false
        foundNothingAt = nil
    }

    /// A hunt ended without a dial, on `status`. Remembered when the FCC answered ("No stations found
    /// here", "HERE covers the US only"), so a return within 10 minutes does not search again.
    public mutating func foundNothing(_ status: HereStatus, at date: Date) {
        if status == .empty || status == .outsideUS { foundNothingAt = date }
    }

    /// The status a starting search shows: finding, unless a dial is ready (nil keeps it).
    public static func status(onStartFrom status: HereStatus) -> HereStatus? {
        status == .ready ? nil : .finding
    }

    /// The search is called off. Returns the status to clear HERE's stations to, only while they are
    /// being found: nobody should tune a part of a dial. A kept or whole dial stays (nil), and so
    /// does a part of one while one of its stations is `playing` (the app went to the background
    /// with it on): the listener keeps it, and the search on return starts afresh. The search
    /// counts as cut short only if one was running.
    public mutating func cancel(status: HereStatus, isSearching: Bool, playing: Bool = false) -> HereStatus? {
        if isSearching { wasCancelled = true }
        return status == .finding && !playing ? .idle : nil
    }

    /// The place a fix counts as, and what to do there. A rough position wobbles, so a fix within one
    /// cell of the last place counts as it while a dial is kept there. `kept` gives the dial saved
    /// for a place; one too old to show counts as none.
    public mutating func arrive(at found: Place, at date: Date,
                                kept: (Place) -> HereDial?) -> (place: Place, next: Next) {
        func usable(_ place: Place) -> HereDial? { kept(place).flatMap { $0.isUsable(at: date) ? $0 : nil } }
        let place: Place
        let dial: HereDial?
        if let lastPlace, found.isWithinOneCell(of: lastPlace), let last = usable(lastPlace) {
            (place, dial) = (lastPlace, last)
        } else {
            (place, dial) = (found, usable(found))
        }
        lastPlace = place
        guard let dial else { return (place, .hunt) }
        return (place, .show(dial, lookUpTown: dial.town == hereName))
    }

    /// No position came. Without an answer in time the last place's kept dial shows, if any;
    /// otherwise HERE says why it has nothing: "Location is off" when refused, else that it cannot
    /// find where it is. Location refused forgets the last place.
    public mutating func noPlace(_ error: LocatorError, at date: Date, kept: (Place) -> HereDial?) -> NoPlace {
        if error == .refused { lastPlace = nil }
        if error == .unavailable, let lastPlace, let dial = kept(lastPlace), dial.isUsable(at: date) {
            return .show(dial)
        }
        return .clear(error == .refused ? .locationOff : .noPosition)
    }

    /// A hunt's stations as a dial, named only "Here" for now: its town may be slow to come, or not
    /// come at all, so it is kept at once. With none, the status that says why (`HuntOutcome.status`).
    public static func hunted(_ outcome: HuntOutcome, at date: Date) -> Hunted {
        guard case .found(let stations) = outcome, !stations.isEmpty else { return .nothing(outcome.status) }
        return .found(HereDial(town: hereName, stations: stations, savedAt: date))
    }

    /// The dial with its town, to keep and show; nil when no name came.
    public static func named(_ dial: HereDial, town: String?) -> HereDial? {
        town.map { HereDial(town: $0, stations: dial.stations, savedAt: dial.savedAt,
                            unchangedRefreshes: dial.unchangedRefreshes) }
    }

    /// Whether a shown dial is looked for again: when it is due (see `HereDial.needsRefresh`).
    public static func refreshes(_ dial: HereDial, at date: Date) -> Bool { dial.needsRefresh(at: date) }

    /// What a refresh that found `stations` keeps for next time, under the kept dial's town, saved
    /// `date`. Other stations that may replace the dial (`HereDial.mayBeReplaced`) do, and its count
    /// of unchanged refreshes starts again at 0. The same stations (call signs), or too few to
    /// replace it, count as unchanged: the dial keeps them, one more unchanged refresh, so a thin
    /// dial waits twice as long before the next (`HereDial.refreshAfter`). Finding nothing (no
    /// connection, say) keeps nothing new: nil, the old dial left alone.
    public static func refreshed(_ dial: HereDial, by stations: [Station], at date: Date) -> HereDial? {
        guard !stations.isEmpty else { return nil }
        if dial.mayBeReplaced(by: stations), !dial.hasSameStations(as: stations) {
            return HereDial(town: dial.town, stations: stations, savedAt: date)
        }
        let kept = dial.mayBeReplaced(by: stations) ? stations : dial.stations
        return HereDial(town: dial.town, stations: kept, savedAt: date,
                        unchangedRefreshes: dial.unchangedRefreshes + 1)
    }

    /// Whether the needle is the owner's as a search begins, so it neither sweeps nor moves onto a
    /// station: while a finger has it, after a return also if they had a hand on it before, and
    /// always after opening on HERE, where it was left.
    public static func needleIsTaken(on start: Start, wheelIsHeld: Bool, wasTaken: Bool) -> Bool {
        switch start {
        case .opened: true
        case .chosen: wheelIsHeld
        case .returned: wheelIsHeld || wasTaken
        }
    }
}
