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

/// Where the radio was left: its band and needle position (0...1). Power and volume are not kept:
/// the radio always opens switched off.
public struct Remembered: Sendable, Equatable {
    public let band: String
    public let position: Double

    public init(band: String, position: Double) {
        self.band = band
        self.position = position
    }
}

/// Volume wheel, pose, city and failed stations, on top of a `Tuner`. The wheel is power and
/// loudness in one; the pose never affects sound.
public struct Radio: Sendable {
    /// The bands. Fixed, but for HERE, whose stations and name follow `setHereStations`.
    public private(set) var cities: [City]
    public private(set) var cityID: String
    /// Where the wheel clicks on.
    public static let wheelOnFrom = 0.15
    /// One ridge on the tuning wheel: 1/160 of the band, about 0.13 MHz.
    public static let tuningRidge = 1.0 / 160
    /// One soft step of the volume wheel.
    public static let volumeRidge = 0.05
    /// The side volume wheel, 0...1: off below `wheelOnFrom`.
    public private(set) var wheel = 0.0
    public private(set) var pose: Pose = .flex
    /// True while the app is in the background with the power off, or while an audio interruption
    /// holds a radio switched on (`shouldSuspend`); silent, display unchanged.
    public private(set) var isSuspended = false
    public private(set) var tuning: TuningState
    public private(set) var dead: Set<String> = []
    /// The position (0...1) last tuned to; the needle shows it.
    public private(set) var position = 0.5
    /// How the search for HERE's stations is going; shown only while HERE is the selected band.
    public private(set) var hereStatus = HereStatus.idle
    /// True while the needle sweeps the dial looking for HERE's stations.
    public private(set) var isScanning = false

    private let config: DialConfig
    private let poseConfig: PoseConfig
    private var tuner: Tuner
    private var lastOnWheel = 0.6

    /// `here` adds the HERE band first, before the bundled cities. The radio opens switched off, on
    /// `band` at `position` where it was left (see `remembered`), with the needle settled on a
    /// station locked there. A band not in this build opens as a first launch does: on the first
    /// bundled city, mid-dial, ignoring the position, which was another band's. A position that is
    /// not a finite number in 0...1, or none, opens mid-dial. With nothing remembered the radio
    /// opens on the first bundled city, never on HERE.
    public init(file: StationFile, config: DialConfig = DialConfig(), poseConfig: PoseConfig = PoseConfig(),
                here: Bool = false, band: String? = nil, position: Double? = nil) {
        let cities = (here ? [City(id: hereID, name: hereName, key: "HERE", stations: [])] : []) + file.cities
        let opening = band.flatMap { band in cities.first { $0.id == band } }
        self.cities = cities
        cityID = opening?.id ?? file.cities.first?.id ?? ""
        self.config = config
        self.poseConfig = poseConfig
        tuner = Tuner(stations: (opening ?? file.cities.first)?.stations ?? [], config: config)
        tuning = tuner.state
        if opening != nil, let position, position.isFinite, (0...1).contains(position) {
            self.position = position
        }
        tune(toPosition: self.position)
        settleOnLockedStation()                 // the needle starts on the station, not beside it
    }

    /// What to keep of where the radio is, to open there next time: the band and the needle. Nil
    /// while HERE's sweep moves the needle, which is not where anyone left it, and with no band.
    public var remembered: Remembered? {
        guard !isScanning, !cityID.isEmpty else { return nil }
        return Remembered(band: cityID, position: position)
    }

    public var scale: DialScale { tuner.scale }
    public var powerOn: Bool { wheel >= Self.wheelOnFrom }
    /// 0 when off; 0.2 at `wheelOnFrom` rising linearly to 1 at the top of the wheel.
    public var loudness: Double {
        guard powerOn else { return 0 }
        return 0.2 + 0.8 * (wheel - Self.wheelOnFrom) / (1 - Self.wheelOnFrom)
    }
    public var isLive: Bool { powerOn && !isSuspended }

    /// Whether the scan is what the owner sees and feels: no station shows, plays or clicks, while
    /// the static and the ticks go on.
    public var isScanningHere: Bool { isScanning && cityID == hereID }

    /// The locked station, for a face to show; nil while HERE's sweep passes its stations.
    public var lockToShow: Station? { isScanningHere ? nil : tuning.locked }

    public var station: Station? {
        guard isLive, !isScanningHere,
              let candidate = tuning.candidate, !dead.contains(candidate.callSign) else { return nil }
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

    /// Choosing HERE, even while on it, tries its stations afresh: none of them is dead.
    public mutating func selectCity(_ id: String) {
        guard let city = cities.first(where: { $0.id == id }) else { return }
        if id == hereID { dead.subtract(city.stations.map(\.callSign)) }
        cityID = id
        tuner = Tuner(stations: city.stations, config: config)
        tune(toPosition: position)
    }

    public mutating func setHere(status: HereStatus) { hereStatus = status }

    public mutating func setScanning(_ on: Bool) { isScanning = on }

    /// Gives HERE its stations, in frequency order as `hereStations` makes them, and the town as its
    /// name (nil keeps the name). The stations it already has only change the name. Otherwise, while
    /// HERE is selected its dial is rebuilt around a needle that stays put, and the stations it
    /// brings are no longer dead, except any that are also on another selected band, so nothing on
    /// that dial changes. Does nothing without the HERE band.
    public mutating func setHereStations(_ stations: [Station], town: String?) {
        guard let index = cities.firstIndex(where: { $0.id == hereID }) else { return }
        let old = cities[index]
        cities[index] = City(id: old.id, name: town ?? old.name, key: old.key, stations: stations)
        guard stations != old.stations else { return }
        let shownElsewhere = cityID == hereID ? [] : scale.marks.map(\.station.callSign)
        dead.subtract(Set(stations.map(\.callSign)).subtracting(shownElsewhere))
        if cityID == hereID { selectCity(hereID) }
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

    /// Where a slow release on the tuning wheel eases the needle to: the locked station's mark;
    /// else, while the radio is on and a live station's name shows in its fade zone (the
    /// candidate, not yet locked), that station's mark; else nil, and the needle stays put.
    /// Taps, VoiceOver steps and launch still count from `settleTarget` (a lock only).
    public var releaseTarget: Double? {
        if let target = settleTarget { return target }
        guard powerOn, let candidate = tuning.candidate, !dead.contains(candidate.callSign) else { return nil }
        return scale.marks.first { $0.station.callSign == candidate.callSign }?.position
    }

    /// Where the needle eases to once HERE has its stations: the locked station's mark, else the
    /// nearest live one; nil with neither.
    public var arrivalTarget: Double? {
        settleTarget ?? liveMarkPositions.min { abs($0 - position) < abs($1 - position) }
    }

    /// Tunes straight onto the locked station's mark, so the needle rests there and the next touch
    /// has an even hold on both sides. Does nothing when no station is locked. Used at launch; the
    /// app eases onto `settleTarget` itself after a release or a band change.
    public mutating func settleOnLockedStation() {
        guard let target = settleTarget else { return }
        tune(toPosition: target)
    }

    /// The marks of stations not marked dead, in dial order: where a flick may settle.
    public var liveMarkPositions: [Double] {
        scale.marks.filter { !dead.contains($0.station.callSign) }.map(\.position)
    }

    /// Where a tap on the tuning wheel or a VoiceOver step goes: the next station up or down the
    /// band, dead ones included so each can be reached. It counts from the locked station's mark
    /// when one is locked (so a needle resting beside it still moves on), otherwise from the
    /// needle. Nil past either end or with no stations.
    public func stepTarget(up: Bool) -> Double? {
        let from = settleTarget ?? tuning.needle
        let marks = scale.marks.map(\.position)
        return up ? nextMark(above: from, marks: marks) : nextMark(below: from, marks: marks)
    }

    public mutating func markDead(_ callSign: String) { dead.insert(callSign) }

    public func display(playback: Playback) -> Display {
        if pose == .flat {
            return Display(title: "Fold me", subtitle: "Sit the phone half open to use the radio.", lamp: .off, bars: 0)
        }
        // Off says nothing: the unlit power lamp says it.
        if !powerOn { return Display(title: "", subtitle: "", lamp: .off, bars: 0) }
        guard !isScanningHere, let candidate = tuning.candidate else {
            return Display(title: "· · ·", subtitle: emptySubtitle, lamp: .off, bars: 0)
        }
        if dead.contains(candidate.callSign) {
            return Display(title: candidate.shownName, subtitle: "No signal", lamp: .off, bars: 0)
        }
        if playback != .playing {
            return Display(title: candidate.shownName, subtitle: "Tuning in", lamp: .seeking, bars: 0)
        }
        return Display(title: candidate.shownName, subtitle: candidate.licenceCity, lamp: .locked,
                       bars: max(1, Int((tuning.strength * 5).rounded())))
    }

    /// The line under the dots where no station shows: static, or on HERE how the search is going.
    private var emptySubtitle: String {
        guard cityID == hereID else { return "Static" }
        if isScanning { return "Finding stations…" }
        switch hereStatus {
        case .finding: return "Finding stations…"
        case .empty: return "No stations found here"
        case .locationOff: return "Location is off"
        case .idle, .ready: return "Static"
        }
    }
}
