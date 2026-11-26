import Testing
import Foundation
@testable import RadioCore

@Test func fittingBandKeepsItsOwnSpacing() {
    let tape = DialTape(positions: [0.25, 0.5, 0.75], rooms: [10, 10, 10], view: 100)
    #expect(tape.length == 100)
    #expect(tape.coordinate(0.5) == 50)
    #expect(tape.offset(needle: 0.5) == 0)
}

@Test func crowdedNeighboursGetTheirRoom() {
    let tape = DialTape(positions: [0.5, 0.51], rooms: [40, 40], view: 100)
    #expect(tape.coordinate(0.5) == 50)
    #expect(abs(tape.coordinate(0.51) - 90) < 1e-9)      // 50 + max(1, 40)
    #expect(abs(tape.length - 139) < 1e-9)               // 90 + max(49, 20)
}

@Test func offsetHoldsTheNeedleInTheMiddle() {
    let tape = DialTape(positions: [0.5, 0.51, 0.52], rooms: [40, 40, 40], view: 100)
    #expect(abs(tape.length - 178) < 1e-9)               // 130 + max(48, 20)
    #expect(abs(tape.offset(needle: 0.51) - 40) < 1e-9)  // 90 - 50
}

@Test func offsetStopsAtEitherEnd() {
    let tape = DialTape(positions: [0.5, 0.51], rooms: [40, 40], view: 100)
    #expect(tape.offset(needle: 0) == 0)
    #expect(abs(tape.offset(needle: 1) - 39) < 1e-9)     // length - view
}

@Test func emptyBandFitsTheGlass() {
    let tape = DialTape(positions: [], rooms: [], view: 100)
    #expect(tape.length == 100)
    #expect(abs(tape.coordinate(0.3) - 30) < 1e-9)
    #expect(tape.offset(needle: 0.9) == 0)
}

@Test func firstNameStartsOnTheTape() {
    let tape = DialTape(positions: [0.02], rooms: [60], view: 100)
    #expect(tape.coordinate(0.02) == 30)                 // max(2, 60 / 2)
    #expect(tape.coordinate(0) == 0)
}

@Test func coordinatesNeverGoBackwards() {
    let positions = [0.1, 0.1001, 0.11, 0.5, 0.5002, 0.9]
    let tape = DialTape(positions: positions, rooms: Array(repeating: 70, count: positions.count), view: 300)
    let samples = stride(from: -0.1, through: 1.1, by: 0.001).map(tape.coordinate)
    #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 })
    #expect(tape.coordinate(-1) == 0)
    #expect(abs(tape.coordinate(2) - tape.length) < 1e-9)
}

@Test func uprightDialNeverSlidesWith16Stations() {
    let stations = (0..<16).map { i -> Station in
        let f = 98.0 + Double(i) * 0.1
        return Station(callSign: "S\(i)", name: "Station \(i)", licenceCity: "Seattle", frequency: f,
                       streamURL: URL(string: "https://example.com/\(i)")!)
    }
    let scale = DialScale(stations: stations, config: DialConfig())
    let tape = DialTape(positions: scale.marks.map(\.position), rooms: Array(repeating: 18.2, count: 16), view: 780)
    #expect(abs(tape.length - 780) < 1e-9)
    #expect(tape.offset(needle: 0.5) == 0)
}
