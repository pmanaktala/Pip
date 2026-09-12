import SwiftData
import SwiftUI

@main
struct PipApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(appState.container)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { appState.refresh() }
        }
    }
}
