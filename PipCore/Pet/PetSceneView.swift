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
                    AccessoryOverlay(kind: accessory, time: time, palette: PetPalette.palette(for: identity.species), live: animated.live, rig: animated.rig, species: identity.species)
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

/// Small props around the pet: sparkles, zzz, stress squiggles, a rain cloud, steam — and the
/// things the pet holds or wears. Drawn in the same 200×200 design space as the pet so they line
/// up at any size; held props are anchored to the paw (`PetDraw.handPoint`) and ride the same
/// body transform as the pet, so they are *in hand* in every frame.
public struct AccessoryOverlay: View {
    public var kind: PetAccessory
    public var time: TimeInterval?
    public var palette: PetPalette
    /// Body motion, so held props move with the pet.
    public var live: LiveMotion
    /// The animated rig, so worn and held props follow the pose.
    public var rig: PetRig
    public var species: PetSpecies

    @Environment(\.colorScheme) private var scheme

    public init(kind: PetAccessory, time: TimeInterval?, palette: PetPalette, live: LiveMotion = .still, rig: PetRig = PetRig(), species: PetSpecies = .penguin) {
        self.kind = kind
        self.time = time
        self.palette = palette
        self.live = live
        self.rig = rig
        self.species = species
    }

    private var paint: PetPaintContext {
        PetPaintContext(rig: rig, live: live, palette: palette, colorScheme: scheme, anatomy: species.anatomy)
    }

    /// The same transform `PetView.draw` applies to the body.
    private func bodyContext(_ ctx: GraphicsContext) -> GraphicsContext {
        var body = ctx
        body.concatenate(PetDraw.bodyTransform(rig: rig, live: live))
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
                // The cloud stays put in the world. The umbrella is *held*: its handle sits in the
                // pet's right paw and the shaft rises from there to a canopy centred over the head,
                // so it tilts with the arm and rides the body through every hop and lean.
                let c = CGPoint(x: 100, y: 8 + sin(t * 1.2) * 1.5)
                let cloudColor = scheme == .dark ? Color(white: 0.55) : Color(red: 0.62, green: 0.68, blue: 0.78)
                var cloud = Path()
                cloud.addEllipse(in: CGRect(x: c.x - 22, y: c.y - 5, width: 24, height: 16))
                cloud.addEllipse(in: CGRect(x: c.x - 10, y: c.y - 13, width: 22, height: 22))
                cloud.addEllipse(in: CGRect(x: c.x + 2, y: c.y - 6, width: 22, height: 16))
                ctx.fill(cloud, with: .color(cloudColor.opacity(0.85)))

                let p = paint
                let transform = PetDraw.bodyTransform(rig: rig, live: live)
                var held = bodyContext(ctx)
                let hand = PetDraw.handPoint(p, species: species, side: 1)
                // Where the canopy wants to be: over the crown, drawn toward the holding paw so the
                // shaft passes the cheek rather than the face.
                let raise = CGFloat(live.prop)
                let goal = CGPoint(x: p.head.center.x + (hand.x - p.head.center.x) * 0.35, y: p.head.top - 24 + (1 - raise) * 10)
                let dx = goal.x - hand.x, dy = goal.y - hand.y
                let shaftLen = max(30, sqrt(dx * dx + dy * dy))
                let dir = CGPoint(x: dx / shaftLen, y: dy / shaftLen)
                let top = goal
                let tiltAngle = atan2(dir.y, dir.x) + .pi / 2
                let stick = scheme == .dark ? Color(white: 0.85) : Color(red: 0.36, green: 0.30, blue: 0.28)
                // Shaft from just under the canopy to a little below the paw, ending in a crook.
                var shaft = Path()
                shaft.move(to: CGPoint(x: top.x - dir.x * 2, y: top.y - dir.y * 2))
                shaft.addLine(to: CGPoint(x: hand.x - dir.x * 10, y: hand.y - dir.y * 10))
                let crookEnd = CGPoint(x: hand.x - dir.x * 10 - dir.y * 8, y: hand.y - dir.y * 10 + dir.x * 8)
                shaft.addQuadCurve(to: crookEnd, control: CGPoint(x: hand.x - dir.x * 17 - dir.y * 2, y: hand.y - dir.y * 17 + dir.x * 2))
                held.stroke(shaft, with: .color(stick), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                // Canopy, drawn in a frame aligned with the shaft.
                var canopyCtx = held
                canopyCtx.translateBy(x: top.x, y: top.y)
                canopyCtx.rotate(by: .radians(tiltAngle))
                let canopyW: CGFloat = 112, canopyH: CGFloat = 28
                var canopy = Path()
                canopy.move(to: CGPoint(x: -canopyW / 2, y: canopyH))
                canopy.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: -canopyW * 0.42, y: -canopyH * 0.35))
                canopy.addQuadCurve(to: CGPoint(x: canopyW / 2, y: canopyH), control: CGPoint(x: canopyW * 0.42, y: -canopyH * 0.35))
                for i in stride(from: 2, through: 0, by: -1) {
                    let x0 = -canopyW / 2 + canopyW * CGFloat(i + 1) / 3
                    let x1 = -canopyW / 2 + canopyW * CGFloat(i) / 3
                    canopy.addQuadCurve(to: CGPoint(x: x1, y: canopyH), control: CGPoint(x: (x0 + x1) / 2, y: canopyH - 7))
                }
                canopy.closeSubpath()
                let coral = Color(red: 0.96, green: 0.55, blue: 0.45)
                canopyCtx.fill(canopy, with: .linearGradient(Gradient(colors: [coral.opacity(0.98), Color(red: 0.86, green: 0.40, blue: 0.34)]), startPoint: CGPoint(x: -canopyW / 2, y: 0), endPoint: CGPoint(x: canopyW / 2, y: canopyH)))
                var ribs = Path()
                for i in 1..<3 {
                    let x = -canopyW / 2 + canopyW * CGFloat(i) / 3
                    ribs.move(to: .zero)
                    ribs.addQuadCurve(to: CGPoint(x: x, y: canopyH), control: CGPoint(x: x / 2, y: canopyH * 0.35))
                }
                canopyCtx.stroke(ribs, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                var tip = Path()
                tip.move(to: .zero)
                tip.addLine(to: CGPoint(x: 0, y: -6))
                canopyCtx.stroke(tip, with: .color(stick), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

                // The paw in front of the handle.
                PetDraw.pawOver(&held, p, species: species, at: hand)

                // Rain: falls in the world, lands on the canopy where the canopy actually is.
                let worldTop = top.applying(transform)
                for i in 0..<5 {
                    let phase = (t * 0.8 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1)
                    let x = c.x - 34 + CGFloat(i) * 17
                    let onCanopy = abs(x - worldTop.x) < canopyW / 2 - 6
                    let landing = onCanopy ? worldTop.y + abs(x - worldTop.x) * 0.24 - 2 : 150
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
                let p = paint
                var head = bodyContext(ctx)
                head.concatenate(p.headTilt)
                let h = p.head
                let capColor = Color(red: 0.52, green: 0.55, blue: 0.86)
                let capShade = Color(red: 0.40, green: 0.42, blue: 0.72)
                let bandW = h.width * 0.86, bandH = h.height * 0.14
                let bandY = h.top + h.height * 0.17
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
                // A small laptop on the floor in front of the pet, its lid open *toward the pet*:
                // we see the back of the screen, and its light spills over the lid onto the face.
                // The paws reach down behind the lid to the keyboard.
                let shell = scheme == .dark ? Color(white: 0.34) : Color(red: 0.76, green: 0.78, blue: 0.82)
                let shellShade = scheme == .dark ? Color(white: 0.24) : Color(red: 0.60, green: 0.62, blue: 0.68)
                let flicker = 0.88 + 0.12 * sin(t * 9) * sin(t * 2.3)
                let glowColor = Color(red: 0.78, green: 0.90, blue: 1)
                // Light on the face and chest, from below.
                ctx.fill(Path(ellipseIn: CGRect(x: 54, y: 66, width: 92, height: 76)), with: .radialGradient(Gradient(colors: [glowColor.opacity(0.30 * flicker), .clear]), center: CGPoint(x: 100, y: 118), startRadius: 0, endRadius: 50))
                // Base: we see its front edge.
                let base = CGRect(x: 63, y: 155, width: 74, height: 9)
                ctx.fill(Path(roundedRect: base, cornerRadius: 2.5), with: .linearGradient(Gradient(colors: [shell, shellShade]), startPoint: CGPoint(x: base.midX, y: base.minY), endPoint: CGPoint(x: base.midX, y: base.maxY)))
                // Lid: leans back toward the pet, so it is a hair narrower at the top.
                var lid = Path()
                lid.move(to: CGPoint(x: 70, y: 115))
                lid.addLine(to: CGPoint(x: 130, y: 115))
                lid.addLine(to: CGPoint(x: 133, y: 156))
                lid.addLine(to: CGPoint(x: 67, y: 156))
                lid.closeSubpath()
                let lidRounded = lid.strokedPath(StrokeStyle(lineWidth: 3, lineJoin: .round)).union(lid)
                ctx.fill(lidRounded, with: .linearGradient(Gradient(colors: [shellShade, shell]), startPoint: CGPoint(x: 100, y: 115), endPoint: CGPoint(x: 100, y: 156)))
                // Screen light leaking around the lid's top edge.
                ctx.fill(Path(roundedRect: CGRect(x: 71, y: 112.5, width: 58, height: 2.5), cornerRadius: 1.2), with: .color(glowColor.opacity(0.85 * flicker)))
                // A small light on the back of the lid.
                ctx.fill(Path(ellipseIn: CGRect(x: 97, y: 132, width: 6, height: 6)), with: .color(.white.opacity(scheme == .dark ? 0.55 : 0.9)))

            case .book:
                // An open book held between the paws: its lower corners sit in the hands, so it
                // follows the arms and the body. `live.prop` runs 1 → 0 → 1 while a page turns.
                let p = paint
                var body = bodyContext(ctx)
                // The book keeps the size and place of the resting hold; only the paws move.
                var holdRig = rig
                holdRig.armHold = 1; holdRig.armRaise = 0; holdRig.armOut = 0; holdRig.armForward = 0; holdRig.armToFace = 0; holdRig.armCross = 0
                let holdPaint = PetPaintContext(rig: holdRig, live: .still, palette: palette, colorScheme: scheme, anatomy: species.anatomy)
                let restL = PetDraw.handPoint(holdPaint, species: species, side: -1)
                let restR = PetDraw.handPoint(holdPaint, species: species, side: 1)
                let hl = PetDraw.handPoint(p, species: species, side: -1)
                let hr = PetDraw.handPoint(p, species: species, side: 1)
                let cx = (restL.x + restR.x) / 2
                let w = max(36, restR.x - restL.x + 12)
                let bottom = (restL.y + restR.y) / 2 + 3
                let h: CGFloat = 26
                let top = bottom - h
                let cover = Color(red: 0.86, green: 0.48, blue: 0.40)
                let page = Color(red: 0.99, green: 0.97, blue: 0.92)
                func pagePath(_ side: CGFloat) -> Path {
                    var pg = Path()
                    pg.move(to: CGPoint(x: cx, y: top + 4))
                    pg.addQuadCurve(to: CGPoint(x: cx + side * w / 2, y: top), control: CGPoint(x: cx + side * w * 0.25, y: top - 3))
                    pg.addLine(to: CGPoint(x: cx + side * w / 2, y: top + h))
                    pg.addQuadCurve(to: CGPoint(x: cx, y: top + h + 4), control: CGPoint(x: cx + side * w * 0.25, y: top + h + 1))
                    pg.closeSubpath()
                    return pg
                }
                let left = pagePath(-1), right = pagePath(1)
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
                // A page mid-turn: the right page swings up about the spine and lands on the left.
                let flip = CGFloat(1 - live.prop)
                if flip > 0.02 {
                    let k = cos(flip * .pi)
                    let turning = right.applying(CGAffineTransform(translationX: cx, y: top + h / 2).scaledBy(x: max(abs(k), 0.04) * (k < 0 ? -1 : 1), y: 1 - 0.15 * sin(flip * .pi)).translatedBy(x: -cx, y: -(top + h / 2)))
                    body.fill(turning, with: .color(page))
                    body.stroke(turning, with: .color(cover.opacity(0.5)), style: StrokeStyle(lineWidth: 0.8))
                }
                PetDraw.pawOver(&body, p, species: species, at: CGPoint(x: hl.x, y: hl.y))
                PetDraw.pawOver(&body, p, species: species, at: CGPoint(x: hr.x, y: hr.y))

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
