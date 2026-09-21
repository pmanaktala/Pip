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
/// The one action — how are you feeling? — is a prominent tab on iOS 27 (the separated circle
/// the tab bar gives one tab) and the tab bar's bottom accessory on iOS 26. Either way it is on
/// every tab and opens the mood sheet.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var tab: Tab = .pet
    @State private var lastContentTab: Tab = .pet

    enum Tab: Hashable { case pet, history, you, log }

    var body: some View {
        @Bindable var appState = appState
        Group {
            #if compiler(>=6.4)
            if #available(iOS 27, *) {
                TabView(selection: $tab) {
                    coreTabs
                    SwiftUI.Tab(appState.hasFreshMood ? "Update your mood" : "Log your mood", systemImage: "bubble.left.and.heart.bubble.right.fill", value: Tab.log, role: .prominent) {
                        Color.clear
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                accessoryTabView
            }
            #else
            accessoryTabView
            #endif
        }
        .sheet(isPresented: $appState.isPickingMood) {
            MoodPickerSheet()
                .presentationDetents([.height(380), .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .height(380)))
                .presentationBackground(.thinMaterial)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: tab) { old, new in
            // The prominent tab is an action, not a place: open the sheet and stay where you were.
            if new == .log {
                Haptics.light()
                appState.isPickingMood = true
                tab = old == .log ? lastContentTab : old
            } else {
                lastContentTab = new
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
            case "picker": appState.isPickingMood = true
            default: break
            }
        }
        #endif
    }

    /// iOS 26: the action rides on the tab bar as its accessory.
    private var accessoryTabView: some View {
        TabView(selection: $tab) {
            coreTabs
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory { MoodAccessoryView() }
    }

    @TabContentBuilder<Tab>
    private var coreTabs: some TabContent<Tab> {
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
}

/// The tab bar accessory: the question when nothing is logged, the answer once it is. Tapping
/// opens the mood sheet from any tab. Collapses to one line when the tab bar minimises.
struct MoodAccessoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.colorScheme) private var scheme

    private var fresh: MoodEntry? { appState.hasFreshMood ? appState.latestEntry : nil }

    var body: some View {
        Button {
            Haptics.light()
            appState.isPickingMood = true
        } label: {
            HStack(spacing: 10) {
                if let entry = fresh {
                    PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: entry.mood, intensity: entry.intensity, identity: appState.identity), showsShadow: false, framing: .face)
                        .frame(width: 26, height: 26)
                        .padding(2)
                        .background(MoodColor.soft(entry.mood, scheme: scheme), in: Circle())
                        .overlay(Circle().strokeBorder(MoodColor.bold(entry.mood).opacity(0.6), lineWidth: 1))
                    Text(entry.intensity.phrase(for: entry.mood).capitalizedFirst)
                        .font(PipFont.headline)
                    if placement != .inline {
                        Text(entry.timestamp.formatted(.relative(presentation: .named)))
                            .font(PipFont.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.bounce, value: appState.latestEntry?.id)
                    Text("How are you feeling?")
                        .font(PipFont.headline)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fresh == nil ? "Log your mood" : "Update your mood")
        .accessibilityHint("Opens the mood sheet.")
    }
}
