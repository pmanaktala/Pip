import SwiftUI

/// Actual shared stage at app and widget proportions, across the whole cast.
enum LabRooms {
    @MainActor static func sheet() -> some View {
        VStack(spacing: 16) {
            ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                HStack(spacing: 12) {
                    ForEach(PetSpecies.allCases) { species in
                        VStack(spacing: 8) {
                            stage(species, width: 250, height: 420, scale: 0.84, floor: 0.7)
                            stage(species, width: 170, height: 170, scale: 0.78, floor: 0.82)
                        }.environment(\.colorScheme, scheme)
                    }
                }
            }
        }.padding(16).background(Color.gray.opacity(0.15))
    }
    static func stage(_ species: PetSpecies, width: CGFloat, height: CGFloat, scale: CGFloat, floor: CGFloat) -> some View {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 14))!
        let scene = PetScene(species: species, stance: .mood(.calm, .moderate))
        return PetStage(scene: scene, live: false, petScale: scale, floor: floor, date: date, showsSeason: false)
            .frame(width: width, height: height).clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
