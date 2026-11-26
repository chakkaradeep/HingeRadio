/// Where the app is, as the system tells it: in front and taking touches, in front but under
/// Control Center, an alert or a system prompt such as the location one, or in the background
/// (locked, or another app in front).
public enum AppPhase: Sendable, Equatable { case active, inactive, background }

/// Whether the radio is suspended (silent, see `Radio.setSuspended`): only in the background with
/// the power off. Switched on, the radio plays on in the background, and being merely inactive
/// never stops it.
public func shouldSuspend(phase: AppPhase, powerOn: Bool) -> Bool {
    phase == .background && !powerOn
}
