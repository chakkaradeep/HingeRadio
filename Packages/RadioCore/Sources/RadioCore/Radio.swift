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

/// Power, pose, city and failed stations, on top of a `Tuner`.
public struct Radio: Sendable {
    public let cities: [City]
    public private(set) var cityID: String
    public private(set) var powerOn = false
    public private(set) var pose: Pose = .flex
    /// True while the app is not the active one; silent like a shut phone, display unchanged.
    public private(set) var isSuspended = false
    public private(set) var tuning: TuningState
    public private(set) var dead: Set<String> = []

    private let config: DialConfig
    private let poseConfig: PoseConfig
    private var tuner: Tuner
    private var position = 0.5

    public init(file: StationFile, config: DialConfig = DialConfig(), poseConfig: PoseConfig = PoseConfig()) {
        cities = file.cities
        cityID = file.cities.first?.id ?? ""
        self.config = config
        self.poseConfig = poseConfig
        tuner = Tuner(stations: file.cities.first?.stations ?? [], config: config)
        tuning = tuner.state
        tune(toPosition: position)
    }

    public var scale: DialScale { tuner.scale }
    public var isLive: Bool { powerOn && pose != .shut && !isSuspended }

    public var station: Station? {
        guard isLive, let candidate = tuning.candidate, !dead.contains(candidate.callSign) else { return nil }
        return candidate
    }

    public mutating func togglePower() { powerOn.toggle() }

    public mutating func setSuspended(_ suspended: Bool) { isSuspended = suspended }

    public mutating func selectCity(_ id: String) {
        guard let city = cities.first(where: { $0.id == id }) else { return }
        cityID = id
        tuner = Tuner(stations: city.stations, config: config)
        tune(toPosition: position)
    }

    /// Moves the needle to `position` (0...1, clamped). Not-a-number is ignored.
    public mutating func tune(toPosition position: Double) {
        guard !position.isNaN else { return }
        self.position = min(1, max(0, position))
        tuning = tuner.update(config.minAngle + self.position * (config.maxAngle - config.minAngle))
    }

    /// Sets the pose from the screen, way up and hinge. A not-a-number angle is ignored.
    public mutating func setPose(_ input: PoseInput) {
        guard !(input.angle?.isNaN ?? false) else { return }
        pose = RadioCore.pose(input, config: poseConfig)
    }

    public mutating func markDead(_ callSign: String) { dead.insert(callSign) }

    public func display(playback: Playback) -> Display {
        if pose == .flat {
            return Display(title: "Fold me", subtitle: "Sit the phone half open to use the radio.", lamp: .off, bars: 0)
        }
        if pose == .shut { return Display(title: "Closed", subtitle: "Open the phone to listen again.", lamp: .off, bars: 0) }
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
