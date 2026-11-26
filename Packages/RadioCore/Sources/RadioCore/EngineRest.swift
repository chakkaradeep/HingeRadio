import Foundation

/// How long, in seconds, the sound engine keeps running with the radio off after the last tick,
/// click or stop, or the last touch on a control.
public let engineRestDelay: TimeInterval = 2

/// Whether the sound engine and its session may stop: never while the radio is live; with it off,
/// when nothing has sounded yet, or `engineRestDelay` after the last sound.
/// Times are seconds on any steady clock; the app uses `ProcessInfo.systemUptime`.
public func engineMayRest(isLive: Bool, lastSound: TimeInterval?, now: TimeInterval) -> Bool {
    guard !isLive else { return false }
    guard let lastSound else { return true }
    return now - lastSound >= engineRestDelay
}
