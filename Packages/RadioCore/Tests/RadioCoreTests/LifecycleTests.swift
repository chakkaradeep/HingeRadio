import Testing
@testable import RadioCore

@Test func activeNeverSuspends() {
    #expect(!shouldSuspend(phase: .active, powerOn: true))
    #expect(!shouldSuspend(phase: .active, powerOn: false))
}

/// Control Center, an alert or the location prompt makes the app inactive: the radio plays on.
@Test func inactiveNeverSuspends() {
    #expect(!shouldSuspend(phase: .inactive, powerOn: true))
    #expect(!shouldSuspend(phase: .inactive, powerOn: false))
}

@Test func backgroundSuspendsOnlyWithThePowerOff() {
    #expect(!shouldSuspend(phase: .background, powerOn: true))
    #expect(shouldSuspend(phase: .background, powerOn: false))
}
