import SwiftUI

/// The place the pet lives: a full-bleed room with a sky, a horizon and a floor.
///
/// Light follows the clock (dawn, day, evening, night) and takes on a little of the current
/// mood, so the same room reads differently at 7am than at 10pm without ever shouting.
/// Shared by the app, widgets and Sit With Pet so it is one world everywhere. Nothing in here
/// is animated; the pet is the only thing that moves.
public struct PetRoom: View {
    public var mood: Mood?
    public var date: Date
    /// Where the floor starts, as a fraction of the height.
    public var horizon: CGFloat
    /// Botanical silhouettes at the edges; off for small surfaces.
    public var showsFoliage: Bool

    @Environment(\.colorScheme) private var scheme

    public init(mood: Mood?, date: Date = .now, horizon: CGFloat = 0.62, showsFoliage: Bool = true) {
        self.mood = mood
        self.date = date
        self.horizon = horizon
        self.showsFoliage = showsFoliage
    }

    public var body: some View {
        let light = RoomLight(date: date, mood: mood, dark: scheme == .dark)
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let floorY = h * horizon
            ZStack(alignment: .topLeading) {
                // Sky: the top of the room is the coolest, the horizon carries the haze.
                LinearGradient(colors: [light.skyTop, light.skyHorizon], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: horizon))

                // Key light: the sun (or moon) somewhere in the sky, low at dawn and dusk, high at noon.
                RadialGradient(colors: [light.keyLight.opacity(light.keyStrength), light.keyLight.opacity(0)],
                               center: UnitPoint(x: light.keyX, y: horizon * light.keyY), startRadius: 0, endRadius: max(w, h) * 0.62)
                if light.night > 0.01 {
                    // A small moon, and stars that come out as the sky darkens.
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.95), Color(red: 0.92, green: 0.93, blue: 1).opacity(0.7)], center: .topLeading, startRadius: 0, endRadius: w * 0.05))
                        .frame(width: w * 0.07, height: w * 0.07)
                        // Kept to the right half and below the header, clear of the name and buttons.
                        .position(x: w * (0.68 + light.keyX * 0.3), y: max(floorY * light.keyY, h * 0.26))
                        .opacity(light.night)
                        .blur(radius: 0.4)
                }

                // Floor: a plane that recedes into the haze at the horizon.
                VStack(spacing: 0) {
                    Color.clear.frame(height: floorY)
                    LinearGradient(colors: [light.floorFar, light.floorNear], startPoint: .top, endPoint: .bottom)
                }
                // A soft band where floor meets sky so the edge never reads as a hard line.
                LinearGradient(colors: [light.skyHorizon.opacity(0), light.skyHorizon.opacity(0.9), light.skyHorizon.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: max(24, h * 0.09))
                    .offset(y: floorY - max(12, h * 0.045))

                Canvas { context, size in
                    // Dust in the light by day; stars at night, more of them the darker it gets.
                    let starCount = 6 + Int(light.night * 26)
                    for i in 0..<starCount {
                        let x = (i < 6 ? 0.45 + PetMath.hash01(Double(i) * 7.1) * 0.5 : PetMath.hash01(Double(i) * 5.3)) * size.width
                        let y = PetMath.hash01(Double(i) * 3.7 + 9) * floorY * (i < 6 ? 0.8 : 0.7)
                        let r = 0.8 + PetMath.hash01(Double(i) * 1.3) * 1.2
                        // By day the motes are faint; bright white dots at noon read as snow.
                        // In dark mode, daytime specks read as stars: only real stars there.
                        let alpha = i < 6 ? (scheme == .dark ? 0 : 0.35) * (1 - light.night) + 0.6 * light.night : 0.85 * light.night * (0.5 + 0.5 * PetMath.hash01(Double(i) * 2.9))
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(alpha)))
                    }
                    guard showsFoliage, size.width > 200 else { return }
                    // Quiet botanical silhouettes ground the room at either edge of the floor.
                    let accent = light.foliage
                    for side in [0, 1] {
                        let x = size.width * (side == 0 ? 0.10 : 0.90)
                        let base = floorY + (size.height - floorY) * 0.34
                        let direction: CGFloat = side == 0 ? 1 : -1
                        let reach = min(size.width, size.height) * 0.22
                        var stem = Path()
                        stem.move(to: CGPoint(x: x, y: base))
                        stem.addQuadCurve(to: CGPoint(x: x + direction * reach * 0.12, y: base - reach), control: CGPoint(x: x - direction * reach * 0.12, y: base - reach * 0.5))
                        context.stroke(stem, with: .color(accent.opacity(0.4)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        for leaf in 0..<4 {
                            let y = base - CGFloat(leaf + 1) * reach * 0.2
                            let d: CGFloat = leaf.isMultiple(of: 2) ? direction : -direction
                            let len = reach * (0.34 - CGFloat(leaf) * 0.04)
                            var shape = Path()
                            shape.move(to: CGPoint(x: x, y: y))
                            shape.addQuadCurve(to: CGPoint(x: x + d * len, y: y - len * 0.45), control: CGPoint(x: x + d * len, y: y + len * 0.15))
                            shape.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + d * len * 0.28, y: y - len * 0.65))
                            context.fill(shape, with: .color(accent.opacity(0.36)))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Room colours for a moment in time. Keyframes at night, dawn, midday, evening and night
/// again, blended by the hour so nothing ever jumps. Mood mixes in as a tint, never a fill.
public struct RoomLight: Sendable, Equatable {
    public var skyTop: Color
    public var skyHorizon: Color
    public var floorFar: Color
    public var floorNear: Color
    public var keyLight: Color
    public var keyStrength: Double
    public var foliage: Color
    /// Where the sun or moon sits: x across the width, y as a fraction of the sky height.
    public var keyX: Double
    public var keyY: Double
    /// 0 by day, 1 in the middle of the night. Drives stars and the moon.
    public var night: Double
    public var hour: Double

    public init(date: Date, mood: Mood?, dark: Bool, calendar: Calendar = .current) {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        var hour = Double(comps.hour ?? 12) + Double(comps.minute ?? 0) / 60
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["PIP_HOUR"], let h = Double(forced) { hour = h }
        #endif
        self.hour = hour
        let frames = dark ? Self.darkFrames : Self.lightFrames
        let f = Self.blend(frames, at: hour)
        let tint = mood.map(\.tint)
        let amount = dark ? 0.07 : 0.14

        // The sun rises on the left around 6:30, is overhead at 13:00 and sets on the right around 19:30;
        // the moon does the same trip through the night.
        let day = hour >= 6.5 && hour < 19.5
        let progress = day ? (hour - 6.5) / 13 : ((hour + 24 - 19.5).truncatingRemainder(dividingBy: 24)) / 11
        keyX = 0.18 + 0.64 * progress
        keyY = 0.72 - 0.6 * sin(progress * .pi)
        night = hour < 5 || hour >= 21 ? 1 : (hour < 6.5 ? (6.5 - hour) / 1.5 : (hour >= 19.5 ? (hour - 19.5) / 1.5 : 0))

        func tinted(_ c: PetRGB, _ k: Double) -> Color { (tint.map { c.mix($0, k) } ?? c).color }
        skyTop = tinted(f.skyTop, amount)
        skyHorizon = tinted(f.skyHorizon, amount * 0.6)
        floorFar = tinted(f.floorFar, amount * 0.7)
        floorNear = tinted(f.floorNear, amount * 0.5)
        keyLight = f.keyLight.color
        keyStrength = f.keyStrength
        foliage = tinted(f.foliage, 0.35)
    }

    // MARK: Keyframes

    struct Frame {
        var hour: Double
        var skyTop: (Double, Double, Double)
        var skyHorizon: (Double, Double, Double)
        var floorFar: (Double, Double, Double)
        var floorNear: (Double, Double, Double)
        var keyLight: (Double, Double, Double)
        var keyStrength: Double
        var foliage: (Double, Double, Double)
    }

    /// Light appearance: a real sky, never saturated. Night is a soft indigo so the pet and dark
    /// text still read; dawn is peach, midday a pale blue, evening apricot into lavender.
    static let lightFrames: [Frame] = [
        Frame(hour: 0, skyTop: (0.36, 0.40, 0.60), skyHorizon: (0.62, 0.62, 0.78), floorFar: (0.58, 0.56, 0.70), floorNear: (0.50, 0.48, 0.63), keyLight: (0.90, 0.92, 1.0), keyStrength: 0.30, foliage: (0.36, 0.36, 0.54)),
        Frame(hour: 5, skyTop: (0.44, 0.46, 0.66), skyHorizon: (0.80, 0.72, 0.78), floorFar: (0.66, 0.62, 0.72), floorNear: (0.56, 0.52, 0.64), keyLight: (1.0, 0.86, 0.72), keyStrength: 0.35, foliage: (0.44, 0.40, 0.54)),
        Frame(hour: 7, skyTop: (0.86, 0.82, 0.90), skyHorizon: (1.0, 0.88, 0.76), floorFar: (0.94, 0.84, 0.74), floorNear: (0.88, 0.76, 0.66), keyLight: (1.0, 0.86, 0.60), keyStrength: 0.6, foliage: (0.68, 0.56, 0.46)),
        Frame(hour: 10, skyTop: (0.56, 0.76, 0.96), skyHorizon: (0.86, 0.92, 0.97), floorFar: (0.92, 0.88, 0.80), floorNear: (0.86, 0.80, 0.72), keyLight: (1.0, 0.98, 0.88), keyStrength: 0.5, foliage: (0.58, 0.66, 0.54)),
        Frame(hour: 14, skyTop: (0.54, 0.75, 0.96), skyHorizon: (0.86, 0.92, 0.97), floorFar: (0.92, 0.88, 0.80), floorNear: (0.86, 0.80, 0.72), keyLight: (1.0, 0.98, 0.90), keyStrength: 0.45, foliage: (0.56, 0.66, 0.54)),
        Frame(hour: 17.5, skyTop: (0.78, 0.76, 0.90), skyHorizon: (1.0, 0.86, 0.70), floorFar: (0.94, 0.82, 0.70), floorNear: (0.88, 0.74, 0.62), keyLight: (1.0, 0.78, 0.50), keyStrength: 0.6, foliage: (0.68, 0.52, 0.46)),
        Frame(hour: 19.5, skyTop: (0.52, 0.48, 0.72), skyHorizon: (0.92, 0.70, 0.66), floorFar: (0.78, 0.66, 0.68), floorNear: (0.66, 0.56, 0.62), keyLight: (1.0, 0.70, 0.52), keyStrength: 0.45, foliage: (0.52, 0.42, 0.52)),
        Frame(hour: 21.5, skyTop: (0.36, 0.40, 0.60), skyHorizon: (0.62, 0.62, 0.78), floorFar: (0.58, 0.56, 0.70), floorNear: (0.50, 0.48, 0.63), keyLight: (0.90, 0.92, 1.0), keyStrength: 0.30, foliage: (0.36, 0.36, 0.54)),
        Frame(hour: 24, skyTop: (0.36, 0.40, 0.60), skyHorizon: (0.62, 0.62, 0.78), floorFar: (0.58, 0.56, 0.70), floorNear: (0.50, 0.48, 0.63), keyLight: (0.90, 0.92, 1.0), keyStrength: 0.30, foliage: (0.36, 0.36, 0.54)),
    ]

    /// Dark appearance: the same sky after dark — blue-grey, never brown — with the light of
    /// day showing as a cooler or warmer cast rather than brightness.
    static let darkFrames: [Frame] = [
        // Night: navy, the moon and stars.
        Frame(hour: 0, skyTop: (0.05, 0.06, 0.13), skyHorizon: (0.14, 0.15, 0.26), floorFar: (0.12, 0.12, 0.20), floorNear: (0.08, 0.08, 0.14), keyLight: (0.72, 0.76, 1.0), keyStrength: 0.22, foliage: (0.34, 0.36, 0.56)),
        Frame(hour: 5, skyTop: (0.10, 0.10, 0.20), skyHorizon: (0.30, 0.22, 0.32), floorFar: (0.20, 0.17, 0.24), floorNear: (0.13, 0.11, 0.17), keyLight: (1.0, 0.80, 0.62), keyStrength: 0.3, foliage: (0.42, 0.36, 0.50)),
        // Dawn: a warm rose glow low in the sky, so a dark-mode morning is unmistakably morning.
        Frame(hour: 7, skyTop: (0.22, 0.22, 0.36), skyHorizon: (0.58, 0.40, 0.40), floorFar: (0.34, 0.27, 0.29), floorNear: (0.22, 0.18, 0.21), keyLight: (1.0, 0.78, 0.55), keyStrength: 0.45, foliage: (0.60, 0.46, 0.44)),
        // Day: a dim blue daylight, never charcoal.
        Frame(hour: 10, skyTop: (0.16, 0.27, 0.44), skyHorizon: (0.32, 0.42, 0.54), floorFar: (0.27, 0.28, 0.31), floorNear: (0.18, 0.19, 0.22), keyLight: (1.0, 0.96, 0.84), keyStrength: 0.34, foliage: (0.42, 0.54, 0.48)),
        Frame(hour: 14, skyTop: (0.15, 0.26, 0.43), skyHorizon: (0.31, 0.41, 0.53), floorFar: (0.27, 0.28, 0.31), floorNear: (0.18, 0.19, 0.22), keyLight: (1.0, 0.96, 0.84), keyStrength: 0.32, foliage: (0.42, 0.54, 0.48)),
        // Evening: apricot into plum.
        Frame(hour: 17.5, skyTop: (0.22, 0.20, 0.36), skyHorizon: (0.54, 0.36, 0.34), floorFar: (0.32, 0.25, 0.27), floorNear: (0.21, 0.16, 0.19), keyLight: (1.0, 0.72, 0.48), keyStrength: 0.42, foliage: (0.56, 0.42, 0.42)),
        Frame(hour: 19.5, skyTop: (0.13, 0.11, 0.24), skyHorizon: (0.34, 0.22, 0.34), floorFar: (0.22, 0.17, 0.25), floorNear: (0.14, 0.11, 0.18), keyLight: (1.0, 0.70, 0.56), keyStrength: 0.3, foliage: (0.44, 0.34, 0.48)),
        Frame(hour: 21.5, skyTop: (0.05, 0.06, 0.13), skyHorizon: (0.14, 0.15, 0.26), floorFar: (0.12, 0.12, 0.20), floorNear: (0.08, 0.08, 0.14), keyLight: (0.72, 0.76, 1.0), keyStrength: 0.22, foliage: (0.34, 0.36, 0.56)),
        Frame(hour: 24, skyTop: (0.05, 0.06, 0.13), skyHorizon: (0.14, 0.15, 0.26), floorFar: (0.12, 0.12, 0.20), floorNear: (0.08, 0.08, 0.14), keyLight: (0.72, 0.76, 1.0), keyStrength: 0.22, foliage: (0.34, 0.36, 0.56)),
    ]

    struct Blended {
        var skyTop: PetRGB, skyHorizon: PetRGB, floorFar: PetRGB, floorNear: PetRGB, keyLight: PetRGB, keyStrength: Double, foliage: PetRGB
    }

    static func blend(_ frames: [Frame], at hour: Double) -> Blended {
        let h = min(max(hour, 0), 24)
        var a = frames[0], b = frames[1]
        for i in 0..<(frames.count - 1) where h >= frames[i].hour && h <= frames[i + 1].hour {
            a = frames[i]; b = frames[i + 1]; break
        }
        let span = max(b.hour - a.hour, 0.001)
        // Ease so the room lingers in each phase and moves through the transitions.
        let raw = (h - a.hour) / span
        let t = raw * raw * (3 - 2 * raw)
        func c(_ x: (Double, Double, Double), _ y: (Double, Double, Double)) -> PetRGB {
            PetRGB(x.0 + (y.0 - x.0) * t, x.1 + (y.1 - x.1) * t, x.2 + (y.2 - x.2) * t)
        }
        return Blended(skyTop: c(a.skyTop, b.skyTop), skyHorizon: c(a.skyHorizon, b.skyHorizon), floorFar: c(a.floorFar, b.floorFar), floorNear: c(a.floorNear, b.floorNear), keyLight: c(a.keyLight, b.keyLight), keyStrength: a.keyStrength + (b.keyStrength - a.keyStrength) * t, foliage: c(a.foliage, b.foliage))
    }

}

public extension Mood {
    /// The mood's colour as components (the room tints with it; `MoodColor.bold` draws it).
    var tint: PetRGB {
        switch self {
        case .happy: PetRGB(0.99, 0.74, 0.20)
        case .excited: PetRGB(0.98, 0.45, 0.40)
        case .calm: PetRGB(0.26, 0.72, 0.64)
        case .neutral: PetRGB(0.58, 0.60, 0.80)
        case .tired: PetRGB(0.42, 0.42, 0.78)
        case .stressed: PetRGB(0.98, 0.56, 0.24)
        case .sad: PetRGB(0.34, 0.58, 0.90)
        case .frustrated: PetRGB(0.90, 0.34, 0.36)
        }
    }
}
