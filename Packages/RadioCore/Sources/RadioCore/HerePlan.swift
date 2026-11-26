import Foundation

/// Why no position came: location is refused or switched off, or no fix came in time.
public enum LocatorError: Error, Sendable, Equatable { case refused, unavailable }

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
        /// Nothing: HERE is empty and nothing is kept.
        case empty
        /// A dial to keep at once and show.
        case found(HereDial)
    }

    /// Whether the last search was cut short.
    public private(set) var wasCancelled = false
    /// The place of the last dial shown or hunted for.
    public private(set) var lastPlace: Place?

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
    /// last search was cut short or ended without a dial.
    public func searches(on start: Start, status: HereStatus, isSearching: Bool) -> Bool {
        guard !isSearching else { return false }
        switch start {
        case .chosen, .opened: return true
        case .returned: return wasCancelled || status == .locationOff || status == .empty
        }
    }

    /// A search starts: it is no longer cut short.
    public mutating func begin() { wasCancelled = false }

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
    /// otherwise HERE says why it has nothing. Location refused forgets the last place.
    public mutating func noPlace(_ error: LocatorError, at date: Date, kept: (Place) -> HereDial?) -> NoPlace {
        if error == .refused { lastPlace = nil }
        if error == .unavailable, let lastPlace, let dial = kept(lastPlace), dial.isUsable(at: date) {
            return .show(dial)
        }
        return .clear(error == .refused ? .locationOff : .empty)
    }

    /// A hunt's stations as a dial, named only "Here" for now: its town may be slow to come, or not
    /// come at all, so it is kept at once.
    public static func hunted(_ stations: [Station], at date: Date) -> Hunted {
        stations.isEmpty ? .empty : .found(HereDial(town: hereName, stations: stations, savedAt: date))
    }

    /// The dial with its town, to keep and show; nil when no name came.
    public static func named(_ dial: HereDial, town: String?) -> HereDial? {
        town.map { HereDial(town: $0, stations: dial.stations, savedAt: dial.savedAt) }
    }

    /// Whether a shown dial is looked for again: when it is due (see `HereDial.needsRefresh`).
    public static func refreshes(_ dial: HereDial, at date: Date) -> Bool { dial.needsRefresh(at: date) }

    /// A refresh's stations as the dial to keep for next time, under the kept dial's town; nil when
    /// they may not replace it (see `HereDial.mayBeReplaced`).
    public static func refreshed(_ dial: HereDial, by stations: [Station], at date: Date) -> HereDial? {
        dial.mayBeReplaced(by: stations) ? HereDial(town: dial.town, stations: stations, savedAt: date) : nil
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
