import SwiftUI

/// A colour as plain components, so palettes can be mixed and shaded without UIKit or AppKit.
public struct PetRGB: Equatable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    public func mix(_ o: PetRGB, _ t: Double) -> PetRGB {
        PetRGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t)
    }

    public func alpha(_ v: Double) -> PetRGB { PetRGB(r, g, b, v) }

    /// A darker, slightly cooler tone of the same colour: the form shadow. Near-white coats
    /// shade warm (a white dog is cream in shadow, not grey).
    public var shade: PetRGB { r + g + b > 2.4 ? mix(PetRGB(0.72, 0.62, 0.52), 0.32) : mix(PetRGB(0.20, 0.16, 0.30), 0.22) }
    /// The rim: a deeper tone of the colour, never black.
    public var rim: PetRGB { r + g + b > 2.4 ? mix(PetRGB(0.45, 0.36, 0.30), 0.62) : mix(PetRGB(0.12, 0.08, 0.16), 0.48) }
}

/// The colours of one species. Pets keep their colours in dark mode; the room adapts instead.
public struct PetPalette: Sendable {
    /// Main coat.
    public var coat: PetRGB
    /// Face, muzzle, chest and belly.
    public var cream: PetRGB
    /// Stripes, ear tips, the dog's ears.
    public var marking: PetRGB
    /// Inner ears, nose, pads.
    public var pink: PetRGB
    /// Beak and feet (penguin); nose (dog).
    public var accent: PetRGB
    /// Eyes, mouth lines, closed-eye strokes.
    public var ink: PetRGB
    public var blush: PetRGB
    /// Held things (mug band, blanket, nightcap), a quiet colour per pet.
    public var prop: PetRGB

    public static func palette(for species: PetSpecies) -> PetPalette {
        switch species {
        case .penguin:
            PetPalette(coat: PetRGB(0.24, 0.26, 0.33), cream: PetRGB(0.98, 0.96, 0.91), marking: PetRGB(0.17, 0.18, 0.24),
                       pink: PetRGB(0.97, 0.66, 0.64), accent: PetRGB(0.99, 0.67, 0.30), ink: PetRGB(0.13, 0.12, 0.17),
                       blush: PetRGB(0.99, 0.56, 0.56, 0.5), prop: PetRGB(0.93, 0.42, 0.38))
        case .cat:
            PetPalette(coat: PetRGB(0.96, 0.64, 0.35), cream: PetRGB(1.0, 0.95, 0.87), marking: PetRGB(0.86, 0.47, 0.22),
                       pink: PetRGB(0.97, 0.63, 0.62), accent: PetRGB(0.97, 0.63, 0.62), ink: PetRGB(0.20, 0.13, 0.12),
                       blush: PetRGB(0.99, 0.50, 0.46, 0.45), prop: PetRGB(0.34, 0.62, 0.72))
        case .dog:
            // A white, fluffy little dog: warm white coat, curly ears a shade deeper, a rosy nose.
            PetPalette(coat: PetRGB(0.97, 0.94, 0.88), cream: PetRGB(1.0, 0.99, 0.96), marking: PetRGB(0.92, 0.86, 0.77),
                       pink: PetRGB(0.96, 0.60, 0.62), accent: PetRGB(0.66, 0.40, 0.38), ink: PetRGB(0.17, 0.13, 0.13),
                       blush: PetRGB(0.99, 0.55, 0.55, 0.45), prop: PetRGB(0.24, 0.62, 0.58))
        }
    }
}

public extension GraphicsContext {
    func fill(_ path: Path, _ rgb: PetRGB) { fill(path, with: .color(rgb.color)) }
    func stroke(_ path: Path, _ rgb: PetRGB, width: CGFloat, cap: CGLineCap = .round, join: CGLineJoin = .round) {
        stroke(path, with: .color(rgb.color), style: StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: join))
    }
}
