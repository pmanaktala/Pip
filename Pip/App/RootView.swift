import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "gallery" {
                PetGalleryView()
            } else if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "onboarding" {
                OnboardingView()
            } else {
                mainOrOnboarding
            }
            #else
            mainOrOnboarding
            #endif
        }
        .fontDesign(.rounded)
        .tint(.accentColor)
    }

    @ViewBuilder
    private var mainOrOnboarding: some View {
        if appState.preferences.hasCompletedOnboarding {
            PetHomeView()
        } else {
            OnboardingView()
        }
    }
}
