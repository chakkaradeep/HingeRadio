import Foundation

/// A stream address worth trying for one station, with the name to show.
public struct StreamChoice: Hashable, Sendable {
    public let name: String
    /// https only, best first.
    public let urls: [URL]
    /// Set when the answer came from Radio Browser, so a dead stream can be reported against it.
    public let radioBrowserID: String?

    public init(name: String, urls: [URL], radioBrowserID: String?) {
        self.name = name
        self.urls = urls
        self.radioBrowserID = radioBrowserID
    }
}

/// Where to ask for a station's stream, in the order they are tried.
public enum StreamSource: CaseIterable, Sendable {
    case iHeart, npr, radioBrowser
}

/// The address to ask `source` about `licence`. `radioBrowserHost` is a bare host,
/// such as de1.api.radio-browser.info.
public func lookupURL(_ source: StreamSource, for licence: Licence, radioBrowserHost: String) -> URL {
    let call = encoded(licence.baseCall)
    let text: String
    switch source {
    case .iHeart:
        text = "https://us.api.iheart.com/api/v2/content/liveStations?callLetters=\(call)"
    case .npr:
        text = "https://station.api.npr.org/v3/stations?q=\(call)"
    case .radioBrowser:
        text = "https://\(radioBrowserHost)/json/stations/search?countrycode=US&hidebroken=true&limit=50&name=\(call)"
    }
    // A host that is not a valid address gets a file URL, which no fetch will ever treat as https.
    return URL(string: text) ?? URL(fileURLWithPath: "/")
}

/// The stream `data` offers for `licence`, or nil when it is not that station,
/// has no https stream, or is not the answer expected (HTML, an empty body, half a response).
public func streamChoice(_ source: StreamSource, from data: Data, for licence: Licence) -> StreamChoice? {
    switch source {
    case .iHeart: iHeartChoice(data, licence)
    case .npr: nprChoice(data, licence)
    case .radioBrowser: radioBrowserChoice(data, licence)
    }
}

/// Whether a probed stream can be played: a 200 answer, https after any redirects,
/// and a type the player reads directly. Playlists (.pls, .m3u) are not streams.
public func isPlayable(status: Int, contentType: String?, finalURL: URL) -> Bool {
    guard status == 200, finalURL.scheme?.lowercased() == "https" else { return false }
    guard !["pls", "m3u"].contains(finalURL.pathExtension.lowercased()) else { return false }
    guard let contentType else { return false }
    let type = contentType.split(separator: ";", maxSplits: 1).first
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
    return playableTypes.contains(type)
}

private let playableTypes: Set<String> = [
    "audio/mpeg", "audio/aac", "audio/aacp", "application/vnd.apple.mpegurl", "application/x-mpegurl"
]

// MARK: - iHeart

private struct IHeartAnswer: Decodable {
    let hits: [Lenient<IHeartHit>]?
}

private struct IHeartHit: Decodable {
    let name: String?
    let callLetters: String?
    let band: String?
    let freq: Number?
    let streams: [String: String]?
}

private func iHeartChoice(_ data: Data, _ licence: Licence) -> StreamChoice? {
    guard let answer = try? JSONDecoder().decode(IHeartAnswer.self, from: data) else { return nil }
    for hit in answer.hits?.compactMap(\.value) ?? [] {
        guard hit.band == "FM",
              sameCall(hit.callLetters, licence),
              sameFrequency(hit.freq?.value, licence),
              let name = hit.name
        else { continue }
        let urls = ["secure_hls_stream", "secure_shoutcast_stream"]
            .compactMap { hit.streams?[$0] }
            .compactMap(httpsURL)
        if !urls.isEmpty { return StreamChoice(name: name, urls: urls, radioBrowserID: nil) }
    }
    return nil
}

// MARK: - NPR

private struct NPRAnswer: Decodable {
    let items: [Lenient<NPRItem>]?
}

private struct NPRItem: Decodable {
    let attributes: Attributes?

    struct Attributes: Decodable {
        let brand: Brand?
        let streamsV2: [Lenient<Stream>]?
    }

    struct Brand: Decodable {
        let call: String?
        let name: String?
        let frequency: Number?
    }

    struct Stream: Decodable {
        let primary: Bool?
        let urls: [Lenient<Link>]?
    }

    struct Link: Decodable {
        let contentType: String?
        let href: String?

        private enum CodingKeys: String, CodingKey {
            case contentType = "content-type"
            case href
        }
    }
}

private func nprChoice(_ data: Data, _ licence: Licence) -> StreamChoice? {
    guard let answer = try? JSONDecoder().decode(NPRAnswer.self, from: data) else { return nil }
    for attributes in answer.items?.compactMap(\.value).compactMap(\.attributes) ?? [] {
        guard let brand = attributes.brand,
              sameCall(brand.call, licence),
              sameFrequency(brand.frequency?.value, licence)
        else { continue }
        let streams = attributes.streamsV2?.compactMap(\.value) ?? []
        let ordered = streams.filter { $0.primary == true } + streams.filter { $0.primary != true }
        let urls = ordered
            .flatMap { $0.urls?.compactMap(\.value) ?? [] }
            .filter { $0.contentType?.lowercased().hasPrefix("audio/") == true }
            .compactMap { $0.href.flatMap(httpsURL) }
        if !urls.isEmpty {
            return StreamChoice(name: brand.name ?? licence.baseCall, urls: urls, radioBrowserID: nil)
        }
    }
    return nil
}

// MARK: - Radio Browser

private struct RadioBrowserEntry: Decodable {
    let stationuuid: String?
    let name: String?
    let url_resolved: String?
    let lastcheckok: Int?
    let ssl_error: Int?
}

private func radioBrowserChoice(_ data: Data, _ licence: Licence) -> StreamChoice? {
    guard let entries = try? JSONDecoder().decode([Lenient<RadioBrowserEntry>].self, from: data) else { return nil }
    for entry in entries.compactMap(\.value) {
        guard entry.lastcheckok == 1, entry.ssl_error == 0,
              let id = entry.stationuuid,
              let name = entry.name,
              holdsWhole(licence.baseCall, in: name),
              holdsWhole(String(format: "%.1f", licence.frequency), in: name),
              let url = entry.url_resolved.flatMap(httpsURL)
        else { continue }
        return StreamChoice(name: licence.baseCall, urls: [url], radioBrowserID: id)
    }
    return nil
}

/// Whether `text` holds `word` standing alone: WKEXP is not KEXP, and 190.3 is not 90.3.
private func holdsWhole(_ word: String, in text: String) -> Bool {
    let pattern = "(?<![A-Za-z0-9])" + NSRegularExpression.escapedPattern(for: word) + "(?![A-Za-z0-9])"
    return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

// MARK: - Shared

/// One list element that decodes to nil instead of failing the whole list.
private struct Lenient<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// A number the answer may write as text ("102.5") or as a number.
private struct Number: Decodable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if let text = try? single.decode(String.self) {
            value = Double(text.trimmingCharacters(in: .whitespaces))
        } else {
            value = try? single.decode(Double.self)
        }
    }
}

private func sameCall(_ call: String?, _ licence: Licence) -> Bool {
    guard let call else { return false }
    let base = call.uppercased().hasSuffix("-FM") ? String(call.dropLast(3)) : call
    return base.caseInsensitiveCompare(licence.baseCall) == .orderedSame
}

private func sameFrequency(_ frequency: Double?, _ licence: Licence) -> Bool {
    guard let frequency else { return false }
    return abs(frequency - licence.frequency) <= 0.05
}

private func httpsURL(_ text: String) -> URL? {
    guard let url = URL(string: text), url.scheme?.lowercased() == "https" else { return nil }
    return url
}

private func encoded(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
}
