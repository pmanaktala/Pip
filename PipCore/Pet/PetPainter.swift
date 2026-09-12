import SwiftUI

/// Shared drawing vocabulary for all species painters.
///
/// Painters draw into a 200×200 "design canvas"; `PetView` scales it to fit.
/// The body is a soft blob (head and body in one, chibi proportions). Species add
/// ears, tails, markings and props on top of the same face system.
public struct PetPaintContext {
    public var rig: PetRig
    public var live: LiveMotion
    public var palette: PetPalette
    public var colorScheme: ColorScheme
    /// Body geometry after squash / lying adjustments.
    public var body: Blob

    public struct Blob {
        public var center: CGPoint
        public var width: CGFloat
        public var height: CGFloat
        /// 0…1 how flat the bottom is.
        public var bottomFlatness: CGFloat

        public var rect: CGRect { CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height) }
        public var bottom: CGFloat { center.y + height / 2 }
        public var top: CGFloat { center.y - height / 2 }

        public func point(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: center.x + fx * width, y: center.y + fy * height)
        }
    }

    public init(rig: PetRig, live: LiveMotion, palette: PetPalette, colorScheme: ColorScheme, bodyWidth: CGFloat = 118, bodyHeight: CGFloat = 106) {
        self.rig = rig
        self.live = live
        self.palette = palette
        self.colorScheme = colorScheme
        let lying = CGFloat(rig.lying)
        let squash = CGFloat(rig.squash)
        var w = bodyWidth + 22 * lying
        var h = bodyHeight - 24 * lying
        h *= squash
        w /= sqrt(squash)
        let floor: CGFloat = 168
        let center = CGPoint(x: 100, y: floor - h / 2)
        body = Blob(center: center, width: w, height: h, bottomFlatness: 0.35 + 0.4 * lying)
    }
}

public protocol PetPainter {
    /// Draw the pet into `ctx` (already transformed into the 200×200 design space).
    static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext)
}

// MARK: - Shared primitives

public enum PetDraw {

    // MARK: Body

    /// A soft, slightly bottom-heavy blob path.
    public static func blobPath(_ b: PetPaintContext.Blob) -> Path {
        let c = b.center, w = b.width, h = b.height
        let kTop: CGFloat = 0.56
        let kSide: CGFloat = 0.62
        let kBottom: CGFloat = 0.72 + 0.2 * b.bottomFlatness
        let top = CGPoint(x: c.x, y: c.y - h / 2)
        let right = CGPoint(x: c.x + w / 2, y: c.y + h * 0.06)
        let bottom = CGPoint(x: c.x, y: c.y + h / 2)
        let left = CGPoint(x: c.x - w / 2, y: c.y + h * 0.06)
        var p = Path()
        p.move(to: top)
        p.addCurve(to: right,
                   control1: CGPoint(x: top.x + w / 2 * kTop, y: top.y),
                   control2: CGPoint(x: right.x, y: right.y - (right.y - top.y) * kSide))
        p.addCurve(to: bottom,
                   control1: CGPoint(x: right.x, y: right.y + (bottom.y - right.y) * kSide),
                   control2: CGPoint(x: bottom.x + w / 2 * kBottom, y: bottom.y))
        p.addCurve(to: left,
                   control1: CGPoint(x: bottom.x - w / 2 * kBottom, y: bottom.y),
                   control2: CGPoint(x: left.x, y: left.y + (bottom.y - left.y) * kSide))
        p.addCurve(to: top,
                   control1: CGPoint(x: left.x, y: left.y - (left.y - top.y) * kSide),
                   control2: CGPoint(x: top.x - w / 2 * kTop, y: top.y))
        p.closeSubpath()
        return p
    }

    /// Fills the body with its gradient, soft highlight and a base shadow.
    public static func fillBody(_ ctx: inout GraphicsContext, _ p: PetPaintContext, path: Path) {
        let b = p.body
        ctx.fill(path, with: .linearGradient(
            Gradient(colors: [p.palette.bodyTop, p.palette.bodyBottom]),
            startPoint: CGPoint(x: b.center.x, y: b.top),
            endPoint: CGPoint(x: b.center.x, y: b.bottom)))

        var inner = ctx
        inner.clip(to: path)
        // Soft top-left highlight.
        let hl = CGRect(x: b.center.x - b.width * 0.42, y: b.top + b.height * 0.06, width: b.width * 0.55, height: b.height * 0.45)
        inner.fill(Path(ellipseIn: hl), with: .radialGradient(
            Gradient(colors: [.white.opacity(0.32), .white.opacity(0)]),
            center: CGPoint(x: hl.midX, y: hl.midY), startRadius: 0, endRadius: hl.width * 0.55))
        // Contact shadow along the bottom.
        inner.fill(path, with: .linearGradient(
            Gradient(colors: [p.palette.outline.opacity(0), p.palette.outline.opacity(0.16)]),
            startPoint: CGPoint(x: b.center.x, y: b.center.y + b.height * 0.15),
            endPoint: CGPoint(x: b.center.x, y: b.bottom)))
    }

    /// Lighter belly patch clipped to the body.
    public static func belly(_ ctx: inout GraphicsContext, _ p: PetPaintContext, path: Path, widthFraction: CGFloat = 0.62, heightFraction: CGFloat = 0.5, yOffset: CGFloat = 0.28, opacity: Double = 0.9) {
        let b = p.body
        var inner = ctx
        inner.clip(to: path)
        let r = CGRect(x: b.center.x - b.width * widthFraction / 2,
                       y: b.center.y + b.height * yOffset - b.height * heightFraction / 2,
                       width: b.width * widthFraction, height: b.height * heightFraction)
        inner.fill(Path(ellipseIn: r), with: .color(p.palette.belly.opacity(opacity)))
    }

    /// Ground shadow beneath the pet; shrinks when the pet hops.
    public static func floorShadow(_ ctx: inout GraphicsContext, _ p: PetPaintContext, spread: Double = 1) {
        let b = p.body
        let lift = -p.live.bounce - CGFloat(min(0, p.rig.lift))
        let k = max(0.6, 1 - lift / 40)
        let w = b.width * 0.78 * k * spread
        let h = b.height * 0.11 * k
        let r = CGRect(x: 100 - w / 2, y: 168 - h / 2 + 4, width: w, height: h)
        let shade: Color = p.colorScheme == .dark ? .black : Color(red: 0.35, green: 0.25, blue: 0.2)
        ctx.fill(Path(ellipseIn: r), with: .radialGradient(
            Gradient(colors: [shade.opacity(0.22 * k), shade.opacity(0)]),
            center: CGPoint(x: r.midX, y: r.midY), startRadius: 0, endRadius: w * 0.5))
    }

    // MARK: Face

    public struct FaceLayout {
        public var eyeSpacing: CGFloat = 0.22
        public var eyeY: CGFloat = -0.09
        public var eyeRadius: CGFloat = 0.082
        public var mouthY: CGFloat = 0.11
        public var mouthWidth: CGFloat = 0.13
        public var blushX: CGFloat = 0.33
        public var blushY: CGFloat = 0.03
        public init() {}
    }

    public static func eyes(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: FaceLayout = FaceLayout(), lidColor: Color? = nil) {
        let b = p.body
        let r = b.width * layout.eyeRadius * CGFloat(p.rig.eyeScale)
        let lid = lidColor ?? p.palette.bodyTop
        for side: CGFloat in [-1, 1] {
            let cx = b.center.x + side * b.width * layout.eyeSpacing + CGFloat(p.rig.gazeX) * r * 0.25
            let cy = b.center.y + b.height * layout.eyeY + CGFloat(p.rig.gazeY) * r * 0.2
            eye(&ctx, p, center: CGPoint(x: cx, y: cy), radius: r, side: side, lidColor: lid)
        }
    }

    static func eye(_ ctx: inout GraphicsContext, _ p: PetPaintContext, center c: CGPoint, radius r: CGFloat, side: CGFloat, lidColor: Color) {
        let rig = p.rig
        let open = CGFloat(rig.eyeOpen)
        let arc = CGFloat(rig.eyeArc)
        let eyeColor = p.palette.eye

        // Closed / nearly closed: a soft curved line. Curves up if happy, down if sleepy.
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

        // Lids: squint and heaviness cover the top with a curved lid.
        let cover = max(CGFloat(rig.eyeSquint) * 0.42, CGFloat(rig.lidHeaviness) * 0.5)
        if cover > 0.01 {
            let lidRect = rect.offsetBy(dx: 0, dy: -height * (1 - cover))
            eyeCtx.fill(Path(ellipseIn: lidRect), with: .color(lidColor))
        }
        // Angry/annoyed squint also cuts the inner-top corner diagonally.
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

        // Happy arc: a thick "^" fading in as eyeArc rises.
        if arc > 0.01 {
            var arcPath = Path()
            arcPath.move(to: CGPoint(x: c.x - r * 0.95, y: c.y + r * 0.25))
            arcPath.addQuadCurve(to: CGPoint(x: c.x + r * 0.95, y: c.y + r * 0.25), control: CGPoint(x: c.x, y: c.y - r * 1.05))
            ctx.stroke(arcPath, with: .color(eyeColor.opacity(Double(arc))), style: StrokeStyle(lineWidth: r * 0.38, lineCap: .round))
            // Fade the round eye out underneath.
            if arc > 0.5 {
                ctx.fill(eyePath, with: .color(lidColor.opacity(Double((arc - 0.5) * 2))))
            }
        }

        // Highlights — these carry the gaze.
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
        let b = p.body
        let r = b.width * layout.eyeRadius * CGFloat(rig.eyeScale)
        for side: CGFloat in [-1, 1] {
            let cx = b.center.x + side * b.width * layout.eyeSpacing
            let cy = b.center.y + b.height * layout.eyeY - r * 1.55
            let innerLift = CGFloat(rig.browInnerUp) * r * 0.55
            // inner end is toward the centre (opposite sign of side)
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
        let b = p.body
        let w = b.width * 0.15, h = b.height * 0.075
        for side: CGFloat in [-1, 1] {
            let cx = b.center.x + side * b.width * layout.blushX
            let cy = b.center.y + b.height * layout.blushY
            let r = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
            ctx.fill(Path(ellipseIn: r), with: .radialGradient(
                Gradient(colors: [p.palette.blush.opacity(0.55 * p.rig.blush), p.palette.blush.opacity(0)]),
                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: w * 0.55))
        }
    }

    public enum MouthStyle { case cat, simple, beak, snout }

    public static func mouth(_ ctx: inout GraphicsContext, _ p: PetPaintContext, style: MouthStyle, layout: FaceLayout = FaceLayout()) {
        let rig = p.rig
        let b = p.body
        let mx = b.center.x
        let my = b.center.y + b.height * layout.mouthY
        let half = b.width * layout.mouthWidth * CGFloat(rig.mouthWidth) / 2
        let curve = CGFloat(rig.mouthCurve)
        let open = CGFloat(rig.mouthOpen)
        let line = StrokeStyle(lineWidth: max(1.6, b.width * 0.018), lineCap: .round, lineJoin: .round)
        let ink = p.palette.eye.opacity(0.85)

        if open > 0.08 {
            // Open mouth: rounded shape whose top edge is the smile curve.
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
            // "ω": two curves meeting under the nose.
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
                    let base = my - curve * half * 0.9 * sin(t * .pi)
                    let wob = sin(t * .pi * 5) * half * 0.22 * CGFloat(rig.mouthWobble)
                    path.addLine(to: CGPoint(x: x, y: base + wob))
                }
            } else {
                path.move(to: CGPoint(x: mx - half, y: my))
                path.addQuadCurve(to: CGPoint(x: mx + half, y: my), control: CGPoint(x: mx, y: my - curve * half * 1.5))
            }
        case .beak:
            return // drawn by the species painter
        }
        ctx.stroke(path, with: .color(ink), style: line)

        // Tongue peeking out on a closed mouth.
        if rig.tongue > 0.05 && style != .cat {
            let tw = half * 0.7, th = half * 0.9 * CGFloat(rig.tongue)
            ctx.fill(Path(roundedRect: CGRect(x: mx - tw / 2, y: my - 1, width: tw, height: th), cornerRadius: tw / 2), with: .color(Color(red: 0.98, green: 0.55, blue: 0.58)))
        }
    }

    public static func sweat(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        guard p.rig.sweat > 0.03 else { return }
        let b = p.body
        let c = CGPoint(x: b.center.x + b.width * 0.36, y: b.top + b.height * 0.2)
        let s = b.width * 0.055
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

    /// Pointed ear (cat, some markings). `lift` 0…1 rotates from flat/back to perked.
    public static func pointedEar(_ ctx: inout GraphicsContext, _ p: PetPaintContext, side: CGFloat, baseFrom: CGPoint, baseTo: CGPoint, length: CGFloat, innerInset: CGFloat = 0.3) {
        let lift = CGFloat(p.rig.earLift) + CGFloat(p.live.earTwitch)
        let mid = CGPoint(x: (baseFrom.x + baseTo.x) / 2, y: (baseFrom.y + baseTo.y) / 2)
        // Perked ears point up and slightly out; lowered ears fold outward and down.
        let angle = side * (0.25 + (1 - lift) * 1.15) // radians from vertical
        let tip = CGPoint(x: mid.x + sin(angle) * length, y: mid.y - cos(angle) * length)
        var ear = Path()
        ear.move(to: baseFrom)
        ear.addQuadCurve(to: tip, control: CGPoint(x: (baseFrom.x + tip.x) / 2 - side * length * 0.15, y: (baseFrom.y + tip.y) / 2))
        ear.addQuadCurve(to: baseTo, control: CGPoint(x: (baseTo.x + tip.x) / 2 + side * length * 0.05, y: (baseTo.y + tip.y) / 2))
        ear.closeSubpath()
        ctx.fill(ear, with: .linearGradient(Gradient(colors: [p.palette.bodyTop, p.palette.bodyBottom]), startPoint: tip, endPoint: mid))
        // Inner ear.
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

    /// Round ear (red panda, capybara-ish). Returns nothing; draws behind head typically.
    public static func roundEar(_ ctx: inout GraphicsContext, _ p: PetPaintContext, center: CGPoint, radius: CGFloat, innerRatio: CGFloat = 0.55) {
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                 with: .linearGradient(Gradient(colors: [p.palette.bodyTop, p.palette.bodyBottom]), startPoint: CGPoint(x: center.x, y: center.y - radius), endPoint: CGPoint(x: center.x, y: center.y + radius)))
        let ir = radius * innerRatio
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - ir, y: center.y - ir + radius * 0.08, width: ir * 2, height: ir * 2)), with: .color(p.palette.earInner.opacity(0.95)))
    }

    /// Curved tail stroke. `lift` 0 = along the floor, 1 = curled high. Wag rotates the end.
    public static func tail(_ ctx: inout GraphicsContext, _ p: PetPaintContext, start: CGPoint, length: CGFloat, width: CGFloat, color: Color, tip: Color? = nil, curl: CGFloat = 1) {
        let lift = CGFloat(p.rig.tailLift)
        let wag = CGFloat(p.live.tailWag)
        // Base angle: 0 = pointing right along the floor, -π/2 = straight up.
        let angle = -lift * 1.25 + wag * 0.45
        let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
        let c1 = CGPoint(x: start.x + length * 0.55, y: start.y + length * 0.1)
        let c2 = CGPoint(x: end.x + curl * length * 0.35 * (1 - lift), y: end.y - curl * length * 0.35 * lift)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: c1, control2: c2)
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        if let tip {
            ctx.fill(Path(ellipseIn: CGRect(x: end.x - width * 0.55, y: end.y - width * 0.55, width: width * 1.1, height: width * 1.1)), with: .color(tip))
        }
    }

    // MARK: Utilities

    public static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}
