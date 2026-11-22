import AVFoundation
import Foundation
import Synchronization

/// Static, a tuning whistle and a lock click, on one `AVAudioEngine`:
/// looped noise through a 1.7 kHz band-pass, and a sine that also carries the click.
/// Holds no level rules: levels come from `mix(...)` through `set`.
@MainActor final class NoiseEngine {
    private let engine = AVAudioEngine()
    private let levels = Levels()
    private var built = false

    func start() throws {
        if !built { try build(); built = true }
        guard !engine.isRunning else { return }
        try engine.start()
    }

    func stop() {
        engine.stop()
    }

    func set(staticLevel: Float, whistle: Float, whistleHz: Float) {
        levels.staticLevel.store(staticLevel.bitPattern, ordering: .relaxed)
        levels.whistle.store(whistle.bitPattern, ordering: .relaxed)
        levels.whistleHz.store(whistleHz.bitPattern, ordering: .relaxed)
    }

    func click() {
        levels.clicks.add(1, ordering: .relaxed)
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

        init(rate: Double) {
            self.rate = Float(rate)
            ramp = NoiseEngine.smoothing(seconds: 0.005, rate: rate)
            clickLength = Int(rate * 0.03)
            clickDecay = Float(exp(-1 / (0.006 * rate)))   // falls ~e^-5 over 30 ms
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
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
                }
            }
            return noErr
        }
    }
}
