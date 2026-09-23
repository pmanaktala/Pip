import SwiftUI
import Testing
import UIKit
@testable import Pip

/// A reproducible contact sheet for reviewing silhouettes and expression at multiple sizes.
@MainActor
struct CharacterRenderTests {
    @Test func characterSheetRenders() throws {
        let content = VStack(spacing: 12) {
            ForEach(PetSpecies.allCases) { species in
                HStack(spacing: 12) {
                    ForEach([Mood.neutral, .happy, .sad, .excited, .stressed], id: \.self) { mood in
                        let identity = PetIdentity(species: species)
                        VStack(spacing: 2) {
                            PetView(identity: identity, state: PetStateResolver.resolve(mood: mood, identity: identity))
                                .frame(width: 150, height: 150)
                            Text("\(species.defaultName) · \(mood.displayName)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color(red: 0.97, green: 0.95, blue: 0.91))
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        #expect(image.size.width > 700)
        if let path = ProcessInfo.processInfo.environment["PIP_ART_OUTPUT"] {
            try #require(image.pngData()).write(to: URL(fileURLWithPath: path))
        }
    }
}
