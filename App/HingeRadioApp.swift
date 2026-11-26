import RadioCore
import SwiftUI

@main
struct HingeRadioApp: App {
    @State private var model = RadioModel(
        stationData: Bundle.main.url(forResource: "Stations", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
    )
    /// The app's phase across all its scenes.
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    model.phaseChanged(AppPhase(phase))
                }
        }
    }
}

private extension AppPhase {
    /// A phase the system adds later counts as inactive, which never stops the radio.
    init(_ phase: ScenePhase) {
        switch phase {
        case .active: self = .active
        case .background: self = .background
        case .inactive: self = .inactive
        @unknown default: self = .inactive
        }
    }
}
