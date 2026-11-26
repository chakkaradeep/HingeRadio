import Testing
@testable import RadioCore

private let phases: [AppPhase] = [.active, .inactive, .background]

@Test func activeNeverSuspendsUninterrupted() {
    #expect(!shouldSuspend(phase: .active, powerOn: true, interrupted: false))
    #expect(!shouldSuspend(phase: .active, powerOn: false, interrupted: false))
}

/// Control Center, an alert or the location prompt makes the app inactive: the radio plays on.
@Test func inactiveNeverSuspendsUninterrupted() {
    #expect(!shouldSuspend(phase: .inactive, powerOn: true, interrupted: false))
    #expect(!shouldSuspend(phase: .inactive, powerOn: false, interrupted: false))
}

@Test func backgroundSuspendsOnlyWithThePowerOff() {
    #expect(!shouldSuspend(phase: .background, powerOn: true, interrupted: false))
    #expect(shouldSuspend(phase: .background, powerOn: false, interrupted: false))
}

/// A call, an alarm or Siri takes the sound: a radio switched on is suspended, in any phase.
@Test func anInterruptionSuspendsARadioSwitchedOn() {
    for phase in phases {
        #expect(shouldSuspend(phase: phase, powerOn: true, interrupted: true))
    }
}

/// Switched off, an interruption changes nothing: off in front is not suspended, off in the
/// background is.
@Test func anInterruptionChangesNothingWithThePowerOff() {
    for phase in phases {
        #expect(shouldSuspend(phase: phase, powerOn: false, interrupted: true)
                == shouldSuspend(phase: phase, powerOn: false, interrupted: false))
    }
}
