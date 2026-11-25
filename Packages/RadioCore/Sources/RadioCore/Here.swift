import Foundation

/// How the search for stations around the phone is going.
public enum HereStatus: Sendable, Equatable { case idle, finding, ready, empty, locationOff }

/// The id of the HERE band, whose stations are found rather than read from the file.
public let hereID = "here"

/// The most stations a dial holds.
private let dialLimit = 16

/// HERE's dial from what was found: each licence with the stream offered for it and the address
/// that answered. The most clearly local stations within the band, at most 16, one per call sign
/// and one per frequency, sorted by frequency.
public func hereStations(_ found: [(Licence, StreamChoice, URL)]) -> [Station] {
    let band = DialConfig()
    var callSigns = Set<String>()
    var frequencies = Set<Double>()
    return found
        .filter { $0.0.frequency >= band.minFrequency && $0.0.frequency <= band.maxFrequency }
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
    public let town: String
    public let stations: [Station]
    public let savedAt: Date

    public init(town: String, stations: [Station], savedAt: Date) {
        self.town = town
        self.stations = stations
        self.savedAt = savedAt
    }

    /// Under 7 days old.
    public func isUsable(at date: Date) -> Bool { date.timeIntervalSince(savedAt) < 7 * 24 * 3600 }

    /// Over 24 hours old.
    public func needsRefresh(at date: Date) -> Bool { date.timeIntervalSince(savedAt) > 24 * 3600 }
}
