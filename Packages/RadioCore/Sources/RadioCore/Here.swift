import Foundation

/// How the search for stations around the phone is going.
public enum HereStatus: Sendable, Equatable { case idle, finding, ready, empty, locationOff }

/// The id of the HERE band, whose stations are found rather than read from the file.
public let hereID = "here"

/// HERE's name until its town is known.
public let hereName = "Here"

/// The most stations a dial holds.
let dialLimit = 16

extension City {
    /// The band's name read aloud: HERE's goes with its town, so it is not mistaken for a city's.
    public var spokenName: String { id == hereID && name != hereName ? "\(hereName), \(name)" : name }
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
    /// connection may have cut short.
    private static let freshFor: TimeInterval = 24 * 3600
    private static let thinFreshFor: TimeInterval = 10 * 60
    /// A dial with fewer stations than this is thin.
    private static let thinLimit = 8

    public let town: String
    public let stations: [Station]
    public let savedAt: Date

    public init(town: String, stations: [Station], savedAt: Date) {
        self.town = town
        self.stations = stations
        self.savedAt = savedAt
    }

    /// Under 7 days old.
    public func isUsable(at date: Date) -> Bool { date.timeIntervalSince(savedAt) < Self.lifetime }

    /// Whether a refresh that found `stations` may take its place: any, and at least half as many,
    /// so a search that went badly never thins a good dial.
    public func mayBeReplaced(by stations: [Station]) -> Bool {
        !stations.isEmpty && stations.count * 2 >= self.stations.count
    }

    /// Over 24 hours old, or over 10 minutes with fewer than 8 stations. So is one saved in the
    /// future, by a clock since put back.
    public func needsRefresh(at date: Date) -> Bool {
        let age = date.timeIntervalSince(savedAt)
        return age < 0 || age > (stations.count < Self.thinLimit ? Self.thinFreshFor : Self.freshFor)
    }
}
