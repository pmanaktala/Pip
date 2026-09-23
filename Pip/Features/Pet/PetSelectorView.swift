import SwiftUI

/// Swipe between pets; each one previews its personality. Choosing takes effect immediately.
struct PetSelectorView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: PetSpecies = .penguin
    @State private var name = ""
    /// When each pet last said hello (it greets you as it scrolls into view).
    @State private var greetedAt: [PetSpecies: Date] = [:]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                ForEach(PetSpecies.allCases) { species in
                    PetCard(species: species, greetedAt: greetedAt[species])
                        .tag(species)
                        .padding(.horizontal, PipSpacing.m)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .safeAreaPadding(.top, PipSpacing.m)
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
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    Text("Your mood history stays with you.")
                        .font(PipFont.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, PipSpacing.xl)
            .animation(.smooth, value: selection == appState.identity.species)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Pets")
        .navigationBarTitleDisplayMode(.inline)
        .pipNavigationTransition()
        .onAppear {
            selection = appState.identity.species
            name = appState.identity.name
        }
        .onDisappear {
            if !name.isEmpty, name != appState.identity.name { appState.rename(name) }
        }
    }

    private func greet(_ species: PetSpecies) {
        greetedAt[species] = .now
    }
}

struct PetCard: View {
    var species: PetSpecies
    var greetedAt: Date?

    var body: some View {
        VStack(spacing: PipSpacing.s) {
            RoomWindow(scene: PetScene(species: species, stance: .mood(.happy, .slight), events: greetedAt.map { [PetEvent(.arrive, at: $0)] } ?? []))
                .frame(height: 300)
                .padding(.top, PipSpacing.s)
            Text(species.defaultName)
                .font(PipFont.title)
            Text(species.displayName)
                .font(PipFont.caption)
                .opacity(0.7)
                .textCase(.uppercase)
            Text(species.blurb)
                .font(PipFont.body)
                .opacity(0.8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PipSpacing.l)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(species.defaultName), \(species.displayName). \(species.blurb)")
    }
}

/// A framed view into the pet's room, for cards and onboarding: the same world as the Pet tab,
/// seen through a rounded window.
struct RoomWindow: View {
    var scene: PetScene

    var body: some View {
        PetStage(scene: scene, petScale: 0.62, floor: 0.8, showsFoliage: false)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.primary.opacity(0.06)))
            .frame(maxWidth: 440)
    }
}
