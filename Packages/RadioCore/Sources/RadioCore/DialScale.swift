public struct DialScale: Sendable {
    public struct Mark: Sendable, Equatable {
        public let station: Station
        public let angle: Double
        public let position: Double
    }

    public let marks: [Mark]
    private let config: DialConfig
    /// (position, frequency) anchors in increasing order: dial start, each mark, dial end.
    private let anchors: [(position: Double, frequency: Double)]

    public init(stations: [Station], config: DialConfig) {
        self.config = config
        let angles = Self.placeAngles(for: stations, config: config)
        let span = config.maxAngle - config.minAngle
        marks = zip(stations, angles).map { station, angle in
            Mark(station: station, angle: angle, position: (angle - config.minAngle) / span)
        }
        anchors = [(0, config.minFrequency)]
            + marks.map { ($0.position, $0.station.frequency) }
            + [(1, config.maxFrequency)]
    }

    public func position(forAngle angle: Double) -> Double {
        let p = (angle - config.minAngle) / (config.maxAngle - config.minAngle)
        return min(1, max(0, p))
    }

    public func position(forFrequency frequency: Double) -> Double {
        interpolate(frequency, from: \.frequency, to: \.position)
    }

    public func frequency(atPosition position: Double) -> Double {
        interpolate(position, from: \.position, to: \.frequency)
    }

    // MARK: - Private

    /// Piecewise-linear lookup through the anchors, clamped to the first and last.
    private func interpolate(_ x: Double,
                             from input: KeyPath<(position: Double, frequency: Double), Double>,
                             to output: KeyPath<(position: Double, frequency: Double), Double>) -> Double {
        guard let first = anchors.first, let last = anchors.last else { return x }
        if x <= first[keyPath: input] { return first[keyPath: output] }
        if x >= last[keyPath: input] { return last[keyPath: output] }
        for (a, b) in zip(anchors, anchors.dropFirst()) where x <= b[keyPath: input] {
            let width = b[keyPath: input] - a[keyPath: input]
            if width <= 0 { return b[keyPath: output] }
            let t = (x - a[keyPath: input]) / width
            return a[keyPath: output] + t * (b[keyPath: output] - a[keyPath: output])
        }
        return last[keyPath: output]
    }

    /// Stretches ideal angles so neighbours are at least `minSpacing` apart (or evenly
    /// spread if they cannot all fit), keeping order and staying inside the lock-zone bounds.
    private static func placeAngles(for stations: [Station], config: DialConfig) -> [Double] {
        let n = stations.count
        guard n > 0 else { return [] }
        let span = config.maxAngle - config.minAngle
        let ideal = stations.map {
            config.minAngle + ($0.frequency - config.minFrequency)
                / (config.maxFrequency - config.minFrequency) * span
        }
        let lo = config.minAngle + config.lockWidth / 2
        let hi = config.maxAngle - config.lockWidth / 2
        let spacing = n > 1 ? min(config.minSpacing, (hi - lo) / Double(n - 1)) : 0

        // Remove the spacing ramp, fit a non-decreasing sequence (pool adjacent violators), restore it.
        var blocks: [(sum: Double, count: Int)] = []
        for (i, a) in ideal.enumerated() {
            blocks.append((a - Double(i) * spacing, 1))
            while blocks.count > 1,
                  let last = blocks.last, let prev = blocks.dropLast().last,
                  prev.sum / Double(prev.count) > last.sum / Double(last.count) {
                blocks.removeLast(2)
                blocks.append((prev.sum + last.sum, prev.count + last.count))
            }
        }
        let fitted = blocks.flatMap { block in
            Array(repeating: block.sum / Double(block.count), count: block.count)
        }
        let upper = hi - Double(n - 1) * spacing
        return fitted.enumerated().map { i, b in
            min(max(b, lo), upper) + Double(i) * spacing
        }
    }
}
