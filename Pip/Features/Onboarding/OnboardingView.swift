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
    @State private var wave = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: PipSpacing.l) {
                Spacer(minLength: 0)
                content
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    .id(step)
                Spacer(minLength: 0)
                controls
            }
            .padding(PipSpacing.l)
        }
        .animation(.spring(duration: 0.5, bounce: 0.1), value: step)
        .onAppear { wave = true }
    }

    /// Each step has its own colour; text is white on it.
    private var pageColor: Color {
        switch step {
        case .welcome: MoodColor.bold(.calm)
        case .pet: MoodColor.bold(.happy)
        case .name: MoodColor.bold(.excited)
        case .health: MoodColor.bold(.sad)
        case .notifications: MoodColor.bold(.neutral)
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            VStack(spacing: PipSpacing.m) {
                PetSceneWithClock(identity: PetIdentity(species: .penguin), state: PetStateResolver.resolve(mood: wave ? .happy : .calm, identity: PetIdentity(species: .penguin)), petScale: 0.78, petVerticalPosition: 0.59)
                    .frame(width: 260, height: 260)
                Text("Meet your mood companion")
                    .font(PipFont.display)
                    .multilineTextAlignment(.center)
                Text("Tell Pip how you feel. Your pet feels it with you, lives on your Home Screen, and keeps everything on your device.")
                    .font(PipFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .pet:
            VStack(spacing: PipSpacing.m) {
                Text("Pick your pet")
                    .font(PipFont.title)
                TabView(selection: $species) {
                    ForEach(PetSpecies.allCases) { s in
                        PetCard(species: s, state: PetStateResolver.resolve(mood: .happy, intensity: .slight, identity: PetIdentity(species: s)))
                            .tag(s)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
                .frame(height: 440)
                .onChange(of: species) { _, _ in Haptics.selection() }
            }
        case .name:
            VStack(spacing: PipSpacing.m) {
                AnimatedPetView(identity: PetIdentity(species: species), state: PetStateResolver.resolve(mood: .excited, intensity: .slight, identity: PetIdentity(species: species)))
                    .frame(width: 200, height: 200)
                Text("Give them a name")
                    .font(PipFont.title)
                TextField(species.defaultName, text: $name)
                    .textFieldStyle(.plain)
                    .font(PipFont.title)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .background(Color(.secondarySystemFill), in: Capsule())
                    .onSubmit { advance() }
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
        VStack(spacing: PipSpacing.m) {
            AnimatedPetView(identity: PetIdentity(species: species), state: PetStateResolver.resolve(mood: .calm, identity: PetIdentity(species: species)))
                .frame(width: 180, height: 180)
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(PipFont.title)
                .multilineTextAlignment(.center)
            Text(body)
                .font(PipFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        switch step {
        case .welcome:
            primary("Let’s go") { advance() }
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
            }
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PipFont.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: 360)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: PipRadius.card, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
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
        if step == .name { appState.selectPet(species, name: name.nilIfEmpty) }
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
