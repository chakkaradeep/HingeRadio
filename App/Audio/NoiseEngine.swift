import AVFoundation
import Foundation
import Synchronization

/// Static, a tuning whistle, a lock click and the wheels' ticks, on one `AVAudioEngine`:
/// looped noise through a 1.7 kHz band-pass, and a sine that also carries the click and the ticks.
/// Holds no level rules: levels come from `mix(...)` through `set`.
///
/// It runs while the radio is live. With the radio off it runs only from a touch on a control
/// (or a feel) until `engineRestDelay` after the last sound, so the wheels tick while switched
/// off; then `RadioModel` stops it, and it rests until the next touch or power-on.
@MainActor final class NoiseEngine {
    private var engine = AVAudioEngine()
    private let levels = Levels()
    private var built = false
    private var configurationObserver: (any NSObjectProtocol)?
    /// Whether the engine is meant to run: from `start()` until `stop()`. An interruption or a
    /// route change that stops the engine leaves it true, so `restartIfStopped()` brings the
    /// engine back; a resting engine is not started again by those.
    private(set) var isStarted = false

    /// Whether the engine is rendering now.
    var isRunning: Bool { engine.isRunning }

    /// Safe to call every time the radio goes live: does nothing while the engine is running.
    func start() throws {
        if !built { try build(); built = true }
        isStarted = true
        guard !engine.isRunning else { return }
        try engine.start()
    }

    func set(staticLevel: Float, whistle: Float, whistleHz: Float) {
        levels.staticLevel.store(staticLevel.bitPattern, ordering: .relaxed)
        levels.whistle.store(whistle.bitPattern, ordering: .relaxed)
        levels.whistleHz.store(whistleHz.bitPattern, ordering: .relaxed)
    }

    func click() {
        levels.clicks.add(1, ordering: .relaxed)
    }

    /// A short, dry tick, quieter than `click()`: `level` 1 is a ridge on the tuning wheel, lower
    /// is softer (the volume wheel), higher is the firmer stop at the end of a wheel's travel.
    func tick(level: Float = 1) {
        levels.tickLevel.store(min(2, max(0, level)).bitPattern, ordering: .relaxed)
        levels.ticks.add(1, ordering: .relaxed)
    }

    /// Stops the engine, so no audio runs while the session changes, or to rest it. `start()`
    /// resumes it. Safe to repeat. A tick or click asked for while stopped waits in its counter
    /// and sounds when the engine next starts, or not at all; it never fails.
    func stop() {
        isStarted = false
        if engine.isRunning { engine.stop() }
    }

    /// After a media services reset the old engine is gone: the next `start()` builds a new one.
    func rebuild() {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
        engine = AVAudioEngine()
        built = false
        isStarted = false
    }

    /// After the audio route or session changes the engine may have stopped: start it again,
    /// unless it was stopped on purpose (`stop()`). Safe to call at any time; failures are
    /// thrown, as from `start()`.
    func restartIfStopped() throws {
        guard built, isStarted, !engine.isRunning else { return }
        try engine.start()
    }

    // MARK: - Graph

    private func build() throws {
        let hardwareRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let rate = hardwareRate > 0 ? hardwareRate : 44_100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else {
            throw CocoaError(.featureUnsupported)
        }

        let noise = AVAudioSourceNode(format: format, renderBlock: Self.noiseBlock(NoiseState(rate: rate), levels))
        let tone = AVAudioSourceNode(format: format, renderBlock: Self.toneBlock(ToneState(rate: rate), levels))

        let bandPass = AVAudioUnitEQ(numberOfBands: 1)
        let band = bandPass.bands[0]
        band.filterType = .bandPass
        band.frequency = 1_700
        band.bandwidth = 2.5          // octaves; about Q 0.5, as in the reference
        band.bypass = false

        for node in [noise, tone, bandPass] as [AVAudioNode] { engine.attach(node) }
        try engine.connectNode(noise, to: bandPass, format: format)
        try engine.connectNode(bandPass, to: engine.mainMixerNode, format: format)
        try engine.connectNode(tone, to: engine.mainMixerNode, format: format)
        engine.prepare()
        // A route or session change stops the engine; start it again so ticks keep sounding.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { try? self?.restartIfStopped() }
        }
    }

    // MARK: - Audio thread
    //
    // The blocks below run on the render thread. They read levels from atomics, keep their own
    // state in preallocated storage touched only by that thread, and never allocate, lock or log.
    // They are built in nonisolated static functions so they carry no main-actor isolation.

    /// Targets written by the main actor, read by the render thread. Floats stored as bit patterns.
    private final class Levels: Sendable {
        let staticLevel = Atomic<UInt32>(0)
        let whistle = Atomic<UInt32>(0)
        let whistleHz = Atomic<UInt32>(Float(180).bitPattern)
        let clicks = Atomic<UInt32>(0)
        let ticks = Atomic<UInt32>(0)
        let tickLevel = Atomic<UInt32>(Float(1).bitPattern)
    }

    /// One-pole smoothing coefficient reaching ~63 % of a change in `seconds`.
    private nonisolated static func smoothing(seconds: Double, rate: Double) -> Float {
        Float(1 - exp(-1 / (seconds * rate)))
    }

    private final class NoiseState: @unchecked Sendable {   // render thread only
        let samples: UnsafeMutablePointer<Float>
        let count: Int
        var index = 0
        var gain: Float = 0
        let ramp: Float

        init(rate: Double) {
            count = Int(rate * 2)
            samples = .allocate(capacity: count)
            for i in 0..<count { samples[i] = Float.random(in: -1...1) }
            ramp = NoiseEngine.smoothing(seconds: 0.005, rate: rate)
        }
        deinit { samples.deallocate() }
    }

    private final class ToneState: @unchecked Sendable {    // render thread only
        let rate: Float
        let ramp: Float
        var phase: Float = 0
        var gain: Float = 0
        var hz: Float = 180
        var seenClicks: UInt32 = 0
        var clickLeft = 0
        let clickLength: Int
        let clickDecay: Float
        var clickEnvelope: Float = 0
        var clickNoise: UInt32 = 0x1234_5678
        // The tick: a 2.9 kHz ping (the pawl on a ridge) and a burst of high-passed noise, both
        // gone within 12 ms, so it reads as dry plastic rather than a beep.
        var seenTicks: UInt32 = 0
        var tickLeft = 0
        let tickLength: Int
        let tickDecay: Float
        var tickEnvelope: Float = 0
        var tickPhase: Float = 0
        var tickPreviousNoise: Float = 0
        let tickStep: Float

        init(rate: Double) {
            self.rate = Float(rate)
            ramp = NoiseEngine.smoothing(seconds: 0.005, rate: rate)
            clickLength = Int(rate * 0.03)
            clickDecay = Float(exp(-1 / (0.006 * rate)))   // falls ~e^-5 over 30 ms
            tickLength = Int(rate * 0.012)
            tickDecay = Float(exp(-1 / (0.0018 * rate)))   // falls ~e^-6.7 over 12 ms
            tickStep = Float(2 * Double.pi * 2_900 / rate)
        }
    }

    private nonisolated static func noiseBlock(_ state: NoiseState, _ levels: Levels) -> AVAudioSourceNodeRenderBlock {
        { _, _, frameCount, bufferList in
            let target = Float(bitPattern: levels.staticLevel.load(ordering: .relaxed))
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            for frame in 0..<Int(frameCount) {
                state.gain += (target - state.gain) * state.ramp
                let value = state.samples[state.index] * state.gain
                state.index += 1
                if state.index == state.count { state.index = 0 }
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
                }
            }
            return noErr
        }
    }

    private nonisolated static func toneBlock(_ state: ToneState, _ levels: Levels) -> AVAudioSourceNodeRenderBlock {
        { _, _, frameCount, bufferList in
            let targetGain = Float(bitPattern: levels.whistle.load(ordering: .relaxed))
            let targetHz = Float(bitPattern: levels.whistleHz.load(ordering: .relaxed))
            let clicks = levels.clicks.load(ordering: .relaxed)
            if clicks != state.seenClicks {
                state.seenClicks = clicks
                state.clickLeft = state.clickLength
                state.clickEnvelope = 0.05
            }
            let ticks = levels.ticks.load(ordering: .relaxed)
            if ticks != state.seenTicks {
                state.seenTicks = ticks
                state.tickLeft = state.tickLength
                state.tickEnvelope = 0.016 * Float(bitPattern: levels.tickLevel.load(ordering: .relaxed))
                state.tickPhase = 0
            }
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            let twoPi = 2 * Float.pi
            for frame in 0..<Int(frameCount) {
                state.gain += (targetGain - state.gain) * state.ramp
                state.hz += (targetHz - state.hz) * state.ramp
                state.phase += twoPi * state.hz / state.rate
                if state.phase >= twoPi { state.phase -= twoPi }
                var value = sin(state.phase) * state.gain
                if state.clickLeft > 0 {
                    state.clickNoise = state.clickNoise &* 1_664_525 &+ 1_013_904_223
                    let white = Float(Int32(bitPattern: state.clickNoise)) / Float(Int32.max)
                    value += white * state.clickEnvelope
                    state.clickEnvelope *= state.clickDecay
                    state.clickLeft -= 1
                }
                if state.tickLeft > 0 {
                    state.clickNoise = state.clickNoise &* 1_664_525 &+ 1_013_904_223
                    let white = Float(Int32(bitPattern: state.clickNoise)) / Float(Int32.max)
                    let edge = white - state.tickPreviousNoise          // a first difference: high-passed
                    state.tickPreviousNoise = white
                    state.tickPhase += state.tickStep
                    if state.tickPhase >= twoPi { state.tickPhase -= twoPi }
                    value += (0.6 * sin(state.tickPhase) + 0.4 * edge) * state.tickEnvelope
                    state.tickEnvelope *= state.tickDecay
                    state.tickLeft -= 1
                }
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
                }
            }
            return noErr
        }
    }
}
