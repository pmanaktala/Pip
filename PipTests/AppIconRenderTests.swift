import SwiftUI
import Testing
import UIKit
@testable import Pip

/// Renders the app icon from the live artwork. Set `PIP_ICON_OUTPUT` to a file path
/// to write the 1024×1024 PNG (used to regenerate the asset catalog fallback icon).
@MainActor
struct AppIconRenderTests {
    @Test func iconRendersOpaque1024Square() throws {
        let renderer = ImageRenderer(content: AppIconView())
        renderer.scale = 1
        renderer.isOpaque = true
        let image = try #require(renderer.uiImage)
        #expect(image.size == CGSize(width: 1024, height: 1024))
        if let path = ProcessInfo.processInfo.environment["PIP_ICON_OUTPUT"], let data = image.pngData() {
            try data.write(to: URL(fileURLWithPath: path))
            // Transparent pet-only layer for the Icon Composer package.
            let layer = ImageRenderer(content: AppIconView(includesBackground: false))
            layer.scale = 1
            layer.isOpaque = false
            if let layerData = layer.uiImage?.pngData() {
                try layerData.write(to: URL(fileURLWithPath: path.replacingOccurrences(of: ".png", with: "-layer.png")))
            }
            // Alternate icons for the other pets.
            for species in [PetSpecies.cat, .dog] {
                let alt = ImageRenderer(content: AppIconView(species: species))
                alt.scale = 1
                alt.isOpaque = true
                if let data = alt.uiImage?.pngData() {
                    try data.write(to: URL(fileURLWithPath: path.replacingOccurrences(of: ".png", with: "-\(species.defaultName.lowercased()).png")))
                }
            }
        }
    }
}
