import SwiftUI

/// Shared drawing vocabulary for all species painters.
///
/// Painters draw into a 200×200 "design canvas"; `PetView` scales it to fit.
/// Every pet is a sitting animal: a distinct head, a pear-shaped torso with haunches,
/// two front legs with paws, and species parts (ears, tail, markings) on top of the
/// same face system. The rig decides the pose; painters only draw.
public struct PetPaintContext {
    public var rig: PetRig
    public var live: LiveMotion
    public var palette: PetPalette
    public var colorScheme: ColorScheme
    public var anatomy: PetAnatomy

    /// Where the feet touch the ground.
    public let floor: CGFloat = 172

    /// Head geometry after pose adjustments (canvas coordinates).
    public var head: Blob
    /// Torso geometry after pose adjustments.
    public var torso: Torso

    public struct Blob {
        public var center: CGPoint
        public var width: CGFloat
        public var height: CGFloat
        /// 0 = ellipse, 1 = squarish cheeks.
        public var squareness: CGFloat

        public var rect: CGRect { CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height) }
        public var top: CGFloat { center.y - height / 2 }
        public var bottom: CGFloat { center.y + height / 2 }

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
    }

    public init(rig: PetRig, live: LiveMotion, palette: PetPalette, colorScheme: ColorScheme, anatomy: PetAnatomy) {
        self.rig = rig
        self.live = live
        self.palette = palette
        self.colorScheme = colorScheme
        self.anatomy = anatomy

        let lying = CGFloat(rig.lying)
        let squash = CGFloat(rig.squash)

        // Torso: sits on the floor; flattens and widens when lying.
        let torsoHeight = (anatomy.torsoHeight - 26 * lying) * squash
        let hip = anatomy.hipWidth + 34 * lying
        let chest = anatomy.chestWidth + 30 * lying
        torso = Torso(centerX: 100, top: 172 - torsoHeight, bottom: 172, chestWidth: chest, hipWidth: hip)

        // Head: sits on the chest, overlapping it; drops down when lying.
        let headW = anatomy.headWidth / sqrt(squash)
        let headH = anatomy.headHeight * (0.92 + 0.08 * squash)
        let headY = torso.top + anatomy.headOverlap - headH / 2 + 4 * lying
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

    public init(headWidth: CGFloat, headHeight: CGFloat, headOverlap: CGFloat, cheekSquareness: CGFloat, torsoHeight: CGFloat, chestWidth: CGFloat, hipWidth: CGFloat, legWidth: CGFloat) {
        self.headWidth = headWidth
        self.headHeight = headHeight
        self.headOverlap = headOverlap
        self.cheekSquareness = cheekSquareness
        self.torsoHeight = torsoHeight
        self.chestWidth = chestWidth
        self.hipWidth = hipWidth
        self.legWidth = legWidth
    }
}

public protocol PetPainter {
    /// Draw the pet into `ctx` (already transformed into the 200×200 design space).
    static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext)
}

// MARK: - Shared primitives

public enum PetDraw {

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

    /// Torso: pear shape — narrow chest, wide hips, flat on the floor.
    public static func torsoPath(_ t: PetPaintContext.Torso) -> Path {
        let cx = t.centerX
        let top = CGPoint(x: cx, y: t.top)
        let hipY = t.bottom - t.height * 0.22
        var p = Path()
        p.move(to: CGPoint(x: cx - t.chestWidth / 2, y: t.top + t.height * 0.18))
        p.addQuadCurve(to: CGPoint(x: cx + t.chestWidth / 2, y: t.top + t.height * 0.18), control: CGPoint(x: cx, y: top.y - t.height * 0.08))
        p.addCurve(to: CGPoint(x: cx + t.hipWidth / 2, y: hipY),
                   control1: CGPoint(x: cx + t.chestWidth / 2 + 4, y: t.top + t.height * 0.5),
                   control2: CGPoint(x: cx + t.hipWidth / 2, y: hipY - t.height * 0.3))
        p.addCurve(to: CGPoint(x: cx + t.hipWidth * 0.32, y: t.bottom),
                   control1: CGPoint(x: cx + t.hipWidth / 2, y: t.bottom - 2),
                   control2: CGPoint(x: cx + t.hipWidth * 0.42, y: t.bottom))
        p.addLine(to: CGPoint(x: cx - t.hipWidth * 0.32, y: t.bottom))
        p.addCurve(to: CGPoint(x: cx - t.hipWidth / 2, y: hipY),
                   control1: CGPoint(x: cx - t.hipWidth * 0.42, y: t.bottom),
                   control2: CGPoint(x: cx - t.hipWidth / 2, y: t.bottom - 2))
        p.addCurve(to: CGPoint(x: cx - t.chestWidth / 2, y: t.top + t.height * 0.18),
                   control1: CGPoint(x: cx - t.hipWidth / 2, y: hipY - t.height * 0.3),
                   control2: CGPoint(x: cx - t.chestWidth / 2 - 4, y: t.top + t.height * 0.5))
        p.closeSubpath()
        return p
    }

    /// Fills a shape with the fur gradient, a soft highlight and a contact shadow.
    public static func fillFur(_ ctx: inout GraphicsContext, _ p: PetPaintContext, path: Path, rect: CGRect, highlight: Bool = true) {
        ctx.fill(path, with: .linearGradient(
            Gradient(colors: [p.palette.bodyTop, p.palette.bodyBottom]),
            startPoint: CGPoint(x: rect.midX, y: rect.minY),
            endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        var inner = ctx
        inner.clip(to: path)
        if highlight {
            let hl = CGRect(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.05, width: rect.width * 0.55, height: rect.height * 0.45)
            inner.fill(Path(ellipseIn: hl), with: .radialGradient(
                Gradient(colors: [.white.opacity(0.28), .white.opacity(0)]),
                center: CGPoint(x: hl.midX, y: hl.midY), startRadius: 0, endRadius: hl.width * 0.55))
        }
        inner.fill(path, with: .linearGradient(
            Gradient(colors: [p.palette.outline.opacity(0), p.palette.outline.opacity(0.14)]),
            startPoint: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.55),
            endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
    }

    /// Torso + haunches + front legs + chest patch. Species call this, then add parts.
    public static func body(_ ctx: inout GraphicsContext, _ p: PetPaintContext, chestPatch: Bool = true, pawColor: Color? = nil) {
        let t = p.torso
        let lying = CGFloat(p.rig.lying)
        let torso = torsoPath(t)

        // Haunches: soft mounds either side of the hips.
        for side: CGFloat in [-1, 1] {
            let hw = t.hipWidth * 0.36, hh = t.height * (0.34 - 0.1 * lying)
            let r = CGRect(x: t.centerX + side * t.hipWidth * 0.34 - hw / 2, y: t.bottom - hh, width: hw, height: hh)
            ctx.fill(Path(ellipseIn: r), with: .color(p.palette.bodyBottom))
        }

        fillFur(&ctx, p, path: torso, rect: CGRect(x: t.centerX - t.hipWidth / 2, y: t.top, width: t.hipWidth, height: t.height))

        if chestPatch {
            var inner = ctx
            inner.clip(to: torso)
            let cw = t.chestWidth * 0.7, ch = t.height * 0.62
            let r = CGRect(x: t.centerX - cw / 2, y: t.bottom - ch - 4, width: cw, height: ch)
            inner.fill(Path(ellipseIn: r), with: .color(p.palette.belly.opacity(0.85)))
        }

        // Front legs: upright when sitting, stretched forward when lying.
        let legW = p.anatomy.legWidth
        let legH = t.height * (0.5 - 0.3 * lying)
        let paw = pawColor ?? p.palette.bodyTop
        for side: CGFloat in [-1, 1] {
            let x = t.centerX + side * t.chestWidth * 0.28
            let legRect = CGRect(x: x - legW / 2, y: t.bottom - legH, width: legW, height: legH)
            ctx.fill(Path(roundedRect: legRect, cornerRadius: legW / 2), with: .linearGradient(
                Gradient(colors: [p.palette.bodyTop, p.palette.bodyBottom]),
                startPoint: CGPoint(x: x, y: legRect.minY), endPoint: CGPoint(x: x, y: legRect.maxY)))
            let pawW = legW * (1.25 + 0.5 * lying), pawH = legW * 0.7
            let pawRect = CGRect(x: x - pawW / 2 + side * lying * 4, y: t.bottom - pawH, width: pawW, height: pawH)
            ctx.fill(Path(ellipseIn: pawRect), with: .color(paw))
            var toes = Path()
            for tx in [-0.22, 0.22] {
                let px = pawRect.midX + CGFloat(tx) * pawW
                toes.move(to: CGPoint(x: px, y: pawRect.midY + 1))
                toes.addLine(to: CGPoint(x: px, y: pawRect.maxY - 1.5))
            }
            ctx.stroke(toes, with: .color(p.palette.outline.opacity(0.28)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        }
    }

    /// Ground shadow beneath the pet; shrinks when the pet hops.
    public static func floorShadow(_ ctx: inout GraphicsContext, _ p: PetPaintContext, spread: Double = 1) {
        let lift = -p.live.bounce - CGFloat(min(0, p.rig.lift))
        let k = max(0.6, 1 - lift / 40)
        let w = (p.torso.hipWidth + 24) * k * spread
        let h = 12 * k
        let r = CGRect(x: 100 - w / 2, y: p.floor - h / 2 + 3, width: w, height: h)
        let shade: Color = p.colorScheme == .dark ? .black : Color(red: 0.35, green: 0.25, blue: 0.2)
        ctx.fill(Path(ellipseIn: r), with: .radialGradient(
            Gradient(colors: [shade.opacity(0.22 * k), shade.opacity(0)]),
            center: CGPoint(x: r.midX, y: r.midY), startRadius: 0, endRadius: w * 0.5))
    }

    // MARK: Face (positions are fractions of the head)

    public struct FaceLayout {
        public var eyeSpacing: CGFloat = 0.21
        public var eyeY: CGFloat = 0.02
        public var eyeRadius: CGFloat = 0.085
        public var mouthY: CGFloat = 0.27
        public var mouthWidth: CGFloat = 0.14
        public var blushX: CGFloat = 0.34
        public var blushY: CGFloat = 0.16
        public init() {}
    }

    public static func eyes(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: FaceLayout = FaceLayout(), lidColor: Color? = nil) {
        let h = p.head
        let r = h.width * layout.eyeRadius * CGFloat(p.rig.eyeScale)
        let lid = lidColor ?? p.palette.bodyTop
        for side: CGFloat in [-1, 1] {
            let cx = h.center.x + side * h.width * layout.eyeSpacing + CGFloat(p.rig.gazeX) * r * 0.25
            let cy = h.center.y + h.height * layout.eyeY + CGFloat(p.rig.gazeY) * r * 0.2
            eye(&ctx, p, center: CGPoint(x: cx, y: cy), radius: r, side: side, lidColor: lid)
        }
    }

    static func eye(_ ctx: inout GraphicsContext, _ p: PetPaintContext, center c: CGPoint, radius r: CGFloat, side: CGFloat, lidColor: Color) {
        let rig = p.rig
        let open = CGFloat(rig.eyeOpen)
        let arc = CGFloat(rig.eyeArc)
        let eyeColor = p.palette.eye

        if open < 0.12 {
            var path = Path()
            let dir: CGFloat = arc > 0.3 ? -1 : 1
            path.move(to: CGPoint(x: c.x - r * 0.95, y: c.y))
            path.addQuadCurve(to: CGPoint(x: c.x + r * 0.95, y: c.y), control: CGPoint(x: c.x, y: c.y + dir * r * 0.9))
            ctx.stroke(path, with: .color(eyeColor), style: StrokeStyle(lineWidth: r * 0.34, lineCap: .round))
            return
        }

        let height = 2 * r * (0.25 + 0.75 * open) * (1 - 0.35 * arc)
        let rect = CGRect(x: c.x - r, y: c.y - height / 2, width: 2 * r, height: height)
        let eyePath = Path(ellipseIn: rect)

        var eyeCtx = ctx
        eyeCtx.clip(to: eyePath)
        eyeCtx.fill(eyePath, with: .color(eyeColor))

        let cover = max(CGFloat(rig.eyeSquint) * 0.42, CGFloat(rig.lidHeaviness) * 0.5)
        if cover > 0.01 {
            let lidRect = rect.offsetBy(dx: 0, dy: -height * (1 - cover))
            eyeCtx.fill(Path(ellipseIn: lidRect), with: .color(lidColor))
        }
        if rig.browInnerUp < -0.2 {
            let k = CGFloat(-rig.browInnerUp) * CGFloat(rig.browWeight)
            var wedge = Path()
            let innerX = c.x + side * r
            wedge.move(to: CGPoint(x: innerX, y: c.y - height * 0.6))
            wedge.addLine(to: CGPoint(x: innerX, y: c.y - height * (0.6 - 0.55 * k)))
            wedge.addLine(to: CGPoint(x: c.x - side * r * 1.05, y: c.y - height * 0.6))
            wedge.closeSubpath()
            eyeCtx.fill(wedge, with: .color(lidColor))
        }

        if arc > 0.01 {
            var arcPath = Path()
            arcPath.move(to: CGPoint(x: c.x - r * 0.95, y: c.y + r * 0.25))
            arcPath.addQuadCurve(to: CGPoint(x: c.x + r * 0.95, y: c.y + r * 0.25), control: CGPoint(x: c.x, y: c.y - r * 1.05))
            ctx.stroke(arcPath, with: .color(eyeColor.opacity(Double(arc))), style: StrokeStyle(lineWidth: r * 0.38, lineCap: .round))
            if arc > 0.5 {
                ctx.fill(eyePath, with: .color(lidColor.opacity(Double((arc - 0.5) * 2))))
            }
        }

        let gx = CGFloat(rig.gazeX) * r * 0.3, gy = CGFloat(rig.gazeY) * r * 0.3
        let ps = CGFloat(rig.pupilScale)
        let hlAlpha = Double(1 - arc * 0.9) * Double(min(1, open * 1.6))
        var hl = ctx
        hl.clip(to: eyePath)
        hl.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.42 + gx - r * 0.3 * ps, y: c.y - r * 0.42 + gy - r * 0.3 * ps, width: r * 0.6 * ps, height: r * 0.6 * ps)), with: .color(.white.opacity(0.95 * hlAlpha)))
        hl.fill(Path(ellipseIn: CGRect(x: c.x + r * 0.28 + gx - r * 0.13, y: c.y + r * 0.3 + gy - r * 0.13, width: r * 0.26, height: r * 0.26)), with: .color(.white.opacity(0.75 * hlAlpha)))
    }

    public static func brows(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: FaceLayout = FaceLayout()) {
        let rig = p.rig
        guard rig.browWeight > 0.02 else { return }
        let h = p.head
        let r = h.width * layout.eyeRadius * CGFloat(rig.eyeScale)
        for side: CGFloat in [-1, 1] {
            let cx = h.center.x + side * h.width * layout.eyeSpacing
            let cy = h.center.y + h.height * layout.eyeY - r * 1.55
            let innerLift = CGFloat(rig.browInnerUp) * r * 0.55
            let outer = CGPoint(x: cx + side * r * 0.9, y: cy + innerLift * 0.35)
            let inner = CGPoint(x: cx - side * r * 0.7, y: cy - innerLift)
            var path = Path()
            path.move(to: outer)
            path.addQuadCurve(to: inner, control: CGPoint(x: cx, y: cy - r * 0.2))
            ctx.stroke(path, with: .color(p.palette.eye.opacity(0.8 * rig.browWeight)), style: StrokeStyle(lineWidth: r * 0.26, lineCap: .round))
        }
    }

    public static func blush(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: FaceLayout = FaceLayout()) {
        guard p.rig.blush > 0.02 else { return }
        let h = p.head
        let w = h.width * 0.16, hh = h.height * 0.09
        for side: CGFloat in [-1, 1] {
            let cx = h.center.x + side * h.width * layout.blushX
            let cy = h.center.y + h.height * layout.blushY
            let r = CGRect(x: cx - w / 2, y: cy - hh / 2, width: w, height: hh)
            ctx.fill(Path(ellipseIn: r), with: .radialGradient(
                Gradient(colors: [p.palette.blush.opacity(0.55 * p.rig.blush), p.palette.blush.opacity(0)]),
                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: w * 0.55))
        }
    }

    public enum MouthStyle { case cat, simple, beak, snout }

    public static func mouth(_ ctx: inout GraphicsContext, _ p: PetPaintContext, style: MouthStyle, layout: FaceLayout = FaceLayout()) {
        let rig = p.rig
        let h = p.head
        let mx = h.center.x
        let my = h.center.y + h.height * layout.mouthY
        let half = h.width * layout.mouthWidth * CGFloat(rig.mouthWidth) / 2
        let curve = CGFloat(rig.mouthCurve)
        let open = CGFloat(rig.mouthOpen)
        let line = StrokeStyle(lineWidth: max(1.6, h.width * 0.02), lineCap: .round, lineJoin: .round)
        let ink = p.palette.eye.opacity(0.85)

        if open > 0.08 {
            let depth = half * (0.9 + 1.6 * open)
            var m = Path()
            m.move(to: CGPoint(x: mx - half, y: my))
            m.addQuadCurve(to: CGPoint(x: mx + half, y: my), control: CGPoint(x: mx, y: my - curve * half * 0.6))
            m.addQuadCurve(to: CGPoint(x: mx - half, y: my), control: CGPoint(x: mx, y: my + depth * 1.7))
            m.closeSubpath()
            ctx.fill(m, with: .color(Color(red: 0.45, green: 0.18, blue: 0.2)))
            var inner = ctx
            inner.clip(to: m)
            let tongueH = depth * (0.55 + 0.35 * CGFloat(rig.tongue))
            inner.fill(Path(ellipseIn: CGRect(x: mx - half * 0.65, y: my + depth * 0.45 - (CGFloat(rig.tongue) * depth * 0.2), width: half * 1.3, height: tongueH)), with: .color(Color(red: 0.98, green: 0.55, blue: 0.58)))
            ctx.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: line.lineWidth * 0.8, lineJoin: .round))
            return
        }

        var path = Path()
        switch style {
        case .cat:
            let drop = half * 0.55
            let endY = my + (curve < 0 ? -curve * half * 0.7 : -curve * half * 0.35)
            let ctrlY = my + drop * (curve >= 0 ? 1.4 : 0.4)
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
        case .beak:
            return
        }
        ctx.stroke(path, with: .color(ink), style: line)

        if rig.tongue > 0.05 && style != .cat {
            let tw = half * 0.7, th = half * 0.9 * CGFloat(rig.tongue)
            ctx.fill(Path(roundedRect: CGRect(x: mx - tw / 2, y: my - 1, width: tw, height: th), cornerRadius: tw / 2), with: .color(Color(red: 0.98, green: 0.55, blue: 0.58)))
        }
    }

    public static func sweat(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        guard p.rig.sweat > 0.03 else { return }
        let h = p.head
        let c = CGPoint(x: h.center.x + h.width * 0.42, y: h.top + h.height * 0.22)
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

    // MARK: Ears & tails

    /// Pointed ear. `lift` 0…1 rotates from flattened-out to perked.
    public static func pointedEar(_ ctx: inout GraphicsContext, _ p: PetPaintContext, side: CGFloat, baseFrom: CGPoint, baseTo: CGPoint, length: CGFloat, innerInset: CGFloat = 0.3) {
        let lift = CGFloat(p.rig.earLift) + CGFloat(p.live.earTwitch)
        let mid = CGPoint(x: (baseFrom.x + baseTo.x) / 2, y: (baseFrom.y + baseTo.y) / 2)
        let angle = side * (0.28 + (1 - lift) * 1.1)
        let tip = CGPoint(x: mid.x + sin(angle) * length, y: mid.y - cos(angle) * length)
        var ear = Path()
        ear.move(to: baseFrom)
        ear.addQuadCurve(to: tip, control: CGPoint(x: (baseFrom.x + tip.x) / 2 - side * length * 0.12, y: (baseFrom.y + tip.y) / 2))
        ear.addQuadCurve(to: baseTo, control: CGPoint(x: (baseTo.x + tip.x) / 2 + side * length * 0.05, y: (baseTo.y + tip.y) / 2))
        ear.closeSubpath()
        ctx.fill(ear, with: .linearGradient(Gradient(colors: [p.palette.bodyTop, p.palette.bodyBottom]), startPoint: tip, endPoint: mid))
        let innerTip = lerp(mid, tip, 1 - innerInset)
        let iFrom = lerp(baseFrom, mid, innerInset * 1.2)
        let iTo = lerp(baseTo, mid, innerInset * 1.2)
        var inner = Path()
        inner.move(to: iFrom)
        inner.addQuadCurve(to: innerTip, control: CGPoint(x: (iFrom.x + innerTip.x) / 2 - side * length * 0.1, y: (iFrom.y + innerTip.y) / 2))
        inner.addQuadCurve(to: iTo, control: CGPoint(x: (iTo.x + innerTip.x) / 2 + side * length * 0.03, y: (iTo.y + innerTip.y) / 2))
        inner.closeSubpath()
        ctx.fill(inner, with: .color(p.palette.earInner.opacity(0.9)))
    }

    /// Round ear.
    public static func roundEar(_ ctx: inout GraphicsContext, _ p: PetPaintContext, center: CGPoint, radius: CGFloat, innerRatio: CGFloat = 0.55) {
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                 with: .linearGradient(Gradient(colors: [p.palette.bodyTop, p.palette.bodyBottom]), startPoint: CGPoint(x: center.x, y: center.y - radius), endPoint: CGPoint(x: center.x, y: center.y + radius)))
        let ir = radius * innerRatio
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - ir, y: center.y - ir + radius * 0.08, width: ir * 2, height: ir * 2)), with: .color(p.palette.earInner.opacity(0.95)))
    }

    /// Curved tail stroke from the hip. `tailLift` 0 = along the floor, 1 = curled high.
    public static func tail(_ ctx: inout GraphicsContext, _ p: PetPaintContext, start: CGPoint, length: CGFloat, width: CGFloat, color: Color, tip: Color? = nil, curl: CGFloat = 1) {
        let lift = CGFloat(p.rig.tailLift)
        let wag = CGFloat(p.live.tailWag)
        let length = length * (1 - 0.3 * CGFloat(p.rig.lying))
        let angle = -lift * 1.3 + wag * 0.45
        let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
        let c1 = CGPoint(x: start.x + length * 0.55, y: start.y + length * 0.12)
        let c2 = CGPoint(x: end.x + curl * length * 0.35 * (1 - lift), y: end.y - curl * length * 0.35 * lift)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: c1, control2: c2)
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        if let tip {
            ctx.fill(Path(ellipseIn: CGRect(x: end.x - width * 0.55, y: end.y - width * 0.55, width: width * 1.1, height: width * 1.1)), with: .color(tip))
        }
    }

    public static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

// MARK: - Species anatomy

public extension PetSpecies {
    var anatomy: PetAnatomy {
        switch self {
        case .cat:
            PetAnatomy(headWidth: 92, headHeight: 78, headOverlap: 26, cheekSquareness: 0.35, torsoHeight: 84, chestWidth: 62, hipWidth: 98, legWidth: 15)
        case .dog:
            PetAnatomy(headWidth: 90, headHeight: 82, headOverlap: 24, cheekSquareness: 0.3, torsoHeight: 86, chestWidth: 66, hipWidth: 100, legWidth: 16)
        case .capybara:
            PetAnatomy(headWidth: 98, headHeight: 66, headOverlap: 18, cheekSquareness: 0.7, torsoHeight: 78, chestWidth: 84, hipWidth: 112, legWidth: 17)
        case .penguin:
            PetAnatomy(headWidth: 74, headHeight: 64, headOverlap: 30, cheekSquareness: 0.2, torsoHeight: 100, chestWidth: 74, hipWidth: 88, legWidth: 0)
        case .redPanda:
            PetAnatomy(headWidth: 94, headHeight: 78, headOverlap: 26, cheekSquareness: 0.4, torsoHeight: 82, chestWidth: 66, hipWidth: 102, legWidth: 16)
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
