import AVFoundation
import Foundation
import Observation
import os
import RadioCore
import UIKit

/// Owns the `Radio` and feeds it the dial position and the pose inputs. Holds no radio rules of its own.
@MainActor @Observable final class RadioModel {
    private(set) var radio: Radio {
        didSet { radioChanged(from: oldValue) }
    }
    /// What the station player last reported. Views never read it: they get `display`, which
    /// goes through `audiblePlayback` like the sound mix does.
    private var reportedPlayback: Playback = .idle {
        didSet { if reportedPlayback != oldValue { updateSound() } }
    }

    /// Which screen the window is on; the inner one until the first window size arrives.
    private(set) var screen: Screen = .inner
    /// Whether the window is wider than tall; false until the first window size arrives.
    private(set) var landscape = false

    @ObservationIgnored private var hingeAngle: Double?
    @ObservationIgnored private var hingeStatus: HingeStatus?
    @ObservationIgnored private var glideTask: Task<Void, Never>?
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
        radio = Radio(file: file)
        player.onPlayback = { [weak self] in self?.reportedPlayback = $0 }
        player.onFailed = { [weak self] in self?.markDead($0.callSign) }
        logMarks()
    }

    var display: Display { radio.display(playback: audible) }
    var city: City? { radio.cities.first { $0.id == radio.cityID } }
    /// The dial position (0...1) last tuned to, before any snap.
    var position: Double { radio.position }

    /// Tunes at once, stopping any glide: a new touch takes over from it.
    func tune(toPosition position: Double) {
        stopGlide()
        step(toPosition: position)
    }

    /// Steps the tuning to `target` along an ease-out over 0.35 s, locking and clicking on each
    /// station it passes. A new touch or a city change stops it where it is.
    func glide(toPosition target: Double) {
        guard !target.isNaN else { return }
        stopGlide()
        let from = radio.position
        let to = min(1, max(0, target))
        glideTask = Task { [weak self] in
            let clock = ContinuousClock()
            let start = clock.now
            while !Task.isCancelled {
                let t = min(1, (clock.now - start) / .seconds(0.35))
                let eased = 1 - pow(1 - t, 3)
                self?.step(toPosition: from + (to - from) * eased)
                if t >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    /// `nil, nil` when the phone has no hinge.
    func hinge(angle: Double?, status: HingeStatus?) {
        hingeAngle = angle
        hingeStatus = status
        updatePose()
    }

    func window(width: Double, height: Double) {
        guard let reading = windowReading(width: width, height: height) else { return }
        screen = reading.screen
        landscape = reading.landscape
        updatePose()
    }

    func togglePower() { radio.togglePower() }

    func selectCity(_ id: String) {
        let before = radio.tuning.locked?.callSign
        stopGlide()
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

    private func step(toPosition position: Double) {
        let before = radio.tuning.locked?.callSign
        radio.tune(toPosition: position)
        logLockChange(from: before)
    }

    private func stopGlide() {
        glideTask?.cancel()
        glideTask = nil
    }

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

    private func updatePose() {
        let before = radio.pose
        radio.setPose(PoseInput(screen: screen, landscape: landscape, angle: hingeAngle, status: hingeStatus))
        if radio.pose != before { log.notice("POSE \(self.radio.pose.rawValue, privacy: .public)") }
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
        let line = after.map { String(format: "LOCK %@ %.3f", $0, radio.position) }
            ?? String(format: "STATIC %.3f", radio.position)
        log.notice("\(line, privacy: .public)")
    }
}
