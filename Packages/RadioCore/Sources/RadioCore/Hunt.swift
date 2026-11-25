import Foundation

/// How far a search has got through the licences in reach, best ranked first: which to look up
/// next, what is confirmed, and when nothing still open could change the dial.
public struct Hunt: Sendable {
    public let licences: [Licence]
    private var nextIndex = 0
    private var settled: [Int: (Licence, StreamChoice, URL)?] = [:]

    /// `ranked` is best first, as from `stationsInReach`. Frequencies off the dial are dropped, so
    /// they are never looked up and never count towards a full dial.
    public init(_ ranked: [Licence]) {
        licences = ranked.filter(\.isInBand)
    }

    /// What has been found so far, for `hereStations`.
    public var confirmed: [(Licence, StreamChoice, URL)] { settled.values.compactMap { $0 } }

    /// The next licence worth looking up, with the index to settle it by. Everything confirmed so
    /// far ranks ahead of it, so it is passed over when its frequency is taken, and there is none
    /// once the dial is full.
    public mutating func next() -> (Int, Licence)? {
        let taken = Set(confirmed.map { $0.0.frequency })
        guard taken.count < dialLimit else { return nil }
        while nextIndex < licences.count {
            defer { nextIndex += 1 }
            if !taken.contains(licences[nextIndex].frequency) { return (nextIndex, licences[nextIndex]) }
        }
        return nil
    }

    /// Records the end of a lookup: what it found, or nil for no stream.
    public mutating func settle(_ index: Int, with found: (Licence, StreamChoice, URL)?) {
        settled.updateValue(found, forKey: index)
    }

    /// Whether nothing still open could change the dial: its last distinct frequency is confirmed,
    /// and each licence ahead of that one is settled or on a frequency a better one holds.
    public var isDecided: Bool {
        var taken = Set<Double>()
        for (index, licence) in licences.enumerated() {
            switch settled[index] {
            case .some(.some): taken.insert(licence.frequency)
            case .some(.none): continue
            case .none: if !taken.contains(licence.frequency) { return false }
            }
            if taken.count == dialLimit { return true }
        }
        return true
    }
}
