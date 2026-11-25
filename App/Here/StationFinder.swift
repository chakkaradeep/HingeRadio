#if HERE
import Foundation
import os
import RadioCore

/// Finds the FM stations around a place that stream: asks the FCC who is licensed there, the
/// stream sources for an address, and each address whether it answers.
/// Holds no rules about stations of its own: reading, matching, ranking, judging, and what to look
/// up next and when to stop (`Hunt`) are `RadioCore`'s.
/// The position goes to the FCC only, and is never logged.
actor StationFinder {
    private let session = URLSession(configuration: StationFinder.configuration,
                                     delegate: RedirectGuard(), delegateQueue: nil)
    private var hostPick: Task<String, Never>?
    private let log = Logger(subsystem: "HingeRadio", category: "here")

    private static let lookupsAtOnce = 6
    /// Seconds allowed for any one request, from start to end.
    private static let deadline: TimeInterval = 8

    deinit { session.finishTasksAndInvalidate() }

    /// The stations around `place`, best ranked 16 at most, sorted by frequency. `onFound` gets the
    /// list so far each time it changes. Cancelled, it stops every request, calls `onFound` no more
    /// and returns an empty list.
    func find(at place: Place, onFound: @Sendable ([Station]) async -> Void) async -> [Station] {
        let began = ContinuousClock.now
        hostPick = nil       // a fresh pick each search, so a host that has gone is not kept
        let listed = await licences(near: place)
        guard !Task.isCancelled else { return [] }
        var hunt = Hunt(stationsInReach(listed))
        log.notice("HERE FCC \(listed.count) licences, \(hunt.licences.count) in reach")

        var stations: [Station] = []
        await withTaskGroup(of: (Int, Found?).self) { group in
            for _ in 0..<Self.lookupsAtOnce { lookUpNext(&hunt, in: &group) }
            for await (index, found) in group {
                guard !Task.isCancelled else { return }
                hunt.settle(index, with: found)
                let soFar = hereStations(hunt.confirmed)
                if soFar != stations {
                    stations = soFar
                    await onFound(soFar)
                }
                if hunt.isDecided { group.cancelAll(); return }
                lookUpNext(&hunt, in: &group)
            }
        }
        guard !Task.isCancelled else { return [] }
        let seconds = (ContinuousClock.now - began) / .seconds(1)
        log.notice("HERE TOTAL \(stations.count) stations in \(seconds, format: .fixed(precision: 1)) s")
        return stations
    }

    /// Tells Radio Browser one of its stations was played, as it asks. The answer does not matter.
    func reportPlay(radioBrowserID: String) async {
        guard UUID(uuidString: radioBrowserID) != nil else { return }
        let host = await radioBrowserHost()
        guard let url = URL(string: "https://\(host)/json/url/\(radioBrowserID)") else { return }
        _ = await fetch(url)
    }

    // MARK: - Search

    private func lookUpNext(_ hunt: inout Hunt, in group: inout TaskGroup<(Int, Found?)>) {
        guard let (index, licence) = hunt.next() else { return }
        group.addTask { (index, await self.confirm(licence)) }
    }

    private func licences(near place: Place) async -> [Licence] {
        guard let data = await fetch(fccSearchURL(place)),
              let text = String(data: data, encoding: .isoLatin1) else { return [] }
        return RadioCore.licences(fromFCC: text)
    }

    /// The first address that answers with a playable stream, asking each source in order.
    private func confirm(_ licence: Licence) async -> Found? {
        for source in StreamSource.allCases {
            // Cancelled, nothing more is started: no host pick, no lookup, no probe.
            guard !Task.isCancelled else { return nil }
            // Only Radio Browser's address uses the host, so only it waits for one to be picked.
            let host = source == .radioBrowser ? await radioBrowserHost() : ""
            guard !Task.isCancelled else { return nil }
            let url = lookupURL(source, for: licence, radioBrowserHost: host)
            guard let data = await fetch(url),
                  let choice = streamChoice(source, from: data, for: licence) else { continue }
            for streamURL in choice.urls {
                guard !Task.isCancelled else { return nil }
                if await answers(streamURL) {
                    log.notice("HERE \(licence.callSign, privacy: .public) \(String(describing: source), privacy: .public)")
                    return (licence, choice, streamURL)
                }
            }
        }
        if !Task.isCancelled { log.notice("HERE \(licence.callSign, privacy: .public) none") }
        return nil
    }

    // MARK: - Network

    /// Ephemeral and without cookies. The request timeout is an idle timer, so a server that
    /// trickles would never meet it; the resource timeout holds the whole request to the deadline.
    private static var configuration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = ["User-Agent": "HingeRadio/1.0", "Accept": "*/*"]
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = deadline
        configuration.timeoutIntervalForResource = deadline
        // Enough that no lookup spends its deadline queueing behind the others.
        configuration.httpMaximumConnectionsPerHost = lookupsAtOnce
        return configuration
    }

    /// The whole answer, or nil for any failure.
    private func fetch(_ url: URL) async -> Data? {
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    /// Whether a stream answers at its final address with something playable: one byte is enough.
    private func answers(_ url: URL) async -> Bool {
        guard let (bytes, response) = try? await session.bytes(from: url) else { return false }
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse, let finalURL = response.url,
              isPlayable(status: response.statusCode,
                         contentType: response.value(forHTTPHeaderField: "Content-Type"),
                         finalURL: finalURL) else { return false }
        var body = bytes.makeAsyncIterator()
        return (try? await body.next()) != nil
    }

    // MARK: - Radio Browser host

    /// The Radio Browser server to ask, picked when first needed and shared by every lookup.
    /// A cancelled lookup stops waiting at once, without cancelling the pick for the others.
    private func radioBrowserHost() async -> String {
        let pick = hostPick ?? Task.detached { await pickRadioBrowserHost(within: Self.deadline) }
        hostPick = pick
        return await firstValue { give in Task { give(await pick.value) } } ?? fallbackHost
    }
}

/// A confirmed station: its licence, the stream offered for it and the address that answered.
private typealias Found = (Licence, StreamChoice, URL)

/// Keeps every redirect on https, and one that would carry the position off the FCC's servers
/// from being followed at all. A refused redirect leaves the 3xx answer, which nothing accepts.
private final class RedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        guard let url = request.url, url.scheme?.lowercased() == "https" else { return nil }
        if Self.isFCC(task.originalRequest?.url), !Self.isFCC(url) { return nil }
        return request
    }

    private static func isFCC(_ url: URL?) -> Bool {
        url?.host()?.lowercased().hasSuffix(".fcc.gov") == true
    }
}

// MARK: - DNS

private let hostSuffix = ".api.radio-browser.info"
private let fallbackHost = "de1" + hostSuffix

/// One of Radio Browser's servers at random, or the fallback when none is named in time.
private func pickRadioBrowserHost(within seconds: TimeInterval) async -> String {
    await firstValue { give in
        let queue = DispatchQueue.global(qos: .userInitiated)
        queue.async { give(radioBrowserHosts().randomElement() ?? fallbackHost) }
        queue.asyncAfter(deadline: .now() + seconds) { give(fallbackHost) }
    } ?? fallbackHost
}

/// The first value `start` gives, or nil at once when the caller is cancelled.
private func firstValue<Value: Sendable>(
    _ start: (@escaping @Sendable (Value) -> Void) -> Void
) async -> Value? {
    let (values, feed) = AsyncStream.makeStream(of: Value.self)
    start { feed.yield($0); feed.finish() }
    return await values.first { _ in true }
}

/// The names of the servers behind the shared address. Blocks while DNS answers.
private func radioBrowserHosts() -> Set<String> {
    var hints = addrinfo()
    hints.ai_socktype = SOCK_STREAM      // one entry per address
    var list: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo("all" + hostSuffix, nil, &hints, &list) == 0 else { return [] }
    defer { freeaddrinfo(list) }

    var hosts = Set<String>()
    var entry = list
    while let address = entry?.pointee {
        entry = address.ai_next
        var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(address.ai_addr, address.ai_addrlen, &name, socklen_t(name.count),
                          nil, 0, NI_NAMEREQD) == 0 else { continue }
        let host = String(decoding: name.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
        if host.hasSuffix(hostSuffix) { hosts.insert(host) }
    }
    return hosts
}
#endif
