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
    /// What the station player last reported. Views never read it: they get `display`, which
    /// goes through `audiblePlayback` like the sound mix does.
    private var reportedPlayback: Playback = .idle {
        didSet { if reportedPlayback != oldValue { updateSound() } }
    }

    /// False until a hinge context with a hinge arrives; while false, dragging the dial glass tunes.
    var hasHinge = false
    /// The angle of the reading the radio last received; 110 until the first one arrives.
    private(set) var angle: Double = 110
    /// Whether the reading the radio last received said the hinge itself is closed.
    private(set) var hingeClosed = false
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
    @ObservationIgnored private var sessionConfigured = false
    /// Launch with `-HingeRadioMuted YES` to run silently (for testing). Read once.
    @ObservationIgnored private let muted = UserDefaults.standard.bool(forKey: "HingeRadioMuted")

    init(stationData: Data?) {
        let file: StationFile
        if let stationData {
            do {
                file = try StationFile.load(from: stationData)
            } catch {
                Logger(subsystem: "HingeRadio", category: "stations")
                    .error("STATIONS invalid, showing an empty dial: \(String(describing: error), privacy: .public)")
                file = .empty
            }
        } else {
            Logger(subsystem: "HingeRadio", category: "stations")
                .error("STATIONS missing from the app bundle, showing an empty dial")
            file = .empty
        }
        radio = Radio(file: file, config: Self.dialConfig)
        player.onPlayback = { [weak self] in self?.reportedPlayback = $0 }
        player.onFailed = { [weak self] in self?.markDead($0.callSign) }
        logMarks()
    }

    var config: DialConfig { Self.dialConfig }
    var display: Display { radio.display(playback: audible) }
    var city: City? { radio.cities.first { $0.id == radio.cityID } }
    /// Closed by angle (below 45 degrees) while the hinge itself is not closed: the inner screen
    /// is still lit, so the closed card belongs above the fold rather than across it.
    var closedOnInnerScreen: Bool { radio.isClosed && !hingeClosed }

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

    /// Called with the app's scene phase: while the app is not active the radio is silent,
    /// and on return the station reconnects and the static comes back.
    func appIsActive(_ active: Bool) { radio.setSuspended(!active) }

    // MARK: - Private

    private func radioChanged(from old: Radio) {
        if radio.isLive, !old.isLive { startAudio() }
        let locked = radio.tuning.locked
        if radio.isLive, let locked, locked.callSign != old.tuning.locked?.callSign {
            if !muted { noise.click() }
            haptic.impactOccurred()
        }
        updateSound()
    }

    /// Follows `radio` and the reported playback: the station to connect, and the levels from `mix`.
    private func updateSound() {
        guard radio.isLive else {
            player.stop()
            player.volume = 0
            noise.set(staticLevel: 0, whistle: 0, whistleHz: 0)
            return
        }
        let station = radio.station
        player.want(station)
        let levels = mix(isLive: true,
                         playing: audible == .playing,
                         strength: radio.tuning.strength,
                         edgeDistance: radio.tuning.edgeDistance)
        if muted {
            player.volume = 0
            noise.set(staticLevel: 0, whistle: 0, whistleHz: 0)
            return
        }
        player.volume = Float(levels.station)
        noise.set(staticLevel: Float(levels.staticLevel), whistle: Float(levels.whistle),
                  whistleHz: Float(levels.whistleHz))
    }

    /// What can be heard: the shared rule from RadioCore, for the screen and the mix alike.
    private var audible: Playback {
        audiblePlayback(reported: reportedPlayback, connected: player.connected, wanted: radio.station)
    }

    /// Each time the radio goes live: the `.playback` session (category set once) and the noise
    /// engine, which may have stopped while the app was away. Failures are logged and leave
    /// station playback working.
    private func startAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            if !sessionConfigured {
                try session.setCategory(.playback)
                sessionConfigured = true
            }
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
        hingeClosed = reading.isClosed
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
