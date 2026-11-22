import Testing
import Foundation
@testable import RadioCore

private func st(_ f: Double) -> Station {
    Station(callSign: "S\(f)", name: "Station \(f)", licenceCity: "Seattle", frequency: f,
            streamURL: URL(string: "https://example.com/\(f)")!)
}

@Test func straightWhenSpacingIsZero() {
    var c = DialConfig(); c.minSpacing = 0
    let s = DialScale(stations: [st(88.5), st(98.0)], config: c)
    #expect(abs(s.marks[0].angle - 73.8095) < 1e-3)
    #expect(abs(s.marks[1].position - 0.5) < 1e-9)
}

@Test func closePairIsPushedApartAndFarStationIsLeftAlone() {
    let s = DialScale(stations: [st(88.1), st(88.3), st(103.5)], config: DialConfig())
    #expect(abs(s.marks[0].angle - 71.5) < 1e-6)
    #expect(abs(s.marks[1].angle - 76.0) < 1e-6)
    #expect(abs(s.marks[2].angle - 130.95238) < 1e-4)
}

@Test func chicagoLowEndKeepsSpacingOrderAndBounds() {
    let freqs = [88.1, 88.3, 88.5, 88.7, 88.9, 89.1, 89.3, 90.1, 90.7, 90.9, 91.5, 92.7, 93.9, 95.5, 98.7, 103.5]
    let s = DialScale(stations: freqs.map(st), config: DialConfig())
    #expect(s.marks.count == 16)
    #expect(s.marks.first!.angle >= 71.5)
    #expect(s.marks.last!.angle <= 148.5)
    for (a, b) in zip(s.marks, s.marks.dropFirst()) {
        #expect(b.angle - a.angle >= 4.5 - 1e-9)
        #expect(b.angle > a.angle)
    }
}

@Test func spacingShrinksWhenTooManyToFit() {
    let freqs = (0..<20).map { 88.1 + Double($0) * 0.2 }
    let s = DialScale(stations: freqs.map(st), config: DialConfig())
    #expect(s.marks.count == 20)
    for (a, b) in zip(s.marks, s.marks.dropFirst()) {
        #expect(abs((b.angle - a.angle) - 77.0 / 19) < 1e-9)
    }
}

@Test func scaleRoundTrips() {
    let freqs = [88.1, 88.3, 90.7, 98.7, 103.5]
    let s = DialScale(stations: freqs.map(st), config: DialConfig())
    #expect(s.frequency(atPosition: 0) == 87.5)
    #expect(s.frequency(atPosition: 1) == 108.5)
    for m in s.marks {
        #expect(abs(s.frequency(atPosition: m.position) - m.station.frequency) < 1e-9)
    }
    for i in 0...20 {
        let p = Double(i) * 0.05
        #expect(abs(s.position(forFrequency: s.frequency(atPosition: p)) - p) < 1e-9)
    }
}

@Test func anglesClamp() {
    let s = DialScale(stations: [], config: DialConfig())
    #expect(s.position(forAngle: 60) == 0)
    #expect(s.position(forAngle: 160) == 1)
    #expect(abs(s.position(forAngle: 110) - 0.5) < 1e-12)
}

@Test func emptyScaleIsStraight() {
    let s = DialScale(stations: [], config: DialConfig())
    #expect(s.marks.isEmpty)
    #expect(abs(s.frequency(atPosition: 0.5) - 98.0) < 1e-9)
}
