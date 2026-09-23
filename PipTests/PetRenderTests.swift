import SwiftUI
import Testing
import UIKit
@testable import Pip

/// Contact sheets from the real renderer, on the simulator. Set `PIP_ART_OUTPUT` to a path to
/// write one (every species in every stance at 150, 60 and 28 pt). PetLab (`tools/PetLab`)
/// renders the same art on the Mac for faster review.
@MainActor
struct PetRenderTests {
    @Test func contactSheetRenders() throws {
        let stances: [PetStance] = Mood.allCases.map { .mood($0, .moderate) } + [.life(.reading), .life(.sleeping), .life(.playing)]
        let content = VStack(alignment: .leading, spacing: 10) {
            ForEach(PetSpecies.allCases) { species in
                HStack(spacing: 8) {
                    ForEach(stances, id: \.self) { stance in
                        VStack(spacing: 3) {
                            PetView(species: species, stance: stance).frame(width: 150, height: 150)
                            HStack(spacing: 4) {
                                PetView(species: species, stance: stance, framing: .face, showsShadow: false).frame(width: 60, height: 60)
                                PetView(species: species, stance: stance, framing: .badge, showsShadow: false).frame(width: 28, height: 28)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(red: 0.94, green: 0.95, blue: 0.97))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        #expect(image.size.width > 1000)
        if let path = ProcessInfo.processInfo.environment["PIP_ART_OUTPUT"] {
            try #require(image.pngData()).write(to: URL(fileURLWithPath: path))
        }
    }
}
