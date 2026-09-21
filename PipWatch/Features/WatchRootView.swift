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
            PetSceneWithClock(identity: state.identity, state: state.displayedState, petScale: 0.6, petVerticalPosition: 0.36, showsFloor: false, showsBackground: true)
                .ignoresSafeArea()
                .onTapGesture { state.poke() }
                .accessibilityElement()
                .accessibilityLabel("\(state.identity.name) \(state.displayedState.mood.petDescription).")
                .accessibilityHint("Double tap to say hello.")

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
        if let entry = state.latestEntry, state.hasFreshMood {
            return "\(state.identity.name) \(entry.mood.petDescription)"
        }
        return "Ready when you are."
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
                            PetView(identity: state.identity, state: PetStateResolver.resolve(mood: mood, identity: state.identity), showsShadow: false, framing: .face)
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

/// Sitting together on the wrist: the pet meditates, a quiet timer counts. Nothing to complete.
struct WatchSitView: View {
    @Environment(WatchState.self) private var state
    @State private var startedAt = Date.now

    private var meditating: PetMoodState {
        var s = PetStateResolver.resolve(mood: .calm, intensity: .moderate, identity: state.identity)
        s.motion.bit = .meditate
        s.motion.breathRate = 0.1
        s.motion.breathAmount = 0.06
        s.motion.blinkInterval = .infinity
        s.motion.gazeInterval = .infinity
        s.motion.sigh = 0
        s.motion.hopHeight = 0
        s.accessory = nil
        return s
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PetSceneWithClock(identity: state.identity, state: meditating, petScale: 0.66, petVerticalPosition: 0.45, showsFloor: false, showsBackground: true)
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel("\(state.identity.name) is sitting with you.")
            VStack(spacing: 2) {
                Text("Just be.")
                    .font(.headline)
                Text(timerInterval: startedAt...startedAt.addingTimeInterval(24 * 3600), countsDown: false, showsHours: false)
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 6)
        }
        .onAppear { startedAt = .now }
    }
}

/// The scene on a frame clock, honouring Reduce Motion (same as the phone's helper).
struct PetSceneWithClock: View {
    var identity: PetIdentity
    var state: PetMoodState
    var petScale: CGFloat = 0.62
    var petVerticalPosition: CGFloat = 0.49
    var showsFloor = true
    var showsBackground = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            PetSceneView(identity: identity, state: state, time: nil, petScale: petScale, petVerticalPosition: petVerticalPosition, showsFloor: showsFloor, showsBackground: showsBackground)
                .animation(.smooth(duration: 0.6), value: state.rig)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                PetSceneView(identity: identity, state: state, time: context.date.timeIntervalSinceReferenceDate, petScale: petScale, petVerticalPosition: petVerticalPosition, showsFloor: showsFloor, showsBackground: showsBackground, date: context.date)
                    .animation(.smooth(duration: 0.7), value: state.rig)
            }
        }
    }
}
