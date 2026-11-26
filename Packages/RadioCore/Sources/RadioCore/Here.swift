import Foundation

/// How the search for stations around the phone is going, and why it ended without a dial.
public enum HereStatus: Sendable, Equatable {
    case idle, finding, ready
    /// The FCC listed stations, but none with a stream was found.
    case empty
    /// Location is refused, or switched off.
    case locationOff
    /// No position came in time.
    case noPosition
    /// The FCC's list could not be had.
    case noConnection
    /// The FCC answered with no licence at all: what a place outside the US gets.
    case outsideUS

    /// What HERE says while it is in this state, under the band's name; nil when it says nothing
    /// of its own (no search yet, or a dial is ready).
    public var words: String? {
        switch self {
        case .finding: "Finding stations…"
        case .empty: "No stations found here"
        case .locationOff: "Location is off"
        case .noPosition: "Can't find where you are"
        case .noConnection: "No connection"
        case .outsideUS: "HERE covers the US only"
        case .idle, .ready: nil
        }
    }
}

/// The id of the HERE band, whose stations are found rather than read from the file.
public let hereID = "here"

/// HERE's name until its town is known.
public let hereName = "Here"

/// The most stations a dial holds.
let dialLimit = 16

extension City {
    /// The band's name read aloud: HERE's goes with its town, so it is not mistaken for a city's.
    public var spokenName: String { id == hereID && name != hereName ? "\(hereName), \(name)" : name }

    /// Whether this is the HERE band, which the face marks with the location arrow in place of a
    /// printed key, and before its name in the header so its town is not mistaken for a city's.
    public var isHere: Bool { id == hereID }
}

extension Licence {
    /// Whether the frequency is on the dial.
    var isInBand: Bool {
        let band = DialConfig()
        return frequency >= band.minFrequency && frequency <= band.maxFrequency
    }
}

/// HERE's dial from what was found: each licence with the stream offered for it and the address
/// that answered. The most clearly local stations within the band, at most 16, one per call sign
/// and one per frequency, sorted by frequency.
public func hereStations(_ found: [(Licence, StreamChoice, URL)]) -> [Station] {
    var callSigns = Set<String>()
    var frequencies = Set<Double>()
    return found
        .filter { $0.0.isInBand }
        .sorted { $0.0.isMoreLocal(than: $1.0) }
        .filter { callSigns.insert($0.0.callSign).inserted }
        .filter { frequencies.insert($0.0.frequency).inserted }
        .prefix(dialLimit)
        .map { licence, choice, url in
            Station(callSign: licence.callSign, name: choice.name, licenceCity: licence.city,
                    frequency: licence.frequency, streamURL: url, radioBrowserID: choice.radioBrowserID)
        }
        .sorted { $0.frequency < $1.frequency }
}

/// A place's dial, kept on the phone so it can show at once next time.
public struct HereDial: Codable, Sendable, Equatable {
    /// Seconds a kept dial may be shown for: 7 days.
    public static let lifetime: TimeInterval = 7 * 24 * 3600

    /// Seconds until a dial is looked for again: a day, or 10 minutes for a thin one, which a poor
    /// connection may have cut short, doubled for each refresh of it that found the same stations,
    /// up to a day.
    private static let freshFor: TimeInterval = 24 * 3600
    private static let thinFreshFor: TimeInterval = 10 * 60
    /// A dial with fewer stations than this is thin.
    private static let thinLimit = 8

    public let town: String
    public let stations: [Station]
    public let savedAt: Date
    /// How many refreshes in a row found the same stations (or too few to replace them) since the
    /// stations last changed: each doubles the wait before a thin dial is looked for again.
    public let unchangedRefreshes: Int

    public init(town: String, stations: [Station], savedAt: Date, unchangedRefreshes: Int = 0) {
        self.town = town
        self.stations = stations
        self.savedAt = savedAt
        self.unchangedRefreshes = unchangedRefreshes
    }

    private enum CodingKeys: String, CodingKey { case town, stations, savedAt, unchangedRefreshes }

    /// A dial file written before refreshes were counted has none: 0.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        town = try container.decode(String.self, forKey: .town)
        stations = try container.decode([Station].self, forKey: .stations)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        unchangedRefreshes = try container.decodeIfPresent(Int.self, forKey: .unchangedRefreshes) ?? 0
    }

    /// Under 7 days old.
    public func isUsable(at date: Date) -> Bool { date.timeIntervalSince(savedAt) < Self.lifetime }

    /// Whether a refresh that found `stations` may take its place: any, and at least half as many,
    /// so a search that went badly never thins a good dial.
    public func mayBeReplaced(by stations: [Station]) -> Bool {
        !stations.isEmpty && stations.count * 2 >= self.stations.count
    }

    /// Whether `stations` are this dial's stations: the same call signs.
    public func hasSameStations(as stations: [Station]) -> Bool {
        Set(stations.map(\.callSign)) == Set(self.stations.map(\.callSign))
    }

    /// Seconds after saving that the dial is looked for again: 24 hours, or for a thin one 10
    /// minutes doubled for each unchanged refresh, at most 24 hours.
    public var refreshAfter: TimeInterval {
        guard stations.count < Self.thinLimit else { return Self.freshFor }
        let doublings = min(max(unchangedRefreshes, 0), 16)    // 10 min × 2^8 is already over a day
        return min(Self.thinFreshFor * Double(1 << doublings), Self.freshFor)
    }

    /// Over `refreshAfter` old: 24 hours, or for a thin dial (fewer than 8 stations) 10 minutes,
    /// 20, 40, … up to 24 hours as refreshes keep finding the same stations. So is one saved in the
    /// future, by a clock since put back.
    public func needsRefresh(at date: Date) -> Bool {
        let age = date.timeIntervalSince(savedAt)
        return age < 0 || age > refreshAfter
    }
}
