import Testing
@testable import RadioCore

private func close(_ value: Double, _ expected: Double, within tolerance: Double = 1e-9) -> Bool {
    abs(value - expected) <= tolerance
}

@Test func offIsSilent() {
    let m = mix(isLive: false, playing: true, strength: 1, edgeDistance: 1.125)
    #expect(close(m.station, 0))
    #expect(close(m.staticLevel, 0))
    #expect(close(m.whistle, 0))
}

@Test func lockedAndPlaying() {
    let m = mix(isLive: true, playing: true, strength: 1, edgeDistance: 0)
    #expect(close(m.station, 1))
    #expect(close(m.staticLevel, 0.015))
    #expect(close(m.whistle, 0))
}

@Test func connectingIsAllStatic() {
    let m = mix(isLive: true, playing: false, strength: 1, edgeDistance: 0)
    #expect(close(m.station, 0))
    #expect(close(m.staticLevel, 0.255))
}

@Test func halfStrength() {
    let m = mix(isLive: true, playing: true, strength: 0.5, edgeDistance: 0)
    #expect(close(m.station, 0.4061, within: 1e-3))
    #expect(close(m.staticLevel, 0.0942, within: 1e-3))
}

@Test func whistlePeaksMidGap() {
    let m = mix(isLive: true, playing: false, strength: 0, edgeDistance: 1.125)
    #expect(close(m.whistle, 0.012))
}
