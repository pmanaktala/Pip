import SwiftUI

/// Colours for one species: three tones for fur/feathers plus a handful of accents.
/// Pets keep their own colours in dark mode so they stay recognisable; the scene adapts instead.
public struct PetPalette: Sendable {
    /// Main fur / feather colour.
    public var base: Color
    /// Core-shadow tone of the base (darker, slightly more saturated).
    public var shade: Color
    /// Rim-light tone of the base.
    public var light: Color
    /// Belly, muzzle, face mask.
    public var belly: Color
    public var earInner: Color
    /// Stripes, patches, tail rings.
    public var marking: Color
    /// Nose / beak / feet.
    public var nose: Color
    /// Facial ink: eyes, mouth, brows. Near-black, tinted to the species.
    public var ink: Color
    public var blush: Color

    public static func palette(for species: PetSpecies) -> PetPalette {
        switch species {
        case .cat:
            PetPalette(
                base: Color(red: 0.98, green: 0.70, blue: 0.34),
                shade: Color(red: 0.88, green: 0.52, blue: 0.20),
                light: Color(red: 0.99, green: 0.85, blue: 0.62),
                belly: Color(red: 1.0, green: 0.95, blue: 0.87),
                earInner: Color(red: 0.98, green: 0.74, blue: 0.70),
                marking: Color(red: 0.80, green: 0.48, blue: 0.24),
                nose: Color(red: 0.92, green: 0.56, blue: 0.56),
                ink: Color(red: 0.22, green: 0.16, blue: 0.14),
                blush: Color(red: 0.96, green: 0.50, blue: 0.45)
            )
        case .dog:
            PetPalette(
                base: Color(red: 0.98, green: 0.88, blue: 0.72),
                shade: Color(red: 0.86, green: 0.70, blue: 0.50),
                light: Color(red: 0.99, green: 0.94, blue: 0.84),
                belly: Color(red: 1.0, green: 0.97, blue: 0.92),
                earInner: Color(red: 0.52, green: 0.35, blue: 0.24),
                marking: Color(red: 0.62, green: 0.42, blue: 0.28),
                nose: Color(red: 0.22, green: 0.17, blue: 0.16),
                ink: Color(red: 0.21, green: 0.16, blue: 0.14),
                blush: Color(red: 0.96, green: 0.55, blue: 0.50)
            )
        case .capybara:
            PetPalette(
                base: Color(red: 0.80, green: 0.60, blue: 0.40),
                shade: Color(red: 0.62, green: 0.44, blue: 0.27),
                light: Color(red: 0.88, green: 0.72, blue: 0.54),
                belly: Color(red: 0.88, green: 0.75, blue: 0.58),
                earInner: Color(red: 0.52, green: 0.36, blue: 0.24),
                marking: Color(red: 0.50, green: 0.35, blue: 0.23),
                nose: Color(red: 0.34, green: 0.24, blue: 0.18),
                ink: Color(red: 0.19, green: 0.13, blue: 0.11),
                blush: Color(red: 0.96, green: 0.55, blue: 0.48)
            )
        case .penguin:
            PetPalette(
                base: Color(red: 0.20, green: 0.22, blue: 0.26),
                shade: Color(red: 0.12, green: 0.13, blue: 0.16),
                light: Color(red: 0.32, green: 0.34, blue: 0.40),
                belly: Color(red: 0.98, green: 0.97, blue: 0.94),
                earInner: Color(red: 0.98, green: 0.80, blue: 0.40),
                marking: Color(red: 0.98, green: 0.80, blue: 0.40),
                nose: Color(red: 0.98, green: 0.64, blue: 0.26),
                ink: Color(red: 0.10, green: 0.11, blue: 0.16),
                blush: Color(red: 0.98, green: 0.58, blue: 0.55)
            )
        case .redPanda:
            PetPalette(
                base: Color(red: 0.93, green: 0.49, blue: 0.21),
                shade: Color(red: 0.74, green: 0.32, blue: 0.11),
                light: Color(red: 0.96, green: 0.62, blue: 0.36),
                belly: Color(red: 0.31, green: 0.20, blue: 0.15),
                earInner: Color(red: 0.98, green: 0.93, blue: 0.86),
                marking: Color(red: 0.98, green: 0.93, blue: 0.86),
                nose: Color(red: 0.20, green: 0.14, blue: 0.12),
                ink: Color(red: 0.19, green: 0.13, blue: 0.11),
                blush: Color(red: 0.98, green: 0.50, blue: 0.42)
            )
        }
    }

    /// Ambient colour associated with a mood; always paired with shape/pose so colour is never the sole cue.
    public static func ambient(for mood: Mood) -> Color { MoodColor.bold(mood) }
}
