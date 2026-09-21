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
        .tint(.accentColor)
    }

    @ViewBuilder
    private var mainOrOnboarding: some View {
        if appState.preferences.hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

/// Three tabs. The pet is home; history and settings are one tap away, never hidden in a toolbar.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var tab: Tab = .pet

    enum Tab: Hashable { case pet, history, you }

    var body: some View {
        TabView(selection: $tab) {
            SwiftUI.Tab("Pet", systemImage: "pawprint.fill", value: Tab.pet) {
                PetHomeView()
            }
            SwiftUI.Tab("History", systemImage: "calendar", value: Tab.history) {
                NavigationStack { HistoryView() }
            }
            SwiftUI.Tab("You", systemImage: "person.crop.circle.fill", value: Tab.you) {
                NavigationStack { SettingsView() }
            }
        }
        .onChange(of: appState.pendingRoute, initial: true) { _, route in
            guard let route else { return }
            tab = .pet
            if route == .sit { appState.presentSit = true }
            appState.pendingRoute = nil
        }
        #if DEBUG
        .onAppear {
            // Screenshot automation.
            switch ProcessInfo.processInfo.environment["PIP_DEBUG"] {
            case "history": tab = .history
            case "settings": tab = .you
            default: break
            }
        }
        #endif
    }
}
