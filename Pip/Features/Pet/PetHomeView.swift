import SwiftUI

/// The main screen: the pet, its room, and one floating way to say how you feel.
struct PetHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showMoodPicker = false
    @State private var showSitWithPet = false
    @State private var path = NavigationPath()

    private enum Destination: Hashable { case history, pets, settings }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                PetSceneWithClock(identity: appState.identity, state: appState.displayedState,
                                  petScale: showMoodPicker ? 0.5 : 0.62,
                                  petVerticalPosition: showMoodPicker ? 0.3 : 0.49)
                    .animation(.spring(duration: 0.55, bounce: 0.15), value: showMoodPicker)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { appState.pokePet() }
                    .accessibilityElement()
                    .accessibilityLabel(petAccessibilityLabel)
                    .accessibilityHint("Double tap to say hello.")
                    .accessibilityAddTraits(.isImage)

                VStack {
                    nameTag
                    Spacer()
                    moodButton
                        .padding(.bottom, PipSpacing.m)
                }
                .padding(.horizontal, PipSpacing.m)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { path.append(Destination.history) } label: { Label("History", systemImage: "calendar") }
                    Button { path.append(Destination.pets) } label: { Label("Pets", systemImage: "pawprint") }
                    Button { path.append(Destination.settings) } label: { Label("Settings", systemImage: "gearshape") }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .history: HistoryView()
                case .pets: PetSelectorView()
                case .settings: SettingsView()
                }
            }
            .sheet(isPresented: $showMoodPicker) {
                MoodPickerSheet()
                    .presentationDetents([.fraction(0.46), .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.46)))
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showSitWithPet) {
                SitWithPetView()
            }
            #if DEBUG
            .onAppear {
                // Screenshot automation: `PIP_DEBUG=picker` opens the picker on launch.
                if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "picker" { showMoodPicker = true }
            }
            #endif
        }
    }

    private var nameTag: some View {
        HStack {
            Button {
                showSitWithPet = true
            } label: {
                HStack(spacing: 6) {
                    Text(appState.identity.name)
                        .font(PipFont.headline)
                    if let mood = appState.latestEntry?.mood, appState.hasFreshMood {
                        Image(systemName: mood.symbolName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .buttonStyle(.glass)
            .tint(PipColor.ink)
            .accessibilityLabel("\(appState.identity.name). Sit together.")
            Spacer()
        }
    }

    private var moodButton: some View {
        Button {
            Haptics.light()
            showMoodPicker = true
        } label: {
            HStack(spacing: 10) {
                if let entry = appState.latestEntry, appState.hasFreshMood {
                    PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: entry.mood, intensity: entry.intensity, identity: appState.identity), showsShadow: false, framing: .face)
                        .frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.intensity.phrase(for: entry.mood).capitalizedFirst)
                            .font(PipFont.headline)
                        Text(entry.timestamp, style: .relative)
                            .font(PipFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "face.smiling")
                        .font(.title3)
                    Text("How are you feeling?")
                        .font(PipFont.headline)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: 360)
        }
        .buttonStyle(.glass)
        .tint(PipColor.ink)
        .accessibilityLabel(appState.hasFreshMood ? "Update your mood" : "Log your mood")
    }

    private var petAccessibilityLabel: String {
        let mood = appState.displayedState.mood
        return "\(appState.identity.name) \(mood.petDescription)."
    }
}

/// Wraps the scene in a frame clock, honouring Reduce Motion.
struct PetSceneWithClock: View {
    var identity: PetIdentity
    var state: PetMoodState
    var petScale: CGFloat = 0.62
    var petVerticalPosition: CGFloat = 0.49
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            PetSceneView(identity: identity, state: state, time: nil, petScale: petScale, petVerticalPosition: petVerticalPosition)
                .animation(.smooth(duration: 0.6), value: state.rig)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                PetSceneView(identity: identity, state: state, time: context.date.timeIntervalSinceReferenceDate, petScale: petScale, petVerticalPosition: petVerticalPosition)
                    .animation(.spring(duration: 0.75, bounce: 0.25), value: state.rig)
            }
        }
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
