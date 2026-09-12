import SwiftData
import SwiftUI

@main
struct PipApp: App {
    @State private var appState: AppState
    @State private var health: HealthSyncService
    @State private var notifications = NotificationService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let health = HealthSyncService()
        let container = PipModelContainer.shared
        let state = AppState(container: container, sideEffects: [
            HealthMoodSideEffect(service: health, context: container.mainContext, preferences: .shared),
        ])
        _appState = State(initialValue: state)
        _health = State(initialValue: health)
        #if DEBUG
        if ProcessInfo.processInfo.environment["PIP_SEED"] == "1" { state.seedDemoData() }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(health)
                .environment(notifications)
                .modelContainer(appState.container)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            appState.refresh()
            Task {
                await health.syncPending(context: appState.context, preferences: appState.preferences)
                await notifications.refreshAuthorization()
                await notifications.reschedule(preferences: appState.preferences, identity: appState.identity)
            }
        }
    }
}
