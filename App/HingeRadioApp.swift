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
                    model.appIsActive(phase == .active)
                    if phase == .background { model.enteredBackground() }
                }
        }
    }
}
