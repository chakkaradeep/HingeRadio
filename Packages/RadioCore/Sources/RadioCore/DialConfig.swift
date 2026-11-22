public struct DialConfig: Sendable, Equatable {
    public var minAngle = 70.0, maxAngle = 150.0, minFrequency = 87.5, maxFrequency = 108.5
    public var minSpacing = 4.5, lockWidth = 3.0, releaseMargin = 0.5, fadeWidth = 0.75, closedBelow = 45.0
    public init() {}
}
