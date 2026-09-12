import SwiftUI

/// Mochi — a round, slightly dramatic cat.
public enum CatPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let b = p.body
        let body = PetDraw.blobPath(b)

        // Tail (behind the body), anchored low on the right.
        PetDraw.tail(&ctx, p,
                     start: CGPoint(x: b.center.x + b.width * 0.30, y: b.bottom - b.height * 0.12),
                     length: b.width * 0.5, width: b.width * 0.11,
                     color: p.palette.bodyBottom, tip: p.palette.marking)

        // Ears sit behind the head outline.
        let earLen = b.height * 0.34
        PetDraw.pointedEar(&ctx, p, side: -1,
                           baseFrom: b.point(-0.40, -0.22), baseTo: b.point(-0.13, -0.47), length: earLen)
        PetDraw.pointedEar(&ctx, p, side: 1,
                           baseFrom: b.point(0.13, -0.47), baseTo: b.point(0.40, -0.22), length: earLen)

        PetDraw.fillBody(&ctx, p, path: body)
        PetDraw.belly(&ctx, p, path: body, widthFraction: 0.5, heightFraction: 0.42, yOffset: 0.3, opacity: 0.85)

        // Forehead stripes — a tabby hint.
        var stripes = ctx
        stripes.clip(to: body)
        for i in -1...1 {
            let x = b.center.x + CGFloat(i) * b.width * 0.08
            var s = Path()
            s.move(to: CGPoint(x: x, y: b.top + b.height * 0.02))
            s.addQuadCurve(to: CGPoint(x: x + CGFloat(i) * 2, y: b.top + b.height * (0.13 - 0.03 * CGFloat(abs(i)))),
                           control: CGPoint(x: x + CGFloat(i) * 1.5, y: b.top + b.height * 0.07))
            stripes.stroke(s, with: .color(p.palette.marking.opacity(0.55)), style: StrokeStyle(lineWidth: b.width * 0.03, lineCap: .round))
        }

        // Paws tucked in front.
        for side: CGFloat in [-1, 1] {
            let paw = CGRect(x: b.center.x + side * b.width * 0.17 - b.width * 0.11, y: b.bottom - b.height * 0.13, width: b.width * 0.22, height: b.height * 0.12)
            ctx.fill(Path(ellipseIn: paw), with: .color(p.palette.bodyTop))
            var toes = Path()
            for t in [-0.05, 0.05] {
                let x = paw.midX + CGFloat(t) * b.width
                toes.move(to: CGPoint(x: x, y: paw.midY))
                toes.addLine(to: CGPoint(x: x, y: paw.maxY - 1))
            }
            ctx.stroke(toes, with: .color(p.palette.marking.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }

        // Face.
        var layout = PetDraw.FaceLayout()
        layout.eyeY = -0.10
        layout.mouthY = 0.09
        PetDraw.blush(&ctx, p, layout: layout)
        PetDraw.eyes(&ctx, p, layout: layout)
        PetDraw.brows(&ctx, p, layout: layout)

        // Nose.
        let nx = b.center.x, ny = b.center.y + b.height * layout.mouthY - b.width * 0.045
        let ns = b.width * 0.03
        var nose = Path()
        nose.move(to: CGPoint(x: nx - ns, y: ny - ns * 0.5))
        nose.addLine(to: CGPoint(x: nx + ns, y: ny - ns * 0.5))
        nose.addQuadCurve(to: CGPoint(x: nx, y: ny + ns * 0.8), control: CGPoint(x: nx + ns * 0.7, y: ny + ns * 0.6))
        nose.addQuadCurve(to: CGPoint(x: nx - ns, y: ny - ns * 0.5), control: CGPoint(x: nx - ns * 0.7, y: ny + ns * 0.6))
        ctx.fill(nose, with: .color(p.palette.nose))

        PetDraw.mouth(&ctx, p, style: .cat, layout: layout)

        // Whiskers.
        var whiskers = Path()
        for side: CGFloat in [-1, 1] {
            for (i, dy) in [-0.02, 0.02, 0.06].enumerated() {
                let x0 = b.center.x + side * b.width * 0.30
                let y0 = b.center.y + b.height * (0.05 + dy)
                let angle = CGFloat(i - 1) * 0.16
                whiskers.move(to: CGPoint(x: x0, y: y0))
                whiskers.addLine(to: CGPoint(x: x0 + side * cos(angle) * b.width * 0.2, y: y0 + sin(angle) * b.width * 0.2 * side))
            }
        }
        ctx.stroke(whiskers, with: .color(p.palette.outline.opacity(0.35)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

        PetDraw.sweat(&ctx, p)
    }
}
