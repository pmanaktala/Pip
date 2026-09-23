#if DEBUG
import SwiftUI

/// Developer gallery: every stance for a species, live. Used to review artwork on device.
struct PetGalleryView: View {
    @State private var species: PetSpecies = PetSpecies(rawValue: ProcessInfo.processInfo.environment["PIP_GALLERY_SPECIES"] ?? "") ?? .penguin
    @State private var animated = true

    private var stances: [PetStance] {
        Mood.allCases.map { .mood($0, .moderate) } + PetActivity.allCases.map { .life($0) } + [.meditating]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(stances, id: \.self) { stance in
                        VStack(spacing: 2) {
                            LivePetView(scene: PetScene(species: species, stance: stance), paused: !animated)
                                .frame(width: 110, height: 110)
                            Text(stance.describe(species.defaultName))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(4)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Species", selection: $species) {
                        ForEach(PetSpecies.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle("Animate", isOn: $animated)
                }
            }
        }
    }
}

#Preview {
    PetGalleryView()
}
#endif
