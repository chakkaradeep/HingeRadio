import Foundation

/// Where the phone is, held to about a kilometre so a lookup never carries a precise position.
/// Rounds in `init` and when decoded, so equality, hashing and the cache key all see one value.
public struct Place: Hashable, Codable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = Self.round(latitude, to: 100)
        self.longitude = Self.round(longitude, to: 100)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(latitude: try values.decode(Double.self, forKey: .latitude),
                  longitude: try values.decode(Double.self, forKey: .longitude))
    }

    private enum CodingKeys: String, CodingKey { case latitude, longitude }

    /// A 0.1 degree grid key, so nearby spots share one cached answer.
    public var cacheKey: String {
        "\(Self.round(latitude, to: 10)),\(Self.round(longitude, to: 10))"
    }

    /// Whether the two share a grid cell or sit in neighbouring ones.
    public func isWithinOneCell(of other: Place) -> Bool {
        func apart(_ a: Double, _ b: Double) -> Double { abs((a * 10).rounded() - (b * 10).rounded()) }
        return apart(latitude, other.latitude) <= 1 && apart(longitude, other.longitude) <= 1
    }

    /// Rounds to `1 / scale` of a degree; adding zero turns -0.0 into 0.0.
    private static func round(_ value: Double, to scale: Double) -> Double {
        (value * scale).rounded() / scale + 0.0
    }
}

/// One FM licence the FCC lists near a place.
public struct Licence: Hashable, Sendable {
    public let callSign: String
    public let city: String
    public let stationClass: String
    /// MHz.
    public let frequency: Double
    public let kilowatts: Double
    /// Kilometres from the place searched.
    public let distance: Double

    public init(callSign: String, city: String, stationClass: String,
                frequency: Double, kilowatts: Double, distance: Double) {
        self.callSign = callSign
        self.city = city
        self.stationClass = stationClass
        self.frequency = frequency
        self.kilowatts = kilowatts
        self.distance = distance
    }

    /// The call sign without the FM suffix: "KEXP-FM" is "KEXP".
    public var baseCall: String {
        callSign.hasSuffix("-FM") ? String(callSign.dropLast(3)) : callSign
    }

    /// Distance as a share of the class's reach; smaller means more clearly local.
    /// A class with no reach is never in reach, so it ranks last rather than dividing by zero.
    public var rank: Double {
        let reach = Self.reach(ofClass: stationClass)
        return reach > 0 ? distance / reach : .infinity
    }

    /// The order for a dial: `rank`, then the stronger signal, then the lower frequency. The call
    /// sign settles the rest so the order never wobbles.
    func isMoreLocal(than other: Licence) -> Bool {
        if rank != other.rank { return rank < other.rank }
        if kilowatts != other.kilowatts { return kilowatts > other.kilowatts }
        if frequency != other.frequency { return frequency < other.frequency }
        return callSign < other.callSign
    }

    /// Kilometres a class is expected to cover. D is a judgement call: class D stations are tiny.
    private static func reach(ofClass stationClass: String) -> Double {
        switch stationClass {
        case "A": 28
        case "B1", "C3": 39
        case "B", "C2": 52
        case "C1": 72
        case "C0": 83
        case "C": 92
        case "D": 10
        default: 0
        }
    }
}

/// The FCC FM query for every station within 100 km of `place`.
/// The FCC wants the position as degrees, minutes and seconds, so this works from whole seconds
/// and a rounded 59.9 seconds carries into the minutes.
public func fccSearchURL(_ place: Place) -> URL {
    func dms(_ degrees: Double) -> (Int, Int, Int) {
        let seconds = Int((abs(degrees) * 3600).rounded())
        return (seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
    let (latD, latM, latS) = dms(place.latitude)
    let (lonD, lonM, lonS) = dms(place.longitude)
    let query = "serv=FM&list=4&dist=100"
        + "&dlat2=\(latD)&mlat2=\(latM)&slat2=\(latS)&NS=\(place.latitude < 0 ? "S" : "N")"
        + "&dlon2=\(lonD)&mlon2=\(lonM)&slon2=\(lonS)&EW=\(place.longitude < 0 ? "W" : "E")"
    return URL(string: "https://transition.fcc.gov/fcc-bin/fmq?" + query)!
}

/// Reads the FCC's pipe-separated answer. Keeps licensed FM rows only (not STA, MOD or CP), one per
/// call sign. Anything that is not a whole row, such as an HTML error page, is skipped, never a crash.
public func licences(fromFCC text: String) -> [Licence] {
    var seen = Set<String>()
    var found: [Licence] = []
    for line in text.split(whereSeparator: \.isNewline) {
        let fields = line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard fields.count > 14, fields[3] == "FM", fields[9] == "LIC",
              let frequency = number(fields[2]), let kilowatts = number(fields[14]),
              let distanceField = fields.first(where: { $0.hasSuffix(" km") }),
              let distance = number(distanceField),
              !fields[1].isEmpty, seen.insert(fields[1]).inserted else { continue }
        found.append(Licence(callSign: fields[1], city: fields[10].capitalized,
                             stationClass: fields[7], frequency: frequency,
                             kilowatts: kilowatts, distance: distance))
    }
    return found
}

/// The leading number of a field such as "90.3  MHz" or "65.    kW".
private func number(_ field: String) -> Double? {
    field.split(separator: " ").first.flatMap { Double($0) }
}

/// The licences within their class's reach, one per call sign, the most clearly local first
/// (`Licence.isMoreLocal`). Not yet cut to the dial's 16.
public func stationsInReach(_ licences: [Licence]) -> [Licence] {
    let ordered = licences.filter { $0.rank <= 1 }.sorted { $0.isMoreLocal(than: $1) }
    var seen = Set<String>()
    return ordered.filter { seen.insert($0.callSign).inserted }
}
