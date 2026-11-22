import Foundation

public struct Station: Codable, Hashable, Identifiable, Sendable {
    public let callSign: String, name: String, licenceCity: String
    public let frequency: Double            // MHz
    public let streamURL: URL
    public let homepage: URL?, radioBrowserID: String?
    public var id: String { callSign }

    public init(callSign: String, name: String, licenceCity: String, frequency: Double,
                streamURL: URL, homepage: URL? = nil, radioBrowserID: String? = nil) {
        self.callSign = callSign
        self.name = name
        self.licenceCity = licenceCity
        self.frequency = frequency
        self.streamURL = streamURL
        self.homepage = homepage
        self.radioBrowserID = radioBrowserID
    }
}

public struct City: Codable, Hashable, Identifiable, Sendable {
    public let id: String, name: String, key: String
    public let stations: [Station]

    public init(id: String, name: String, key: String, stations: [Station]) {
        self.id = id
        self.name = name
        self.key = key
        self.stations = stations
    }
}

public enum StationFileError: Error, Equatable {
    case unsorted(city: String), duplicateFrequency(city: String, frequency: Double)
    case tooManyStations(city: String, count: Int), outOfBand(city: String, callSign: String)
}

public struct StationFile: Codable, Sendable {
    public let generated: String
    public let cities: [City]

    public init(generated: String, cities: [City]) {
        self.generated = generated
        self.cities = cities
    }

    public static let empty = StationFile(generated: "", cities: [])

    /// Decodes the file, then checks every city: at most 16 stations, all in the FM band,
    /// frequencies unique and sorted ascending.
    public static func load(from data: Data) throws -> StationFile {
        let file = try JSONDecoder().decode(StationFile.self, from: data)
        let band = DialConfig()
        for city in file.cities {
            if city.stations.count > 16 {
                throw StationFileError.tooManyStations(city: city.key, count: city.stations.count)
            }
            for station in city.stations
            where station.frequency < band.minFrequency || station.frequency > band.maxFrequency {
                throw StationFileError.outOfBand(city: city.key, callSign: station.callSign)
            }
            for (a, b) in zip(city.stations, city.stations.dropFirst()) {
                if a.frequency == b.frequency {
                    throw StationFileError.duplicateFrequency(city: city.key, frequency: b.frequency)
                }
                if a.frequency > b.frequency {
                    throw StationFileError.unsorted(city: city.key)
                }
            }
        }
        return file
    }
}
