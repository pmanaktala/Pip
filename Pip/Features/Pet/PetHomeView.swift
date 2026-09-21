import SwiftUI

/// The Pet tab: your pet, large, under a native large title, with one primary action.
///
/// Structure follows the platform (large title, glass toolbar buttons, a scroll view) and the
/// skin stays calm: the only strong colour on the screen is the mood mark on the primary action.
struct PetHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @State private var showSitWithPet = false
    @State private var showPets = false
    @State private var showWidgets = false
    @State private var touchBegan: Date?
    @State private var touchMoved = false
    @State private var holdTask: Task<Void, Never>?

    private var mood: Mood? { appState.hasFreshMood ? appState.latestEntry?.mood : nil }
    private let petScale: CGFloat = 0.66
    private let petVerticalPosition: CGFloat = 0.47

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                room
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                controls
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                        showSitWithPet = true
                    } label: {
                        Label("Sit with \(appState.identity.name)", systemImage: "figure.mind.and.body")
                    }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPets = true
                    } label: {
                        Label("Pets", systemImage: "pawprint")
                    }
                }
            }
            .navigationDestination(isPresented: $showPets) { PetSelectorView() }
            #if DEBUG
            .navigationDestination(isPresented: $showWidgets) { WidgetGalleryView() }
            #endif
            .fullScreenCover(isPresented: $showSitWithPet) {
                SitWithPetView()
            }
            .onChange(of: appState.presentSit, initial: true) { _, present in
                if present { showSitWithPet = true; appState.presentSit = false }
            }
            #if DEBUG
            .onAppear {
                switch ProcessInfo.processInfo.environment["PIP_DEBUG"] {
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

    // MARK: Room

    /// The whole tab is the pet's room. A tap says hello; a held finger is petting; while a
    /// finger is anywhere in the room the pet's eyes follow it.
    private var room: some View {
        GeometryReader { geo in
            // While the mood sheet is up the camera tilts down: the pet rises into the visible
            // third of the screen so its reaction to the tap is the first thing you see.
            PetSceneWithClock(identity: appState.identity, state: appState.displayedState,
                              petScale: appState.isPickingMood ? 0.5 : petScale, petVerticalPosition: appState.isPickingMood ? 0.27 : petVerticalPosition, showsFloor: true, showsBackground: true)
                .contentShape(Rectangle())
                .animation(.spring(duration: 0.55, bounce: 0.12), value: appState.isPickingMood)
                .gesture(touch(in: geo.size))
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel(petAccessibilityLabel)
        .accessibilityHint("Double tap to say hello.")
        .accessibilityAction { appState.pokePet() }
        .accessibilityAction(named: "Pet \(appState.identity.name)") {
            appState.startPetting()
            Task { try? await Task.sleep(for: .seconds(2)); appState.stopPetting() }
        }
        .accessibilitySortPriority(1)
    }

    /// One recogniser for all three: it starts on touch-down, so the eyes follow immediately;
    /// a hold longer than a beat (or a stroke) becomes petting; a quick release is a tap.
    private func touch(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let head = CGPoint(x: size.width / 2, y: size.height * petVerticalPosition - size.width * petScale * 0.2)
                appState.look(at: CGPoint(x: (value.location.x - head.x) / (size.width * 0.38),
                                          y: (value.location.y - head.y) / (size.height * 0.3)))
                if touchBegan == nil {
                    touchBegan = .now
                    // A still finger sends no more changes, so the hold is timed rather than polled.
                    holdTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.45))
                        guard !Task.isCancelled, touchBegan != nil else { return }
                        appState.startPetting()
                    }
                }
                if abs(value.translation.width) + abs(value.translation.height) > 24 { touchMoved = true }
                let held = Date.now.timeIntervalSince(touchBegan ?? .now)
                if !appState.isPetting, touchMoved, held > 0.2 { appState.startPetting() }
            }
            .onEnded { _ in
                holdTask?.cancel()
                if appState.isPetting {
                    appState.stopPetting()
                } else if !touchMoved {
                    appState.pokePet()
                }
                appState.look(at: nil)
                touchBegan = nil
                touchMoved = false
            }
    }

    /// The name floats over the sky like a large title; the line under it is who they are.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(appState.identity.name)
                .font(PipFont.display)
            Text("\(appState.identity.species.displayName) · \(appState.identity.personality.displayName)")
                .font(PipFont.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, PipSpacing.l)
        .padding(.top, PipSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(2)
    }

    // MARK: Controls

    /// What floats over the floor: one quiet line and, once there is more than one, today's faces.
    /// The action itself lives in the tab bar accessory.
    private var controls: some View {
        VStack(spacing: 10) {
            statusLine
            todayFaces
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, PipSpacing.l)
        .padding(.bottom, PipSpacing.m)
        .frame(maxWidth: .infinity)
    }

    /// How they feel and since when, or what they are up to.
    private var statusLine: some View {
        Group {
            if let entry = appState.latestEntry, appState.hasFreshMood {
                HStack(spacing: 6) {
                    Circle().fill(MoodColor.bold(entry.mood)).frame(width: 7, height: 7)
                    Text("\(appState.identity.name) \(entry.mood.petDescription) · \(entry.timestamp.formatted(.relative(presentation: .named)))")
                }
            } else {
                Text(PetLife.describe(appState.identity.name, at: .now))
            }
        }
        .font(PipFont.callout)
        .foregroundStyle(.secondary)
        .contentTransition(.numericText())
        .animation(.smooth(duration: 0.4), value: mood)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var todayFaces: some View {
        if appState.todayEntries.count > 1 {
            HStack(spacing: -6) {
                ForEach(appState.todayEntries.sorted { $0.timestamp < $1.timestamp }.suffix(8)) { entry in
                    PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: entry.mood, intensity: entry.intensity, identity: appState.identity), showsShadow: false, framing: .face)
                        .frame(width: 26, height: 26)
                        .padding(2)
                        .background(MoodColor.soft(entry.mood, scheme: scheme), in: Circle())
                        .overlay(Circle().strokeBorder(Color(.systemBackground).opacity(0.9), lineWidth: 1.5))
                        .accessibilityLabel("\(entry.intensity.phrase(for: entry.mood).capitalizedFirst), \(entry.timestamp.formatted(date: .omitted, time: .shortened))")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("^[\(appState.todayEntries.count) moment](inflect: true) today")
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
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
    var showsBackground = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.self) private var environment

    /// 60 fps normally; 30 when the system asks for less (iOS 27's reduced-resource hint).
    private var frameInterval: Double {
        #if compiler(>=6.4)
        if #available(iOS 27, *), environment.systemPrefersReducedResourceUsage { return 1.0 / 30 }
        #endif
        return 1.0 / 60
    }

    var body: some View {
        if reduceMotion {
            PetSceneView(identity: identity, state: state, time: nil, petScale: petScale, petVerticalPosition: petVerticalPosition, showsFloor: showsFloor, showsBackground: showsBackground)
                .animation(.smooth(duration: 0.6), value: state.rig)
        } else {
            TimelineView(.animation(minimumInterval: frameInterval)) { context in
                PetSceneView(identity: identity, state: state, time: context.date.timeIntervalSinceReferenceDate, petScale: petScale, petVerticalPosition: petVerticalPosition, showsFloor: showsFloor, showsBackground: showsBackground, date: context.date)
                    .animation(.smooth(duration: 0.7), value: state.rig)
            }
        }
    }
}
