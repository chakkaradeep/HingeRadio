import AVFoundation
import Foundation
import Observation
import os
import RadioCore
import UIKit

/// Owns the `Radio` and feeds it hinge readings. Holds no radio rules of its own.
@MainActor @Observable final class RadioModel {
    /// The one place the dial's end angles are chosen (docs/hinge-measurements.md, Decision 1).
    static let dialConfig: DialConfig = {
        var config = DialConfig()
        config.minAngle = 70
        config.maxAngle = 150
        return config
    }()

    private(set) var radio: Radio {
        didSet { radioChanged(from: oldValue) }
    }
    /// Written by the station player.
    var playback: Playback = .idle {
        didSet { if playback != oldValue { updateSound() } }
    }

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
    @ObservationIgnored private let soundLog = Logger(subsystem: "HingeRadio", category: "sound")
    @ObservationIgnored private let player = StationPlayer()
    @ObservationIgnored private let noise = NoiseEngine()
    @ObservationIgnored private let haptic = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private var audioStarted = false

    init(stationData: Data?) {
        let file = stationData.flatMap { try? StationFile.load(from: $0) } ?? .empty
        radio = Radio(file: file, config: Self.dialConfig)
        player.onPlayback = { [weak self] in self?.playback = $0 }
        player.onFailed = { [weak self] in self?.markDead($0.callSign) }
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
        if id != radio.cityID { player.stop() }   // the old city's station goes silent at once
        radio.selectCity(id)
        logMarks()
        logLockChange(from: before)
    }

    func markDead(_ callSign: String) { radio.markDead(callSign) }

    // MARK: - Private

    private func radioChanged(from old: Radio) {
        let locked = radio.tuning.locked
        if radio.isLive, let locked, locked.callSign != old.tuning.locked?.callSign {
            noise.click()
            haptic.impactOccurred()
        }
        updateSound()
    }

    /// Follows `radio` and `playback`: the station to connect, and the levels from `mix`.
    private func updateSound() {
        guard radio.isLive else {
            player.stop()
            player.volume = 0
            noise.set(staticLevel: 0, whistle: 0, whistleHz: 0)
            return
        }
        startAudioIfNeeded()
        let station = radio.station
        player.want(station)
        let levels = mix(isLive: true,
                         playing: playback == .playing && player.connected == station,
                         strength: radio.tuning.strength,
                         edgeDistance: radio.tuning.edgeDistance)
        player.volume = Float(levels.station)
        noise.set(staticLevel: Float(levels.staticLevel), whistle: Float(levels.whistle),
                  whistleHz: Float(levels.whistleHz))
    }

    /// On first power on: the `.playback` session and the noise engine. Failures are logged and
    /// leave station playback working.
    private func startAudioIfNeeded() {
        guard !audioStarted else { return }
        audioStarted = true
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
        } catch {
            soundLog.error("AUDIO SESSION \(error.localizedDescription, privacy: .public)")
        }
        do {
            try noise.start()
        } catch {
            soundLog.error("NOISE ENGINE \(error.localizedDescription, privacy: .public)")
        }
    }

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
