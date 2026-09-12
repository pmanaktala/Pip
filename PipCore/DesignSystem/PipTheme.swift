import SwiftUI

/// Semantic colours. Defined in the asset catalogs (app + widget) with light/dark variants.
public enum PipColor {
    public static let sceneTop = Color("SceneTop")
    public static let sceneBottom = Color("SceneBottom")
    public static let sceneFloor = Color("SceneFloor")
    public static let ink = Color("Ink")
    public static let inkSecondary = Color("InkSecondary")
}

/// Type ramp. Everything is a Dynamic Type text style; rounded design for warmth.
public enum PipFont {
    public static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
    public static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    public static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    public static let body = Font.system(.body, design: .rounded)
    public static let callout = Font.system(.callout, design: .rounded)
    public static let caption = Font.system(.caption, design: .rounded, weight: .medium)
    public static let footnote = Font.system(.footnote, design: .rounded)
}

public enum PipSpacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 16
    public static let l: CGFloat = 24
    public static let xl: CGFloat = 32
}

/// Ambient theming derived from a mood. Always paired with the pet's pose so colour is never the only cue.
public struct MoodTheme: Sendable {
    public var ambient: Color
    public var strength: Double

    public init(mood: Mood?, intensity: MoodIntensity = .moderate, environment: PetEnvironment? = nil) {
        if let mood {
            ambient = PetPalette.ambient(for: mood)
            strength = environment?.tintStrength ?? 0.4
        } else {
            ambient = PetPalette.ambient(for: .neutral)
            strength = 0.25
        }
    }

    /// Glow behind the pet, tuned per colour scheme so dark mode glows rather than washes out.
    public func glow(for scheme: ColorScheme, radius: CGFloat) -> RadialGradient {
        let alpha = scheme == .dark ? 0.32 * strength + 0.06 : 0.55 * strength + 0.1
        return RadialGradient(colors: [ambient.opacity(alpha), ambient.opacity(0)], center: .center, startRadius: 0, endRadius: radius)
    }
}

// MARK: - Glass helpers

public extension View {
    /// Liquid Glass surface for floating controls. Available on every supported OS (iOS 26+).
    func pipGlass(interactive: Bool = false, tint: Color? = nil) -> some View {
        glassEffect(interactive ? .regular.interactive().tint(tint) : .regular.tint(tint), in: .capsule)
    }

    /// Cross-fade navigation on iOS 27, default zoom/push on iOS 26.
    @ViewBuilder
    func pipNavigationTransition() -> some View {
        if #available(iOS 27, *) {
            self.navigationTransition(.crossFade)
        } else {
            self
        }
    }
}
