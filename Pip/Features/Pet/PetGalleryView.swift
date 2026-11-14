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

/// Reproducible all-species live review of physical reading-object changes.
struct PetHandlingGalleryView: View {
    private var stances: [PetStance] {
        if ProcessInfo.processInfo.environment["PIP_HANDLING_SCENARIO"] == "blanket" {
            return [.mood(.calm, .moderate), .mood(.sad, .moderate), .life(.reading), .mood(.tired, .moderate), .life(.sleeping), .mood(.neutral, .moderate)]
        }
        return [.mood(.calm, .moderate), .life(.reading), .mood(.neutral, .moderate), .mood(.calm, .moderate), .life(.sleeping), .mood(.neutral, .moderate)]
    }
    @State private var index = 0
    @State private var previous: PetStance?
    @State private var since = Date.distantPast

    var body: some View {
        VStack(spacing: 8) {
            ForEach(PetSpecies.allCases) { species in
                PetStage(scene: PetScene(species: species, stance: stances[index], previous: previous, stanceSince: since),
                         petScale: 0.7, floor: 0.85, showsFoliage: false, showsSeason: false)
                    .frame(height: 220)
                    .overlay(alignment: .topLeading) { Text(species.defaultName).font(.headline).padding(8) }
            }
            Text(stances[index].describe("Review")).font(.caption)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.2))
                guard !Task.isCancelled else { return }
                previous = stances[index]
                index = (index + 1) % stances.count
                since = .now
            }
        }
    }
}
#endif
