#if DEBUG && os(iOS)
import SwiftUI
import UIKit

/// Test/preview-only artwork injection. Assets live in the test bundle, never the app bundle.
/// This is a static visual study: it does not impersonate the production mood/animation rig.
private struct PetConceptArtworkKey: EnvironmentKey {
    static let defaultValue: URL? = nil
}

extension EnvironmentValues {
    var petConceptArtwork: URL? {
        get { self[PetConceptArtworkKey.self] }
        set { self[PetConceptArtworkKey.self] = newValue }
    }
}

struct PetConceptArtwork: View {
    var species: PetSpecies
    var framing: PetFraming
    var directory: URL

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let zoom: CGFloat = framing == .full ? 1 : (framing == .badge ? 1.8 : 1.7)
            let focus: CGFloat = framing == .full ? 0.5 : 0.29
            // Measured opaque foot baselines from the preview PNGs, aligned to the stage's
            // y=170/200 floor. The artwork itself stays unchanged.
            let foot: CGFloat = species == .dog ? 1084.0 / 1254 : 1090.0 / 1254
            if framing == .full {
                Ellipse().fill(.black.opacity(0.14))
                    .frame(width: side * 0.44, height: side * 0.03)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + side * 0.35)
            }
            if let image = UIImage(contentsOfFile: directory.appendingPathComponent("PetConcept-\(species.rawValue).png").path) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: side * zoom, height: side * zoom)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + (0.5 - focus) * side * zoom + (framing == .full ? (0.85 - foot) * side : 0))
            }
        }
        .mask {
            if framing == .full { Rectangle() } else { Circle() }
        }
        .accessibilityHidden(true)
    }
}
#endif
