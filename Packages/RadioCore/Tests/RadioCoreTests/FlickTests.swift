import Testing
@testable import RadioCore

@Test func slowReleaseStaysPut() {
    #expect(flickTarget(from: 0.40, predicted: 0.42, marks: [0.2, 0.5, 0.8]) == 0.40)
}

@Test func flickSettlesOnNearestMarkToPredictedEnd() {
    #expect(flickTarget(from: 0.20, predicted: 0.55, marks: [0.2, 0.5, 0.8]) == 0.5)
    #expect(flickTarget(from: 0.80, predicted: 0.30, marks: [0.2, 0.5, 0.8]) == 0.2)
}

@Test func flickPastTheEndsSettlesOnTheEndStation() {
    #expect(flickTarget(from: 0.5, predicted: 3.0, marks: [0.2, 0.5, 0.8]) == 0.8)
    #expect(flickTarget(from: 0.5, predicted: -3.0, marks: [0.2, 0.5, 0.8]) == 0.2)
}

@Test func flickWithNoMarksClamps() {
    #expect(flickTarget(from: 0.5, predicted: 3.0, marks: []) == 1)
    #expect(flickTarget(from: 0.5, predicted: -3.0, marks: []) == 0)
}

@Test func notANumberStaysPut() {
    #expect(flickTarget(from: 0.5, predicted: .nan, marks: [0.2]) == 0.5)
}
