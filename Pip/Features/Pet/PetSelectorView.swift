import SwiftUI

/// Swipe between pets; each one previews its personality. Choosing takes effect immediately.
struct PetSelectorView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: PetSpecies = .cat
    @State private var name = ""
    @State private var greeting: [PetSpecies: PetMoodState] = [:]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                ForEach(PetSpecies.allCases) { species in
                    PetCard(species: species, state: greeting[species] ?? previewState(for: species))
                        .tag(species)
                        .padding(.horizontal, PipSpacing.m)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .onChange(of: selection) { _, new in
                Haptics.selection()
                greet(new)
            }

            VStack(spacing: PipSpacing.m) {
                if selection == appState.identity.species {
                    HStack {
                        TextField(selection.defaultName, text: $name)
                            .textFieldStyle(.plain)
                            .font(PipFont.headline)
                            .multilineTextAlignment(.center)
                            .submitLabel(.done)
                            .onSubmit { appState.rename(name) }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: 260)
                            .glassEffect(.regular, in: .capsule)
                            .accessibilityLabel("Pet name")
                    }
                    Text("This is your pet. Tap the name to change it.")
                        .font(PipFont.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        appState.selectPet(selection)
                        name = appState.identity.name
                    } label: {
                        Text("Choose \(selection.defaultName)")
                            .font(PipFont.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glassProminent)
                    Text("Your mood history stays with you.")
                        .font(PipFont.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, PipSpacing.xl)
            .animation(.smooth, value: selection == appState.identity.species)
        }
        .background(LinearGradient(colors: [PipColor.sceneTop, PipColor.sceneBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .navigationTitle("Pets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selection = appState.identity.species
            name = appState.identity.name
        }
        .onDisappear {
            if !name.isEmpty, name != appState.identity.name { appState.rename(name) }
        }
    }

    private func previewState(for species: PetSpecies) -> PetMoodState {
        PetStateResolver.resolve(mood: .calm, intensity: .slight, identity: PetIdentity(species: species))
    }

    /// A little hello when a pet scrolls into view, then back to resting.
    private func greet(_ species: PetSpecies) {
        withAnimation(.spring(duration: 0.6, bounce: 0.35)) {
            greeting[species] = PetStateResolver.resolve(mood: .happy, intensity: .strong, identity: PetIdentity(species: species))
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.smooth(duration: 0.8)) { greeting[species] = nil }
        }
    }
}

struct PetCard: View {
    var species: PetSpecies
    var state: PetMoodState

    var body: some View {
        VStack(spacing: PipSpacing.s) {
            AnimatedPetView(identity: PetIdentity(species: species), state: state)
                .frame(maxWidth: 300)
                .padding(.top, PipSpacing.m)
            Text(species.defaultName)
                .font(PipFont.title)
            Text(species.displayName)
                .font(PipFont.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(species.blurb)
                .font(PipFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PipSpacing.l)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(species.defaultName), \(species.displayName). \(species.blurb)")
    }
}
