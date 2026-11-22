import Foundation

/// Levels for the station, the static and the tuning whistle.
public struct Mix: Sendable, Equatable {
    public var station: Double, staticLevel: Double, whistle: Double, whistleHz: Double

    public init(station: Double, staticLevel: Double, whistle: Double, whistleHz: Double) {
        self.station = station
        self.staticLevel = staticLevel
        self.whistle = whistle
        self.whistleHz = whistleHz
    }
}

/// `playing` means the station under the needle is the one making sound.
public func mix(isLive: Bool, playing: Bool, strength: Double, edgeDistance: Double) -> Mix {
    let live = (isLive && playing) ? strength : 0
    let whistleGap = 2.25
    let whistle = (isLive && edgeDistance > 0 && edgeDistance < whistleGap)
        ? 0.012 * sin(Double.pi * edgeDistance / whistleGap) : 0
    return Mix(station: pow(live, 1.3),
               staticLevel: isLive ? 0.015 + 0.24 * pow(1 - live, 1.6) : 0,
               whistle: whistle,
               whistleHz: 180 + 700 * edgeDistance)
}
