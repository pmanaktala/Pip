import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var showGallery = false

    var body: some View {
        Group {
            if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "gallery" {
                PetGalleryView()
            } else if appState.preferences.hasCompletedOnboarding {
                PetHomeView()
            } else {
                OnboardingView()
            }
        }
        .fontDesign(.rounded)
        .tint(.accentColor)
    }
}
