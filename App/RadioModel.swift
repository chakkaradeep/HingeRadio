import Foundation
import Observation
import os
import RadioCore

/// Owns the `Radio` and feeds it hinge readings. Holds no radio rules of its own.
@MainActor @Observable final class RadioModel {
    /// The one place the dial's end angles are chosen (docs/hinge-measurements.md, Decision 1).
    static let dialConfig: DialConfig = {
        var config = DialConfig()
        config.minAngle = 70
        config.maxAngle = 150
        return config
    }()

    private(set) var radio: Radio
    var playback: Playback = .idle           // written by Task 6

    /// False until a hinge context with a hinge arrives; while false, dragging the dial glass tunes.
    var hasHinge = false
    /// The angle of the reading the radio last received; 110 until the first one arrives.
    private(set) var angle: Double = 110
    /// Set by the debug slider. While not nil it replaces hinge readings.
    var debugAngle: Double? {
        didSet {
            if let debugAngle {
                apply(HingeReading(angle: debugAngle, isClosed: false, time: ProcessInfo.processInfo.systemUptime))
            } else if let lastHingeReading {
                apply(lastHingeReading)
            }
        }
    }

    @ObservationIgnored private var lastHingeReading: HingeReading?
    @ObservationIgnored private let log = Logger(subsystem: "HingeRadio", category: "dial")

    init(stationData: Data?) {
        let file = stationData.flatMap { try? StationFile.load(from: $0) } ?? .empty
        radio = Radio(file: file, config: Self.dialConfig)
        logMarks()
    }

    var config: DialConfig { Self.dialConfig }
    var display: Display { radio.display(playback: playback) }
    var city: City? { radio.cities.first { $0.id == radio.cityID } }

    func hinge(_ reading: HingeReading) {
        lastHingeReading = reading
        guard debugAngle == nil else { return }
        apply(reading)
    }

    func togglePower() { radio.togglePower() }

    func selectCity(_ id: String) {
        let before = radio.tuning.locked?.callSign
        radio.selectCity(id)
        logMarks()
        logLockChange(from: before)
    }

    func markDead(_ callSign: String) { radio.markDead(callSign) }

    // MARK: - Private

    private func apply(_ reading: HingeReading) {
        guard !reading.angle.isNaN else { return }
        let before = radio.tuning.locked?.callSign
        radio.hinge(reading)
        angle = reading.angle
        logLockChange(from: before)
    }

    private func logMarks() {
        for mark in radio.scale.marks {
            let line = String(format: "MARK %@ %.1f %.2f", mark.station.callSign, mark.station.frequency, mark.angle)
            log.notice("\(line, privacy: .public)")
        }
    }

    private func logLockChange(from before: String?) {
        let after = radio.tuning.locked?.callSign
        guard after != before else { return }
        let line = after.map { String(format: "LOCK %@ %.2f", $0, angle) } ?? String(format: "STATIC %.2f", angle)
        log.notice("\(line, privacy: .public)")
    }
}
