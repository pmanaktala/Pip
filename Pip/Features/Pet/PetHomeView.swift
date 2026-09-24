import SwiftUI

/// The Pet tab: your pet, large, under a native large title, with one primary action.
///
/// Structure follows the platform (large title, glass toolbar buttons, a scroll view) and the
/// skin stays calm: the only strong colour on the screen is the mood mark on the primary action.
struct PetHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @State private var showPlay = false
    /// The evening the goodnight card was put away (it comes back the next night).
    @AppStorage("goodnight.dismissed") private var goodnightDismissed = ""
    @State private var playMode: PlayView.Mode = .play
    @State private var showPets = false
    @State private var showWidgets = false
    @State private var touch = TouchState()
    @State private var purr: Task<Void, Never>?
    @State private var listening: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    /// A finger on the room: where it started, whether it began on the pet, whether it moved.
    struct TouchState {
        var began: Date?
        var start: CGPoint = .zero
        var onHead = false
        var onBody = false
        var moved = false
        var hold: Task<Void, Never>?
        var onPet: Bool { onHead || onBody }
    }

    private var mood: Mood? { appState.hasFreshMood ? appState.latestEntry?.mood : nil }
    private var petScale: CGFloat { appState.isPickingMood ? 0.42 : 0.84 }
    private var floor: CGFloat { appState.isPickingMood ? 0.43 : 0.7 }

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
                        playMode = .play
                        showPlay = true
                    } label: {
                        Label("Play with \(appState.identity.name)", systemImage: "tennisball.fill")
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
            .fullScreenCover(isPresented: $showPlay) {
                PlayView(mode: playMode)
            }
            .onChange(of: appState.presentSit, initial: true) { _, present in
                // "Sit together" links (Live Activity, notifications) open straight into Meditate.
                if present { playMode = .meditate; showPlay = true; appState.presentSit = false }
            }
            #if DEBUG
            .onAppear {
                switch ProcessInfo.processInfo.environment["PIP_DEBUG"] {
                case "pets": showPets = true
                case "sit", "meditate": playMode = .meditate; showPlay = true
                case "play", "fetch", "bubbles", "treat": playMode = .play; showPlay = true
                case "widgets": showWidgets = true
                case "poke":
                    Task { try? await Task.sleep(for: .seconds(1.5)); appState.pet.tap(onHead: true) }
                case "react":
                    Task { try? await Task.sleep(for: .seconds(1.5)); appState.log(mood: .excited) }
                default: break
                }
            }
            #endif
        }
    }

    // MARK: Room

    /// The whole tab is the pet's room. Only the pet answers touch: a tap on its head is a boop,
    /// on its body a tickle, and a finger that rests or strokes is petting. A tap anywhere else
    /// just draws its eyes (Bible §6).
    private var room: some View {
        GeometryReader { geo in
            // While the mood sheet is up the camera tilts down: the pet rises into the visible
            // part of the screen so its reaction is the first thing you see.
            ZStack {
                PetRoom(mood: mood, horizon: floor)
                PetStage(scene: appState.pet.scene, petScale: petScale, floor: floor, showsRoom: false)
            }
            .contentShape(Rectangle())
            .animation(.spring(duration: 0.55, bounce: 0.12), value: appState.isPickingMood)
            .gesture(touchGesture(in: geo.size))
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel(appState.pet.statusLine)
        .accessibilityHint("Double tap to boop \(appState.identity.name).")
        .accessibilityAction { boop(onHead: true) }
        .accessibilityAction(named: "Pet \(appState.identity.name)") {
            startPetting()
            Task { try? await Task.sleep(for: .seconds(2)); stopPetting() }
        }
        .accessibilitySortPriority(1)
        .onAppear {
            appState.pet.startClock()
            appState.pet.arrive(now: .now.addingTimeInterval(0.35))
            // While the pet is on screen, notice when you start or stop listening to something.
            listening = Task { @MainActor in
                while !Task.isCancelled {
                    appState.checkListening()
                    try? await Task.sleep(for: .seconds(6))
                }
            }
        }
        .onDisappear { appState.pet.stopClock(); listening?.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { appState.pet.arrive(now: .now.addingTimeInterval(0.3)); appState.pet.startClock() }
            else if phase == .background { appState.pet.stopClock() }
        }
    }

    private func touchGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let species = appState.identity.species
                let head = PetStage.headRect(in: size, species: species, petScale: petScale, floor: floor)
                if touch.began == nil {
                    touch.began = .now
                    touch.start = value.location
                    touch.onHead = head.insetBy(dx: -10, dy: -10).contains(value.location)
                    touch.onBody = !touch.onHead && PetStage.bodyRect(in: size, species: species, petScale: petScale, floor: floor).insetBy(dx: -8, dy: -8).contains(value.location)
                    if touch.onPet {
                        // A still finger sends no more changes, so the hold is timed rather than polled.
                        touch.hold = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.4))
                            guard !Task.isCancelled, touch.began != nil, touch.onPet else { return }
                            startPetting()
                        }
                    }
                }
                // Eyes follow the finger, wherever it is.
                appState.pet.look(at: CGPoint(x: (value.location.x - head.midX) / (size.width * 0.4),
                                              y: (value.location.y - head.midY) / (size.height * 0.3)))
                if hypot(value.location.x - touch.start.x, value.location.y - touch.start.y) > 14 {
                    touch.moved = true
                    // A stroke across the pet is petting.
                    if touch.onPet, !appState.pet.isPetting { startPetting() }
                }
            }
            .onEnded { _ in
                touch.hold?.cancel()
                if appState.pet.isPetting {
                    stopPetting()
                } else if touch.onPet, !touch.moved {
                    boop(onHead: touch.onHead)
                }
                appState.pet.look(at: nil)
                touch = TouchState()
            }
    }

    private func boop(onHead: Bool) {
        Haptics.soft()
        appState.pet.tap(onHead: onHead)
    }

    private func startPetting() {
        guard !appState.pet.isPetting else { return }
        appState.pet.beginPetting()
        Haptics.soft()
        purr = Task { @MainActor in
            // A slow purr in the fingertips for as long as the hand stays.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.7))
                guard !Task.isCancelled else { return }
                Haptics.soft()
            }
        }
    }

    private func stopPetting() {
        purr?.cancel()
        purr = nil
        appState.pet.endPetting()
    }

    /// The name floats over the sky like a large title; the line under it is who they are.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(appState.identity.name)
                .font(PipFont.display)
            // While the mood sheet is up the pet rises into this space: keep the line out of its way.
            if !appState.isPickingMood {
                Text(appState.pet.statusPhrase)
                    .font(PipFont.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                    .animation(.smooth(duration: 0.5), value: appState.pet.statusPhrase)
            }
        }
        // The name and line sit over the sky; at the largest text sizes they stop growing before
        // they reach the pet (everything else in the app keeps scaling).
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.horizontal, PipSpacing.l)
        .padding(.top, PipSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(2)
    }

    // MARK: Controls

    /// What floats over the floor: once there is more than one, today's faces.
    /// The action itself lives in the tab bar.
    private var controls: some View {
        Group {
            if PetDay.isBedtime(.now), !appState.todayEntries.isEmpty, goodnightDismissed != Self.goodnightDay() {
                GoodnightCard { withAnimation(.smooth) { goodnightDismissed = Self.goodnightDay() } }
            } else {
                todayFaces
            }
        }
            .frame(maxWidth: 520)
            .padding(.horizontal, PipSpacing.l)
            .padding(.bottom, PipSpacing.m)
            .frame(maxWidth: .infinity)
    }

    /// The evening a goodnight belongs to: after midnight it still counts as the night before.
    static func goodnightDay(_ date: Date = .now) -> String {
        date.addingTimeInterval(-6 * 3600).formatted(.iso8601.year().month().day())
    }

    @ViewBuilder
    private var todayFaces: some View {
        if appState.todayEntries.count > 1 {
            // Spaced, not stacked: each face has to be readable at a glance.
            HStack(spacing: 6) {
                ForEach(appState.todayEntries.sorted { $0.timestamp < $1.timestamp }.suffix(6)) { entry in
                    PetView(species: appState.identity.species, mood: entry.mood, intensity: entry.intensity)
                        .frame(width: 30, height: 30)
                        .padding(3)
                        .background(MoodColor.soft(entry.mood, scheme: scheme), in: Circle())
                        .clipShape(Circle())
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

}

/// A button that squishes under the finger — every primary action in Pip should feel physical.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.4), value: configuration.isPressed)
    }
}


/// Bedtime on the Pet tab, once you've logged something today: the pet says goodnight with one
/// plain sentence about your day (the same on-device words as History, or a simple fallback) and
/// today's faces. No scores, no advice. It shows once an evening: it puts itself away after 15
/// seconds, or when you close it, and comes back the next night.
struct GoodnightCard: View {
    var onDismiss: () -> Void = {}
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var scheme
    @State private var words: String?

    private var entries: [MoodEntry] { appState.todayEntries.sorted { $0.timestamp < $1.timestamp } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PetPoseView(species: appState.identity.species, pose: PetStance.life(.windingDown).holds(appState.identity.species)[0], wear: .nightcap, framing: .face, showsShadow: false)
                    .frame(width: 34, height: 34)
                Text("Goodnight from \(appState.identity.name)")
                    .font(PipFont.headline)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss goodnight")
            }
            Text(words ?? Self.fallback(entries.map(\.mood)))
                .font(PipFont.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            HStack(spacing: 6) {
                ForEach(entries.suffix(6)) { entry in
                    PetView(species: appState.identity.species, mood: entry.mood, intensity: entry.intensity)
                        .frame(width: 26, height: 26)
                        .padding(2)
                        .background(MoodColor.soft(entry.mood, scheme: scheme), in: Circle())
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .contain)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .task(id: entries.map(\.id)) { await write() }
        .task {
            // Seen once is enough: it tucks itself away after a little while, for the rest of the night.
            try? await Task.sleep(for: .seconds(15))
            if !Task.isCancelled { onDismiss() }
        }
    }

    /// "Today: calm, then happy." — the day's feelings in order, without repeats.
    static func fallback(_ moods: [Mood]) -> String {
        var seen: [Mood] = []
        for m in moods where seen.last != m { seen.append(m) }
        let names = seen.suffix(3).map { $0.displayName.lowercased() }
        guard let first = names.first else { return "Sleep well." }
        return names.count == 1 ? "Today felt \(first). Sleep well." : "Today: \(names.dropLast().joined(separator: ", ")), then \(names.last!). Sleep well."
    }

    private func write() async {
        guard appState.preferences.petWordsEnabled else { return }
        var hasher = Hasher()
        for e in entries { hasher.combine(e.id); hasher.combine(e.moodRaw); hasher.combine(e.note ?? "") }
        let key = "goodnight.\(Date.now.formatted(.iso8601.year().month().day())).\(hasher.finalize())"
        let input = entries.map {
            PetWords.Entry(dayName: "Today", partOfDay: MoodHistory.DayPart.part(of: $0.timestamp).displayName.lowercased(),
                           mood: $0.mood.displayName.lowercased(), intensity: $0.intensity.adverb ?? "",
                           contexts: $0.contexts.map { $0.displayName.lowercased() }, note: $0.note)
        }
        guard let text = await PetWords.line(kind: .day, key: key, petName: appState.identity.name,
                                             species: appState.identity.species.displayName.lowercased(), entries: input),
              !Task.isCancelled else { return }
        withAnimation(.smooth) { words = text }
    }
}
