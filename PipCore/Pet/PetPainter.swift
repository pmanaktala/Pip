import SwiftUI

/// Shared drawing vocabulary for all species painters. See `Docs/CharacterSpec.md`.
///
/// Painters draw into a 200×200 "design canvas"; `PetView` scales it to fit. Every pet
/// is a sitting animal built from the same parts — head, bean torso, haunches, front
/// legs — with species parts (ears, tail, markings, flippers) on top of one face system.
/// The rig decides the pose; painters only draw. Paired parts are drawn once and
/// mirrored, every form is lit by the same key light, and stroke weights come from the
/// context so they hold up at badge size.
public struct PetPaintContext {
    public var rig: PetRig
    public var live: LiveMotion
    public var palette: PetPalette
    public var colorScheme: ColorScheme
    public var anatomy: PetAnatomy
    public var detail: Detail

    /// Rendering detail. `.small` drops hairline features and thickens ink so a 24pt badge still reads.
    public enum Detail: Sendable { case full, small }

    /// Where the feet touch the ground.
    public let floor: CGFloat = 168
    /// Centre line.
    public let axis: CGFloat = 100

    /// Head geometry after pose adjustments (canvas coordinates).
    public var head: Blob
    /// Torso geometry after pose adjustments.
    public var torso: Torso

    /// Ink stroke width for mouths, brows and closed eyes.
    public var inkWidth: CGFloat { detail == .small ? 3.6 : 2.2 }
    public var ink: Color { palette.ink }

    /// Horizontal shift applied to every facial feature when the head turns.
    public var faceShift: CGFloat { CGFloat(rig.headTurn) * head.width * 0.07 }

    public struct Blob {
        public var center: CGPoint
        public var width: CGFloat
        public var height: CGFloat
        /// 0 = ellipse, 1 = squarish cheeks.
        public var squareness: CGFloat

        public var rect: CGRect { CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height) }
        public var top: CGFloat { center.y - height / 2 }
        public var bottom: CGFloat { center.y + height / 2 }

        /// A point in head-relative units (fractions of width / height from the centre).
        public func point(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: center.x + fx * width, y: center.y + fy * height)
        }
    }

    public struct Torso {
        public var centerX: CGFloat
        public var top: CGFloat
        public var bottom: CGFloat
        public var chestWidth: CGFloat
        public var hipWidth: CGFloat

        public var height: CGFloat { bottom - top }
        public var center: CGPoint { CGPoint(x: centerX, y: (top + bottom) / 2) }
        public var rect: CGRect { CGRect(x: centerX - hipWidth / 2, y: top, width: hipWidth, height: height) }
    }

    public init(rig: PetRig, live: LiveMotion, palette: PetPalette, colorScheme: ColorScheme, anatomy: PetAnatomy, detail: Detail = .full) {
        self.rig = rig
        self.live = live
        self.palette = palette
        self.colorScheme = colorScheme
        self.anatomy = anatomy
        self.detail = detail

        let lying = CGFloat(rig.lying)
        let squash = CGFloat(rig.squash)
        let drop = CGFloat(rig.headDrop)

        // Torso: sits on the floor; flattens and widens when lying.
        let torsoHeight = (anatomy.torsoHeight - 24 * lying) * squash
        let hip = anatomy.hipWidth + 30 * lying
        let chest = anatomy.chestWidth + 26 * lying
        torso = Torso(centerX: 100, top: 168 - torsoHeight, bottom: 168, chestWidth: chest, hipWidth: hip)

        // Head: sits on the chest with a short neck; sinks into the shoulders when dropped or lying.
        let headW = anatomy.headWidth / sqrt(squash)
        let headH = anatomy.headHeight * (0.94 + 0.06 * squash)
        let overlap = anatomy.headOverlap + 10 * drop + 6 * lying
        let headY = torso.top + overlap - headH / 2 + CGFloat(live.headBob)
        head = Blob(center: CGPoint(x: 100, y: headY), width: headW, height: headH, squareness: anatomy.cheekSquareness)
    }
}

/// Base proportions of a species in the 200×200 design space.
public struct PetAnatomy: Sendable {
    public var headWidth: CGFloat
    public var headHeight: CGFloat
    /// How far the head sinks into the chest (a short neck).
    public var headOverlap: CGFloat
    public var cheekSquareness: CGFloat
    public var torsoHeight: CGFloat
    public var chestWidth: CGFloat
    public var hipWidth: CGFloat
    public var legWidth: CGFloat
    /// Eye radius as a fraction of head width.
    public var eyeRadius: CGFloat

    public init(headWidth: CGFloat, headHeight: CGFloat, headOverlap: CGFloat, cheekSquareness: CGFloat, torsoHeight: CGFloat, chestWidth: CGFloat, hipWidth: CGFloat, legWidth: CGFloat, eyeRadius: CGFloat = 0.083) {
        self.headWidth = headWidth
        self.headHeight = headHeight
        self.headOverlap = headOverlap
        self.cheekSquareness = cheekSquareness
        self.torsoHeight = torsoHeight
        self.chestWidth = chestWidth
        self.hipWidth = hipWidth
        self.legWidth = legWidth
        self.eyeRadius = eyeRadius
    }
}

public protocol PetPainter {
    /// Draw the pet into `ctx` (already transformed into the 200×200 design space).
    static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext)
}

// MARK: - Shared primitives

public enum PetDraw {

    // MARK: Symmetry

    /// Draws `part` twice: once as written (the pet's right side, `side == 1`) and once mirrored
    /// through `axis` (`side == -1`). Write the geometry for the right side only; use `side` only
    /// for deliberate asymmetry such as a single ear twitch.
    public static func mirrored(_ ctx: inout GraphicsContext, axis: CGFloat = 100, _ part: (inout GraphicsContext, CGFloat) -> Void) {
        part(&ctx, 1)
        var flipped = ctx
        flipped.translateBy(x: axis, y: 0)
        flipped.scaleBy(x: -1, y: 1)
        flipped.translateBy(x: -axis, y: 0)
        part(&flipped, -1)
    }

    // MARK: Lighting

    /// Fills a form with its base colour, then a soft core shadow (bottom-right) and a rim light
    /// (top-left). Every solid part of every pet goes through here so the lighting agrees.
    public static func form(_ ctx: inout GraphicsContext, _ path: Path, in rect: CGRect, base: Color, shade: Color, light: Color, strength: CGFloat = 1) {
        ctx.fill(path, with: .color(base))
        guard strength > 0 else { return }
        var inner = ctx
        inner.clip(to: path)
        let d = max(rect.width, rect.height)
        // Inside a mirrored context the x axis is flipped; keep the key light top-left on screen.
        let flipped = ctx.transform.a < 0
        let lx: CGFloat = flipped ? 0.64 : 0.36
        let shadowCenter = CGPoint(x: rect.minX + rect.width * lx, y: rect.minY + rect.height * 0.32)
        inner.fill(path, with: .radialGradient(
            Gradient(stops: [.init(color: shade.opacity(0), location: 0), .init(color: shade.opacity(0), location: 0.55), .init(color: shade.opacity(0.42 * strength), location: 1)]),
            center: shadowCenter, startRadius: 0, endRadius: d * 0.82))
        let lightCenter = CGPoint(x: rect.minX + rect.width * (flipped ? 0.66 : 0.34), y: rect.minY + rect.height * 0.24)
        inner.fill(path, with: .radialGradient(
            Gradient(colors: [light.opacity(0.55 * strength), light.opacity(0)]),
            center: lightCenter, startRadius: 0, endRadius: d * 0.42))
    }

    /// Convenience: `form` with the palette's fur tones.
    public static func fur(_ ctx: inout GraphicsContext, _ p: PetPaintContext, _ path: Path, in rect: CGRect, strength: CGFloat = 1) {
        form(&ctx, path, in: rect, base: p.palette.base, shade: p.palette.shade, light: p.palette.light, strength: strength)
    }

    /// A soft dark ellipse clipped to `within` — where one part rests on another.
    public static func contactShadow(_ ctx: inout GraphicsContext, _ p: PetPaintContext, ellipse: CGRect, within: Path, opacity: Double = 0.22) {
        var inner = ctx
        inner.clip(to: within)
        inner.fill(Path(ellipseIn: ellipse), with: .radialGradient(
            Gradient(colors: [p.palette.shade.opacity(opacity), p.palette.shade.opacity(0)]),
            center: CGPoint(x: ellipse.midX, y: ellipse.midY), startRadius: 0, endRadius: ellipse.width * 0.52))
    }

    // MARK: Head & body shapes

    /// Head: a soft rounded shape, slightly wider at the cheeks than the crown.
    public static func headPath(_ b: PetPaintContext.Blob) -> Path {
        let c = b.center, w = b.width, h = b.height
        let k: CGFloat = 0.55 + 0.25 * b.squareness
        let crown = CGPoint(x: c.x, y: c.y - h / 2)
        let right = CGPoint(x: c.x + w / 2, y: c.y + h * 0.08)
        let chin = CGPoint(x: c.x, y: c.y + h / 2)
        let left = CGPoint(x: c.x - w / 2, y: c.y + h * 0.08)
        var p = Path()
        p.move(to: crown)
        p.addCurve(to: right, control1: CGPoint(x: crown.x + w * 0.5 * k, y: crown.y), control2: CGPoint(x: right.x, y: right.y - (right.y - crown.y) * k))
        p.addCurve(to: chin, control1: CGPoint(x: right.x, y: right.y + (chin.y - right.y) * (k + 0.1)), control2: CGPoint(x: chin.x + w * 0.5 * (k + 0.05), y: chin.y))
        p.addCurve(to: left, control1: CGPoint(x: chin.x - w * 0.5 * (k + 0.05), y: chin.y), control2: CGPoint(x: left.x, y: left.y + (chin.y - left.y) * (k + 0.1)))
        p.addCurve(to: crown, control1: CGPoint(x: left.x, y: left.y - (left.y - crown.y) * k), control2: CGPoint(x: crown.x - w * 0.5 * k, y: crown.y))
        p.closeSubpath()
        return p
    }

    /// Torso: a bean — narrow shoulders, a slight waist, wide haunches, flat on the floor.
    public static func torsoPath(_ t: PetPaintContext.Torso) -> Path {
        let cx = t.centerX, h = t.height
        let shoulderY = t.top + h * 0.2
        let hipY = t.bottom - h * 0.26
        let cornerX = t.hipWidth * 0.36
        var p = Path()
        p.move(to: CGPoint(x: cx, y: t.top))
        // Right side, top to bottom.
        p.addCurve(to: CGPoint(x: cx + t.chestWidth / 2, y: shoulderY),
                   control1: CGPoint(x: cx + t.chestWidth * 0.36, y: t.top),
                   control2: CGPoint(x: cx + t.chestWidth / 2, y: t.top + h * 0.06))
        p.addCurve(to: CGPoint(x: cx + t.hipWidth / 2, y: hipY),
                   control1: CGPoint(x: cx + t.chestWidth / 2, y: t.top + h * 0.48),
                   control2: CGPoint(x: cx + t.hipWidth / 2, y: hipY - h * 0.22))
        p.addCurve(to: CGPoint(x: cx + cornerX, y: t.bottom),
                   control1: CGPoint(x: cx + t.hipWidth / 2, y: t.bottom - h * 0.02),
                   control2: CGPoint(x: cx + cornerX + 10, y: t.bottom))
        p.addLine(to: CGPoint(x: cx - cornerX, y: t.bottom))
        // Left side, bottom to top (mirror of the above).
        p.addCurve(to: CGPoint(x: cx - t.hipWidth / 2, y: hipY),
                   control1: CGPoint(x: cx - cornerX - 10, y: t.bottom),
                   control2: CGPoint(x: cx - t.hipWidth / 2, y: t.bottom - h * 0.02))
        p.addCurve(to: CGPoint(x: cx - t.chestWidth / 2, y: shoulderY),
                   control1: CGPoint(x: cx - t.hipWidth / 2, y: hipY - h * 0.22),
                   control2: CGPoint(x: cx - t.chestWidth / 2, y: t.top + h * 0.48))
        p.addCurve(to: CGPoint(x: cx, y: t.top),
                   control1: CGPoint(x: cx - t.chestWidth / 2, y: t.top + h * 0.06),
                   control2: CGPoint(x: cx - t.chestWidth * 0.36, y: t.top))
        p.closeSubpath()
        return p
    }

    /// Haunches + torso + belly patch + front legs. Species call this, then add parts.
    public static func body(_ ctx: inout GraphicsContext, _ p: PetPaintContext, belly: Bool = true, pawColor: Color? = nil, legColor: Color? = nil) {
        let t = p.torso
        let lying = CGFloat(p.rig.lying)
        let torso = torsoPath(t)

        // Haunches: rounded mounds behind the torso, bottoms on the floor.
        mirrored(&ctx) { ctx, _ in
            let hw = t.hipWidth * 0.42, hh = t.height * (0.42 - 0.12 * lying)
            let r = CGRect(x: t.centerX + t.hipWidth * 0.3 - hw / 2, y: t.bottom - hh, width: hw, height: hh)
            form(&ctx, Path(ellipseIn: r), in: r, base: p.palette.base, shade: p.palette.shade, light: p.palette.light, strength: 1.2)
        }

        fur(&ctx, p, torso, in: t.rect)

        if belly {
            // Chest patch: a soft-edged oval low on the chest, between the front legs.
            var inner = ctx
            inner.clip(to: torso)
            let bw = t.chestWidth * 0.58, bh = t.height * 0.5
            let r = CGRect(x: t.centerX - bw / 2, y: t.bottom - bh - 6, width: bw, height: bh)
            inner.fill(Path(ellipseIn: r), with: .radialGradient(
                Gradient(stops: [.init(color: p.palette.belly.opacity(0.95), location: 0), .init(color: p.palette.belly.opacity(0.9), location: 0.7), .init(color: p.palette.belly.opacity(0), location: 1)]),
                center: CGPoint(x: r.midX, y: r.midY), startRadius: 0, endRadius: max(bw, bh) * 0.55))
        }

        legs(&ctx, p, pawColor: pawColor ?? p.palette.base, legColor: legColor ?? p.palette.base)
    }

    /// Two front legs with paws, in front of the torso. Stretch forward when lying.
    public static func legs(_ ctx: inout GraphicsContext, _ p: PetPaintContext, pawColor: Color, legColor: Color) {
        let t = p.torso
        let lying = CGFloat(p.rig.lying)
        let legW = p.anatomy.legWidth
        guard legW > 0 else { return }
        let legH = t.height * (0.46 - 0.26 * lying)
        let legShade = p.palette.shade
        mirrored(&ctx) { ctx, _ in
            let x = t.centerX + t.chestWidth * 0.26 + lying * 6
            let legRect = CGRect(x: x - legW / 2, y: t.bottom - legH, width: legW, height: legH)
            let leg = Path(roundedRect: legRect, cornerRadius: legW / 2)
            form(&ctx, leg, in: legRect, base: legColor, shade: legShade, light: p.palette.light, strength: 0.9)
            // Where the leg leaves the chest.
            var inner = ctx
            inner.clip(to: leg)
            inner.fill(leg, with: .linearGradient(Gradient(colors: [legShade.opacity(0.3), legShade.opacity(0)]),
                                                  startPoint: CGPoint(x: x, y: legRect.minY), endPoint: CGPoint(x: x, y: legRect.minY + legH * 0.45)))
            // Paw: a soft oval on the floor with two toe lines.
            let pawW = legW * (1.35 + 0.45 * lying), pawH = legW * 0.68
            let pawRect = CGRect(x: x - pawW / 2 + lying * 5, y: t.bottom - pawH, width: pawW, height: pawH)
            ctx.fill(Path(ellipseIn: pawRect), with: .color(pawColor))
            if p.detail == .full {
                var toes = Path()
                for tx in [-0.2, 0.2] {
                    let px = pawRect.midX + CGFloat(tx) * pawW
                    toes.move(to: CGPoint(x: px, y: pawRect.midY + 1))
                    toes.addLine(to: CGPoint(x: px, y: pawRect.maxY - 1.4))
                }
                ctx.stroke(toes, with: .color(legShade.opacity(0.5)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }
    }

    /// Ground shadow beneath the pet. Follows hops (shrinks and fades) and leans.
    public static func floorShadow(_ ctx: inout GraphicsContext, _ p: PetPaintContext, spread: Double = 1) {
        let lift = CGFloat(p.live.hop) - CGFloat(min(0, p.rig.lift))
        let k = max(0.55, 1 - lift / 45)
        let w = (p.torso.hipWidth + 28) * k * spread
        let h = 13 * k
        let lean = CGFloat(p.rig.lean + p.live.lean)
        let r = CGRect(x: p.axis - w / 2 + lean * 0.6, y: p.floor - h / 2 + 4, width: w, height: h)
        let shade: Color = p.colorScheme == .dark ? .black : Color(red: 0.30, green: 0.22, blue: 0.18)
        ctx.fill(Path(ellipseIn: r), with: .radialGradient(
            Gradient(colors: [shade.opacity(0.26 * k), shade.opacity(0.14 * k), shade.opacity(0)]),
            center: CGPoint(x: r.midX, y: r.midY), startRadius: 0, endRadius: w * 0.5))
    }

    /// Soft shadow on the torso under the chin, so the head sits *on* the body.
    public static func neckShadow(_ ctx: inout GraphicsContext, _ p: PetPaintContext, within: Path) {
        let h = p.head
        let r = CGRect(x: h.center.x - h.width * 0.42, y: h.bottom - h.height * 0.14, width: h.width * 0.84, height: h.height * 0.3)
        contactShadow(&ctx, p, ellipse: r, within: within, opacity: 0.3)
    }

    // MARK: Face (positions are fractions of the head)

    public struct FaceLayout {
        /// Eye centre offset from the head centre, as a fraction of head width.
        public var eyeSpacing: CGFloat = 0.21
        /// Eye line as a fraction of head height from the centre (negative = above).
        public var eyeY: CGFloat = -0.02
        public var eyeRadius: CGFloat = 0.083
        public var mouthY: CGFloat = 0.22
        public var mouthWidth: CGFloat = 0.13
        public var blushX: CGFloat = 0.36
        public var blushY: CGFloat = 0.14
        public init() {}
    }

    public static func eyeCenter(_ p: PetPaintContext, layout: FaceLayout, side: CGFloat) -> CGPoint {
        let h = p.head
        let r = h.width * layout.eyeRadius
        return CGPoint(x: h.center.x + p.faceShift + side * h.width * layout.eyeSpacing + CGFloat(p.rig.gazeX) * r * 0.2,
                       y: h.center.y + h.height * layout.eyeY + CGFloat(p.rig.gazeY) * r * 0.15)
    }

    /// Both eyes. Highlights stay top-left on both (key light), so eyes are drawn explicitly, not mirrored.
    public static func eyes(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: FaceLayout = FaceLayout(), lidColor: Color? = nil) {
        let r = p.head.width * layout.eyeRadius * CGFloat(p.rig.eyeScale)
        let lid = lidColor ?? p.palette.base
        for side: CGFloat in [-1, 1] {
            eye(&ctx, p, center: eyeCenter(p, layout: layout, side: side), radius: r, side: side, lidColor: lid)
        }
    }

    static func eye(_ ctx: inout GraphicsContext, _ p: PetPaintContext, center c: CGPoint, radius r: CGFloat, side: CGFloat, lidColor: Color) {
        let rig = p.rig
        let open = CGFloat(rig.eyeOpen)
        let arc = CGFloat(rig.eyeArc)
        let inkStyle = StrokeStyle(lineWidth: max(p.inkWidth, r * 0.36), lineCap: .round)

        // Closed: a single curved line. Curves up (^) when happy, down when resting.
        if open < 0.12 {
            var path = Path()
            let dir: CGFloat = arc > 0.3 ? -1 : 1
            path.move(to: CGPoint(x: c.x - r * 0.95, y: c.y))
            path.addQuadCurve(to: CGPoint(x: c.x + r * 0.95, y: c.y), control: CGPoint(x: c.x, y: c.y + dir * r * 0.9))
            ctx.stroke(path, with: .color(p.ink), style: inkStyle)
            return
        }

        // Happy arc replaces the eye entirely once it is strong enough.
        if arc > 0.55 {
            var path = Path()
            path.move(to: CGPoint(x: c.x - r * 1.0, y: c.y + r * 0.3))
            path.addQuadCurve(to: CGPoint(x: c.x + r * 1.0, y: c.y + r * 0.3), control: CGPoint(x: c.x, y: c.y - r * 1.2))
            ctx.stroke(path, with: .color(p.ink), style: inkStyle)
            return
        }

        let height = 2 * r * (0.3 + 0.7 * open) * (1 - 0.3 * arc)
        let rect = CGRect(x: c.x - r, y: c.y - height / 2, width: 2 * r, height: height)
        let eyePath = Path(ellipseIn: rect)

        var eyeCtx = ctx
        eyeCtx.clip(to: eyePath)
        eyeCtx.fill(eyePath, with: .color(p.ink))

        // Upper lid: squint / heavy lids cover from the top.
        let cover = max(CGFloat(rig.eyeSquint) * 0.42, CGFloat(rig.lidHeaviness) * 0.5)
        if cover > 0.01 {
            let lidRect = rect.offsetBy(dx: 0, dy: -height * (1 - cover))
            eyeCtx.fill(Path(ellipseIn: lidRect), with: .color(lidColor))
        }
        // Angry: the inner corner of the lid comes down in a wedge.
        if rig.browInnerUp < -0.2 {
            let k = CGFloat(-rig.browInnerUp) * CGFloat(max(rig.browWeight, 0.5))
            var wedge = Path()
            let innerX = c.x - side * r
            wedge.move(to: CGPoint(x: innerX, y: c.y - height * 0.7))
            wedge.addLine(to: CGPoint(x: innerX, y: c.y - height * (0.7 - 0.6 * k)))
            wedge.addLine(to: CGPoint(x: c.x + side * r * 1.05, y: c.y - height * 0.7))
            wedge.closeSubpath()
            eyeCtx.fill(wedge, with: .color(lidColor))
        }
        // Lower lid lifts a little for a soft smile.
        if arc > 0.01 {
            let lower = rect.offsetBy(dx: 0, dy: height * (1 - arc * 0.55))
            eyeCtx.fill(Path(ellipseIn: lower), with: .color(lidColor))
        }

        // Highlights: key light top-left on both eyes; a small secondary catch bottom-right.
        let gx = CGFloat(rig.gazeX) * r * 0.25, gy = CGFloat(rig.gazeY) * r * 0.25
        let ps = CGFloat(rig.pupilScale)
        let alpha = Double(min(1, open * 1.5))
        let big = r * 0.62 * ps
        eyeCtx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.38 + gx - big / 2, y: c.y - r * 0.4 + gy - big / 2, width: big, height: big)), with: .color(.white.opacity(0.95 * alpha)))
        if p.detail == .full {
            let small = r * 0.26
            eyeCtx.fill(Path(ellipseIn: CGRect(x: c.x + r * 0.32 + gx - small / 2, y: c.y + r * 0.34 + gy - small / 2, width: small, height: small)), with: .color(.white.opacity(0.7 * alpha)))
        }
    }

    public static func brows(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: FaceLayout = FaceLayout()) {
        let rig = p.rig
        guard rig.browWeight > 0.02 else { return }
        let h = p.head
        let r = h.width * layout.eyeRadius * CGFloat(rig.eyeScale)
        for side: CGFloat in [-1, 1] {
            let c = eyeCenter(p, layout: layout, side: side)
            let cy = c.y - r * 1.55
            let innerLift = CGFloat(rig.browInnerUp) * r * 0.55
            let outer = CGPoint(x: c.x + side * r * 0.9, y: cy + innerLift * 0.35)
            let inner = CGPoint(x: c.x - side * r * 0.7, y: cy - innerLift)
            var path = Path()
            path.move(to: outer)
            path.addQuadCurve(to: inner, control: CGPoint(x: c.x, y: cy - r * 0.2))
            ctx.stroke(path, with: .color(p.ink.opacity(0.85 * rig.browWeight)), style: StrokeStyle(lineWidth: p.inkWidth, lineCap: .round))
        }
    }

    public static func blush(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: FaceLayout = FaceLayout()) {
        guard p.rig.blush > 0.02 else { return }
        let h = p.head
        let w = h.width * 0.17, hh = h.height * 0.09
        for side: CGFloat in [-1, 1] {
            let cx = h.center.x + p.faceShift * 0.6 + side * h.width * layout.blushX
            let cy = h.center.y + h.height * layout.blushY
            let r = CGRect(x: cx - w / 2, y: cy - hh / 2, width: w, height: hh)
            ctx.fill(Path(ellipseIn: r), with: .radialGradient(
                Gradient(colors: [p.palette.blush.opacity(0.5 * p.rig.blush), p.palette.blush.opacity(0)]),
                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: w * 0.55))
        }
    }

    public enum MouthStyle { case cat, simple, snout }

    /// The mouth anchor (below the nose).
    public static func mouthAnchor(_ p: PetPaintContext, layout: FaceLayout) -> CGPoint {
        CGPoint(x: p.head.center.x + p.faceShift, y: p.head.center.y + p.head.height * layout.mouthY)
    }

    public static func mouth(_ ctx: inout GraphicsContext, _ p: PetPaintContext, style: MouthStyle, layout: FaceLayout = FaceLayout()) {
        let rig = p.rig
        let h = p.head
        let a = mouthAnchor(p, layout: layout)
        let mx = a.x, my = a.y
        let half = h.width * layout.mouthWidth * CGFloat(rig.mouthWidth) / 2
        let curve = CGFloat(rig.mouthCurve)
        let open = CGFloat(rig.mouthOpen)
        let line = StrokeStyle(lineWidth: p.inkWidth, lineCap: .round, lineJoin: .round)
        let inkColor = p.ink

        // Open mouth: a rounded shape with a tongue.
        if open > 0.08 {
            let depth = half * (0.8 + 1.5 * open)
            var m = Path()
            m.move(to: CGPoint(x: mx - half, y: my))
            m.addQuadCurve(to: CGPoint(x: mx + half, y: my), control: CGPoint(x: mx, y: my - curve * half * 0.5))
            m.addQuadCurve(to: CGPoint(x: mx - half, y: my), control: CGPoint(x: mx, y: my + depth * 1.8))
            m.closeSubpath()
            ctx.fill(m, with: .color(Color(red: 0.42, green: 0.16, blue: 0.19)))
            var inner = ctx
            inner.clip(to: m)
            let tongueH = depth * (0.55 + 0.4 * CGFloat(rig.tongue))
            inner.fill(Path(ellipseIn: CGRect(x: mx - half * 0.6, y: my + depth * 0.5 - CGFloat(rig.tongue) * depth * 0.25, width: half * 1.2, height: tongueH)), with: .color(Color(red: 0.98, green: 0.56, blue: 0.6)))
            return
        }

        var path = Path()
        switch style {
        case .cat:
            // ω: two small arcs meeting under the nose. Frowns flatten and invert them.
            let drop = half * 0.6
            let endY = my + (curve < 0 ? -curve * half * 0.8 : -curve * half * 0.3)
            let ctrlY = my + drop * (curve >= 0 ? 1.4 : 0.3)
            path.move(to: CGPoint(x: mx - half, y: endY))
            path.addQuadCurve(to: CGPoint(x: mx, y: my), control: CGPoint(x: mx - half * 0.5, y: ctrlY))
            path.addQuadCurve(to: CGPoint(x: mx + half, y: endY), control: CGPoint(x: mx + half * 0.5, y: ctrlY))
        case .simple, .snout:
            if rig.mouthWobble > 0.05 {
                let n = 6
                path.move(to: CGPoint(x: mx - half, y: my))
                for i in 1...n {
                    let t = CGFloat(i) / CGFloat(n)
                    let x = mx - half + 2 * half * t
                    let base = my + curve * half * 0.9 * sin(t * .pi)
                    let wob = sin(t * .pi * 5) * half * 0.22 * CGFloat(rig.mouthWobble)
                    path.addLine(to: CGPoint(x: x, y: base + wob))
                }
            } else {
                path.move(to: CGPoint(x: mx - half, y: my))
                path.addQuadCurve(to: CGPoint(x: mx + half, y: my), control: CGPoint(x: mx, y: my + curve * half * 1.5))
            }
        }
        ctx.stroke(path, with: .color(inkColor), style: line)

        if rig.tongue > 0.05 && style != .cat {
            let tw = half * 0.7, th = half * 0.9 * CGFloat(rig.tongue)
            ctx.fill(Path(roundedRect: CGRect(x: mx - tw / 2, y: my - 1, width: tw, height: th), cornerRadius: tw / 2), with: .color(Color(red: 0.98, green: 0.56, blue: 0.6)))
        }
    }

    public static func sweat(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        guard p.rig.sweat > 0.03 else { return }
        let h = p.head
        let c = CGPoint(x: h.center.x + h.width * 0.44, y: h.top + h.height * 0.2)
        let s = h.width * 0.06
        var drop = Path()
        drop.move(to: CGPoint(x: c.x, y: c.y - s * 1.4))
        drop.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y + s * 0.4), control: CGPoint(x: c.x + s * 1.1, y: c.y - s * 0.6))
        drop.addArc(center: CGPoint(x: c.x, y: c.y + s * 0.4), radius: s, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        drop.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s * 1.4), control: CGPoint(x: c.x - s * 1.1, y: c.y - s * 0.6))
        let blue = Color(red: 0.55, green: 0.78, blue: 0.98)
        ctx.fill(drop, with: .color(blue.opacity(0.9 * p.rig.sweat)))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - s * 0.5, y: c.y - s * 0.3, width: s * 0.4, height: s * 0.5)), with: .color(.white.opacity(0.7 * p.rig.sweat)))
    }

    // MARK: Ears & tails (right-side geometry; call inside `mirrored`)

    /// Pointed ear on the right side of the head. `lift` 0…1 rotates from flattened-out to perked.
    public static func pointedEar(_ ctx: inout GraphicsContext, _ p: PetPaintContext, side: CGFloat, baseInner: CGPoint, baseOuter: CGPoint, length: CGFloat, innerInset: CGFloat = 0.3) {
        let twitch = side == 1 ? CGFloat(p.live.earTwitch) * 0.25 : 0
        let lift = (CGFloat(p.rig.earLift) + twitch).clamped(0, 1.1)
        let mid = CGPoint(x: (baseInner.x + baseOuter.x) / 2, y: (baseInner.y + baseOuter.y) / 2)
        let angle = 0.32 + (1 - lift) * 1.15
        let tip = CGPoint(x: mid.x + sin(angle) * length, y: mid.y - cos(angle) * length)
        var ear = Path()
        ear.move(to: baseInner)
        ear.addQuadCurve(to: tip, control: CGPoint(x: (baseInner.x + tip.x) / 2 - length * 0.1, y: (baseInner.y + tip.y) / 2))
        ear.addQuadCurve(to: baseOuter, control: CGPoint(x: (baseOuter.x + tip.x) / 2 + length * 0.08, y: (baseOuter.y + tip.y) / 2))
        ear.closeSubpath()
        let bounds = ear.boundingRect
        fur(&ctx, p, ear, in: bounds, strength: 0.8)
        let innerTip = lerp(mid, tip, 1 - innerInset)
        let iFrom = lerp(baseInner, mid, innerInset * 1.1)
        let iTo = lerp(baseOuter, mid, innerInset * 1.1)
        var inner = Path()
        inner.move(to: iFrom)
        inner.addQuadCurve(to: innerTip, control: CGPoint(x: (iFrom.x + innerTip.x) / 2 - length * 0.08, y: (iFrom.y + innerTip.y) / 2))
        inner.addQuadCurve(to: iTo, control: CGPoint(x: (iTo.x + innerTip.x) / 2 + length * 0.04, y: (iTo.y + innerTip.y) / 2))
        inner.closeSubpath()
        ctx.fill(inner, with: .color(p.palette.earInner.opacity(0.9)))
    }

    /// Round ear.
    public static func roundEar(_ ctx: inout GraphicsContext, _ p: PetPaintContext, center: CGPoint, radius: CGFloat, innerRatio: CGFloat = 0.55, rim: Color? = nil) {
        let r = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        if let rim {
            let rr = r.insetBy(dx: -radius * 0.1, dy: -radius * 0.1)
            ctx.fill(Path(ellipseIn: rr), with: .color(rim))
        }
        fur(&ctx, p, Path(ellipseIn: r), in: r, strength: 0.8)
        let ir = radius * innerRatio
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - ir, y: center.y - ir + radius * 0.1, width: ir * 2, height: ir * 2)), with: .color(p.palette.earInner.opacity(0.95)))
    }

    /// A tail that wraps around the front of the haunch along the floor when down and
    /// rises beside the body when lifted. Returns the path so painters can add rings.
    @discardableResult
    public static func tail(_ ctx: inout GraphicsContext, _ p: PetPaintContext, width: CGFloat, length: CGFloat, color: Color, tip: Color? = nil) -> (path: Path, end: CGPoint) {
        let t = p.torso
        let lift = CGFloat(p.rig.tailLift)
        let wag = CGFloat(p.live.tailWag)
        let start = CGPoint(x: t.centerX + t.hipWidth * 0.3, y: t.bottom - width * 0.6)
        // Down: sweeps along the floor to the right and curls up at the tip.
        // Up: rises beside the body and curls inward.
        let downEnd = CGPoint(x: start.x + length * 0.72, y: t.bottom - width * 0.55 - length * 0.12)
        let upEnd = CGPoint(x: start.x + length * 0.42 + wag * 10, y: t.bottom - length * 0.95)
        let end = lerp(downEnd, upEnd, lift)
        let downC1 = CGPoint(x: start.x + length * 0.35, y: t.bottom + width * 0.1)
        let downC2 = CGPoint(x: downEnd.x + length * 0.15, y: t.bottom + width * 0.05)
        let upC1 = CGPoint(x: start.x + length * 0.55, y: t.bottom - length * 0.05)
        let upC2 = CGPoint(x: upEnd.x + length * 0.3 + wag * 12, y: upEnd.y + length * 0.35)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: lerp(downC1, upC1, lift), control2: lerp(downC2, upC2, lift))
        let stroked = path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
        form(&ctx, stroked, in: stroked.boundingRect, base: color, shade: p.palette.shade, light: p.palette.light, strength: 0.9)
        if let tip {
            let tr = CGRect(x: end.x - width * 0.5, y: end.y - width * 0.5, width: width, height: width)
            var inner = ctx
            inner.clip(to: stroked)
            inner.fill(Path(ellipseIn: tr.insetBy(dx: -width * 0.2, dy: -width * 0.2)), with: .color(tip))
        }
        return (path, end)
    }

    public static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    public static func pointOnCubic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
        let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        return CGPoint(x: x, y: y)
    }
}

extension CGFloat {
    func clamped(_ lower: CGFloat, _ upper: CGFloat) -> CGFloat { Swift.min(Swift.max(self, lower), upper) }
}

// MARK: - Species anatomy

public extension PetSpecies {
    var anatomy: PetAnatomy {
        switch self {
        case .cat:
            PetAnatomy(headWidth: 90, headHeight: 76, headOverlap: 16, cheekSquareness: 0.35, torsoHeight: 84, chestWidth: 64, hipWidth: 104, legWidth: 15)
        case .dog:
            PetAnatomy(headWidth: 92, headHeight: 78, headOverlap: 16, cheekSquareness: 0.3, torsoHeight: 86, chestWidth: 68, hipWidth: 106, legWidth: 16)
        case .capybara:
            PetAnatomy(headWidth: 96, headHeight: 66, headOverlap: 14, cheekSquareness: 0.75, torsoHeight: 80, chestWidth: 86, hipWidth: 118, legWidth: 17, eyeRadius: 0.058)
        case .penguin:
            PetAnatomy(headWidth: 78, headHeight: 70, headOverlap: 30, cheekSquareness: 0.2, torsoHeight: 104, chestWidth: 78, hipWidth: 96, legWidth: 0, eyeRadius: 0.09)
        case .redPanda:
            PetAnatomy(headWidth: 92, headHeight: 76, headOverlap: 16, cheekSquareness: 0.4, torsoHeight: 82, chestWidth: 66, hipWidth: 108, legWidth: 16)
        }
    }
}

public extension PetDraw {
    /// A context rotated by the rig's head tilt about the neck. Draw head parts through it.
    static func headContext(_ ctx: GraphicsContext, _ p: PetPaintContext) -> GraphicsContext {
        var hc = ctx
        let neck = CGPoint(x: p.head.center.x, y: p.head.bottom - 6)
        hc.translateBy(x: neck.x, y: neck.y)
        hc.rotate(by: .degrees(p.rig.tilt))
        hc.translateBy(x: -neck.x, y: -neck.y)
        return hc
    }
}
