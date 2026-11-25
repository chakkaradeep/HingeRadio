import Foundation
import Testing
@testable import RadioCore

/// A class C licence, so `distance` alone sets how well it ranks: nearer is better.
private func licence(_ call: String, _ mhz: Double, distance: Double) -> Licence {
    Licence(callSign: call, city: "City", stationClass: "C", frequency: mhz, kilowatts: 1, distance: distance)
}

private func confirmation(_ licence: Licence) -> (Licence, StreamChoice, URL) {
    let url = URL(string: "https://example.com/\(licence.callSign)")!
    return (licence, StreamChoice(name: licence.callSign, urls: [url], radioBrowserID: nil), url)
}

/// `count` licences on frequencies of their own, best ranked first: K0, K1 and so on.
private func ranked(_ count: Int) -> [Licence] {
    (0..<count).map { licence("K\($0)", 88.1 + Double($0), distance: Double($0 + 1)) }
}

/// Everything a hunt hands out when nothing is settled in between.
private func handedOut(_ hunt: inout Hunt) -> [String] {
    var calls: [String] = []
    while let (_, licence) = hunt.next() { calls.append(licence.callSign) }
    return calls
}

/// SplitMix64, so the random searches are the same on every run.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Handing out

@Test func handsOutBestRankedFirstAndEachOnce() {
    var hunt = Hunt(ranked(3))
    #expect(handedOut(&hunt) == ["K0", "K1", "K2"])
    #expect(hunt.next() == nil)
}

@Test func aFrequencyABetterLicenceHoldsIsNotHandedOutAgain() {
    let best = licence("KBEST", 90.3, distance: 1)
    var hunt = Hunt([best, licence("KSAME", 90.3, distance: 2), licence("KNEXT", 91.5, distance: 3)])
    let first = hunt.next()
    #expect(first?.1 == best)
    hunt.settle(0, with: confirmation(best))
    #expect(handedOut(&hunt) == ["KNEXT"])
}

@Test func aFrequencyIsStillOpenWhenTheBetterLicenceHasNoStream() {
    var hunt = Hunt([licence("KBEST", 90.3, distance: 1), licence("KSAME", 90.3, distance: 2)])
    _ = hunt.next()
    hunt.settle(0, with: nil)
    #expect(handedOut(&hunt) == ["KSAME"])
}

@Test func aStationOutsideTheBandIsNeverHandedOut() {
    let band = DialConfig()
    var hunt = Hunt([
        licence("KLOW", band.minFrequency - 0.1, distance: 1),
        licence("KMIN", band.minFrequency, distance: 2),
        licence("KMAX", band.maxFrequency, distance: 3),
        licence("KHIGH", band.maxFrequency + 0.1, distance: 4),
    ])
    #expect(handedOut(&hunt) == ["KMIN", "KMAX"])
}

@Test func nothingMoreIsHandedOutOnceTheDialIsFull() {
    let all = ranked(18)
    var hunt = Hunt(all)
    for index in 0..<15 {
        _ = hunt.next()
        hunt.settle(index, with: confirmation(all[index]))
    }
    let sixteenth = hunt.next()
    #expect(sixteenth?.1 == all[15])
    hunt.settle(15, with: confirmation(all[15]))
    #expect(hunt.next() == nil)
}

// MARK: - Deciding

@Test func anEmptyHuntIsDecided() {
    #expect(Hunt([]).isDecided)
}

@Test func aShortHuntIsDecidedOnlyWhenEveryLicenceIsSettled() {
    let all = ranked(2)
    var hunt = Hunt(all)
    hunt.settle(0, with: confirmation(all[0]))
    #expect(!hunt.isDecided)
    hunt.settle(1, with: nil)
    #expect(hunt.isDecided)
}

@Test func aSettledNilCountsAsSettled() {
    let all = ranked(18)
    var hunt = Hunt(all)
    for index in 1...16 { hunt.settle(index, with: confirmation(all[index])) }
    #expect(!hunt.isDecided)          // the best ranked is still open, and would take a place
    hunt.settle(0, with: nil)
    #expect(hunt.isDecided)           // 16 confirmed behind it; the 18th cannot matter
    #expect(hunt.confirmed.count == 16)
}

@Test func coChannelLicencesInFlightTogetherResolveToTheBetterRanked() {
    let best = licence("KBEST", 90.3, distance: 1)
    let same = licence("KSAME", 90.3, distance: 2)
    var hunt = Hunt([best, same])
    #expect(handedOut(&hunt) == ["KBEST", "KSAME"])
    hunt.settle(1, with: confirmation(same))
    #expect(hereStations(hunt.confirmed).map(\.callSign) == ["KSAME"])
    #expect(!hunt.isDecided)          // the better one can still take the frequency
    hunt.settle(0, with: confirmation(best))
    #expect(hunt.isDecided)
    #expect(hereStations(hunt.confirmed).map(\.callSign) == ["KBEST"])
}

@Test func anOpenLicenceOnAFrequencyABetterOneHoldsDoesNotHoldUpTheAnswer() {
    let best = licence("KBEST", 90.3, distance: 1)
    var hunt = Hunt([best, licence("KSAME", 90.3, distance: 2)])
    hunt.settle(0, with: confirmation(best))
    #expect(hunt.isDecided)
}

@Test func theEarlyStopNeverChangesTheAnswer() {
    var random = SeededGenerator(state: 2026)
    var earlyStops = 0, lookups = 0, inReach = 0
    for search in 0..<4000 {
        let licences = stationsInReach((0..<Int.random(in: 0...45, using: &random)).map {
            licence("K\($0)", 86.9 + Double(Int.random(in: 0...36, using: &random)) * 0.6,
                    distance: Double.random(in: 1...90, using: &random))
        })
        let streaming = Set(licences.filter { _ in Double.random(in: 0...1, using: &random) < 0.7 })

        var hunt = Hunt(licences)
        var inFlight: [(Int, Licence)] = []
        for _ in 0..<6 { if let lookup = hunt.next() { inFlight.append(lookup) } }
        while !inFlight.isEmpty {
            // Lookups finish in any order.
            let (index, licence) = inFlight.remove(at: Int.random(in: 0..<inFlight.count, using: &random))
            lookups += 1
            hunt.settle(index, with: streaming.contains(licence) ? confirmation(licence) : nil)
            if hunt.isDecided {
                if !inFlight.isEmpty { earlyStops += 1 }
                break
            }
            if let lookup = hunt.next() { inFlight.append(lookup) }
        }
        inReach += licences.count
        let everyStreaming = licences.filter(streaming.contains).map(confirmation)
        #expect(hunt.isDecided, "search \(search)")
        #expect(hereStations(hunt.confirmed) == hereStations(everyStreaming), "search \(search)")
    }
    #expect(earlyStops > 500)         // or the searches above were not testing the stop
    #expect(lookups < inReach)
}
