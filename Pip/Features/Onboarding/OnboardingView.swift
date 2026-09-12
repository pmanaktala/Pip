import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    var body: some View {
        Button("Start") { appState.preferences.hasCompletedOnboarding = true }
    }
}
