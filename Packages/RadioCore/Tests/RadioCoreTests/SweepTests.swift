import Testing
@testable import RadioCore

private func close(_ value: Double, _ expected: Double) -> Bool { abs(value - expected) < 1e-9 }

@Test func aSweepGoesUpTheDialInOneLap() {
    let sweep = Sweep(from: 0)
    #expect(close(sweep.step(at: 0).position, 0))
    #expect(close(sweep.step(at: Sweep.lap / 4).position, 0.25))
    #expect(close(sweep.step(at: Sweep.lap * 0.75).position, 0.75))
    #expect(!sweep.step(at: Sweep.lap * 0.75).isReturning)
}

@Test func aSweepFirstReturnsToTheBottomFromWhereTheNeedleIs() {
    let sweep = Sweep(from: 0.5)
    let first = sweep.step(at: 0)
    #expect(close(first.position, 0.5))
    #expect(first.isReturning)
    let halfway = sweep.step(at: Sweep.returnTime / 4)               // half the dial takes half the time
    #expect(close(halfway.position, 0.25))
    let bottom = sweep.step(at: Sweep.returnTime / 2)
    #expect(close(bottom.position, 0))
    #expect(!bottom.isReturning)
    #expect(close(sweep.step(at: Sweep.returnTime / 2 + Sweep.lap / 2).position, 0.5))
}

@Test func aSweepReturnsAndGoesUpAgain() {
    let sweep = Sweep(from: 0)
    let top = sweep.step(at: Sweep.lap)
    #expect(close(top.position, 1))
    #expect(top.isReturning)
    let halfway = sweep.step(at: Sweep.lap + Sweep.returnTime / 2)
    #expect(close(halfway.position, 0.5))
    #expect(halfway.isReturning)
    let second = sweep.step(at: 2 * (Sweep.lap + Sweep.returnTime) + Sweep.lap / 2)
    #expect(close(second.position, 0.5))
    #expect(!second.isReturning)
}

@Test func aSweepNeverLeavesTheDialOrJumps() {
    let sweep = Sweep(from: 0.7)
    let frame = 1.0 / 120
    var last = sweep.step(at: 0).position
    for tick in 1...2400 {
        let position = sweep.step(at: Double(tick) * frame).position
        #expect((0...1).contains(position))
        #expect(abs(position - last) < 0.04)
        last = position
    }
}

@Test func aSweepAskedBeforeItBeganIsWhereItBegan() {
    #expect(close(Sweep(from: 0.4).step(at: -1).position, 0.4))
    #expect(close(Sweep(from: 0).step(at: -1).position, 0))
}
