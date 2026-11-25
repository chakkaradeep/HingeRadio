import Foundation

extension Station {
    /// The name to show beside the frequency: the station's name without its own exact frequency,
    /// so "94.7 WLS" at 94.7 shows as "WLS". The unit, brackets and separators written with the
    /// frequency go too. Any other number stays, because it is the brand ("Hot 97", at 97.1), and
    /// so does the frequency inside a word ("K102.5", "94.7's Best"). When nothing but "FM" or
    /// "MHz" is left, the call sign shows.
    public var shownName: String {
        let own = NSRegularExpression.escapedPattern(for: String(format: "%.1f", frequency))
        let core = "(?<![\\w.])(?:FM)?\(own)(?!\\d)(?:[ -]?(?:FM|MHz)\\b|(?![\\w'’]))"
        let gap = "[\\s\\-–—:/|,·•]*"
        let pattern = "(?i)\(gap)(?:[(\\[]\\s*\(core)\\s*[)\\]]|\(core))\(gap)"
        let rest = name.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        guard rest != name else { return name }
        let shown = rest
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ([)\\]])", with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard shown.contains(where: { $0.isLetter || $0.isNumber }),
              !["FM", "MHZ"].contains(shown.uppercased()) else {
            return callSign.hasSuffix("-FM") ? String(callSign.dropLast(3)) : callSign
        }
        return shown
    }
}
