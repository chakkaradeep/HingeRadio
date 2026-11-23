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

/// Volume wheel, pose, city and failed stations, on top of a `Tuner`. The wheel is power and
/// loudness in one; the pose never affects sound.
public struct Radio: Sendable {
    public let cities: [City]
    public private(set) var cityID: String
    /// Where the wheel clicks on.
    public static let wheelOnFrom = 0.15
    /// The side volume wheel, 0...1: off below `wheelOnFrom`.
    public private(set) var wheel = 0.0
    public private(set) var pose: Pose = .flex
    /// True while the app is not the active one; silent, display unchanged.
    public private(set) var isSuspended = false
    public private(set) var tuning: TuningState
    public private(set) var dead: Set<String> = []
    /// The position (0...1) last tuned to; the needle shows it.
    public private(set) var position = 0.5

    private let config: DialConfig
    private let poseConfig: PoseConfig
    private var tuner: Tuner
    private var lastOnWheel = 0.6

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
    public var powerOn: Bool { wheel >= Self.wheelOnFrom }
    /// 0 when off; 0.2 at `wheelOnFrom` rising linearly to 1 at the top of the wheel.
    public var loudness: Double {
        guard powerOn else { return 0 }
        return 0.2 + 0.8 * (wheel - Self.wheelOnFrom) / (1 - Self.wheelOnFrom)
    }
    public var isLive: Bool { powerOn && !isSuspended }

    public var station: Station? {
        guard isLive, let candidate = tuning.candidate, !dead.contains(candidate.callSign) else { return nil }
        return candidate
    }

    /// Sets the wheel (clamped to 0...1). Not-a-number is ignored.
    public mutating func setWheel(_ value: Double) {
        guard !value.isNaN else { return }
        wheel = min(1, max(0, value))
        if powerOn { lastOnWheel = wheel }
    }

    /// Off goes to the last on position (0.6 if never on); on goes to 0.
    public mutating func togglePower() { setWheel(powerOn ? 0 : lastOnWheel) }

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

    /// Where a slow release should ease the needle to: the locked station's mark, or nil when
    /// nothing is locked.
    public var settleTarget: Double? {
        guard let locked = tuning.locked else { return nil }
        return scale.marks.first { $0.station.callSign == locked.callSign }?.position
    }

    /// Tunes straight onto the locked station's mark, so the needle rests there and the next touch
    /// has an even hold on both sides. Does nothing when no station is locked.
    public mutating func settleOnLockedStation() {
        guard let target = settleTarget else { return }
        tune(toPosition: target)
    }

    /// The marks of stations not marked dead, in dial order: where a flick may settle.
    public var liveMarkPositions: [Double] {
        scale.marks.filter { !dead.contains($0.station.callSign) }.map(\.position)
    }

    public mutating func markDead(_ callSign: String) { dead.insert(callSign) }

    public func display(playback: Playback) -> Display {
        if pose == .flat {
            return Display(title: "Fold me", subtitle: "Sit the phone half open to use the radio.", lamp: .off, bars: 0)
        }
        // Off says nothing: the unlit power lamp says it.
        if !powerOn { return Display(title: "", subtitle: "", lamp: .off, bars: 0) }
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
