import SwiftData
import SwiftUI

@main
struct PipApp: App {
    @State private var appState: AppState
    @State private var health: HealthSyncService
    @State private var notifications: NotificationService
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let health = HealthSyncService()
        #if DEBUG
        // UI tests run against a fresh in-memory store with onboarding already done.
        let uiTesting = ProcessInfo.processInfo.environment["PIP_UITEST"] == "1"
        let container = uiTesting ? PipModelContainer.make(inMemory: true) : PipModelContainer.shared
        let preferences = uiTesting ? Preferences(defaults: UserDefaults(suiteName: "uitest.\(UUID().uuidString)")!) : Preferences.shared
        if uiTesting { preferences.hasCompletedOnboarding = true }
        #else
        let container = PipModelContainer.shared
        let preferences = Preferences.shared
        #endif
        let effects: [any MoodLogSideEffect] = [
            LiveActivityMoodSideEffect(preferences: preferences),
            HealthMoodSideEffect(service: health, context: container.mainContext, preferences: preferences),
            DeviceSyncSideEffect(),
        ]
        MoodSideEffectRegistry.effects = effects
        let state = AppState(container: container, preferences: preferences, sideEffects: effects)
        let notifications = NotificationService()
        notifications.onOpen = { [state] url in state.handle(url: url) }
        // Fast path to the Watch; iCloud remains the store of record.
        DeviceSync.shared.start(container: container)
        DeviceSync.shared.onRemoteChange = { [state] in state.refresh() }
        _appState = State(initialValue: state)
        _health = State(initialValue: health)
        _notifications = State(initialValue: notifications)
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
                .onOpenURL { url in appState.handle(url: url) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            appState.refresh()
            appState.evaluatePetMoments()
            Task {
                await health.syncPending(context: appState.context, preferences: appState.preferences)
                await notifications.refreshAuthorization()
                await notifications.reschedule(preferences: appState.preferences, identity: appState.identity)
            }
        }
    }
}
