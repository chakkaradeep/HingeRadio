#if HERE
import Foundation
import os
import RadioCore

/// Runs HERE's searches for the model, one at a time: where the phone is, then the dial kept for
/// that place, then a hunt for its stations when there is none or it is over a day old.
@MainActor final class HereSearch {
    private weak var model: RadioModel?
    private let locator = Locator()
    private let finder = StationFinder()
    private let cache = HereCache()
    private var task: Task<Void, Never>?
    /// Whether the last search was cut short.
    private var wasCancelled = false
    /// The place of the last dial shown or hunted for.
    private var lastPlace: Place?
    private let log = Logger(subsystem: "HingeRadio", category: "here")

    /// HERE's name until its town is known.
    private static let unnamed = "Here"

    init(model: RadioModel) { self.model = model }

    /// HERE was chosen: a search, unless one is already running.
    func chosen() {
        if task == nil { start() }
    }

    /// The app came back with HERE selected: a search, if the last one did not end with a dial.
    func returned() {
        guard task == nil, let status = model?.radio.hereStatus else { return }
        if wasCancelled || status == .locationOff || status == .empty { start() }
    }

    func cancel() {
        guard let task else { return }
        task.cancel()
        self.task = nil
        wasCancelled = true
        log.notice("HERE CANCELLED")
    }

    // MARK: - Private

    private func start() {
        task?.cancel()
        wasCancelled = false
        model?.hereSearchBegan()
        if model?.radio.hereStatus != .ready { model?.setHere(status: .finding) }
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
        let (place, dial) = kept(near: found)
        lastPlace = place
        if let dial {
            show(dial)
            if dial.needsRefresh(at: .now) { await refresh(dial, at: place) }
        } else {
            await hunt(at: place)
        }
    }

    /// The kept dial for a place, with the place it belongs to. A rough position wobbles, so a
    /// neighbouring cell of the last place still counts as it.
    private func kept(near place: Place) -> (Place, HereDial?) {
        if let lastPlace, place.isWithinOneCell(of: lastPlace), let dial = cache.load(lastPlace) {
            return (lastPlace, dial)
        }
        return (place, cache.load(place))
    }

    private func showNoPlace(_ error: LocatorError) {
        if error == .unavailable, let lastPlace, let dial = cache.load(lastPlace) {
            show(dial)
        } else {
            clear(.init(error))
        }
    }

    private func show(_ dial: HereDial) {
        log.notice("HERE CACHED \(dial.stations.count) stations")
        model?.setHereStations(dial.stations, town: dial.town)
        model?.setHere(status: .ready)
        model?.arriveOnStation()
    }

    private func clear(_ status: HereStatus) {
        model?.setHereStations([], town: Self.unnamed)
        model?.setHere(status: status)
    }

    /// Shows stations as they are found, then keeps the list with its town.
    private func hunt(at place: Place) async {
        clear(.finding)
        let stations = await finder.find(at: place) { [weak self] in await self?.show($0) }
        guard isCurrent else { return }
        guard !stations.isEmpty else {
            model?.setHere(status: .empty)
            return
        }
        model?.setHere(status: .ready)
        model?.arriveOnStation()
        let town = await locator.town(for: place) ?? Self.unnamed
        cache.save(HereDial(town: town, stations: stations, savedAt: .now), for: place)
        if isCurrent { model?.setHereStations(stations, town: town) }
    }

    private func show(_ stations: [Station]) {
        if isCurrent { model?.setHereStations(stations, town: nil) }
    }

    /// Only keeps the new list, for the next time HERE is chosen: the dial being listened to does
    /// not move. Finding nothing keeps the old one.
    private func refresh(_ dial: HereDial, at place: Place) async {
        let stations = await finder.find(at: place) { _ in }
        guard isCurrent, !stations.isEmpty else { return }
        let town = await locator.town(for: place) ?? dial.town
        cache.save(HereDial(town: town, stations: stations, savedAt: .now), for: place)
        log.notice("HERE REFRESHED \(stations.count) stations")
    }
}

private extension HereStatus {
    init(_ error: LocatorError) {
        switch error {
        case .refused: self = .locationOff
        case .unavailable: self = .empty
        }
    }
}
#endif
