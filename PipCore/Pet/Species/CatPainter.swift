import SwiftUI

/// Mochi — a sitting orange tabby. One silhouette with triangular ears, a pale chest,
/// three forehead stripes, small eyes, a tiny nose and ω mouth, a wrapping tail, a bell collar.
public enum CatPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let h = p.head
        let earInner = h.point(0.14, -0.44), earOuter = h.point(0.44, -0.16)
        let earLen: CGFloat = 34
        let ear = PetDraw.pointedEarPath(p, baseInner: earInner, baseOuter: earOuter, length: earLen)
        let silhouette = PetDraw.silhouette(p, extras: [PetDraw.symmetric(ear)])
        ctx.fill(silhouette, with: .color(p.palette.base))

        PetDraw.belly(&ctx, p, within: silhouette, widthFraction: 0.5, heightFraction: 0.5)

        // Tail in front of the haunch, wrapping around the paws when down.
        PetDraw.tail(&ctx, p, width: 13, length: 62, color: p.palette.base, tip: p.palette.marking)
        PetDraw.paws(&ctx, p, color: p.palette.light)

        // Inner ears.
        PetDraw.mirrored(&ctx) { ctx, _ in
            PetDraw.innerEar(&ctx, p, baseInner: earInner, baseOuter: earOuter, length: earLen, color: p.palette.earInner)
        }

        var hc = PetDraw.headContext(ctx, p)

        // Three short forehead stripes.
        if p.detail == .full {
            var stripes = Path()
            for i in -1...1 {
                let x = h.center.x + CGFloat(i) * h.width * 0.1
                stripes.move(to: CGPoint(x: x, y: h.top + h.height * 0.04))
                stripes.addLine(to: CGPoint(x: x, y: h.top + h.height * (0.16 - 0.03 * CGFloat(abs(i)))))
            }
            hc.stroke(stripes, with: .color(p.palette.marking), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        }

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.2
        layout.eyeY = 0.0
        layout.eyeRadius = p.anatomy.eyeRadius
        layout.mouthY = 0.22
        layout.mouthWidth = 0.1
        layout.blushX = 0.34
        layout.blushY = 0.13
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)

        // Tiny nose.
        let a = PetDraw.mouthAnchor(p, layout: layout)
        let ns = h.width * 0.03
        var nose = Path()
        nose.move(to: CGPoint(x: a.x - ns, y: a.y - ns * 2.2))
        nose.addLine(to: CGPoint(x: a.x + ns, y: a.y - ns * 2.2))
        nose.addQuadCurve(to: CGPoint(x: a.x, y: a.y - ns * 0.8), control: CGPoint(x: a.x + ns * 0.6, y: a.y - ns * 0.9))
        nose.addQuadCurve(to: CGPoint(x: a.x - ns, y: a.y - ns * 2.2), control: CGPoint(x: a.x - ns * 0.6, y: a.y - ns * 0.9))
        hc.fill(nose, with: .color(p.palette.nose))

        PetDraw.mouth(&hc, p, style: .cat, layout: layout)
        PetProps.collar(&hc, p)
        PetDraw.sweat(&hc, p)
    }
}
