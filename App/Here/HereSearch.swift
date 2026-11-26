#if HERE
import Foundation
import os
import RadioCore

/// Runs HERE's searches for the model, one at a time: where the phone is, then the dial kept for
/// that place, then a hunt for its stations when there is none or it is due a refresh
/// (`HerePlan.refreshes`). Opening on HERE first shows the last place's kept dial.
@MainActor final class HereSearch {
    private weak var model: RadioModel?
    private let locator = Locator()
    private let finder = StationFinder()
    private let cache = HereCache()
    private var task: Task<Void, Never>?
    /// The rules, and what they remember from one search to the next.
    private var plan = HerePlan()
    /// Whether the last place kept from an earlier run has been read in this one.
    private var recalled = false
    private let log = Logger(subsystem: "HingeRadio", category: "here")

    init(model: RadioModel) { self.model = model }

    /// The radio opened on HERE: the dial kept for the last place, if it may still be shown, shows
    /// at once under the needle where it was left; with location refused, no dial and "Location is
    /// off". The search waits for `openedAndActive()`.
    func opened() {
        let (dial, refused) = recall()
        guard let model else { return }
        if refused {
            log.notice("HERE OPENED refused")
            model.setHere(status: .locationOff)
            return
        }
        guard let dial else { return }
        log.notice("HERE OPENED \(dial.stations.count) stations")
        model.setHereStations(dial.stations, town: dial.town)
        model.setHere(status: .ready)
    }

    /// The radio opened on HERE and the app is now active: a search, which leaves the needle alone.
    func openedAndActive() {
        let status = model?.radio.hereStatus ?? .idle
        if plan.searches(on: .opened, status: status, isSearching: task != nil) { start(.opened) }
    }

    /// HERE was chosen: a search, unless one is already running.
    func chosen() {
        _ = recall()
        let status = model?.radio.hereStatus ?? .idle
        if plan.searches(on: .chosen, status: status, isSearching: task != nil) { start(.chosen) }
    }

    /// The app came back with HERE selected: a search, if the last one did not end with a dial.
    func returned() {
        guard let status = model?.radio.hereStatus,
              plan.searches(on: .returned, status: status, isSearching: task != nil) else { return }
        start(.returned)
    }

    /// A station Radio Browser listed started playing: tells it, as it asks. Its own task, so no
    /// band change or cancelled search stops it; a failure is ignored.
    func played(radioBrowserID: String) {
        log.notice("HERE PLAY SENT")
        Task { [finder] in await finder.reportPlay(radioBrowserID: radioBrowserID) }
    }

    /// Ends the search, and drops the part of a dial it had found: nobody should tune it, and the
    /// next search starts afresh. A dial that was kept, or is whole, stays, and so does a part of
    /// one while one of its stations is `playing` (`HerePlan.cancel`).
    func cancel(playing: Bool = false) {
        if let status = plan.cancel(status: model?.radio.hereStatus ?? .idle, isSearching: task != nil,
                                    playing: playing) {
            clear(status)
        }
        model?.endScan()
        guard let task else { return }
        task.cancel()
        self.task = nil
        log.notice("HERE CANCELLED")
    }

    // MARK: - Private

    /// The first time HERE is opened or chosen in this run: the last place kept from an earlier
    /// one, and the dial kept there if it may show (`HerePlan.opening`). With location refused the
    /// place is forgotten and its file removed. Later calls give nothing.
    private func recall() -> (dial: HereDial?, refused: Bool) {
        guard !recalled else { return (nil, false) }
        recalled = true
        let refused = locator.isRefused
        plan = HerePlan(lastPlace: cache.lastPlace())
        let dial = plan.opening(at: .now, refused: refused) { cache.load($0) }
        if refused { cache.forgetLastPlace() }
        return (dial, refused)
    }

    private func start(_ start: HerePlan.Start) {
        task?.cancel()
        plan.begin()
        model?.hereSearchBegan(start)
        if let model, let status = HerePlan.status(onStartFrom: model.radio.hereStatus) {
            model.setHere(status: status)
        }
        task = Task {
            await search()
            if !Task.isCancelled { task = nil }
        }
    }

    /// Whether the search calling this is still the one the owner is waiting for: checked after
    /// every wait, before anything is shown.
    private var isCurrent: Bool { !Task.isCancelled && model?.radio.cityID == hereID }

    private func search() async {
        let found: Place
        do {
            found = try await locator.place()
        } catch {
            if isCurrent { showNoPlace(error) }
            return
        }
        guard isCurrent else { return }
        let (place, next) = plan.arrive(at: found, at: .now) { cache.load($0) }
        cache.keep(lastPlace: place)
        switch next {
        case .show(let dial, let lookUpTown):
            show(dial)
            let dial = lookUpTown ? await named(dial, at: place) : dial
            if isCurrent, HerePlan.refreshes(dial, at: .now) { await refresh(dial, at: place) }
        case .hunt:
            await hunt(at: place)
        }
    }

    private func showNoPlace(_ error: LocatorError) {
        if error == .refused { cache.forgetLastPlace() }
        switch plan.noPlace(error, at: .now, kept: { cache.load($0) }) {
        case .show(let dial): show(dial)
        case .clear(let status): clear(status)
        }
    }

    private func show(_ dial: HereDial) {
        log.notice("HERE CACHED \(dial.stations.count) stations")
        model?.setHereStations(dial.stations, town: dial.town)
        model?.setHere(status: .ready)
        model?.arriveOnStation()
    }

    private func clear(_ status: HereStatus) {
        model?.setHereStations([], town: hereName)
        model?.setHere(status: status)
    }

    /// Shows stations as they are found, the needle sweeping the dial meanwhile, and keeps the list
    /// at once: its town may be slow to come, or not come at all. Finding none, HERE says why: no
    /// connection to the FCC, outside the US, or no stations with a stream.
    private func hunt(at place: Place) async {
        clear(.finding)
        model?.beginScan()
        let outcome = await finder.find(at: place) { [weak self] in await self?.show($0) }
        guard isCurrent else { return }          // whatever ended this search ended its sweep
        model?.endScan()
        let dial: HereDial
        switch HerePlan.hunted(outcome, at: .now) {
        case .nothing(let status):
            model?.setHere(status: status)
            return
        case .found(let found):
            dial = found
        }
        cache.save(dial, for: place)
        log.notice("HERE SAVED")
        model?.setHere(status: .ready)
        model?.arriveOnStation()
        _ = await named(dial, at: place)
    }

    /// The dial on screen with its town looked up, shown and kept; unchanged when no name comes.
    private func named(_ dial: HereDial, at place: Place) async -> HereDial {
        let town = await locator.town(for: place)
        guard let named = HerePlan.named(dial, town: town), isCurrent else { return dial }
        cache.save(named, for: place)
        log.notice("HERE NAMED")
        model?.setHereStations(named.stations, town: named.town)
        return named
    }

    private func show(_ stations: [Station]) {
        if isCurrent { model?.setHereStations(stations, town: nil) }
    }

    /// Only keeps the new list, for the next time HERE is chosen: the dial being listened to does
    /// not move. Finding nothing, or far fewer stations, keeps the old one.
    private func refresh(_ dial: HereDial, at place: Place) async {
        let stations = await finder.find(at: place) { _ in }.stations
        guard isCurrent, let fresh = HerePlan.refreshed(dial, by: stations, at: .now) else { return }
        cache.save(fresh, for: place)
        log.notice("HERE REFRESHED \(stations.count) stations")
    }
}
#endif
