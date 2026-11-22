import SwiftUI

@main
struct HingeRadioApp: App {
    @State private var model = RadioModel(
        stationData: Bundle.main.url(forResource: "Stations", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
    )

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
