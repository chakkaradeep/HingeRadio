/// What a control feels like as it moves: a sound with a matching haptic.
public enum Feel: Sendable, Equatable {
    case bandClick, powerClick, lockClick(callSign: String)
    case tuningStop, volumeStop
    case tuningTick, volumeTick

    public var isTick: Bool { self == .tuningTick || self == .volumeTick }
}

/// The feel of one change of the radio, or nil. At most one, the firmest that applies:
/// a new city, then power, then a newly locked station click; a wheel newly at the end of its
/// travel stops; passing a tuning ridge ticks; passing a volume step ticks only while on.
/// They come with the radio off too (the wheels are mechanical). Pose, suspension and dead
/// stations never feel like anything, nor does HERE's dial changing under the needle. A scan of
/// HERE ticks but clicks onto no station and stops at neither end.
public func feel(from old: Radio, to new: Radio) -> Feel? {
    if new.cityID != old.cityID { return .bandClick }
    if new.cityID == hereID, new.cities != old.cities { return nil }
    if new.powerOn != old.powerOn { return .powerClick }
    if !new.isScanningHere, let locked = new.tuning.locked?.callSign, locked != old.tuning.locked?.callSign {
        return .lockClick(callSign: locked)
    }
    if !new.isScanningHere, new.position != old.position, new.position == 0 || new.position == 1 {
        return .tuningStop
    }
    if new.wheel != old.wheel, new.wheel == 0 || new.wheel == 1 { return .volumeStop }
    if ticksCrossed(from: old.position, to: new.position, step: Radio.tuningRidge) > 0 { return .tuningTick }
    if old.powerOn, new.powerOn, ticksCrossed(from: old.wheel, to: new.wheel, step: Radio.volumeRidge) > 0 {
        return .volumeTick
    }
    return nil
}
