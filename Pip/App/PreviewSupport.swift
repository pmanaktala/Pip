#if DEBUG
import SwiftData
import SwiftUI

/// In-memory app state for previews, optionally seeded with two weeks of moods.
extension AppState {
    @MainActor
    static func preview(species: PetSpecies = .cat, seeded: Bool = true) -> AppState {
        let state = AppState(container: PipModelContainer.make(inMemory: true), preferences: Preferences(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)")!))
        state.selectPet(species)
        if seeded { state.seedDemoData() }
        return state
    }
}

/// Wraps a preview in everything the feature views expect from the environment.
struct PreviewHost<Content: View>: View {
    @State private var appState: AppState
    @State private var health = HealthSyncService()
    @State private var notifications = NotificationService()
    let content: Content

    init(species: PetSpecies = .cat, seeded: Bool = true, @ViewBuilder content: () -> Content) {
        _appState = State(initialValue: .preview(species: species, seeded: seeded))
        self.content = content()
    }

    var body: some View {
        content
            .environment(appState)
            .environment(health)
            .environment(notifications)
            .modelContainer(appState.container)
            .fontDesign(.rounded)
    }
}

#Preview("Home · cat") {
    PreviewHost { PetHomeView() }
}

#Preview("Home · penguin · dark") {
    PreviewHost(species: .penguin) { PetHomeView() }
        .preferredColorScheme(.dark)
}

#Preview("Home · AX5") {
    PreviewHost(species: .dog) { PetHomeView() }
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Mood picker") {
    PreviewHost { MoodPickerSheet() }
}

#Preview("History") {
    PreviewHost(species: .cat) { NavigationStack { HistoryView() } }
}

#Preview("Pets") {
    PreviewHost { NavigationStack { PetSelectorView() } }
}

#Preview("Settings") {
    PreviewHost { NavigationStack { SettingsView() } }
}

#Preview("Onboarding") {
    PreviewHost(seeded: false) { OnboardingView() }
}

#Preview("Sit With Pet") {
    PreviewHost(species: .dog) { PlayView() }
}
#endif
