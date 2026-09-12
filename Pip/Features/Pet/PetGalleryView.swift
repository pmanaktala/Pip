import SwiftUI

/// Developer gallery: every mood × intensity for a species. Used to tune artwork.
struct PetGalleryView: View {
    @State private var species: PetSpecies = .cat
    @State private var animated = true

    private struct Cell { let mood: Mood; let intensity: MoodIntensity; var id: String { "\(mood.rawValue)-\(intensity.rawValue)" } }
    private var cells: [Cell] {
        let filter = ProcessInfo.processInfo.environment["PIP_GALLERY_MOODS"]?.split(separator: ",").compactMap { Mood(rawValue: String($0)) } ?? []
        let moods = filter.isEmpty ? Mood.allCases : filter
        return moods.flatMap { m in MoodIntensity.allCases.map { Cell(mood: m, intensity: $0) } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(cells, id: \.id) { cell in
                        let mood = cell.mood, intensity = cell.intensity
                        do {
                            let identity = PetIdentity(species: species)
                            let state = PetStateResolver.resolve(mood: mood, intensity: intensity, identity: identity)
                            VStack(spacing: 2) {
                                AnimatedPetView(identity: identity, state: state, isPaused: !animated)
                                    .frame(width: 110, height: 110)
                                Text(intensity.phrase(for: mood))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(4)
                            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
                        }
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
