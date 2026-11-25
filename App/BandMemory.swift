import Foundation
import RadioCore

/// Where the radio was left, its band and needle position, kept in the app's defaults so it opens
/// there next time (see `Radio.init(file:config:poseConfig:here:band:position:)`, which decides
/// what a saved value is worth). Written only when the needle settles, never per frame.
struct BandMemory {
    static let bandKey = "HingeRadioBand"
    static let positionKey = "HingeRadioPosition"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// The saved band id, or nil when none was saved or it is not text.
    var band: String? { defaults.object(forKey: Self.bandKey) as? String }

    /// The saved position, or nil when none was saved or it is not a number.
    var position: Double? { (defaults.object(forKey: Self.positionKey) as? NSNumber)?.doubleValue }

    func keep(_ remembered: Remembered) {
        defaults.set(remembered.band, forKey: Self.bandKey)
        defaults.set(remembered.position, forKey: Self.positionKey)
    }
}
