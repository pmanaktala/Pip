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

                // Key light: a window somewhere off to the upper right.
                RadialGradient(colors: [light.keyLight.opacity(light.keyStrength), light.keyLight.opacity(0)],
                               center: UnitPoint(x: 0.78, y: horizon * 0.35), startRadius: 0, endRadius: max(w, h) * 0.62)

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
                    // Dust in the light: a handful of still motes, only where the sky is.
                    for i in 0..<10 {
                        let x = (0.45 + PetAnimator.hash01(Double(i) * 7.1) * 0.5) * size.width
                        let y = PetAnimator.hash01(Double(i) * 3.7 + 9) * floorY * 0.8
                        let r = 0.8 + PetAnimator.hash01(Double(i) * 1.3) * 1.2
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(scheme == .dark ? 0.35 : 0.7)))
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

    public init(date: Date, mood: Mood?, dark: Bool, calendar: Calendar = .current) {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(comps.hour ?? 12) + Double(comps.minute ?? 0) / 60
        let frames = dark ? Self.darkFrames : Self.lightFrames
        let f = Self.blend(frames, at: hour)
        let tint = mood.map(MoodColor.bold)
        let amount = dark ? 0.16 : 0.13

        skyTop = tint.map { Self.mix(f.skyTop, $0, amount) } ?? f.skyTop
        skyHorizon = tint.map { Self.mix(f.skyHorizon, $0, amount * 0.6) } ?? f.skyHorizon
        floorFar = tint.map { Self.mix(f.floorFar, $0, amount * 0.7) } ?? f.floorFar
        floorNear = tint.map { Self.mix(f.floorNear, $0, amount * 0.5) } ?? f.floorNear
        keyLight = f.keyLight
        keyStrength = f.keyStrength
        foliage = tint.map { Self.mix(f.foliage, $0, 0.35) } ?? f.foliage
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

    /// Light appearance: pale, warm, never saturated. Night stays airy so text remains dark-on-light.
    static let lightFrames: [Frame] = [
        Frame(hour: 0, skyTop: (0.72, 0.74, 0.86), skyHorizon: (0.86, 0.85, 0.92), floorFar: (0.80, 0.78, 0.86), floorNear: (0.74, 0.72, 0.82), keyLight: (0.92, 0.93, 1.0), keyStrength: 0.35, foliage: (0.50, 0.50, 0.66)),
        Frame(hour: 6.5, skyTop: (0.96, 0.86, 0.80), skyHorizon: (0.99, 0.94, 0.87), floorFar: (0.94, 0.86, 0.78), floorNear: (0.90, 0.80, 0.71), keyLight: (1.0, 0.90, 0.72), keyStrength: 0.55, foliage: (0.70, 0.58, 0.48)),
        Frame(hour: 12, skyTop: (0.88, 0.93, 0.96), skyHorizon: (0.98, 0.97, 0.94), floorFar: (0.93, 0.89, 0.83), floorNear: (0.88, 0.83, 0.76), keyLight: (1.0, 0.97, 0.86), keyStrength: 0.5, foliage: (0.62, 0.66, 0.58)),
        Frame(hour: 18.5, skyTop: (0.93, 0.82, 0.80), skyHorizon: (0.99, 0.92, 0.85), floorFar: (0.92, 0.83, 0.77), floorNear: (0.87, 0.77, 0.71), keyLight: (1.0, 0.84, 0.66), keyStrength: 0.55, foliage: (0.68, 0.54, 0.50)),
        Frame(hour: 22, skyTop: (0.72, 0.74, 0.86), skyHorizon: (0.86, 0.85, 0.92), floorFar: (0.80, 0.78, 0.86), floorNear: (0.74, 0.72, 0.82), keyLight: (0.92, 0.93, 1.0), keyStrength: 0.35, foliage: (0.50, 0.50, 0.66)),
        Frame(hour: 24, skyTop: (0.72, 0.74, 0.86), skyHorizon: (0.86, 0.85, 0.92), floorFar: (0.80, 0.78, 0.86), floorNear: (0.74, 0.72, 0.82), keyLight: (0.92, 0.93, 1.0), keyStrength: 0.35, foliage: (0.50, 0.50, 0.66)),
    ]

    /// Dark appearance: a dim room, the key light doing most of the work.
    static let darkFrames: [Frame] = [
        Frame(hour: 0, skyTop: (0.06, 0.07, 0.13), skyHorizon: (0.15, 0.15, 0.24), floorFar: (0.13, 0.12, 0.19), floorNear: (0.09, 0.08, 0.13), keyLight: (0.70, 0.74, 1.0), keyStrength: 0.22, foliage: (0.36, 0.38, 0.56)),
        Frame(hour: 6.5, skyTop: (0.16, 0.12, 0.16), skyHorizon: (0.34, 0.24, 0.24), floorFar: (0.26, 0.20, 0.20), floorNear: (0.17, 0.13, 0.13), keyLight: (1.0, 0.78, 0.58), keyStrength: 0.30, foliage: (0.50, 0.38, 0.34)),
        Frame(hour: 12, skyTop: (0.11, 0.14, 0.19), skyHorizon: (0.22, 0.23, 0.27), floorFar: (0.20, 0.18, 0.18), floorNear: (0.14, 0.12, 0.12), keyLight: (1.0, 0.95, 0.82), keyStrength: 0.26, foliage: (0.40, 0.46, 0.40)),
        Frame(hour: 18.5, skyTop: (0.16, 0.11, 0.15), skyHorizon: (0.33, 0.22, 0.22), floorFar: (0.25, 0.19, 0.19), floorNear: (0.16, 0.12, 0.12), keyLight: (1.0, 0.72, 0.52), keyStrength: 0.30, foliage: (0.50, 0.36, 0.34)),
        Frame(hour: 22, skyTop: (0.06, 0.07, 0.13), skyHorizon: (0.15, 0.15, 0.24), floorFar: (0.13, 0.12, 0.19), floorNear: (0.09, 0.08, 0.13), keyLight: (0.70, 0.74, 1.0), keyStrength: 0.22, foliage: (0.36, 0.38, 0.56)),
        Frame(hour: 24, skyTop: (0.06, 0.07, 0.13), skyHorizon: (0.15, 0.15, 0.24), floorFar: (0.13, 0.12, 0.19), floorNear: (0.09, 0.08, 0.13), keyLight: (0.70, 0.74, 1.0), keyStrength: 0.22, foliage: (0.36, 0.38, 0.56)),
    ]

    struct Blended {
        var skyTop: Color, skyHorizon: Color, floorFar: Color, floorNear: Color, keyLight: Color, keyStrength: Double, foliage: Color
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
        func c(_ x: (Double, Double, Double), _ y: (Double, Double, Double)) -> Color {
            Color(red: x.0 + (y.0 - x.0) * t, green: x.1 + (y.1 - x.1) * t, blue: x.2 + (y.2 - x.2) * t)
        }
        return Blended(skyTop: c(a.skyTop, b.skyTop), skyHorizon: c(a.skyHorizon, b.skyHorizon), floorFar: c(a.floorFar, b.floorFar), floorNear: c(a.floorNear, b.floorNear), keyLight: c(a.keyLight, b.keyLight), keyStrength: a.keyStrength + (b.keyStrength - a.keyStrength) * t, foliage: c(a.foliage, b.foliage))
    }

    static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ca = UIColor(a), cb = UIColor(b)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        ca.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        cb.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let u = CGFloat(t)
        return Color(red: r1 + (r2 - r1) * u, green: g1 + (g2 - g1) * u, blue: b1 + (b2 - b1) * u)
    }
}
