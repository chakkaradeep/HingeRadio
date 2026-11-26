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
        didSet { if reportedPlayback != oldValue { updateSound(); countPlay() } }
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
    /// True while a settle moves the needle: the detent pulls in without ticking.
    @ObservationIgnored private var quietTicks = false
    /// The session's move to `.ambient` after switching off, waiting for the off click to ring out.
    @ObservationIgnored private var offSession: Task<Void, Never>?
    /// When the last tick, click or stop sounded, or a finger last came down on a control
    /// (`ProcessInfo.systemUptime`); nil until the first.
    @ObservationIgnored private var lastSound: TimeInterval?
    /// With the radio off: waits until `engineRestDelay` after `lastSound`, then rests the session
    /// and the engine. One at a time; a new sound only moves `lastSound`, which it reads on waking.
    @ObservationIgnored private var restTimer: Task<Void, Never>?
    /// True while a finger is on the tuning wheel.
    @ObservationIgnored private var wheelIsHeld = false
    /// Whether the owner has had a hand on the tuning since HERE's search began: the needle is
    /// then theirs, and does not move when stations arrive.
    @ObservationIgnored private var needleIsTaken = false
    /// True from the app going to the background until it is next active.
    @ObservationIgnored private var wasInBackground = false
    /// The app's phase, last told by `phaseChanged`; with the power, it decides suspension.
    @ObservationIgnored private var phase = AppPhase.inactive
    /// Where the radio was left, kept for next time, and what was last written there.
    @ObservationIgnored private let memory: BandMemory
    @ObservationIgnored private var lastRemembered: Remembered?
    #if HERE
    @ObservationIgnored private lazy var hereSearch = HereSearch(model: self)
    @ObservationIgnored private var playCount = PlayCount()
    /// True from opening on HERE until the app is first active, when its search starts.
    @ObservationIgnored private var searchOnceActive = false
    #endif
    @ObservationIgnored private var sessionObservers: [any NSObjectProtocol] = []
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
        let memory = BandMemory()
        #if HERE
        radio = Radio(file: file, here: true, band: memory.band, position: memory.position)
        #else
        radio = Radio(file: file, band: memory.band, position: memory.position)
        #endif
        self.memory = memory
        lastRemembered = radio.remembered
        log.notice("OPEN \(self.radio.cityID, privacy: .public) \(self.radio.position, format: .fixed(precision: 3))")
        player.onPlayback = { [weak self] in self?.reportedPlayback = $0 }
        player.onFailed = { [weak self] in self?.markDead($0.callSign) }
        logMarks()
        observeSession()
        #if HERE
        // Opening on HERE shows the last place's kept dial at once; the search, and with it any
        // location prompt or sweep, waits until the window is up and the app active.
        if radio.cityID == hereID {
            hereSearch.opened()
            searchOnceActive = true
        }
        #endif
    }

    var display: Display { radio.display(playback: audible) }
    var city: City? { radio.cities.first { $0.id == radio.cityID } }
    /// The dial position (0...1) last tuned to; the needle shows it.
    var position: Double { radio.position }

    /// The fastest the wheels tick: a quick roll sounds like a ratchet, not a buzz.
    static let tickInterval = Duration.milliseconds(33)

    /// Tunes at once, stopping any glide: a new touch takes over from it.
    func tune(toPosition position: Double) {
        stopGlide()
        step(toPosition: position)
    }

    /// Steps the tuning to `target` along an ease-out over `duration` seconds, one step per screen
    /// frame, locking and clicking on each station it passes. A new touch or a city change stops it
    /// where it is. A `quiet` glide (a settle) passes ridges without ticking.
    func glide(toPosition target: Double, duration: Double = 0.35, quiet: Bool = false) {
        guard !target.isNaN else { return }
        stopGlide()
        let from = radio.position
        let to = min(1, max(0, target))
        let start = CACurrentMediaTime()
        frames.run { [weak self] now in
            let t = min(1, max(0, (now - start) / duration))
            let eased = 1 - pow(1 - t, 3)
            self?.step(toPosition: from + (to - from) * eased, quiet: quiet)
            if t >= 1 { self?.rememberDial() }                 // the needle has come to rest
            return t < 1
        }
    }

    /// A finger came down on a wheel or the band switch, or VoiceOver is turning a wheel: with the
    /// radio off, the session and the engine start if they rest, before the first tick is due,
    /// and stay up until `engineRestDelay` after the last sound.
    func wake() {
        heard()
        wakeEngineIfResting()
    }

    /// A finger came down on a wheel: whatever glide is running, or HERE's sweep, stops under it.
    func holdStill() {
        wheelIsHeld = true
        needleIsTaken = true
        stopGlide()
    }

    /// The finger left the tuning wheel, or the system took the touch away. The needle rests
    /// where it is, unless the release set it gliding.
    func letGo() {
        wheelIsHeld = false
        if !frames.isRunning { rememberDial() }
    }

    /// To the next station up or down the band (see `Radio.stepTarget`): a glide, or a jump when
    /// `animated` is false. Nothing past either end.
    func stepStation(up: Bool, animated: Bool) {
        needleIsTaken = true
        endScan()
        guard let target = radio.stepTarget(up: up) else { return }
        if animated {
            glide(toPosition: target)
        } else {
            tune(toPosition: target)
            rememberDial()
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

    /// After a band change: eases the needle onto the locked station's mark over 0.2 s (at once
    /// when `animated` is false), without ticking. With nothing locked the needle stays where it is.
    func settle(animated: Bool) { ease(to: radio.settleTarget, animated: animated) }

    /// After a slow release on the tuning wheel: the same quiet ease, onto the locked station's
    /// mark or onto the station whose name shows in its fade zone (`Radio.releaseTarget`).
    func settleAfterRelease(animated: Bool) { ease(to: radio.releaseTarget, animated: animated) }

    private func ease(to target: Double?, animated: Bool) {
        guard let target, target != radio.position else { return }
        if animated {
            glide(toPosition: target, duration: 0.2, quiet: true)
        } else {
            stopGlide()
            step(toPosition: target, quiet: true)
            rememberDial()
        }
    }

    func togglePower() { changePower { $0.togglePower() } }

    var wheel: Double { radio.wheel }
    func setWheel(_ value: Double) { changePower { $0.setWheel(value) } }

    /// Changes the wheel and, in the same assignment, the suspension that follows from the power
    /// (`shouldSuspend`): switched off in the background the radio is suspended, as an off
    /// background is; switched on there, it plays.
    private func changePower(_ change: (inout Radio) -> Void) {
        var next = radio
        change(&next)
        next.setSuspended(shouldSuspend(phase: phase, powerOn: next.powerOn))
        radio = next
    }

    /// Changes city; if a station of the new city is locked under the needle, the needle then
    /// settles onto its mark (at once when `animated` is false). Choosing HERE starts a search for
    /// its stations; choosing any other band ends it. Choosing HERE again tries its dead stations
    /// again, but leaves its sweep running.
    func selectCity(_ id: String, animated: Bool) {
        if radio.isScanning, id == radio.cityID { return }
        let before = radio.tuning.locked?.callSign
        stopGlide()
        if id != radio.cityID { player.stop() }   // the old city's station goes silent at once
        radio.selectCity(id)
        logMarks()
        logLockChange(from: before)
        settle(animated: animated)
        if !frames.isRunning { rememberDial() }     // else at the settle's end
        #if HERE
        if radio.cityID == hereID { hereSearch.chosen() } else { hereSearch.cancel() }
        #endif
    }

    func markDead(_ callSign: String) { radio.markDead(callSign) }

    /// Called with the app's scene phase. Only the background with the radio off suspends it
    /// (`shouldSuspend`): switched on, it plays on under Control Center, an alert or the location
    /// prompt, with the phone locked and behind another app, and nothing reconnects on return.
    /// Every background ends HERE's search; being inactive does not.
    func phaseChanged(_ phase: AppPhase) {
        self.phase = phase
        if phase == .background { wasInBackground = true }      // first: no wake from here on
        let suspend = shouldSuspend(phase: phase, powerOn: radio.powerOn)
        if suspend != radio.isSuspended { radio.setSuspended(suspend) }
        switch phase {
        case .background: enteredBackground()   // after suspending: a cleared dial is not animated
        case .active: becameActive()
        case .inactive: break
        }
    }

    /// The app is active again. A radio that played on is left alone: the same station, the same
    /// session. With the radio off the noise engine is not started here: it rests until `wake()`
    /// or a feel, unless something sounded within `engineRestDelay`.
    private func becameActive() {
        for haptic in [tickHaptic, clickHaptic, stopHaptic] { haptic.prepare() }
        #if HERE
        if wasInBackground, radio.cityID == hereID { hereSearch.returned() }
        if searchOnceActive {
            searchOnceActive = false
            if radio.cityID == hereID { hereSearch.openedAndActive() }
        }
        #endif
        wasInBackground = false
        if !radio.isLive {                              // going live already started the engine
            if engineMayRest(isLive: false, lastSound: lastSound, now: Self.uptime) {
                restEngine()
            } else {
                wakeEngineIfResting()
                scheduleRest()
            }
        }
    }

    /// The app went to the background, not merely inactive as under a system prompt: HERE's search
    /// ends, whether the radio plays on or not. It starts again on return.
    private func enteredBackground() {
        wasInBackground = true
        rememberDial()                  // before the search ends: a sweep's needle is not kept
        #if HERE
        hereSearch.cancel()
        #endif
    }

    #if HERE
    // MARK: - HERE

    /// A search began: the needle may sweep, and move onto a station at its end, unless a finger
    /// has it or, with the app back from the background, the owner had a hand on it before. Any
    /// sweep of the last search is over.
    func hereSearchBegan(_ start: HerePlan.Start) {
        endScan()
        needleIsTaken = HerePlan.needleIsTaken(on: start, wheelIsHeld: wheelIsHeld, wasTaken: needleIsTaken)
    }

    /// Sweeps the needle over the dial (see `Sweep`) until `stopGlide`, ticking on the way up.
    /// Not with Reduce Motion, which ends a sweep it is switched on in, nor once the owner has had
    /// a hand on the needle.
    func beginScan() {
        guard !needleIsTaken, !UIAccessibility.isReduceMotionEnabled else { return }
        stopGlide()
        radio.setScanning(true)
        log.notice("SCAN \(self.radio.position, format: .fixed(precision: 3))")
        let sweep = Sweep(from: radio.position)
        let start = CACurrentMediaTime()
        frames.run { [weak self] now in
            guard let self, self.radio.isScanning else { return false }
            guard !UIAccessibility.isReduceMotionEnabled else {
                self.endScan()
                return false
            }
            let next = sweep.step(at: now - start)
            self.step(toPosition: next.position, quiet: next.isReturning || self.radio.isSuspended)
            return true
        }
    }

    func setHere(status: HereStatus) {
        guard status != radio.hereStatus else { return }
        radio.setHere(status: status)
        log.notice("HERE \(String(describing: status), privacy: .public)")
    }

    /// HERE's stations, in frequency order, and its name (nil keeps it).
    func setHereStations(_ stations: [Station], town: String?) {
        let before = radio.tuning.locked?.callSign
        let marks = radio.scale.marks
        radio.setHereStations(stations, town: town)
        if radio.scale.marks != marks { logMarks() }
        logLockChange(from: before)
    }

    /// Eases the needle onto a station (`Radio.arrivalTarget`), unless the owner has a hand on it.
    func arriveOnStation() {
        guard !needleIsTaken else { return }
        ease(to: radio.arrivalTarget, animated: !UIAccessibility.isReduceMotionEnabled)
    }
    #endif

    /// Ends HERE's sweep, if it is running; a glide is left alone.
    func endScan() {
        if radio.isScanning { stopGlide() }
    }

    // MARK: - Private

    /// Keeps the band and the needle for next time, when they have changed; never while HERE's
    /// sweep moves the needle (`Radio.remembered`). Called only where the needle comes to rest.
    private func rememberDial() {
        guard let remembered = radio.remembered, remembered != lastRemembered else { return }
        memory.keep(remembered)
        lastRemembered = remembered
        log.notice("REMEMBER \(remembered.band, privacy: .public) \(remembered.position, format: .fixed(precision: 3))")
    }

    /// Tells Radio Browser when a station of HERE's that it listed starts playing (see `PlayCount`).
    private func countPlay() {
        #if HERE
        guard let id = playCount.report(reportedPlayback, of: player.connected, onHere: radio.cityID == hereID)
        else { return }
        hereSearch.played(radioBrowserID: id)
        #endif
    }

    private func step(toPosition position: Double, quiet: Bool = false) {
        let before = radio.tuning.locked?.callSign
        quietTicks = quiet
        radio.tune(toPosition: position)
        quietTicks = false
        logLockChange(from: before)
    }

    /// The one place a sweep ends: `isScanning` is on only while its frames run, and every move of
    /// the needle stops them here first.
    private func stopGlide() {
        frames.stop()
        guard radio.isScanning else { return }
        radio.setScanning(false)
        log.notice("SCAN END \(self.radio.position, format: .fixed(precision: 3))")
        logLockChange(from: nil)
    }

    private func radioChanged(from old: Radio) {
        if radio.isLive, !old.isLive {
            offSession?.cancel()
            restTimer?.cancel()
            restTimer = nil
            if !noise.isStarted { soundLog.notice("ENGINE WAKE") }
            startAudio(live: true)                  // before the click, so the click is not cut
        }
        if let feel = RadioCore.feel(from: old, to: radio), !(quietTicks && feel.isTick) {
            play(feel)
        }
        updateSound()
        if old.isLive, !radio.isLive, !radio.isSuspended { returnToAmbient() }
        if radio.isSuspended, !old.isSuspended { restNow() }
    }

    // MARK: - Feel

    /// Plays one feel (decided by `RadioCore.feel`) and its haptic. A tick within `tickInterval`
    /// of the last tick, click or stop is dropped, so a fast roll is a ratchet and a click is never
    /// blurred by a tick on its heels.
    private func play(_ feel: Feel) {
        let now = ContinuousClock.now
        let name = switch feel {
        case .bandClick: "click band"
        case .powerClick: radio.powerOn ? "click on" : "click off"
        case .lockClick(let callSign): "click lock \(callSign)"
        case .tuningStop: "stop tuning"
        case .volumeStop: "stop volume"
        case .tuningTick: "tick tuning"
        case .volumeTick: "tick volume"
        }
        switch feel {
        case .tuningTick, .volumeTick:
            guard now - lastTick >= Self.tickInterval else { return }
            lastTick = now
            let soft = feel == .volumeTick
            sound { $0.tick(level: soft ? 0.5 : 1) }
            tickHaptic.impactOccurred(intensity: soft ? 0.4 : 0.7)
            tickHaptic.prepare()
            feelLog.info("FEEL \(name, privacy: .public)")
        case .tuningStop, .volumeStop:
            lastTick = now
            sound { $0.tick(level: 1.8) }
            stopHaptic.impactOccurred(intensity: 0.9)
            stopHaptic.prepare()
            feelLog.notice("FEEL \(name, privacy: .public)")
        case .bandClick, .powerClick, .lockClick:
            lastTick = now
            sound { $0.click() }
            clickHaptic.impactOccurred()
            clickHaptic.prepare()
            feelLog.notice("FEEL \(name, privacy: .public)")
        }
    }

    /// Sounds one feel on the noise engine (unless muted), first waking the engine if it rests:
    /// that first sound may come late or be lost, never more. Keeps the engine up for
    /// `engineRestDelay` after it.
    private func sound(_ make: (NoiseEngine) -> Void) {
        heard()
        guard !muted else { return }
        wakeEngineIfResting()
        make(noise)
    }

    // MARK: - Engine rest

    private static var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Something sounded, or a finger came down on a control: with the radio off, the engine rests
    /// `engineRestDelay` after the last such moment.
    private func heard() {
        lastSound = Self.uptime
        if !radio.isLive { scheduleRest() }
    }

    /// With the radio off and the app not in the background: starts the `.ambient` session and the
    /// engine if they were rested (`!noise.isStarted`). A wake that fails leaves `isStarted` set, so
    /// it is not tried again on every tick; the rest timer rests it and the next touch tries again.
    /// Going live has its own path (`startAudio(live: true)`).
    private func wakeEngineIfResting() {
        guard !radio.isLive, !wasInBackground, !noise.isStarted else { return }
        soundLog.notice("ENGINE WAKE")
        startAudio(live: false)
    }

    /// Starts the rest timer unless it is already waiting; it reads `lastSound` each time it wakes.
    private func scheduleRest() {
        guard restTimer == nil else { return }
        restTimer = Task { [weak self] in
            while !Task.isCancelled, let wait = self?.restOrWait() {
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    /// Rests the engine if `engineMayRest` says so and ends the timer; otherwise the seconds left
    /// to wait. Nil, ending the timer, once the radio is live.
    private func restOrWait() -> TimeInterval? {
        let now = Self.uptime
        guard !radio.isLive else {
            restTimer = nil
            return nil
        }
        guard engineMayRest(isLive: false, lastSound: lastSound, now: now) else {
            return (lastSound ?? now) + engineRestDelay - now
        }
        restTimer = nil
        restEngine()
        return nil
    }

    /// Suspended (off in the background, gone there or switched off there): the engine and the
    /// session rest at once, without waiting `engineRestDelay`, and with no move to `.ambient`
    /// first: nothing there can be heard, and nothing wakes them until the app is active again.
    private func restNow() {
        offSession?.cancel()
        restTimer?.cancel()
        restTimer = nil
        restEngine()
    }

    /// With the radio off: stops the engine and lets the session go with notify-others, so other
    /// apps' audio may resume. Does nothing if the engine is already at rest.
    private func restEngine() {
        guard !radio.isLive, noise.isStarted || noise.isRunning else { return }
        noise.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            soundLog.error("AUDIO SESSION release \(error.localizedDescription, privacy: .public)")
        }
        soundLog.notice("ENGINE REST")
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

    /// Each time the radio goes live, and with it off each time the engine wakes from rest or the
    /// off click has rung out: the session and the noise engine. Live, the
    /// session is `.playback`; off, it is `.ambient`, so the wheels' ticks mix with other apps'
    /// sound rather than stopping it. When the category changes the engine is stopped around the
    /// change and started again, so no output runs across it. Going off, the session is first let
    /// go with notify-others, so audio the radio interrupted may resume. Failures are logged and
    /// leave station playback working.
    private func startAudio(live: Bool, force: Bool = false) {
        let session = AVAudioSession.sharedInstance()
        let category: AVAudioSession.Category = live ? .playback : .ambient
        if force || session.category != category {
            noise.stop()
            if !live {
                do {
                    try session.setActive(false, options: .notifyOthersOnDeactivation)
                } catch {
                    soundLog.error("AUDIO SESSION release \(error.localizedDescription, privacy: .public)")
                }
            }
            do {
                try session.setCategory(category)
                soundLog.notice("SESSION \(live ? "playback" : "ambient", privacy: .public)")
            } catch {
                soundLog.error("AUDIO SESSION category \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
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

    /// After switching off: once the off click has rung out, back to the `.ambient` session; the
    /// engine then rests `engineRestDelay` after the last sound.
    private func returnToAmbient() {
        offSession?.cancel()
        offSession = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, !Task.isCancelled, !self.radio.isLive, !self.radio.isSuspended else { return }
            self.startAudio(live: false)
            self.scheduleRest()
        }
    }

    /// An interruption (a call, an alarm, Siri) makes the session inactive and stops the engine;
    /// when the system recommends resuming, unless the radio is suspended, the session and the
    /// engine come back. A media services reset loses both, so the noise graph is built anew and
    /// the session set up again. The old route going away (headphones unplugged) switches the
    /// radio off.
    private func observeSession() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        sessionObservers.append(center.addObserver(
            forName: AVAudioSession.didBecomeInactiveNotification, object: session, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.soundLog.notice("SESSION inactive") }
        })
        sessionObservers.append(center.addObserver(
            forName: AVAudioSession.resumptionRecommendationNotification, object: session, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.interruptionEnded() }
        })
        sessionObservers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.mediaServicesReset() }
        })
        sessionObservers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
        ) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            MainActor.assumeIsolated { self?.routeChanged(reason) }
        })
    }

    /// The headphones the radio played through went away: it switches off rather than carry on out
    /// loud, as music apps pause. The volume is kept for next time; in the background, switching
    /// off suspends it (`changePower`).
    private func routeChanged(_ reason: AVAudioSession.RouteChangeReason?) {
        guard reason == .oldDeviceUnavailable, radio.isLive else { return }
        soundLog.notice("ROUTE gone")
        togglePower()
    }

    /// The system says an interruption is over: unless the radio is suspended (off in the
    /// background), the session and the engine come back so the wheels tick again and the static
    /// returns; switched on, that is in the background too.
    /// A resting engine (radio off) stays at rest: the next touch wakes it.
    private func interruptionEnded() {
        soundLog.notice("AUDIO RESUME")
        guard !radio.isSuspended else { return }
        if radio.isLive || noise.isStarted {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try noise.restartIfStopped()
            } catch {
                soundLog.error("AUDIO RESUME \(error.localizedDescription, privacy: .public)")
            }
        }
        updateSound()
    }

    private func mediaServicesReset() {
        soundLog.notice("AUDIO RESET")
        let wasAwake = noise.isStarted
        noise.rebuild()
        guard !radio.isSuspended, radio.isLive || wasAwake else { return }   // a resting engine stays at rest
        startAudio(live: radio.isLive, force: true)
        if !radio.isLive { scheduleRest() }
        updateSound()
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

    /// Nothing while the needle sweeps: it locks onto no station.
    private func logLockChange(from before: String?) {
        guard !radio.isScanning else { return }
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

    /// Whether a body is running.
    var isRunning: Bool { link != nil }

    func stop() {
        link?.invalidate()
        link = nil
        body = nil
    }

    @objc private func frame(_ link: CADisplayLink) {
        if body?(link.targetTimestamp) != true { stop() }
    }
}
