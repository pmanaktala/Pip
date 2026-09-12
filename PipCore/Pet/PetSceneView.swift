import SwiftUI

/// The pet in its environment: warm gradient, soft floor, ambient mood glow and small props.
/// Shared by the app (animated) and widgets (static, `time == nil`).
public struct PetSceneView: View {
    public var identity: PetIdentity
    public var state: PetMoodState
    public var time: TimeInterval?
    /// Fraction of the scene height the pet occupies.
    public var petScale: CGFloat
    public var showsFloor: Bool
    public var showsAccessory: Bool
    /// Vertical position of the pet's centre as a fraction of the scene height.
    public var petVerticalPosition: CGFloat

    @Environment(\.colorScheme) private var scheme

    public init(identity: PetIdentity, state: PetMoodState, time: TimeInterval? = nil, petScale: CGFloat = 0.62, petVerticalPosition: CGFloat = 0.49, showsFloor: Bool = true, showsAccessory: Bool = true) {
        self.identity = identity
        self.state = state
        self.time = time
        self.petScale = petScale
        self.petVerticalPosition = petVerticalPosition
        self.showsFloor = showsFloor
        self.showsAccessory = showsAccessory
    }

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let petSide = min(size.width, size.height) * petScale
            let theme = MoodTheme(mood: state.mood, intensity: state.intensity, environment: state.environment)
            let petCenter = CGPoint(x: size.width / 2, y: size.height * petVerticalPosition)
            let horizon = petVerticalPosition + petSide * 0.58 / size.height

            ZStack {
                LinearGradient(colors: [PipColor.sceneTop, PipColor.sceneBottom], startPoint: .top, endPoint: .bottom)

                if showsFloor {
                    FloorShape(horizon: horizon)
                        .fill(LinearGradient(colors: [PipColor.sceneFloor.opacity(0.0), PipColor.sceneFloor], startPoint: .top, endPoint: .bottom))
                }

                // Ambient glow and dimness.
                Circle()
                    .fill(theme.glow(for: scheme, radius: petSide * 0.95))
                    .frame(width: petSide * 1.9, height: petSide * 1.9)
                    .position(petCenter)
                    .blendMode(scheme == .dark ? .screen : .multiply)
                    .animation(.smooth(duration: 1.2), value: state.mood)

                Color.black
                    .opacity(state.environment.dimness * (scheme == .dark ? 0.35 : 0.08))
                    .animation(.smooth(duration: 1.2), value: state.environment.dimness)

                PetView(identity: identity, state: state, time: time)
                    .frame(width: petSide, height: petSide)
                    .position(x: petCenter.x, y: petCenter.y + petSide * 0.08)

                if showsAccessory, let accessory = state.accessory {
                    AccessoryOverlay(kind: accessory, time: time, palette: PetPalette.palette(for: identity.species))
                        .frame(width: petSide, height: petSide)
                        .position(x: petCenter.x, y: petCenter.y + petSide * 0.08)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.smooth(duration: 0.8), value: state.accessory)
        }
    }
}

/// A gently curved floor.
struct FloorShape: Shape {
    var horizon: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.height * horizon
        p.move(to: CGPoint(x: 0, y: y + rect.height * 0.06))
        p.addQuadCurve(to: CGPoint(x: rect.width, y: y + rect.height * 0.06), control: CGPoint(x: rect.width / 2, y: y - rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

/// Small props around the pet: sparkles, zzz, stress squiggles, a rain cloud, steam.
/// Drawn in the same 200×200 design space as the pet so they line up at any size.
public struct AccessoryOverlay: View {
    public var kind: PetAccessory
    public var time: TimeInterval?
    public var palette: PetPalette

    @Environment(\.colorScheme) private var scheme

    public init(kind: PetAccessory, time: TimeInterval?, palette: PetPalette) {
        self.kind = kind
        self.time = time
        self.palette = palette
    }

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 200
            var ctx = context
            ctx.translateBy(x: (size.width - 200 * scale) / 2, y: (size.height - 200 * scale) / 2)
            ctx.scaleBy(x: scale, y: scale)
            let t = time ?? 1.7
            let ink = scheme == .dark ? Color.white.opacity(0.75) : PipColor.ink.opacity(0.55)
            switch kind {
            case .sparkles:
                for i in 0..<5 {
                    let seed = Double(i)
                    let phase = (t * 0.7 + seed * 0.37).truncatingRemainder(dividingBy: 1)
                    let alpha = sin(phase * .pi)
                    let x = 40 + PetAnimator.hash01(seed + floor(t * 0.7 + seed * 0.37)) * 120
                    let y = 30 + PetAnimator.hash01(seed * 3.1 + floor(t * 0.7 + seed * 0.37)) * 70 - phase * 12
                    let s = 3.5 + 2.5 * PetAnimator.hash01(seed * 7)
                    sparkle(&ctx, at: CGPoint(x: x, y: y), size: s * (0.6 + 0.4 * alpha), color: Color(red: 1, green: 0.78, blue: 0.35).opacity(0.9 * alpha))
                }
            case .zzz:
                for i in 0..<3 {
                    let phase = ((t * 0.35) + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                    let alpha = sin(phase * .pi)
                    let x = 138 + phase * 22 + Double(i) * 3
                    let y = 78 - phase * 36
                    let fontSize = 9.0 + phase * 8
                    let text = Text("z").font(.system(size: fontSize, weight: .bold, design: .rounded)).foregroundStyle(ink.opacity(alpha))
                    ctx.draw(text, at: CGPoint(x: x, y: y))
                }
            case .stressLines:
                // Little tension marks that vibrate near the head.
                let shake = sin(t * 30) * 1.2
                for side: CGFloat in [-1, 1] {
                    for j in 0..<2 {
                        var p = Path()
                        let x = 100 + side * (58 + CGFloat(j) * 7) + shake
                        let y: CGFloat = 60 + CGFloat(j) * 4
                        p.move(to: CGPoint(x: x, y: y))
                        p.addQuadCurve(to: CGPoint(x: x, y: y + 14), control: CGPoint(x: x + side * 4, y: y + 7))
                        ctx.stroke(p, with: .color(ink.opacity(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
            case .rainCloud:
                let bob = sin(t * 1.2) * 1.5
                let c = CGPoint(x: 142, y: 40 + bob)
                var cloud = Path()
                cloud.addEllipse(in: CGRect(x: c.x - 16, y: c.y - 6, width: 20, height: 14))
                cloud.addEllipse(in: CGRect(x: c.x - 6, y: c.y - 12, width: 18, height: 18))
                cloud.addEllipse(in: CGRect(x: c.x + 2, y: c.y - 6, width: 18, height: 14))
                let cloudColor = scheme == .dark ? Color(white: 0.55) : Color(red: 0.62, green: 0.68, blue: 0.78)
                ctx.fill(cloud, with: .color(cloudColor.opacity(0.85)))
                for i in 0..<3 {
                    let phase = (t * 0.9 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                    let x = c.x - 8 + CGFloat(i) * 9
                    let y = c.y + 10 + phase * 16
                    var drop = Path()
                    drop.move(to: CGPoint(x: x, y: y))
                    drop.addLine(to: CGPoint(x: x - 1, y: y + 4))
                    ctx.stroke(drop, with: .color(Color(red: 0.45, green: 0.65, blue: 0.95).opacity(0.8 * (1 - phase))), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }
            case .steam:
                for i in 0..<3 {
                    let phase = (t * 0.5 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                    let alpha = sin(phase * .pi) * 0.6
                    let x = 100 + CGFloat(i - 1) * 16 + sin(phase * 6 + Double(i)) * 3
                    let y = 46 - phase * 26
                    let r = 4 + phase * 5
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(ink.opacity(alpha)))
                }
            case .heart:
                let phase = (t * 0.6).truncatingRemainder(dividingBy: 1)
                let alpha = sin(phase * .pi)
                heart(&ctx, at: CGPoint(x: 146, y: 62 - phase * 20), size: 8, color: palette.blush.opacity(alpha))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func sparkle(_ ctx: inout GraphicsContext, at c: CGPoint, size s: CGFloat, color: Color) {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - s))
        p.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), control: CGPoint(x: c.x + s * 0.2, y: c.y - s * 0.2))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: CGPoint(x: c.x + s * 0.2, y: c.y + s * 0.2))
        p.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), control: CGPoint(x: c.x - s * 0.2, y: c.y + s * 0.2))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: CGPoint(x: c.x - s * 0.2, y: c.y - s * 0.2))
        ctx.fill(p, with: .color(color))
    }

    private func heart(_ ctx: inout GraphicsContext, at c: CGPoint, size s: CGFloat, color: Color) {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y + s))
        p.addCurve(to: CGPoint(x: c.x - s, y: c.y - s * 0.3), control1: CGPoint(x: c.x - s * 0.6, y: c.y + s * 0.5), control2: CGPoint(x: c.x - s, y: c.y + s * 0.1))
        p.addArc(center: CGPoint(x: c.x - s * 0.5, y: c.y - s * 0.3), radius: s * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: c.x + s * 0.5, y: c.y - s * 0.3), radius: s * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: c.x, y: c.y + s), control1: CGPoint(x: c.x + s, y: c.y + s * 0.1), control2: CGPoint(x: c.x + s * 0.6, y: c.y + s * 0.5))
        ctx.fill(p, with: .color(color))
    }
}
