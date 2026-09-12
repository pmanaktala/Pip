import SwiftUI

/// Mochi — a sitting tabby with a curling tail and a slightly dramatic face.
public enum CatPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso

        // Tail from the hip, behind the body.
        PetDraw.tail(&ctx, p,
                     start: CGPoint(x: t.centerX + t.hipWidth * 0.34, y: t.bottom - 14),
                     length: 58, width: 13, color: p.palette.bodyBottom, tip: p.palette.marking)

        PetDraw.body(&ctx, p)

        // Head group (tilts about the neck).
        var hc = PetDraw.headContext(ctx, p)
        let h = p.head
        let head = PetDraw.headPath(h)

        let earLen: CGFloat = 30
        PetDraw.pointedEar(&hc, p, side: -1, baseFrom: h.point(-0.42, -0.2), baseTo: h.point(-0.14, -0.47), length: earLen)
        PetDraw.pointedEar(&hc, p, side: 1, baseFrom: h.point(0.14, -0.47), baseTo: h.point(0.42, -0.2), length: earLen)

        PetDraw.fillFur(&hc, p, path: head, rect: h.rect)

        // Tabby stripes on the forehead and cheeks.
        var stripes = hc
        stripes.clip(to: head)
        for i in -1...1 {
            let x = h.center.x + CGFloat(i) * h.width * 0.09
            var s = Path()
            s.move(to: CGPoint(x: x, y: h.top + 3))
            s.addQuadCurve(to: CGPoint(x: x + CGFloat(i) * 1.5, y: h.top + h.height * (0.2 - 0.04 * CGFloat(abs(i)))), control: CGPoint(x: x + CGFloat(i), y: h.top + 8))
            stripes.stroke(s, with: .color(p.palette.marking.opacity(0.5)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        }
        for side: CGFloat in [-1, 1] {
            var s = Path()
            s.move(to: CGPoint(x: h.center.x + side * h.width * 0.5, y: h.center.y - 2))
            s.addLine(to: CGPoint(x: h.center.x + side * h.width * 0.38, y: h.center.y + 2))
            stripes.stroke(s, with: .color(p.palette.marking.opacity(0.4)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // Muzzle: a paler patch around nose and mouth.
        let mz = CGRect(x: h.center.x - h.width * 0.2, y: h.center.y + h.height * 0.12, width: h.width * 0.4, height: h.height * 0.26)
        hc.fill(Path(ellipseIn: mz), with: .color(p.palette.belly.opacity(0.55)))

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.21
        layout.eyeY = 0.0
        layout.eyeRadius = 0.085
        layout.mouthY = 0.27
        layout.mouthWidth = 0.13
        layout.blushX = 0.36
        layout.blushY = 0.15
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)

        // Nose.
        let nx = h.center.x, ny = h.center.y + h.height * layout.mouthY - h.width * 0.05
        let ns = h.width * 0.032
        var nose = Path()
        nose.move(to: CGPoint(x: nx - ns, y: ny - ns * 0.5))
        nose.addLine(to: CGPoint(x: nx + ns, y: ny - ns * 0.5))
        nose.addQuadCurve(to: CGPoint(x: nx, y: ny + ns * 0.8), control: CGPoint(x: nx + ns * 0.7, y: ny + ns * 0.6))
        nose.addQuadCurve(to: CGPoint(x: nx - ns, y: ny - ns * 0.5), control: CGPoint(x: nx - ns * 0.7, y: ny + ns * 0.6))
        hc.fill(nose, with: .color(p.palette.nose))

        PetDraw.mouth(&hc, p, style: .cat, layout: layout)

        // Whiskers.
        var whiskers = Path()
        for side: CGFloat in [-1, 1] {
            for (i, dy) in [-0.02, 0.03, 0.08].enumerated() {
                let x0 = h.center.x + side * h.width * 0.3
                let y0 = h.center.y + h.height * (0.16 + dy)
                let angle = CGFloat(i - 1) * 0.16
                whiskers.move(to: CGPoint(x: x0, y: y0))
                whiskers.addLine(to: CGPoint(x: x0 + side * cos(angle) * h.width * 0.26, y: y0 + sin(angle) * h.width * 0.26 * side))
            }
        }
        hc.stroke(whiskers, with: .color(p.palette.outline.opacity(0.35)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

        PetDraw.sweat(&hc, p)
    }
}
