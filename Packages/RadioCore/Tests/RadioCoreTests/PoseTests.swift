import Testing
@testable import RadioCore

private func p(_ screen: Screen, _ angle: Double?, landscape: Bool = false,
               status: HingeStatus = .partiallyOpen) -> Pose {
    pose(PoseInput(screen: screen, landscape: landscape, angle: angle, status: angle == nil ? nil : status))
}

@Test func shutBelow20OnEitherScreen() {
    #expect(p(.outer, 0, status: .closed) == .shut)
    #expect(p(.outer, 19.9, status: .closed) == .shut)
    #expect(p(.inner, 19.9) == .shut)
    #expect(p(.inner, 19.9, landscape: true) == .shut)
}

@Test func outerScreenPartlyOpenIsTent() {
    #expect(p(.outer, 20, landscape: true, status: .closed) == .tent)     // status reads closed on the outer screen
    #expect(p(.outer, 71.39, landscape: true, status: .closed) == .tent)
    #expect(p(.outer, 60, landscape: true, status: .partiallyOpen) == .tent)
    #expect(p(.outer, 60, landscape: false, status: .closed) == .tent)    // upright: the same face
}

@Test func innerPortraitIsFlex() {
    #expect(p(.inner, 20) == .flex)
    #expect(p(.inner, 110) == .flex)
    #expect(p(.inner, 174.9) == .flex)
}

@Test func innerLandscapeIsBook() {
    #expect(p(.inner, 110, landscape: true) == .book)
}

@Test func flatFrom175OrFullyOpen() {
    #expect(p(.inner, 175) == .flat)
    #expect(p(.inner, 180, landscape: true, status: .fullyOpen) == .flat)
    #expect(p(.inner, 170, status: .fullyOpen) == .flat)
}

@Test func noHingeIsFlexOrBook() {
    #expect(p(.inner, nil) == .flex)
    #expect(p(.inner, nil, landscape: true) == .book)
}

@Test func oddAnglesAreSafe() {
    #expect(p(.inner, -5) == .shut)
    #expect(p(.inner, 400) == .flat)
    #expect(p(.outer, 400, status: .closed) == .tent)
}

@Test func windowSizesMapToScreens() {
    #expect(windowReading(width: 669, height: 951) == WindowReading(screen: .inner, landscape: false))
    #expect(windowReading(width: 951, height: 669) == WindowReading(screen: .inner, landscape: true))
    #expect(windowReading(width: 466, height: 678) == WindowReading(screen: .outer, landscape: false))
    #expect(windowReading(width: 678, height: 466) == WindowReading(screen: .outer, landscape: true))
    #expect(windowReading(width: 600, height: 600)?.landscape == false)   // square counts as upright
}

@Test func badWindowSizesAreIgnored() {
    #expect(windowReading(width: 0, height: 0) == nil)
    #expect(windowReading(width: -1, height: 500) == nil)
    #expect(windowReading(width: .nan, height: 500) == nil)
    #expect(windowReading(width: .infinity, height: 500) == nil)
}
