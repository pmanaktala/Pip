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

                ScrollView {
                    VStack(spacing: 20) {
                        header
                        VStack(spacing: 4) {
                            Text("A little company.\nA little more you.")
                                .font(.system(.largeTitle, design: .serif, weight: .regular))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("A soft place for every kind of day.")
                                .font(PipFont.callout)
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                        }
                        .padding(.top, 4)

                        Button { appState.pokePet() } label: {
                            PetSceneWithClock(identity: appState.identity, state: appState.displayedState,
                                              petScale: 0.80, petVerticalPosition: 0.58, showsFloor: true)
                                .frame(height: 310)
                                .overlay(alignment: .bottom) {
                                    Label("Tap to say hello", systemImage: "hand.wave")
                                        .font(PipFont.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 3)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(petAccessibilityLabel)
                        .accessibilityHint("Double tap to say hello.")

                        moodButton
                        HStack(spacing: 12) {
                            Button { showSitWithPet = true } label: {
                                ritualLabel("Take a breath", subtitle: "A moment together", symbol: "wind")
                            }
                            Button { showPets = true } label: {
                                ritualLabel("Your companion", subtitle: "Meet the little ones", symbol: "pawprint")
                            }
                        }
                        .buttonStyle(PressableButtonStyle())
                        todayRibbon
                    }
                    .frame(maxWidth: 480)
                    .padding(.horizontal, PipSpacing.l)
                    .padding(.top, PipSpacing.s)
                    .padding(.bottom, PipSpacing.l)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
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
            .onChange(of: appState.presentSit, initial: true) { _, present in
                if present { showSitWithPet = true; appState.presentSit = false }
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
                Text("pip")
                    .font(.system(.title, design: .serif, weight: .semibold))
                Text("WITH " + appState.identity.name.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Button {
                Haptics.light()
                showSitWithPet = true
            } label: {
                Image(systemName: "wind")
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
            .foregroundStyle(MoodColor.onBold)
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
        mood.map(MoodColor.bold) ?? MoodColor.bold(.calm)
    }

    private func ritualLabel(_ title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).font(.title3).foregroundStyle(PipColor.inkSecondary)
            Text(title).font(PipFont.headline)
            Text(subtitle).font(PipFont.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.04)))
    }

    private var todayRibbon: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("The shape of today").font(PipFont.headline)
                Spacer()
                Text(appState.todayEntries.count.formatted() + " moments")
                    .font(PipFont.caption).foregroundStyle(.secondary)
            }
            if appState.todayEntries.isEmpty {
                Text("Every feeling has a place here. Start with this one.")
                    .font(PipFont.callout).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 5) {
                    ForEach(appState.todayEntries.suffix(12)) { entry in
                        Capsule().fill(MoodColor.bold(entry.mood).gradient)
                            .frame(height: 24)
                            .accessibilityLabel("\(entry.mood.displayName), \(entry.timestamp.formatted(date: .omitted, time: .shortened))")
                    }
                }
            }
        }
        .padding(.vertical, 8)
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
