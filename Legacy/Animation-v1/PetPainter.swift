import SwiftUI

/// Shared drawing vocabulary for all species painters. See `Docs/CharacterSpec.md`.
///
/// Painters draw into a 200×200 "design canvas"; `PetView` scales it to fit. Every pet
/// follows one construction: a softly lit silhouette (head merged into a sitting body,
/// species features part of the outline), a lighter belly, glossy eyes, a tiny nose or
/// beak, paws or feet, and one prop. Feeling comes from pose and glyphs, not rendering.
/// Paired parts are drawn once and mirrored, with a consistent upper-left key light.
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
    public var inkWidth: CGFloat { detail == .small ? 3.2 : 2.0 }
    public var ink: Color { palette.ink }

    /// Horizontal shift applied to every facial feature when the head turns.
    public var faceShift: CGFloat { CGFloat(rig.headTurn) * head.width * 0.07 }

    /// Transform that tilts the head about the neck (applied to head-part paths drawn in body space).
    public var headTilt: CGAffineTransform {
        let neck = CGPoint(x: head.center.x, y: head.bottom - 8)
        return CGAffineTransform(translationX: neck.x, y: neck.y).rotated(by: CGFloat(rig.tilt + live.headLag) * .pi / 180).translatedBy(x: -neck.x, y: -neck.y)
    }

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
        let torsoHeight = (anatomy.torsoHeight - 22 * lying) * squash
        let hip = anatomy.hipWidth + 28 * lying
        let chest = anatomy.chestWidth + 24 * lying
        torso = Torso(centerX: 100, top: 168 - torsoHeight, bottom: 168, chestWidth: chest, hipWidth: hip)

        // Head: merges into the chest; sinks into the shoulders when dropped or lying.
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
    /// How far the head sinks into the chest (a short neck). Large values merge head and body.
    public var headOverlap: CGFloat
    public var cheekSquareness: CGFloat
    public var torsoHeight: CGFloat
    public var chestWidth: CGFloat
    public var hipWidth: CGFloat
    /// Eye radius as a fraction of head width.
    public var eyeRadius: CGFloat

    public init(headWidth: CGFloat, headHeight: CGFloat, headOverlap: CGFloat, cheekSquareness: CGFloat, torsoHeight: CGFloat, chestWidth: CGFloat, hipWidth: CGFloat, eyeRadius: CGFloat = 0.072) {
        self.headWidth = headWidth
        self.headHeight = headHeight
        self.headOverlap = headOverlap
        self.cheekSquareness = cheekSquareness
        self.torsoHeight = torsoHeight
        self.chestWidth = chestWidth
        self.hipWidth = hipWidth
        self.eyeRadius = eyeRadius
    }
}

public protocol PetPainter {
    /// Draw the pet into `ctx` (already transformed into the 200×200 design space).
    static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext)
}

// MARK: - Shared primitives

public enum PetDraw {

    /// Soft toy volume: one warm key light and a quiet lower-right shadow.
    /// Kept in vector geometry so expressions interpolate and tiny widgets stay crisp.
    public static func plush(_ ctx: inout GraphicsContext, _ shape: Path, _ p: PetPaintContext) {
        let bounds = shape.boundingRect
        ctx.fill(shape, with: .linearGradient(Gradient(stops: [
            .init(color: p.palette.light, location: 0),
            .init(color: p.palette.base, location: 0.42),
            .init(color: p.palette.shade, location: 1)
        ]), startPoint: CGPoint(x: bounds.minX, y: bounds.minY), endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)))
        guard p.detail == .full else { return }
        var light = ctx
        light.clip(to: shape)
        light.fill(shape, with: .radialGradient(Gradient(colors: [.white.opacity(0.20), .white.opacity(0)]),
            center: CGPoint(x: p.head.center.x - p.head.width * 0.2, y: p.head.top + p.head.height * 0.2),
            startRadius: 0, endRadius: p.head.width * 0.8))
    }

    /// Small front arms make a pose legible on every mammal, not just the penguin.
    /// Rest hangs beside the belly; `armRaise` lifts one arm high (a wave) and the other a little;
    /// `armOut` spreads both wide and open; `armCross` folds both across the chest.
    public static func arms(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso
        let cross = CGFloat(p.rig.armCross).clamped(0, 1)
        let out = CGFloat(p.rig.armOut).clamped(0, 1) * (1 - cross)
        let swing = CGFloat(p.live.armSwing)
        mirrored(&ctx) { context, side in
            let raised = CGFloat(p.rig.armRaise).clamped(0, 1) * (side == 1 ? 1 : 0.35) * (1 - cross)
            let root = CGPoint(x: t.centerX + t.hipWidth * 0.36, y: t.top + t.height * 0.38)
            let rest = CGPoint(x: root.x + 7, y: root.y + 22)
            let up = CGPoint(x: root.x + 20, y: root.y - 20)
            let wide = CGPoint(x: root.x + 30 + swing * 3, y: root.y + 4 - swing * 6)
            // Crossed: the hand ends on the far side of the chest, just under the chin.
            let folded = CGPoint(x: t.centerX - t.hipWidth * 0.12, y: root.y + 10)
            var end = CGPoint(x: rest.x + (up.x - rest.x) * raised, y: rest.y + (up.y - rest.y) * raised)
            end = CGPoint(x: end.x + (wide.x - end.x) * out, y: end.y + (wide.y - end.y) * out)
            end = CGPoint(x: end.x + (folded.x - end.x) * cross, y: end.y + (folded.y - end.y) * cross)
            let control = CGPoint(x: root.x + 12 + out * 8 - cross * 4, y: root.y + 12 - raised * 20 + cross * 12)
            var arm = Path()
            arm.move(to: root)
            arm.addQuadCurve(to: end, control: control)
            let shape = arm.strokedPath(StrokeStyle(lineWidth: 17, lineCap: .round))
            plush(&context, shape, p)
        }
    }

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

    /// Builds a symmetric path from right-side geometry: the path and its mirror, unioned.
    public static func symmetric(_ right: Path, axis: CGFloat = 100) -> Path {
        right.union(right.applying(CGAffineTransform(translationX: axis, y: 0).scaledBy(x: -1, y: 1).translatedBy(x: -axis, y: 0)))
    }

    // MARK: Fills

    /// Flat fill. The signature keeps `shade`/`light`/`strength` so callers read the same, but the
    /// style is flat: no gradients, no cel shade. Separation between parts comes from colour choice.
    public static func form(_ ctx: inout GraphicsContext, _ path: Path, in rect: CGRect, base: Color, shade: Color, light: Color, strength: CGFloat = 1) {
        ctx.fill(path, with: .color(base))
    }

    /// Convenience: flat fill with the palette's fur colour.
    public static func fur(_ ctx: inout GraphicsContext, _ p: PetPaintContext, _ path: Path, in rect: CGRect = .zero, strength: CGFloat = 1) {
        ctx.fill(path, with: .color(p.palette.base))
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

    /// Torso: a bean — narrow shoulders, wide haunches, flat on the floor with rounded corners.
    public static func torsoPath(_ t: PetPaintContext.Torso) -> Path {
        let cx = t.centerX, h = t.height
        let shoulderY = t.top + h * 0.2
        let hipY = t.bottom - h * 0.3
        let cornerX = t.hipWidth * 0.34
        var p = Path()
        p.move(to: CGPoint(x: cx, y: t.top))
        p.addCurve(to: CGPoint(x: cx + t.chestWidth / 2, y: shoulderY),
                   control1: CGPoint(x: cx + t.chestWidth * 0.36, y: t.top),
                   control2: CGPoint(x: cx + t.chestWidth / 2, y: t.top + h * 0.06))
        p.addCurve(to: CGPoint(x: cx + t.hipWidth / 2, y: hipY),
                   control1: CGPoint(x: cx + t.chestWidth / 2, y: t.top + h * 0.5),
                   control2: CGPoint(x: cx + t.hipWidth / 2, y: hipY - h * 0.24))
        p.addCurve(to: CGPoint(x: cx + cornerX, y: t.bottom),
                   control1: CGPoint(x: cx + t.hipWidth / 2, y: t.bottom - h * 0.02),
                   control2: CGPoint(x: cx + cornerX + 10, y: t.bottom))
        p.addLine(to: CGPoint(x: cx - cornerX, y: t.bottom))
        p.addCurve(to: CGPoint(x: cx - t.hipWidth / 2, y: hipY),
                   control1: CGPoint(x: cx - cornerX - 10, y: t.bottom),
                   control2: CGPoint(x: cx - t.hipWidth / 2, y: t.bottom - h * 0.02))
        p.addCurve(to: CGPoint(x: cx - t.chestWidth / 2, y: shoulderY),
                   control1: CGPoint(x: cx - t.hipWidth / 2, y: hipY - h * 0.24),
                   control2: CGPoint(x: cx - t.chestWidth / 2, y: t.top + h * 0.5))
        p.addCurve(to: CGPoint(x: cx, y: t.top),
                   control1: CGPoint(x: cx - t.chestWidth / 2, y: t.top + h * 0.06),
                   control2: CGPoint(x: cx - t.chestWidth * 0.36, y: t.top))
        p.closeSubpath()
        return p
    }

    /// The one silhouette: torso + tilted head + any extra outline parts (ears, snout), unioned.
    public static func silhouette(_ p: PetPaintContext, extras: [Path] = []) -> Path {
        var shape = torsoPath(p.torso).union(headPath(p.head).applying(p.headTilt))
        for extra in extras { shape = shape.union(extra.applying(p.headTilt)) }
        return shape
    }

    /// A lighter chest patch, clipped to the silhouette.
    public static func belly(_ ctx: inout GraphicsContext, _ p: PetPaintContext, within: Path, widthFraction: CGFloat = 0.56, heightFraction: CGFloat = 0.55, color: Color? = nil) {
        let t = p.torso
        var inner = ctx
        inner.clip(to: within)
        let bw = t.hipWidth * widthFraction, bh = t.height * heightFraction
        inner.fill(Path(ellipseIn: CGRect(x: t.centerX - bw / 2, y: t.bottom - bh - 4, width: bw, height: bh)), with: .color(color ?? p.palette.belly))
    }

    /// Two small paws at the bottom front, mirrored.
    public static func paws(_ ctx: inout GraphicsContext, _ p: PetPaintContext, color: Color, spread: CGFloat = 0.2, width: CGFloat = 24, height: CGFloat = 12) {
        let t = p.torso
        let lying = CGFloat(p.rig.lying)
        mirrored(&ctx) { ctx, _ in
            let x = t.centerX + t.hipWidth * spread + lying * 8
            let r = CGRect(x: x - width / 2, y: t.bottom - height + 2, width: width * (1 + 0.3 * lying), height: height)
            ctx.fill(Path(ellipseIn: r), with: .color(color))
            if p.detail == .full {
                var toes = Path()
                for tx in [-0.18, 0.18] {
                    toes.move(to: CGPoint(x: r.midX + CGFloat(tx) * r.width, y: r.midY + 1.5))
                    toes.addLine(to: CGPoint(x: r.midX + CGFloat(tx) * r.width, y: r.maxY - 1.5))
                }
                ctx.stroke(toes, with: .color(p.palette.shade.opacity(0.55)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }
    }

    /// Ground shadow beneath the pet. Follows hops (shrinks and fades) and leans.
    public static func floorShadow(_ ctx: inout GraphicsContext, _ p: PetPaintContext, spread: Double = 1) {
        let lift = CGFloat(p.live.hop) - CGFloat(min(0, p.rig.lift))
        let k = max(0.55, 1 - lift / 45)
        let w = (p.torso.hipWidth + 20) * k * spread
        let h = 10 * k
        let lean = CGFloat(p.rig.lean + p.live.lean)
        let r = CGRect(x: p.axis - w / 2 + lean * 0.6, y: p.floor - h / 2 + 4, width: w, height: h)
        let shade: Color = p.colorScheme == .dark ? .black : Color(red: 0.30, green: 0.22, blue: 0.18)
        ctx.fill(Path(ellipseIn: r), with: .color(shade.opacity(0.14 * k)))
    }

    // MARK: Face (positions are fractions of the head)

    public struct FaceLayout {
        /// Eye centre offset from the head centre, as a fraction of head width.
        public var eyeSpacing: CGFloat = 0.19
        /// Eye line as a fraction of head height from the centre (negative = above).
        public var eyeY: CGFloat = -0.02
        public var eyeRadius: CGFloat = 0.055
        public var mouthY: CGFloat = 0.2
        public var mouthWidth: CGFloat = 0.1
        public var blushX: CGFloat = 0.33
        public var blushY: CGFloat = 0.12
        public init() {}
    }

    public static func eyeCenter(_ p: PetPaintContext, layout: FaceLayout, side: CGFloat) -> CGPoint {
        let h = p.head
        let r = h.width * layout.eyeRadius
        return CGPoint(x: h.center.x + p.faceShift + side * h.width * layout.eyeSpacing + CGFloat(p.rig.gazeX) * r * 0.5,
                       y: h.center.y + h.height * layout.eyeY + CGFloat(p.rig.gazeY) * r * 0.4)
    }

    /// Both eyes: small ink ovals with one highlight. Drawn explicitly (not mirrored) so the
    /// highlight stays top-left on both.
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
        let inkStyle = StrokeStyle(lineWidth: max(p.inkWidth, r * 0.5), lineCap: .round)

        // Closed: a short line, curving down at rest and up (^) when happy.
        if open < 0.12 {
            var path = Path()
            let dir: CGFloat = arc > 0.3 ? -1 : 1
            path.move(to: CGPoint(x: c.x - r * 1.1, y: c.y))
            path.addQuadCurve(to: CGPoint(x: c.x + r * 1.1, y: c.y), control: CGPoint(x: c.x, y: c.y + dir * r * 1.0))
            ctx.stroke(path, with: .color(p.ink), style: inkStyle)
            return
        }
        // Happy arc replaces the eye entirely once it is strong enough.
        if arc > 0.55 {
            var path = Path()
            path.move(to: CGPoint(x: c.x - r * 1.2, y: c.y + r * 0.4))
            path.addQuadCurve(to: CGPoint(x: c.x + r * 1.2, y: c.y + r * 0.4), control: CGPoint(x: c.x, y: c.y - r * 1.3))
            ctx.stroke(path, with: .color(p.ink), style: inkStyle)
            return
        }

        let height = 2 * r * 1.15 * (0.35 + 0.65 * open) * (1 - 0.25 * arc)
        let rect = CGRect(x: c.x - r, y: c.y - height / 2, width: 2 * r, height: height)
        let eyePath = Path(ellipseIn: rect)
        var eyeCtx = ctx
        eyeCtx.clip(to: eyePath)
        eyeCtx.fill(eyePath, with: .linearGradient(Gradient(colors: [p.ink, p.palette.shade]), startPoint: CGPoint(x: c.x, y: rect.minY), endPoint: CGPoint(x: c.x, y: rect.maxY)))

        if p.detail == .full {
            let glint = r * 0.25
            eyeCtx.fill(Path(ellipseIn: CGRect(x: c.x + r * 0.25, y: c.y + r * 0.35, width: glint, height: glint)), with: .color(.white.opacity(0.5)))
        }
        // Upper lid: squint / heavy lids cover from the top.
        let cover = max(CGFloat(rig.eyeSquint) * 0.45, CGFloat(rig.lidHeaviness) * 0.5)
        if cover > 0.01 {
            eyeCtx.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: -height * (1 - cover))), with: .color(lidColor))
        }
        // Angry: the inner corner of the lid comes down in a wedge.
        if rig.browInnerUp < -0.2 {
            let k = CGFloat(-rig.browInnerUp) * CGFloat(max(rig.browWeight, 0.5))
            var wedge = Path()
            let innerX = c.x - side * r
            wedge.move(to: CGPoint(x: innerX, y: c.y - height * 0.7))
            wedge.addLine(to: CGPoint(x: innerX, y: c.y - height * (0.7 - 0.65 * k)))
            wedge.addLine(to: CGPoint(x: c.x + side * r * 1.05, y: c.y - height * 0.7))
            wedge.closeSubpath()
            eyeCtx.fill(wedge, with: .color(lidColor))
        }
        // Lower lid lifts a little for a soft smile.
        if arc > 0.01 {
            eyeCtx.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: height * (1 - arc * 0.5))), with: .color(lidColor))
        }
        // One highlight, top-left, key light.
        let hl = r * 0.55 * CGFloat(rig.pupilScale)
        let gx = CGFloat(rig.gazeX) * r * 0.2, gy = CGFloat(rig.gazeY) * r * 0.2
        eyeCtx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.42 + gx - hl / 2, y: c.y - r * 0.5 + gy - hl / 2, width: hl, height: hl)), with: .color(.white.opacity(0.95 * Double(min(1, open * 1.5)))))
    }

    public static func brows(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: FaceLayout = FaceLayout()) {
        let rig = p.rig
        guard rig.browWeight > 0.02 else { return }
        let h = p.head
        let r = h.width * layout.eyeRadius * CGFloat(rig.eyeScale)
        for side: CGFloat in [-1, 1] {
            let c = eyeCenter(p, layout: layout, side: side)
            let cy = c.y - r * 2.2
            let innerLift = CGFloat(rig.browInnerUp) * r * 0.8
            let outer = CGPoint(x: c.x + side * r * 1.2, y: cy + innerLift * 0.35)
            let inner = CGPoint(x: c.x - side * r * 0.9, y: cy - innerLift)
            var path = Path()
            path.move(to: outer)
            path.addQuadCurve(to: inner, control: CGPoint(x: c.x, y: cy - r * 0.2))
            ctx.stroke(path, with: .color(p.ink.opacity(0.85 * rig.browWeight)), style: StrokeStyle(lineWidth: p.inkWidth, lineCap: .round))
        }
    }

    /// Blush shows only when a mood asks for it (happy, excited); neutral pets have none.
    public static func blush(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: FaceLayout = FaceLayout()) {
        guard p.rig.blush > 0.4 else { return }
        let h = p.head
        let w = h.width * 0.14, hh = h.height * 0.07
        let alpha = min(1, (p.rig.blush - 0.4) / 0.4)
        for side: CGFloat in [-1, 1] {
            let cx = h.center.x + p.faceShift * 0.6 + side * h.width * layout.blushX
            let cy = h.center.y + h.height * layout.blushY
            ctx.fill(Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - hh / 2, width: w, height: hh)), with: .color(p.palette.blush.opacity(0.55 * alpha)))
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

        // Open mouth: a small rounded shape with a tongue.
        if open > 0.15 {
            let depth = half * (0.8 + 1.4 * open)
            var m = Path()
            m.move(to: CGPoint(x: mx - half, y: my))
            m.addQuadCurve(to: CGPoint(x: mx + half, y: my), control: CGPoint(x: mx, y: my - curve * half * 0.4))
            m.addQuadCurve(to: CGPoint(x: mx - half, y: my), control: CGPoint(x: mx, y: my + depth * 1.8))
            m.closeSubpath()
            ctx.fill(m, with: .color(Color(red: 0.42, green: 0.16, blue: 0.19)))
            var inner = ctx
            inner.clip(to: m)
            inner.fill(Path(ellipseIn: CGRect(x: mx - half * 0.6, y: my + depth * 0.5 - CGFloat(rig.tongue) * depth * 0.25, width: half * 1.2, height: depth * (0.55 + 0.4 * CGFloat(rig.tongue)))), with: .color(Color(red: 0.98, green: 0.56, blue: 0.6)))
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
        case .snout:
            // Snouts: a short vertical philtrum from the nose meeting a wide, gentle curve — reads
            // as a muzzle rather than a dash, and keeps its expression at every size.
            let stem = half * 0.55
            path.move(to: CGPoint(x: mx, y: my - stem))
            path.addLine(to: CGPoint(x: mx, y: my))
            let wob = rig.mouthWobble > 0.05 ? half * 0.18 * CGFloat(rig.mouthWobble) : 0
            path.move(to: CGPoint(x: mx - half, y: my - curve * half * 0.5 + wob))
            path.addQuadCurve(to: CGPoint(x: mx, y: my), control: CGPoint(x: mx - half * 0.5, y: my + curve * half * 0.9))
            path.addQuadCurve(to: CGPoint(x: mx + half, y: my - curve * half * 0.5 - wob), control: CGPoint(x: mx + half * 0.5, y: my + curve * half * 0.9))
        case .simple:
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
                path.addQuadCurve(to: CGPoint(x: mx + half, y: my), control: CGPoint(x: mx, y: my + curve * half * 1.6))
            }
        }
        ctx.stroke(path, with: .color(p.ink), style: line)

        if rig.tongue > 0.05 && style != .cat {
            let tw = half * 0.7, th = half * 0.9 * CGFloat(rig.tongue)
            ctx.fill(Path(roundedRect: CGRect(x: mx - tw / 2, y: my - 1, width: tw, height: th), cornerRadius: tw / 2), with: .color(Color(red: 0.98, green: 0.56, blue: 0.6)))
        }
    }

    /// A sweat drop beside the head (stressed).
    public static func sweat(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        guard p.rig.sweat > 0.03 else { return }
        let h = p.head
        let c = CGPoint(x: h.center.x + h.width * 0.5, y: h.top + h.height * 0.16)
        let s = h.width * 0.055
        var drop = Path()
        drop.move(to: CGPoint(x: c.x, y: c.y - s * 1.5))
        drop.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y + s * 0.4), control: CGPoint(x: c.x + s * 1.1, y: c.y - s * 0.6))
        drop.addArc(center: CGPoint(x: c.x, y: c.y + s * 0.4), radius: s, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        drop.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s * 1.5), control: CGPoint(x: c.x - s * 1.1, y: c.y - s * 0.6))
        ctx.fill(drop, with: .color(Color(red: 0.42, green: 0.72, blue: 0.98).opacity(0.95 * p.rig.sweat)))
    }

    // MARK: Ears & tails (right-side geometry)

    /// Pointed ear outline on the right side of the head, in body space (tilt is applied by `silhouette`).
    public static func pointedEarPath(_ p: PetPaintContext, baseInner: CGPoint, baseOuter: CGPoint, length: CGFloat) -> Path {
        let lift = (CGFloat(p.rig.earLift) + CGFloat(p.live.earTwitch) * 0.2).clamped(0, 1.1)
        let mid = CGPoint(x: (baseInner.x + baseOuter.x) / 2, y: (baseInner.y + baseOuter.y) / 2)
        let angle = 0.3 + (1 - lift) * 1.1
        let tip = CGPoint(x: mid.x + sin(angle) * length, y: mid.y - cos(angle) * length)
        var ear = Path()
        ear.move(to: baseInner)
        ear.addQuadCurve(to: tip, control: CGPoint(x: (baseInner.x + tip.x) / 2 - length * 0.08, y: (baseInner.y + tip.y) / 2))
        ear.addQuadCurve(to: baseOuter, control: CGPoint(x: (baseOuter.x + tip.x) / 2 + length * 0.1, y: (baseOuter.y + tip.y) / 2))
        // Close along the head so the union has no seam.
        ear.addLine(to: CGPoint(x: mid.x, y: mid.y + length * 0.3))
        ear.closeSubpath()
        return ear
    }

    /// Inner ear for a pointed ear: a smaller triangle inset from the outline.
    public static func innerEar(_ ctx: inout GraphicsContext, _ p: PetPaintContext, baseInner: CGPoint, baseOuter: CGPoint, length: CGFloat, color: Color) {
        let lift = (CGFloat(p.rig.earLift) + CGFloat(p.live.earTwitch) * 0.2).clamped(0, 1.1)
        let mid = CGPoint(x: (baseInner.x + baseOuter.x) / 2, y: (baseInner.y + baseOuter.y) / 2)
        let angle = 0.3 + (1 - lift) * 1.1
        let tip = CGPoint(x: mid.x + sin(angle) * length, y: mid.y - cos(angle) * length)
        let iFrom = lerp(baseInner, mid, 0.4), iTo = lerp(baseOuter, mid, 0.4), iTip = lerp(mid, tip, 0.72)
        var inner = Path()
        inner.move(to: iFrom)
        inner.addQuadCurve(to: iTip, control: CGPoint(x: (iFrom.x + iTip.x) / 2 - length * 0.05, y: (iFrom.y + iTip.y) / 2))
        inner.addQuadCurve(to: iTo, control: CGPoint(x: (iTo.x + iTip.x) / 2 + length * 0.05, y: (iTo.y + iTip.y) / 2))
        inner.closeSubpath()
        ctx.fill(inner.applying(p.headTilt), with: .color(color))
    }

    /// A tail that wraps around the front of the haunch when down and rises beside the body when up.
    @discardableResult
    public static func tail(_ ctx: inout GraphicsContext, _ p: PetPaintContext, width: CGFloat, length: CGFloat, color: Color, tip: Color? = nil) -> (path: Path, end: CGPoint) {
        let t = p.torso
        let lift = CGFloat(p.rig.tailLift)
        let wag = CGFloat(p.live.tailWag)
        let start = CGPoint(x: t.centerX + t.hipWidth * 0.3, y: t.bottom - width * 0.6)
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
        ctx.fill(stroked, with: .color(color))
        if let tip {
            var inner = ctx
            inner.clip(to: stroked)
            inner.fill(Path(ellipseIn: CGRect(x: end.x - width * 0.7, y: end.y - width * 0.7, width: width * 1.4, height: width * 1.4)), with: .color(tip))
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
            PetAnatomy(headWidth: 108, headHeight: 86, headOverlap: 33, cheekSquareness: 0.48, torsoHeight: 72, chestWidth: 74, hipWidth: 100)
        case .dog:
            PetAnatomy(headWidth: 106, headHeight: 88, headOverlap: 32, cheekSquareness: 0.4, torsoHeight: 73, chestWidth: 76, hipWidth: 102)
        case .capybara:
            PetAnatomy(headWidth: 108, headHeight: 72, headOverlap: 26, cheekSquareness: 0.95, torsoHeight: 70, chestWidth: 100, hipWidth: 120, eyeRadius: 0.052)
        case .penguin:
            PetAnatomy(headWidth: 94, headHeight: 84, headOverlap: 38, cheekSquareness: 0.3, torsoHeight: 90, chestWidth: 86, hipWidth: 108, eyeRadius: 0.075)
        case .redPanda:
            PetAnatomy(headWidth: 110, headHeight: 84, headOverlap: 34, cheekSquareness: 0.5, torsoHeight: 72, chestWidth: 74, hipWidth: 104)
        }
    }
}

public extension PetDraw {
    /// A context rotated by the rig's head tilt about the neck. Draw head parts through it.
    static func headContext(_ ctx: GraphicsContext, _ p: PetPaintContext) -> GraphicsContext {
        var hc = ctx
        hc.concatenate(p.headTilt)
        return hc
    }
}
