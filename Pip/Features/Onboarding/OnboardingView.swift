import SwiftUI

/// Welcome → pick a pet → name it → optional Health → optional notifications → start.
/// Every permission is skippable; nothing is requested before its step.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(HealthSyncService.self) private var health
    @Environment(NotificationService.self) private var notifications

    private enum Step: Int, CaseIterable { case welcome, pet, name, health, notifications }

    @State private var step: Step = .welcome
    @State private var species: PetSpecies = .penguin
    @State private var name = ""
    @State private var scene = PetScene(species: .penguin, stance: .mood(.happy, .slight))
    @FocusState private var nameFocused: Bool

    /// The horizon rises while the keyboard is up, so the pet stays in view as you name it.
    private var floor: CGFloat { nameFocused ? 0.3 : 0.5 }

    /// The whole of onboarding happens in the pet's room: the same sky as the Pet tab, one live pet
    /// standing on the floor, and each step in a glass panel beneath it. The pet takes part —
    /// it waves hello, hops in when you pick it, listens while you type its name.
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                PetRoom(mood: nil, horizon: floor)
                    .ignoresSafeArea()
                PetStage(scene: scene, petScale: 0.72, floor: floor, showsRoom: false)
                    .ignoresSafeArea()
                    .accessibilityElement()
                    .accessibilityLabel("\(species.defaultName), \(species.displayName)")
                    .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                        guard step == .pet, abs(value.translation.width) > abs(value.translation.height) else { return }
                        choose(offset: value.translation.width < 0 ? 1 : -1)
                    })

                VStack(spacing: PipSpacing.m) {
                    content
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        .id(step)
                    controls
                }
                .frame(maxWidth: 480)
                .padding(PipSpacing.l)
                .glassEffect(.regular, in: .rect(cornerRadius: 32))
                .padding(.horizontal, PipSpacing.m)
                .padding(.bottom, PipSpacing.s)
                .frame(maxHeight: geo.size.height * 0.5, alignment: .bottom)
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.1), value: step)
        .animation(.smooth(duration: 0.35), value: nameFocused)
        .onAppear {
            greet(.arrive, after: 0.6)
            #if DEBUG
            // Screenshot automation: PIP_ONBOARDING_STEP=0…4
            if let raw = ProcessInfo.processInfo.environment["PIP_ONBOARDING_STEP"].flatMap(Int.init), let s = Step(rawValue: raw) { step = s }
            #endif
        }
    }

    /// Plays something on the pet in the room.
    private func greet(_ kind: PetEvent.Kind, after delay: TimeInterval = 0) {
        let at = Date.now.addingTimeInterval(delay)
        scene.events.removeAll { at.timeIntervalSince($0.at) > 6 }
        scene.events.append(PetEvent(kind, at: at))
    }

    private func choose(offset: Int) {
        let all = PetSpecies.allCases
        let i = ((all.firstIndex(of: species) ?? 0) + offset + all.count) % all.count
        choose(all[i])
    }

    private func choose(_ s: PetSpecies) {
        guard s != species else { return }
        Haptics.selection()
        species = s
        scene.species = s
        greet(.hop)
        greet(.arrive, after: 0.35)
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            VStack(spacing: PipSpacing.s) {
                Text("Meet your mood companion")
                    .font(PipFont.display)
                    .multilineTextAlignment(.center)
                Text("A small pet who feels what you feel, and helps you notice it.")
                    .font(PipFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .pet:
            VStack(spacing: PipSpacing.s) {
                Text(species.defaultName)
                    .font(PipFont.title)
                    .contentTransition(.opacity)
                Text(species.blurb)
                    .font(PipFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 44, alignment: .top)
                HStack(spacing: 14) {
                    ForEach(PetSpecies.allCases) { s in
                        Button { choose(s) } label: {
                            PetView(species: s, mood: .happy)
                                .frame(width: 46, height: 46)
                                .padding(4)
                                .background(Circle().fill(s == species ? Color.accentColor.opacity(0.22) : Color.clear))
                                .overlay(Circle().strokeBorder(s == species ? Color.accentColor : Color.clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(s.defaultName), \(s.displayName)")
                        .accessibilityAddTraits(s == species ? .isSelected : [])
                    }
                }
                .animation(.smooth(duration: 0.25), value: species)
            }
        case .name:
            VStack(spacing: PipSpacing.s) {
                Text("Give them a name")
                    .font(PipFont.title)
                TextField(species.defaultName, text: $name)
                    .textFieldStyle(.plain)
                    .font(PipFont.title)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color(.secondarySystemFill), in: Capsule())
                    .onSubmit { advance() }
                    // It listens while you type, ears up.
                    .onChange(of: name) { greet(.listening) }
                Text("Or keep \(species.defaultName). Either is lovely.")
                    .font(PipFont.footnote)
                    .foregroundStyle(.secondary)
            }
        case .health:
            permissionStep(
                symbol: "heart.text.square",
                title: "Apple Health, optionally",
                body: "Each mood you log can also be saved as a State of Mind entry in Apple Health. Pip only writes; it never reads your Health data. You can change this any time in Settings.")
        case .notifications:
            permissionStep(
                symbol: "bell.badge",
                title: "The occasional hello",
                body: "\(displayName) can send a rare, gentle note — like when they’ve found a comfortable spot. Never a reminder to log your mood. Off by default; you choose.")
        }
    }

    private func permissionStep(symbol: String, title: String, body: String) -> some View {
        VStack(spacing: PipSpacing.s) {
            Label(title, systemImage: symbol)
                .font(PipFont.title)
                .labelStyle(.titleAndIcon)
                .multilineTextAlignment(.center)
            Text(body)
                .font(PipFont.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        switch step {
        case .welcome:
            VStack(spacing: PipSpacing.m) {
                primary("Let’s go") { advance() }
                footnote("Private by design. Your moods stay on your device.", symbol: "lock.fill")
            }
        case .pet:
            primary("This one") { advance() }
        case .name:
            primary("Continue") { advance() }
        case .health:
            VStack(spacing: PipSpacing.s) {
                primary("Turn on Health sync") {
                    Task {
                        let ok = await health.requestAuthorization()
                        appState.preferences.healthSyncEnabled = ok
                        advance()
                    }
                }
                secondary("Not now") { advance() }
            }
        case .notifications:
            VStack(spacing: PipSpacing.s) {
                primary("Allow the occasional hello") {
                    Task {
                        let ok = await notifications.requestAuthorization()
                        appState.preferences.notificationsCompany = ok
                        appState.preferences.notificationsSleepy = ok
                        appState.preferences.notificationsMoments = ok
                        finish()
                    }
                }
                secondary("Skip") { finish() }
                footnote("Pip is company for noticing how you feel — not therapy, and never a substitute for care.", symbol: "heart")
            }
        }
    }

    /// The small print, in the place Apple puts it: under the action, never in the headline.
    private func footnote(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(PipFont.footnote)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .labelStyle(.titleAndIcon)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 360)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PipFont.headline)
                .frame(maxWidth: 360)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.extraLarge)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(PipFont.headline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }

    private var displayName: String { name.trimmingCharacters(in: .whitespaces).isEmpty ? species.defaultName : name }

    private func advance() {
        nameFocused = false
        Haptics.light()
        guard let next = Step(rawValue: step.rawValue + 1) else { finish(); return }
        if step == .name {
            appState.selectPet(species, name: name.nilIfEmpty)
            // Happy with its name.
            greet(.logged(.happy, .moderate))
        }
        if step == .pet { greet(.poke(head: true, variant: 1)) }
        if next == .health || next == .notifications { scene.stance = .mood(.calm, .slight) }
        if next == .health, !health.isAvailable {
            step = .notifications
        } else {
            step = next
        }
    }

    private func finish() {
        appState.selectPet(species, name: name.nilIfEmpty)
        Haptics.success()
        appState.preferences.hasCompletedOnboarding = true
    }
}
