import SwiftUI

/// Two pages: the pet (with the one action), and sitting together. Swipe between them.
struct WatchRootView: View {
    @Environment(WatchState.self) private var state
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            NavigationStack { WatchHomeView() }
                .tag(0)
            WatchSitView()
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
        #if DEBUG
        .onAppear { if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "sit" { page = 1 } }
        #endif
    }
}

/// The pet in its room, how it feels, and the one button.
struct WatchHomeView: View {
    @Environment(WatchState.self) private var state
    @State private var showPicker = false

    var body: some View {
        ZStack(alignment: .bottom) {
            PetStage(scene: state.pet.scene, petScale: 0.46, floor: 0.52, showsFoliage: false, mood: state.hasFreshMood ? state.latestEntry?.mood : nil)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.soft()
                    state.pet.tap(onHead: true)
                }
                .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 30) {
                    // Resting a finger on the pet: petting, with the same afterglow as the phone.
                    Haptics.soft()
                    state.pet.beginPetting()
                    Task { try? await Task.sleep(for: .seconds(1.6)); state.pet.endPetting() }
                }
                .accessibilityElement()
                .accessibilityLabel(state.pet.statusLine)
                .accessibilityHint("Double tap to boop \(state.identity.name).")
                .onAppear { state.pet.startClock(); state.pet.arrive(now: .now.addingTimeInterval(0.3)) }
                .onDisappear { state.pet.stopClock() }

            VStack(spacing: 6) {
                Text(statusLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Button {
                    Haptics.light()
                    showPicker = true
                } label: {
                    if let entry = state.latestEntry, state.hasFreshMood {
                        Label(entry.intensity.phrase(for: entry.mood).capitalizedFirst, systemImage: entry.mood.symbolName)
                    } else {
                        Label("How are you?", systemImage: "bubble.left.and.text.bubble.right.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(state.hasFreshMood ? state.latestEntry.map { MoodColor.bold($0.mood) } ?? .accentColor : .accentColor)
                .foregroundStyle(state.hasFreshMood ? MoodColor.onBold : .white)
                .accessibilityLabel(state.hasFreshMood ? "Update your mood" : "Log your mood")
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle(state.identity.name)
        .sheet(isPresented: $showPicker) {
            WatchMoodPicker()
        }
        #if DEBUG
        .onAppear {
            // Screenshot automation, like the phone: PIP_DEBUG=picker|log
            switch ProcessInfo.processInfo.environment["PIP_DEBUG"] {
            case "picker": showPicker = true
            case "log": Task { try? await Task.sleep(for: .seconds(1)); state.log(mood: .happy) }
            default: break
            }
        }
        #endif
    }

    private var statusLine: String {
        state.pet.statusPhrase
    }
}

/// Eight moods, each with the pet's face. One tap logs and closes; intensity is the phone's job.
struct WatchMoodPicker: View {
    @Environment(WatchState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Mood.allCases) { mood in
                    Button {
                        Haptics.selection()
                        state.log(mood: mood)
                        dismiss()
                    } label: {
                        VStack(spacing: 3) {
                            PetView(species: state.identity.species, mood: mood)
                                .frame(width: 44, height: 44)
                                .padding(3)
                                .background(MoodColor.soft(mood, scheme: scheme), in: Circle())
                                .overlay(Circle().strokeBorder(MoodColor.bold(mood).opacity(0.7), lineWidth: 1.5))
                            Text(mood.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mood.displayName)
                    .accessibilityHint("Logs this mood.")
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("How are you?")
    }
}

/// Sitting together on the wrist: the pet closes its eyes and breathes. Nothing counts.
struct WatchSitView: View {
    @Environment(WatchState.self) private var state

    var body: some View {
        ZStack(alignment: .bottom) {
            PetStage(scene: PetScene(species: state.identity.species, stance: .meditating), petScale: 0.72, floor: 0.66, showsFoliage: false, mood: .calm)
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel(PetStance.meditating.describe(state.identity.name))
            Text("Just be.")
                .font(.headline)
                .padding(.bottom, 6)
        }
    }
}
