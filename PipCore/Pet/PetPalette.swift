import SwiftUI

/// Colours for one species. Pets keep their own colours in dark mode so they stay recognisable.
public struct PetPalette: Sendable {
    public var bodyTop: Color
    public var bodyBottom: Color
    public var belly: Color
    public var earInner: Color
    public var marking: Color
    public var nose: Color
    public var eye: Color
    public var blush: Color
    public var outline: Color

    public static func palette(for species: PetSpecies) -> PetPalette {
        switch species {
        case .cat:
            PetPalette(
                bodyTop: Color(red: 0.99, green: 0.86, blue: 0.62),
                bodyBottom: Color(red: 0.95, green: 0.70, blue: 0.42),
                belly: Color(red: 1.0, green: 0.96, blue: 0.88),
                earInner: Color(red: 0.98, green: 0.72, blue: 0.68),
                marking: Color(red: 0.86, green: 0.58, blue: 0.32),
                nose: Color(red: 0.93, green: 0.55, blue: 0.52),
                eye: Color(red: 0.20, green: 0.15, blue: 0.14),
                blush: Color(red: 0.98, green: 0.52, blue: 0.48),
                outline: Color(red: 0.55, green: 0.35, blue: 0.18)
            )
        case .dog:
            PetPalette(
                bodyTop: Color(red: 0.96, green: 0.86, blue: 0.70),
                bodyBottom: Color(red: 0.86, green: 0.70, blue: 0.50),
                belly: Color(red: 1.0, green: 0.97, blue: 0.92),
                earInner: Color(red: 0.70, green: 0.50, blue: 0.34),
                marking: Color(red: 0.72, green: 0.52, blue: 0.34),
                nose: Color(red: 0.24, green: 0.18, blue: 0.16),
                eye: Color(red: 0.20, green: 0.15, blue: 0.14),
                blush: Color(red: 0.98, green: 0.55, blue: 0.50),
                outline: Color(red: 0.50, green: 0.34, blue: 0.20)
            )
        case .capybara:
            PetPalette(
                bodyTop: Color(red: 0.80, green: 0.62, blue: 0.42),
                bodyBottom: Color(red: 0.64, green: 0.46, blue: 0.30),
                belly: Color(red: 0.90, green: 0.78, blue: 0.62),
                earInner: Color(red: 0.55, green: 0.38, blue: 0.26),
                marking: Color(red: 0.50, green: 0.34, blue: 0.22),
                nose: Color(red: 0.36, green: 0.24, blue: 0.16),
                eye: Color(red: 0.18, green: 0.13, blue: 0.11),
                blush: Color(red: 0.96, green: 0.55, blue: 0.48),
                outline: Color(red: 0.42, green: 0.28, blue: 0.16)
            )
        case .penguin:
            PetPalette(
                bodyTop: Color(red: 0.30, green: 0.34, blue: 0.44),
                bodyBottom: Color(red: 0.18, green: 0.21, blue: 0.30),
                belly: Color(red: 0.98, green: 0.97, blue: 0.95),
                earInner: Color(red: 0.98, green: 0.72, blue: 0.30),
                marking: Color(red: 0.98, green: 0.72, blue: 0.30),
                nose: Color(red: 0.98, green: 0.62, blue: 0.24),
                eye: Color(red: 0.12, green: 0.12, blue: 0.16),
                blush: Color(red: 0.98, green: 0.58, blue: 0.55),
                outline: Color(red: 0.10, green: 0.12, blue: 0.20)
            )
        case .redPanda:
            PetPalette(
                bodyTop: Color(red: 0.90, green: 0.50, blue: 0.28),
                bodyBottom: Color(red: 0.74, green: 0.36, blue: 0.18),
                belly: Color(red: 0.36, green: 0.22, blue: 0.16),
                earInner: Color(red: 0.98, green: 0.94, blue: 0.88),
                marking: Color(red: 0.98, green: 0.94, blue: 0.88),
                nose: Color(red: 0.22, green: 0.15, blue: 0.13),
                eye: Color(red: 0.18, green: 0.13, blue: 0.11),
                blush: Color(red: 0.98, green: 0.50, blue: 0.42),
                outline: Color(red: 0.50, green: 0.24, blue: 0.10)
            )
        }
    }

    /// Ambient colour associated with a mood; always paired with shape/pose so colour is never the sole cue.
    public static func ambient(for mood: Mood) -> Color {
        switch mood {
        case .happy: Color(red: 1.0, green: 0.82, blue: 0.55)
        case .excited: Color(red: 1.0, green: 0.70, blue: 0.62)
        case .calm: Color(red: 0.62, green: 0.84, blue: 0.78)
        case .neutral: Color(red: 0.80, green: 0.80, blue: 0.84)
        case .tired: Color(red: 0.62, green: 0.62, blue: 0.86)
        case .stressed: Color(red: 0.96, green: 0.70, blue: 0.45)
        case .sad: Color(red: 0.60, green: 0.72, blue: 0.90)
        case .frustrated: Color(red: 0.96, green: 0.58, blue: 0.52)
        }
    }
}
