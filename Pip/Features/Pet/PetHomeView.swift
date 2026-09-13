import SwiftUI

/// The Pet tab: your pet, large, on a canvas tinted by how you feel, with one primary action.
struct PetHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @State private var showMoodPicker = false
    @State private var showSitWithPet = false
    @State private var showPets = false
    @State private var showWidgets = false

    private var mood: Mood? { appState.hasFreshMood ? appState.latestEntry?.mood : nil }

    var body: some View {
        NavigationStack {
            ZStack {
                canvas

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, PipSpacing.l)
                        .padding(.top, PipSpacing.s)
                    Spacer(minLength: 0)
                }

                PetSceneWithClock(identity: appState.identity, state: appState.displayedState,
                                  petScale: showMoodPicker ? 0.62 : 0.86, petVerticalPosition: showMoodPicker ? 0.3 : 0.5, showsFloor: true)
                    .frame(maxWidth: 440)
                    .padding(.top, 40)
                    .padding(.bottom, 120)
                    .animation(.spring(duration: 0.5, bounce: 0.15), value: showMoodPicker)
                    .contentShape(Rectangle())
                    .onTapGesture { appState.pokePet() }
                    .accessibilityElement()
                    .accessibilityLabel(petAccessibilityLabel)
                    .accessibilityHint("Double tap to say hello.")
                    .accessibilityAddTraits(.isImage)

                VStack {
                    Spacer()
                    moodButton
                        .padding(.horizontal, PipSpacing.l)
                        .padding(.bottom, PipSpacing.m)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showPets) { PetSelectorView() }
            #if DEBUG
            .navigationDestination(isPresented: $showWidgets) { WidgetGalleryView() }
            #endif
            .sheet(isPresented: $showMoodPicker) {
                MoodPickerSheet()
                    .presentationDetents([.fraction(0.58), .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.58)))
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showSitWithPet) {
                SitWithPetView()
            }
            .onChange(of: appState.pendingRoute, initial: true) { _, route in
                guard let route else { return }
                if route == .sit { showSitWithPet = true }
                appState.pendingRoute = nil
            }
            #if DEBUG
            .onAppear {
                switch ProcessInfo.processInfo.environment["PIP_DEBUG"] {
                case "picker": showMoodPicker = true
                case "pets": showPets = true
                case "sit": showSitWithPet = true
                case "widgets": showWidgets = true
                case "poke":
                    Task { try? await Task.sleep(for: .seconds(1.5)); appState.pokePet() }
                case "react":
                    Task { try? await Task.sleep(for: .seconds(1.5)); appState.log(mood: .excited) }
                default: break
                }
            }
            #endif
        }
    }

    // MARK: Canvas

    /// The whole tab takes on the current mood, gently: a wash from the top that fades into the floor.
    private var canvas: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(colors: [
                mood.map { MoodColor.bold($0).opacity(scheme == .dark ? 0.18 : 0.14) } ?? PipColor.sceneTop.opacity(scheme == .dark ? 0.5 : 0.8),
                mood.map { MoodColor.bold($0).opacity(0.02) } ?? PipColor.sceneBottom.opacity(scheme == .dark ? 0.3 : 0.4),
            ], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 1.0), value: mood)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: PipSpacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.identity.name)
                    .font(PipFont.display)
                Text(statusLine)
                    .font(PipFont.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Button {
                Haptics.light()
                showSitWithPet = true
            } label: {
                Image(systemName: "sofa.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Sit with \(appState.identity.name)")
        }
    }

    private var statusLine: String {
        if let entry = appState.latestEntry, appState.hasFreshMood {
            return "\(entry.mood.petDescription.capitalizedFirst) · \(entry.timestamp.formatted(.relative(presentation: .named)))"
        }
        return "Ready when you are."
    }

    // MARK: Primary action

    private var moodButton: some View {
        Button {
            Haptics.light()
            showMoodPicker = true
        } label: {
            HStack(spacing: 12) {
                if let entry = appState.latestEntry, appState.hasFreshMood {
                    PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: entry.mood, intensity: entry.intensity, identity: appState.identity), showsShadow: false, framing: .badge)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.25), in: Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        Text(entry.intensity.phrase(for: entry.mood).capitalizedFirst)
                            .font(PipFont.headline)
                        Text("Tap to update")
                            .font(PipFont.caption)
                            .opacity(0.8)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.headline.weight(.bold))
                } else {
                    Image(systemName: "face.smiling.inverse")
                        .font(.title2)
                    Text("How are you feeling?")
                        .font(PipFont.headline)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.headline.weight(.bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 420)
            .background(buttonColor, in: RoundedRectangle(cornerRadius: PipRadius.card, style: .continuous))
            .shadow(color: buttonColor.opacity(0.35), radius: 16, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(appState.hasFreshMood ? "Update your mood" : "Log your mood")
        .animation(.smooth(duration: 0.6), value: mood)
    }

    private var buttonColor: Color {
        mood.map(MoodColor.bold) ?? Color.accentColor
    }

    private var petAccessibilityLabel: String {
        "\(appState.identity.name) \(appState.displayedState.mood.petDescription)."
    }
}

/// A button that squishes under the finger — every primary action in Pip should feel physical.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Wraps the scene in a frame clock, honouring Reduce Motion.
struct PetSceneWithClock: View {
    var identity: PetIdentity
    var state: PetMoodState
    var petScale: CGFloat = 0.62
    var petVerticalPosition: CGFloat = 0.49
    var showsFloor = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            PetSceneView(identity: identity, state: state, time: nil, petScale: petScale, petVerticalPosition: petVerticalPosition, showsFloor: showsFloor, showsBackground: false)
                .animation(.smooth(duration: 0.6), value: state.rig)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                PetSceneView(identity: identity, state: state, time: context.date.timeIntervalSinceReferenceDate, petScale: petScale, petVerticalPosition: petVerticalPosition, showsFloor: showsFloor, showsBackground: false)
                    .animation(.smooth(duration: 0.7), value: state.rig)
            }
        }
    }
}
