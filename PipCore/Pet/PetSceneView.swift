import SwiftUI

/// The pet in its room: sky, horizon and floor lit by the time of day, an ambient mood glow
/// and small props. Shared by the app (animated) and widgets (static, `time == nil`).
public struct PetSceneView: View {
    public var identity: PetIdentity
    public var state: PetMoodState
    public var time: TimeInterval?
    /// Fraction of the scene height the pet occupies.
    public var petScale: CGFloat
    public var showsFloor: Bool
    public var showsAccessory: Bool
    /// Paint the scene's own background gradient. Off when the host paints the canvas.
    public var showsBackground: Bool
    /// Vertical position of the pet's centre as a fraction of the scene height.
    public var petVerticalPosition: CGFloat
    /// The moment the room is lit for. Widgets pass their entry date.
    public var date: Date

    @Environment(\.colorScheme) private var scheme

    public init(identity: PetIdentity, state: PetMoodState, time: TimeInterval? = nil, petScale: CGFloat = 0.62, petVerticalPosition: CGFloat = 0.49, showsFloor: Bool = true, showsAccessory: Bool = true, showsBackground: Bool = true, date: Date = .now) {
        self.showsBackground = showsBackground
        self.date = date
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
            // The pet's feet are at 168/200 of its frame; the stage sits exactly there.
            let floorY = petCenter.y - petSide / 2 + petSide * 0.84
            let dark = scheme == .dark

            ZStack {
                if showsBackground {
                    // The room fills the frame; its horizon is exactly where the feet land.
                    PetRoom(mood: state.mood, date: date, horizon: floorY / max(size.height, 1), showsFoliage: showsFloor)
                }

                // Ambient light behind the pet: additive in the dark, a warm wash in the light.
                Ellipse()
                    .fill(theme.glow(for: scheme, radius: petSide * 0.7))
                    .frame(width: petSide * 1.7, height: petSide * 1.4)
                    .position(x: petCenter.x, y: floorY - petSide * 0.42)
                    .modifier(AdditiveInDark(enabled: dark))
                    .animation(.smooth(duration: 1.2), value: state.mood)

                if showsFloor {
                    // Stage: the pool of light on the floor the pet sits in.
                    Ellipse()
                        .fill(RadialGradient(colors: [dark ? Color.white.opacity(0.16) : PipColor.sceneFloor.opacity(0.75), PipColor.sceneFloor.opacity(0)], center: .center, startRadius: 0, endRadius: petSide * 0.62))
                        .frame(width: petSide * 1.3, height: petSide * 0.26)
                        .position(x: petCenter.x, y: floorY + petSide * 0.015)
                }

                PetView(identity: identity, state: state, time: time)
                    .frame(width: petSide, height: petSide)
                    .position(petCenter)

                if showsAccessory, let accessory = state.accessory {
                    let animated = PetAnimator.animate(rig: state.rig, motion: state.motion, time: time)
                    AccessoryOverlay(kind: accessory, time: time, palette: PetPalette.palette(for: identity.species), live: animated.live, lift: animated.rig.lift, lean: animated.rig.lean, rig: animated.rig, anatomy: identity.species.anatomy)
                        .frame(width: petSide, height: petSide)
                        .position(petCenter)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.smooth(duration: 0.8), value: state.accessory)
        }
    }
}

/// Additive blending only in dark mode; in light mode a blend mode would force an offscreen
/// group and leave a visible edge around the scene.
private struct AdditiveInDark: ViewModifier {
    var enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.blendMode(.plusLighter) } else { content }
    }
}

/// Small props around the pet: sparkles, zzz, stress squiggles, a rain cloud, steam.
/// Drawn in the same 200×200 design space as the pet so they line up at any size.
public struct AccessoryOverlay: View {
    public var kind: PetAccessory
    public var time: TimeInterval?
    public var palette: PetPalette
    /// Body motion, so held props move with the pet.
    public var live: LiveMotion
    public var lift: Double
    public var lean: Double
    /// The animated rig and species anatomy, so worn props (the nightcap) sit on the head.
    public var rig: PetRig
    public var anatomy: PetAnatomy?

    @Environment(\.colorScheme) private var scheme

    public init(kind: PetAccessory, time: TimeInterval?, palette: PetPalette, live: LiveMotion = .still, lift: Double = 0, lean: Double = 0, rig: PetRig = PetRig(), anatomy: PetAnatomy? = nil) {
        self.kind = kind
        self.time = time
        self.palette = palette
        self.live = live
        self.lift = lift
        self.lean = lean
        self.rig = rig
        self.anatomy = anatomy
    }

    /// The same body transform `PetView.draw` applies: shiver/hop/lift, lean about the feet, squash.
    private func bodyContext(_ ctx: GraphicsContext) -> GraphicsContext {
        var body = ctx
        let pivot = CGPoint(x: 100, y: 168)
        let squash = CGFloat(live.squash)
        body.translateBy(x: CGFloat(live.shiverX), y: CGFloat(-live.hop + lift))
        body.translateBy(x: pivot.x, y: pivot.y)
        body.rotate(by: .degrees(lean + live.lean))
        body.scaleBy(x: 1 - (squash - 1) * 0.55, y: squash)
        body.translateBy(x: -pivot.x, y: -pivot.y)
        return body
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
            case .umbrella:
                // The cloud stays put in the world; the umbrella is held, so it rides the body.
                let c = CGPoint(x: 100, y: 8 + sin(t * 1.2) * 1.5)
                let cloudColor = scheme == .dark ? Color(white: 0.55) : Color(red: 0.62, green: 0.68, blue: 0.78)
                var cloud = Path()
                cloud.addEllipse(in: CGRect(x: c.x - 22, y: c.y - 5, width: 24, height: 16))
                cloud.addEllipse(in: CGRect(x: c.x - 10, y: c.y - 13, width: 22, height: 22))
                cloud.addEllipse(in: CGRect(x: c.x + 2, y: c.y - 6, width: 22, height: 16))
                ctx.fill(cloud, with: .color(cloudColor.opacity(0.85)))

                var held = ctx
                held.translateBy(x: CGFloat(live.shiverX), y: CGFloat(-live.hop + lift))
                held.translateBy(x: 100, y: 168)
                held.rotate(by: .degrees(lean + live.lean))
                held.translateBy(x: -100, y: -168)
                let raise = CGFloat(live.prop)
                let top = CGPoint(x: 100, y: 46 - raise * 8 + CGFloat(live.headBob) * 0.3)
                let canopyW: CGFloat = 92, canopyH: CGFloat = 26
                var canopy = Path()
                canopy.move(to: CGPoint(x: top.x - canopyW / 2, y: top.y + canopyH))
                canopy.addQuadCurve(to: CGPoint(x: top.x, y: top.y), control: CGPoint(x: top.x - canopyW * 0.42, y: top.y - canopyH * 0.35))
                canopy.addQuadCurve(to: CGPoint(x: top.x + canopyW / 2, y: top.y + canopyH), control: CGPoint(x: top.x + canopyW * 0.42, y: top.y - canopyH * 0.35))
                // Three scallops along the bottom edge.
                for i in stride(from: 2, through: 0, by: -1) {
                    let x0 = top.x - canopyW / 2 + canopyW * CGFloat(i + 1) / 3
                    let x1 = top.x - canopyW / 2 + canopyW * CGFloat(i) / 3
                    canopy.addQuadCurve(to: CGPoint(x: x1, y: top.y + canopyH), control: CGPoint(x: (x0 + x1) / 2, y: top.y + canopyH - 7))
                }
                canopy.closeSubpath()
                let coral = Color(red: 0.96, green: 0.55, blue: 0.45)
                held.fill(canopy, with: .linearGradient(Gradient(colors: [coral.opacity(0.98), Color(red: 0.86, green: 0.40, blue: 0.34)]), startPoint: CGPoint(x: top.x - canopyW / 2, y: top.y), endPoint: CGPoint(x: top.x + canopyW / 2, y: top.y + canopyH)))
                var ribs = Path()
                for i in 1..<3 {
                    let x = top.x - canopyW / 2 + canopyW * CGFloat(i) / 3
                    ribs.move(to: top)
                    ribs.addQuadCurve(to: CGPoint(x: x, y: top.y + canopyH), control: CGPoint(x: (top.x + x) / 2, y: top.y + canopyH * 0.35))
                }
                held.stroke(ribs, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                var tip = Path()
                tip.move(to: top)
                tip.addLine(to: CGPoint(x: top.x, y: top.y - 6))
                var handle = Path()
                handle.move(to: CGPoint(x: top.x, y: top.y + canopyH - 2))
                handle.addLine(to: CGPoint(x: top.x, y: top.y + canopyH + 56))
                handle.addQuadCurve(to: CGPoint(x: top.x - 8, y: top.y + canopyH + 56), control: CGPoint(x: top.x - 4, y: top.y + canopyH + 64))
                let stick = scheme == .dark ? Color(white: 0.85) : Color(red: 0.36, green: 0.30, blue: 0.28)
                held.stroke(tip, with: .color(stick), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                held.stroke(handle, with: .color(stick), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

                // Rain that hits the canopy and skips off it, plus a couple of stray drops past the edge.
                for i in 0..<5 {
                    let phase = (t * 0.8 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1)
                    let x = c.x - 34 + CGFloat(i) * 17
                    let onCanopy = abs(x - top.x) < canopyW / 2 - 4
                    let landing = onCanopy ? top.y + abs(x - top.x) * 0.22 - 3 : 150
                    let y = c.y + 12 + phase * (landing - c.y - 12)
                    var drop = Path()
                    drop.move(to: CGPoint(x: x, y: y))
                    drop.addLine(to: CGPoint(x: x - 1, y: y + 4))
                    ctx.stroke(drop, with: .color(Color(red: 0.45, green: 0.65, blue: 0.95).opacity(0.8 * (1 - phase * 0.4))), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    if onCanopy, phase > 0.85 {
                        let k = (phase - 0.85) / 0.15
                        let splash = Path(ellipseIn: CGRect(x: x - 1.2, y: landing - 2 - k * 4, width: 2.4, height: 2.4))
                        ctx.fill(splash, with: .color(Color(red: 0.45, green: 0.65, blue: 0.95).opacity(0.7 * (1 - k))))
                    }
                }
            case .nightcap:
                // A soft cap that sits on the head and moves with it, and a slow zzz.
                let p = PetPaintContext(rig: rig, live: live, palette: palette, colorScheme: scheme, anatomy: anatomy ?? PetSpecies.penguin.anatomy)
                var head = bodyContext(ctx)
                head.concatenate(p.headTilt)
                let h = p.head
                let capColor = Color(red: 0.52, green: 0.55, blue: 0.86)
                let capShade = Color(red: 0.40, green: 0.42, blue: 0.72)
                let bandW = h.width * 0.78, bandH = h.height * 0.14
                let bandY = h.top + h.height * 0.10
                // Cone: from the band up and over to the pet's right, drooping at the tip.
                var cone = Path()
                cone.move(to: CGPoint(x: h.center.x - bandW / 2, y: bandY))
                cone.addQuadCurve(to: CGPoint(x: h.center.x + h.width * 0.62, y: bandY - h.height * 0.28), control: CGPoint(x: h.center.x - h.width * 0.05, y: bandY - h.height * 0.62))
                cone.addQuadCurve(to: CGPoint(x: h.center.x + bandW / 2, y: bandY), control: CGPoint(x: h.center.x + h.width * 0.42, y: bandY - h.height * 0.16))
                cone.closeSubpath()
                head.fill(cone, with: .linearGradient(Gradient(colors: [capColor, capShade]), startPoint: CGPoint(x: h.center.x - bandW / 2, y: bandY - h.height * 0.5), endPoint: CGPoint(x: h.center.x + bandW / 2, y: bandY)))
                let band = CGRect(x: h.center.x - bandW / 2, y: bandY - bandH / 2, width: bandW, height: bandH)
                head.fill(Path(roundedRect: band, cornerRadius: bandH / 2), with: .color(Color(red: 0.97, green: 0.96, blue: 0.92)))
                let pom = CGRect(x: h.center.x + h.width * 0.62 - bandH * 0.55, y: bandY - h.height * 0.28 - bandH * 0.55, width: bandH * 1.1, height: bandH * 1.1)
                head.fill(Path(ellipseIn: pom), with: .color(Color(red: 0.97, green: 0.96, blue: 0.92)))
                for i in 0..<3 {
                    let phase = ((t * 0.3) + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                    let alpha = sin(phase * .pi)
                    let x = 140 + phase * 20 + Double(i) * 3
                    let y = 70 - phase * 34
                    let fontSize = 9.0 + phase * 8
                    ctx.draw(Text("z").font(.system(size: fontSize, weight: .bold, design: .rounded)).foregroundStyle(ink.opacity(alpha)), at: CGPoint(x: x, y: y))
                }

            case .laptop:
                // A small open laptop on the floor in front of the pet; the screen lights the face.
                let base = CGRect(x: 66, y: 150, width: 68, height: 11)
                let lid = CGRect(x: 71, y: 116, width: 58, height: 36)
                var lidPath = Path()
                lidPath.move(to: CGPoint(x: lid.minX + 3, y: lid.minY))
                lidPath.addLine(to: CGPoint(x: lid.maxX - 3, y: lid.minY))
                lidPath.addLine(to: CGPoint(x: lid.maxX, y: lid.maxY))
                lidPath.addLine(to: CGPoint(x: lid.minX, y: lid.maxY))
                lidPath.closeSubpath()
                let shell = scheme == .dark ? Color(white: 0.30) : Color(red: 0.72, green: 0.74, blue: 0.78)
                let shellShade = scheme == .dark ? Color(white: 0.22) : Color(red: 0.58, green: 0.60, blue: 0.66)
                // Screen glow on the face, drawn first so the laptop sits on top of it.
                let flicker = 0.9 + 0.1 * sin(t * 9)
                ctx.fill(Path(ellipseIn: CGRect(x: 60, y: 60, width: 80, height: 70)), with: .radialGradient(Gradient(colors: [Color(red: 0.75, green: 0.88, blue: 1).opacity(0.28 * flicker), .clear]), center: CGPoint(x: 100, y: 100), startRadius: 0, endRadius: 46))
                ctx.fill(lidPath, with: .linearGradient(Gradient(colors: [shell, shellShade]), startPoint: CGPoint(x: lid.midX, y: lid.minY), endPoint: CGPoint(x: lid.midX, y: lid.maxY)))
                let screen = CGRect(x: lid.minX + 6, y: lid.minY + 4, width: lid.width - 12, height: lid.height - 9)
                ctx.fill(Path(roundedRect: screen, cornerRadius: 2), with: .linearGradient(Gradient(colors: [Color(red: 0.86, green: 0.94, blue: 1), Color(red: 0.70, green: 0.84, blue: 0.98)]), startPoint: CGPoint(x: screen.minX, y: screen.minY), endPoint: CGPoint(x: screen.maxX, y: screen.maxY)))
                // A few lines of "text" that scroll while typing.
                let scroll = (t * 0.6).truncatingRemainder(dividingBy: 1)
                for i in 0..<4 {
                    let y = screen.minY + 5 + CGFloat(i) * 5.5 - CGFloat(scroll) * 5.5
                    guard y > screen.minY + 2, y < screen.maxY - 2 else { continue }
                    let w = screen.width * (0.4 + 0.5 * PetAnimator.hash01(Double(i) + floor(t * 0.6)))
                    ctx.fill(Path(roundedRect: CGRect(x: screen.minX + 4, y: y, width: w, height: 2), cornerRadius: 1), with: .color(Color(red: 0.30, green: 0.42, blue: 0.62).opacity(0.7)))
                }
                ctx.fill(Path(roundedRect: base, cornerRadius: 3), with: .linearGradient(Gradient(colors: [shell, shellShade]), startPoint: CGPoint(x: base.midX, y: base.minY), endPoint: CGPoint(x: base.midX, y: base.maxY)))
                ctx.fill(Path(roundedRect: CGRect(x: base.minX + 8, y: base.minY + 3, width: base.width - 16, height: 4), cornerRadius: 1.5), with: .color(shellShade.opacity(0.6)))

            case .book:
                // An open book held at the chest, following the body.
                var body = bodyContext(ctx)
                let cx: CGFloat = 100, top: CGFloat = 116, w: CGFloat = 48, h: CGFloat = 26
                let cover = Color(red: 0.86, green: 0.48, blue: 0.40)
                let page = Color(red: 0.99, green: 0.97, blue: 0.92)
                var left = Path(), right = Path()
                left.move(to: CGPoint(x: cx, y: top + 4))
                left.addQuadCurve(to: CGPoint(x: cx - w / 2, y: top), control: CGPoint(x: cx - w * 0.25, y: top - 3))
                left.addLine(to: CGPoint(x: cx - w / 2, y: top + h))
                left.addQuadCurve(to: CGPoint(x: cx, y: top + h + 4), control: CGPoint(x: cx - w * 0.25, y: top + h + 1))
                left.closeSubpath()
                right.move(to: CGPoint(x: cx, y: top + 4))
                right.addQuadCurve(to: CGPoint(x: cx + w / 2, y: top), control: CGPoint(x: cx + w * 0.25, y: top - 3))
                right.addLine(to: CGPoint(x: cx + w / 2, y: top + h))
                right.addQuadCurve(to: CGPoint(x: cx, y: top + h + 4), control: CGPoint(x: cx + w * 0.25, y: top + h + 1))
                right.closeSubpath()
                body.fill(left.applying(CGAffineTransform(translationX: -1.5, y: 2)), with: .color(cover))
                body.fill(right.applying(CGAffineTransform(translationX: 1.5, y: 2)), with: .color(cover))
                body.fill(left, with: .color(page))
                body.fill(right, with: .color(page))
                var lines = Path()
                for side: CGFloat in [-1, 1] {
                    for i in 0..<3 {
                        let y = top + 7 + CGFloat(i) * 5.5
                        lines.move(to: CGPoint(x: cx + side * 5, y: y))
                        lines.addLine(to: CGPoint(x: cx + side * (w / 2 - 6), y: y - side * 0.5))
                    }
                }
                body.stroke(lines, with: .color(Color(red: 0.55, green: 0.50, blue: 0.48).opacity(0.5)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

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
