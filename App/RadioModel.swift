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
    @ObservationIgnored private let frames = FrameClock()
    @ObservationIgnored private let log = Logger(subsystem: "HingeRadio", category: "dial")
    @ObservationIgnored private let soundLog = Logger(subsystem: "HingeRadio", category: "sound")
    @ObservationIgnored private let player = StationPlayer()
    @ObservationIgnored private let noise = NoiseEngine()
    @ObservationIgnored private let feelLog = Logger(subsystem: "HingeRadio", category: "feel")
    @ObservationIgnored private let tickHaptic = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private let clickHaptic = UIImpactFeedbackGenerator(style: .rigid)
    @ObservationIgnored private let stopHaptic = UIImpactFeedbackGenerator(style: .medium)
    @ObservationIgnored private var lastTick = ContinuousClock.now - .seconds(1)
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
    /// The dial position (0...1) last tuned to; the needle shows it.
    var position: Double { radio.position }

    /// One ridge on the tuning wheel: 1/160 of the band, about 0.13 MHz.
    static let tuningRidge = 1.0 / 160
    /// One soft step of the volume wheel while it is on.
    static let volumeRidge = 0.05
    /// The fastest the wheels tick: a quick roll sounds like a ratchet, not a buzz.
    static let tickInterval = Duration.milliseconds(33)

    /// Tunes at once, stopping any glide: a new touch takes over from it.
    func tune(toPosition position: Double) {
        stopGlide()
        step(toPosition: position)
    }

    /// Steps the tuning to `target` along an ease-out over `duration` seconds, one step per screen
    /// frame, locking and clicking on each station it passes. A new touch or a city change stops it
    /// where it is.
    func glide(toPosition target: Double, duration: Double = 0.35) {
        guard !target.isNaN else { return }
        stopGlide()
        let from = radio.position
        let to = min(1, max(0, target))
        let start = CACurrentMediaTime()
        frames.run { [weak self] now in
            let t = min(1, max(0, (now - start) / duration))
            let eased = 1 - pow(1 - t, 3)
            self?.step(toPosition: from + (to - from) * eased)
            return t < 1
        }
    }

    /// `nil, nil` when the phone has no hinge.
    func hinge(angle: Double?, status: HingeStatus?) {
        guard !(angle?.isNaN ?? false) else { return }     // never store a not-a-number angle
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

    /// After a slow release: eases the needle onto the locked station's mark over 0.2 s (at once
    /// when `animated` is false). With nothing locked the needle stays where it is.
    func settle(animated: Bool) {
        guard let target = radio.settleTarget else { return }
        if animated { glide(toPosition: target, duration: 0.2) } else { tune(toPosition: target) }
    }

    func togglePower() { radio.togglePower() }

    var wheel: Double { radio.wheel }
    func setWheel(_ value: Double) { radio.setWheel(value) }

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
    /// While active the noise engine runs even with the radio off, so the wheels tick.
    func appIsActive(_ active: Bool) {
        radio.setSuspended(!active)
        guard active else { return }
        if !radio.isLive { startAudio() }          // going live already started it
        for haptic in [tickHaptic, clickHaptic, stopHaptic] { haptic.prepare() }
    }

    // MARK: - Private

    private func step(toPosition position: Double) {
        let before = radio.tuning.locked?.callSign
        radio.tune(toPosition: position)
        logLockChange(from: before)
    }

    private func stopGlide() { frames.stop() }

    private func radioChanged(from old: Radio) {
        if radio.isLive, !old.isLive { startAudio() }
        feel(from: old)
        updateSound()
    }

    // MARK: - Feel

    private enum Feel { case tuningTick, volumeTick, stop, click }

    /// The one place that decides the clicks, stops and ticks, each a sound with its haptic.
    /// Every change gives at most one, the firmest that applies: a new city, power or a new lock
    /// clicks; reaching the end of a wheel's travel stops; passing a ridge ticks. They work with the
    /// radio off too: the wheels are mechanical.
    private func feel(from old: Radio) {
        if radio.cityID != old.cityID { return fire(.click, "click band") }
        if radio.powerOn != old.powerOn { return fire(.click, radio.powerOn ? "click on" : "click off") }
        if let locked = radio.tuning.locked?.callSign, locked != old.tuning.locked?.callSign {
            return fire(.click, "click lock \(locked)")
        }
        let tuningEnd = radio.position != old.position && (radio.position == 0 || radio.position == 1)
        let volumeEnd = radio.wheel != old.wheel && (radio.wheel == 0 || radio.wheel == 1)
        if tuningEnd || volumeEnd { return fire(.stop, tuningEnd ? "stop tuning" : "stop volume") }
        if ticksCrossed(from: old.position, to: radio.position, step: Self.tuningRidge) > 0 {
            return fire(.tuningTick, "tick tuning")
        }
        if radio.powerOn, old.powerOn, ticksCrossed(from: old.wheel, to: radio.wheel, step: Self.volumeRidge) > 0 {
            fire(.volumeTick, "tick volume")
        }
    }

    /// Plays one feel and its haptic. A tick within `tickInterval` of the last tick, click or stop
    /// is dropped, so a fast roll is a ratchet and a click is never blurred by a tick on its heels.
    private func fire(_ feel: Feel, _ name: String) {
        let now = ContinuousClock.now
        switch feel {
        case .tuningTick, .volumeTick:
            guard now - lastTick >= Self.tickInterval else { return }
            lastTick = now
            let soft = feel == .volumeTick
            if !muted { noise.tick(level: soft ? 0.5 : 1) }
            tickHaptic.impactOccurred(intensity: soft ? 0.4 : 0.7)
            tickHaptic.prepare()
            feelLog.info("FEEL \(name, privacy: .public)")
        case .stop:
            lastTick = now
            if !muted { noise.tick(level: 1.8) }
            stopHaptic.impactOccurred(intensity: 0.9)
            stopHaptic.prepare()
            feelLog.notice("FEEL \(name, privacy: .public)")
        case .click:
            lastTick = now
            if !muted { noise.click() }
            clickHaptic.impactOccurred()
            clickHaptic.prepare()
            feelLog.notice("FEEL \(name, privacy: .public)")
        }
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
        let loudness = radio.loudness
        let levels = mix(isLive: true,
                         playing: audible == .playing,
                         strength: radio.tuning.strength,
                         edgeDistance: radio.tuning.edgeDistance)
        if muted {
            player.volume = 0
            noise.set(staticLevel: 0, whistle: 0, whistleHz: 0)
            return
        }
        player.volume = Float(levels.station * loudness)
        noise.set(staticLevel: Float(levels.staticLevel * loudness), whistle: Float(levels.whistle * loudness),
                  whistleHz: Float(levels.whistleHz))
    }

    /// What can be heard: the shared rule from RadioCore, for the screen and the mix alike.
    private var audible: Playback {
        audiblePlayback(reported: reportedPlayback, connected: player.connected, wanted: radio.station)
    }

    /// Each time the radio goes live, and each time the app becomes active: the session and the
    /// noise engine, which may have stopped while the app was away. Live, the session is
    /// `.playback`; off, it is `.ambient`, so the wheels' ticks mix with other apps' sound rather
    /// than stopping it. Failures are logged and leave station playback working.
    private func startAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            let category: AVAudioSession.Category = radio.isLive ? .playback : .ambient
            if session.category != category { try session.setCategory(category) }
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

    /// Assigns `radio` only when the pose changes, so the many hinge callbacks of a fold do not
    /// invalidate every view.
    private func updatePose() {
        var next = radio
        next.setPose(PoseInput(screen: screen, landscape: landscape, angle: hingeAngle, status: hingeStatus))
        guard next.pose != radio.pose else { return }
        radio = next
        log.notice("POSE \(self.radio.pose.rawValue, privacy: .public)")
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

/// Calls a closure once per screen frame, up to 120 a second, until it returns false or `stop()`.
@MainActor private final class FrameClock: NSObject {
    private var link: CADisplayLink?
    private var body: ((CFTimeInterval) -> Bool)?

    /// `body` gets the time the coming frame will show, in `CACurrentMediaTime()` seconds.
    func run(_ body: @escaping (CFTimeInterval) -> Bool) {
        stop()
        self.body = body
        let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        body = nil
    }

    @objc private func frame(_ link: CADisplayLink) {
        if body?(link.targetTimestamp) != true { stop() }
    }
}
