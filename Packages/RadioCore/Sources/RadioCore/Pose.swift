public enum Screen: Sendable, Equatable { case inner, outer }

public enum HingeStatus: Sendable, Equatable { case closed, partiallyOpen, fullyOpen }

public enum Pose: String, Sendable, Equatable { case shut, tent, flex, book, flat }

public struct PoseConfig: Sendable, Equatable {
    public var shutBelow = 20.0, flatFrom = 175.0, outerShortSideBelow = 560.0
    public init() {}
}

public struct PoseInput: Sendable, Equatable {
    public var screen: Screen
    public var landscape: Bool
    public var angle: Double?          // nil when the phone has no hinge
    public var status: HingeStatus?    // nil when the phone has no hinge
    public init(screen: Screen, landscape: Bool, angle: Double?, status: HingeStatus?) {
        self.screen = screen
        self.landscape = landscape
        self.angle = angle
        self.status = status
    }
}

public struct WindowReading: Sendable, Equatable {
    public var screen: Screen
    public var landscape: Bool
    public init(screen: Screen, landscape: Bool) {
        self.screen = screen
        self.landscape = landscape
    }
}

public func pose(_ input: PoseInput, config: PoseConfig = PoseConfig()) -> Pose {
    guard let angle = input.angle else {
        return input.landscape ? .book : .flex
    }
    if angle < config.shutBelow { return .shut }
    if input.screen == .outer { return .tent }
    if input.status == .fullyOpen || angle >= config.flatFrom { return .flat }
    return input.landscape ? .book : .flex
}

public func windowReading(width: Double, height: Double, config: PoseConfig = PoseConfig()) -> WindowReading? {
    guard width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
    let shortSide = min(width, height)
    let screen: Screen = shortSide < config.outerShortSideBelow ? .outer : .inner
    return WindowReading(screen: screen, landscape: width > height)
}
