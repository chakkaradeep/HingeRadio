import Foundation

public enum Playback: Sendable, Equatable { case idle, connecting, playing }
public enum Lamp: Sendable, Equatable { case off, seeking, locked }

public struct Display: Sendable, Equatable {
    public var title: String, subtitle: String
    public var lamp: Lamp
    public var bars: Int

    public init(title: String, subtitle: String, lamp: Lamp, bars: Int) {
        self.title = title
        self.subtitle = subtitle
        self.lamp = lamp
        self.bars = bars
    }
}

/// Power, closed state, city and failed stations, on top of a `Tuner`.
public struct Radio: Sendable {
    public let cities: [City]
    public private(set) var cityID: String
    public private(set) var powerOn = false
    public private(set) var isClosed = false
    public private(set) var tuning: TuningState
    public private(set) var dead: Set<String> = []

    private let config: DialConfig
    private var tuner: Tuner
    private var lastReading = HingeReading(angle: 110, isClosed: false, time: 0)

    public init(file: StationFile, config: DialConfig = DialConfig()) {
        cities = file.cities
        cityID = file.cities.first?.id ?? ""
        self.config = config
        tuner = Tuner(stations: file.cities.first?.stations ?? [], config: config)
        tuning = tuner.state
        hinge(lastReading)
    }

    public var scale: DialScale { tuner.scale }
    public var isLive: Bool { powerOn && !isClosed }

    public var station: Station? {
        guard isLive, let candidate = tuning.candidate, !dead.contains(candidate.callSign) else { return nil }
        return candidate
    }

    public mutating func togglePower() { powerOn.toggle() }

    public mutating func selectCity(_ id: String) {
        guard let city = cities.first(where: { $0.id == id }) else { return }
        cityID = id
        tuner = Tuner(stations: city.stations, config: config)
        hinge(lastReading)
    }

    public mutating func hinge(_ reading: HingeReading) {
        guard !reading.angle.isNaN else { return }
        lastReading = reading
        isClosed = reading.isClosed || reading.angle < config.closedBelow
        tuning = tuner.update(reading)
    }

    public mutating func markDead(_ callSign: String) { dead.insert(callSign) }

    public func display(playback: Playback) -> Display {
        if isClosed { return Display(title: "Closed", subtitle: "Open the phone to listen again.", lamp: .off, bars: 0) }
        if !powerOn { return Display(title: "Off", subtitle: "Switch on to listen", lamp: .off, bars: 0) }
        guard let candidate = tuning.candidate else {
            return Display(title: "· · ·", subtitle: "Static", lamp: .off, bars: 0)
        }
        if dead.contains(candidate.callSign) {
            return Display(title: candidate.name, subtitle: "No signal", lamp: .off, bars: 0)
        }
        if playback != .playing {
            return Display(title: candidate.name, subtitle: "Tuning in", lamp: .seeking, bars: 0)
        }
        return Display(title: candidate.name, subtitle: candidate.licenceCity, lamp: .locked,
                       bars: max(1, Int((tuning.strength * 5).rounded())))
    }
}
