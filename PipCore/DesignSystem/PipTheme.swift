import SwiftUI

/// Semantic colours. Defined in the asset catalogs (app + widget) with light/dark variants.
public enum PipColor {
    public static let sceneTop = Color("SceneTop")
    public static let sceneBottom = Color("SceneBottom")
    public static let sceneFloor = Color("SceneFloor")
    public static let ink = Color("Ink")
    public static let inkSecondary = Color("InkSecondary")
}

/// Mood colours. `bold` is the full-strength block colour (white text on it); `soft` is the
/// same hue as a tint for canvases and chips; `ink` is a dark tone of it for text on soft.
/// Colour is always paired with the pet's pose, never the only cue.
public enum MoodColor {
    /// Consistent dark foreground on saturated mood surfaces, including yellow and mint.
    public static let onBold = Color(red: 0.12, green: 0.16, blue: 0.18)

    public static func bold(_ mood: Mood) -> Color {
        switch mood {
        case .happy: Color(red: 0.99, green: 0.74, blue: 0.20)
        case .excited: Color(red: 0.98, green: 0.45, blue: 0.40)
        case .calm: Color(red: 0.26, green: 0.72, blue: 0.64)
        case .neutral: Color(red: 0.58, green: 0.60, blue: 0.80)
        case .tired: Color(red: 0.42, green: 0.42, blue: 0.78)
        case .stressed: Color(red: 0.98, green: 0.56, blue: 0.24)
        case .sad: Color(red: 0.34, green: 0.58, blue: 0.90)
        case .frustrated: Color(red: 0.90, green: 0.34, blue: 0.36)
        }
    }

    /// Light tint for backgrounds: strong enough to read as the mood, soft enough for text.
    public static func soft(_ mood: Mood, scheme: ColorScheme) -> Color {
        bold(mood).opacity(scheme == .dark ? 0.22 : 0.16)
    }

    /// Dark tone of the mood for text and glyphs on a soft tint.
    public static func ink(_ mood: Mood) -> Color {
        switch mood {
        case .happy: Color(red: 0.55, green: 0.36, blue: 0.02)
        case .excited: Color(red: 0.62, green: 0.18, blue: 0.14)
        case .calm: Color(red: 0.08, green: 0.38, blue: 0.33)
        case .neutral: Color(red: 0.28, green: 0.30, blue: 0.50)
        case .tired: Color(red: 0.22, green: 0.22, blue: 0.50)
        case .stressed: Color(red: 0.60, green: 0.28, blue: 0.04)
        case .sad: Color(red: 0.12, green: 0.30, blue: 0.58)
        case .frustrated: Color(red: 0.56, green: 0.14, blue: 0.16)
        }
    }
}

/// Type ramp. Everything is a Dynamic Type text style; rounded and heavy for warmth.
public enum PipFont {
    public static let display = Font.system(.largeTitle, design: .serif, weight: .regular)
    public static let title = Font.system(.title, design: .serif, weight: .regular)
    public static let title2 = Font.system(.title2, design: .rounded, weight: .bold)
    public static let headline = Font.system(.headline, design: .rounded, weight: .bold)
    public static let body = Font.system(.body, design: .rounded)
    public static let callout = Font.system(.callout, design: .rounded)
    public static let caption = Font.system(.caption, design: .rounded, weight: .semibold)
    public static let footnote = Font.system(.footnote, design: .rounded)
}

public enum PipSpacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 16
    public static let l: CGFloat = 24
    public static let xl: CGFloat = 32
}

public enum PipRadius {
    public static let card: CGFloat = 24
    public static let tile: CGFloat = 20
    public static let chip: CGFloat = 14
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

    /// Glow behind the pet, tuned per colour scheme: additive light in the dark, a soft wash in the light.
    public func glow(for scheme: ColorScheme, radius: CGFloat) -> RadialGradient {
        let alpha = scheme == .dark ? 0.22 * strength + 0.04 : 0.42 * strength + 0.08
        return RadialGradient(colors: [ambient.opacity(alpha), ambient.opacity(alpha * 0.4), ambient.opacity(0)], center: .center, startRadius: 0, endRadius: radius)
    }
}

// MARK: - Glass helpers

public extension View {
    /// Liquid Glass surface for floating controls. Available on every supported OS (iOS 26+).
    func pipGlass(interactive: Bool = false, tint: Color? = nil) -> some View {
        glassEffect(interactive ? .regular.interactive().tint(tint) : .regular.tint(tint), in: .capsule)
    }

    /// Cross-fade navigation on iOS 27, default zoom/push on iOS 26.
    /// The compile-time check keeps the project building with the iOS 26 SDK (CI runners).
    @ViewBuilder
    func pipNavigationTransition() -> some View {
        #if swift(>=6.4)
        if #available(iOS 27, *) {
            self.navigationTransition(.crossFade)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// iOS 27 tabs picker style, segmented on iOS 26.
    @ViewBuilder
    func pipTabsPickerStyle() -> some View {
        #if swift(>=6.4)
        if #available(iOS 27, *) {
            self.pickerStyle(.tabs)
        } else {
            self.pickerStyle(.segmented)
        }
        #else
        self.pickerStyle(.segmented)
        #endif
    }
}
