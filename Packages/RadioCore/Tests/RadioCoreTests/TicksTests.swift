import Testing
@testable import RadioCore

@Test func ticksNoMove() {
    #expect(ticksCrossed(from: 0.3, to: 0.3, step: 0.1) == 0)
}

@Test func ticksInsideOneStep() {
    #expect(ticksCrossed(from: 0.31, to: 0.39, step: 0.1) == 0)
    #expect(ticksCrossed(from: 0.39, to: 0.31, step: 0.1) == 0)
}

@Test func ticksOntoABoundary() {
    #expect(ticksCrossed(from: 0.25, to: 0.5, step: 0.25) == 1)        // landing on one counts it
    #expect(ticksCrossed(from: 0.5, to: 0.6, step: 0.25) == 0)         // leaving it upward does not again
    #expect(ticksCrossed(from: 0.5, to: 0.25, step: 0.25) == 1)        // reaching the next one down does
}

@Test func ticksAcrossThreeSteps() {
    #expect(ticksCrossed(from: 0.05, to: 0.35, step: 0.1) == 3)
    #expect(ticksCrossed(from: 0, to: 1, step: 1.0 / 160) == 160)
}

@Test func ticksBackwards() {
    #expect(ticksCrossed(from: 0.35, to: 0.05, step: 0.1) == 3)
}

@Test func ticksBadInputs() {
    #expect(ticksCrossed(from: .nan, to: 0.5, step: 0.1) == 0)
    #expect(ticksCrossed(from: 0.1, to: .nan, step: 0.1) == 0)
    #expect(ticksCrossed(from: 0.1, to: 0.5, step: .nan) == 0)
    #expect(ticksCrossed(from: 0.1, to: 0.5, step: 0) == 0)
    #expect(ticksCrossed(from: 0.1, to: 0.5, step: -0.1) == 0)
    #expect(ticksCrossed(from: 0.1, to: .infinity, step: 0.1) == 0)
}
