import SwiftUI

/// The small graphic signs around the pet: zzz, notes, hearts, sparkles, steam, sweat, a tear,
/// "?" and "!". Each channel in the pose is an intensity; the clock only makes them drift.
enum PetEffects {
    static func draw(_ ctx: GraphicsContext, body: GraphicsContext, head: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pose = p.pose
        let t = p.time ?? 0.35
        let ink = p.palette.ink
        let badge = p.detail == .badge
        // Sweat and tears belong to the face.
        if pose.sweat > 0.02 {
            let c = CGPoint(x: fig.headRX * 0.78, y: -fig.headRY * 0.45)
            var drop = Path()
            drop.move(to: CGPoint(x: c.x, y: c.y - 7))
            drop.addQuadCurve(to: CGPoint(x: c.x + 4.5, y: c.y + 2), control: CGPoint(x: c.x + 4.5, y: c.y - 2))
            drop.addArc(center: CGPoint(x: c.x, y: c.y + 2), radius: 4.5, startAngle: .zero, endAngle: .degrees(180), clockwise: false)
            drop.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 7), control: CGPoint(x: c.x - 4.5, y: c.y - 2))
            head.fill(drop, PetRGB(0.55, 0.78, 0.98, pose.sweat))
            head.fill(PetDraw.ellipse(CGPoint(x: c.x - 1.5, y: c.y + 1), 1.2, 1.8), PetRGB(1, 1, 1, 0.8 * pose.sweat))
        }
        if pose.tears > 0.02 {
            PetDraw.mirrored(head) { c, _ in
                let x = fig.eyeX + 2, y = fig.eyeY + fig.eyeH * 0.55
                let fall = CGFloat((t * 0.4).truncatingRemainder(dividingBy: 1)) * 5 * CGFloat(pose.tears)
                c.fill(PetDraw.ellipse(CGPoint(x: x, y: y + 2 + fall), 2.4, 3.2), PetRGB(0.62, 0.84, 1.0, 0.95 * pose.tears))
            }
        }
        if badge {
            // Badges keep only the one sign that carries the most, drawn big and close.
            if pose.zzz > 0.3 { letter("z", head, at: CGPoint(x: fig.headRX * 0.9, y: -fig.headRY * 0.95), size: 16, color: ink.alpha(0.8)) }
            if pose.steam > 0.3 {
                PetDraw.mirrored(head) { c, _ in
                    c.fill(PetDraw.ellipse(CGPoint(x: fig.headRX + 3, y: -fig.headRY * 0.55), 5, 4), PetRGB(0.97, 0.97, 0.99, 0.95))
                    c.fill(PetDraw.ellipse(CGPoint(x: fig.headRX + 8, y: -fig.headRY * 0.72), 3.5, 3), PetRGB(0.97, 0.97, 0.99, 0.8))
                }
            }
            if pose.sparkles > 0.3 {
                sparkle(head, at: CGPoint(x: fig.headRX * 0.95, y: -fig.headRY * 0.85), size: 5, color: PetRGB(1.0, 0.78, 0.25))
                sparkle(head, at: CGPoint(x: -fig.headRX * 0.9, y: -fig.headRY * 0.6), size: 3.5, color: PetRGB(1.0, 0.78, 0.25))
            }
            if pose.hearts > 0.3 { heart(head, at: CGPoint(x: fig.headRX * 0.92, y: -fig.headRY * 0.82), size: 8, color: PetRGB(0.98, 0.42, 0.50)) }
            if pose.question > 0.3 { letter("?", head, at: CGPoint(x: fig.headRX * 0.95, y: -fig.headRY * 0.9), size: 18, color: ink.alpha(0.85)) }
            if pose.exclaim > 0.3 { letter("!", head, at: CGPoint(x: fig.headRX * 0.95, y: -fig.headRY * 0.9), size: 19, color: ink.alpha(0.85)) }
            return
        }
        // Everything else floats above the head, in the body's space (it doesn't tilt with the head).
        let top = CGPoint(x: fig.headCenter.x, y: fig.headCenter.y - fig.headRY + CGFloat(pose.headBob))
        if pose.bubble > 0.02 {
            // Bubbles leave the mouth, grow a little and drift up and to one side.
            let mouth = CGPoint(x: fig.headCenter.x + 4, y: fig.headCenter.y + fig.mouthY + CGFloat(pose.headBob))
            for i in 0..<3 {
                let ph = (t * 0.42 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let a = pose.bubble * min(1, ph * 6) * (1 - ph * ph)
                let r = 4 + CGFloat(ph) * 8 + CGFloat(i) * 1.5
                let pt = CGPoint(x: mouth.x + 8 + CGFloat(ph) * 34 + CGFloat(sin(ph * 8 + Double(i))) * 5, y: mouth.y - CGFloat(ph) * 82)
                bubble(body, at: pt, radius: r, alpha: a)
            }
        }
        if pose.zzz > 0.02 {
            for i in 0..<3 {
                let ph = (t * 0.28 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let a = pose.zzz * sin(ph * .pi)
                let pt = CGPoint(x: top.x + 30 + CGFloat(ph) * 18, y: top.y + 6 - CGFloat(ph) * 30)
                letter("z", body, at: pt, size: 9 + CGFloat(ph) * 8, color: ink.alpha(0.7 * a))
            }
        }
        if pose.notes > 0.02 {
            for i in 0..<2 {
                let ph = (t * 0.33 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let a = pose.notes * sin(ph * .pi)
                let side: CGFloat = i == 0 ? 1 : -1
                let pt = CGPoint(x: top.x + side * (34 + CGFloat(ph) * 10) + CGFloat(sin(ph * 9)) * 3, y: top.y + 18 - CGFloat(ph) * 30)
                note(body, at: pt, color: p.palette.prop.mix(ink, 0.3).alpha(a))
            }
        }
        if pose.hearts > 0.02 {
            for i in 0..<2 {
                let ph = (t * 0.36 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let a = pose.hearts * sin(ph * .pi)
                let pt = CGPoint(x: top.x + (i == 0 ? 30 : -26) + CGFloat(sin(ph * 7 + Double(i))) * 3, y: top.y + 10 - CGFloat(ph) * 34)
                heart(body, at: pt, size: 7 + CGFloat(ph) * 3, color: PetRGB(0.98, 0.42, 0.50, a))
            }
        }
        if pose.sparkles > 0.02 {
            for i in 0..<4 {
                let ph = (t * 0.9 + Double(i) * 0.27).truncatingRemainder(dividingBy: 1)
                let a = pose.sparkles * sin(ph * .pi)
                let angle = Double(i) * 1.7 + 0.4
                let r = 50 + CGFloat(i % 2) * 12
                let pt = CGPoint(x: top.x + CGFloat(cos(angle)) * r, y: top.y + 26 + CGFloat(sin(angle)) * r * 0.7 - 20)
                sparkle(body, at: pt, size: 4 + CGFloat(sin(ph * .pi)) * 3.5, color: PetRGB(1.0, 0.80, 0.30, a))
            }
        }
        if pose.steam > 0.02 {
            PetDraw.mirrored(body, axis: 100) { c, _ in
                for i in 0..<2 {
                    let ph = (t * 1.1 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                    let a = pose.steam * sin(ph * .pi) * 0.9
                    let pt = CGPoint(x: top.x + fig.headRX + 4 + CGFloat(ph) * 12, y: top.y + 22 - CGFloat(ph) * 14)
                    c.fill(PetDraw.ellipse(pt, 4 + CGFloat(ph) * 4, 3.5 + CGFloat(ph) * 3), PetRGB(0.96, 0.96, 0.98, a))
                }
            }
        }
        if let sign = p.sign {
            // A small battery over its head: filling with a bolt when charging, nearly empty when low.
            let c = CGPoint(x: top.x - fig.headRX * 0.85, y: top.y - 2)
            let shell = Path(roundedRect: CGRect(x: c.x - 9, y: c.y - 5, width: 16, height: 10), cornerSize: CGSize(width: 2.5, height: 2.5))
            body.fill(shell, PetRGB(1, 1, 1, 0.92))
            body.stroke(shell, ink.alpha(0.55), width: 1.2)
            body.fill(Path(roundedRect: CGRect(x: c.x + 7.5, y: c.y - 2, width: 2, height: 4), cornerSize: CGSize(width: 1, height: 1)), ink.alpha(0.55))
            let level: CGFloat = sign == .charging ? 0.35 + 0.6 * CGFloat((t * 0.25).truncatingRemainder(dividingBy: 1)) : 0.18
            let fillColor = sign == .charging ? PetRGB(0.35, 0.78, 0.45) : PetRGB(0.95, 0.42, 0.36)
            body.fill(Path(roundedRect: CGRect(x: c.x - 7.5, y: c.y - 3.5, width: 13 * level, height: 7), cornerSize: CGSize(width: 1.5, height: 1.5)), fillColor)
            if sign == .charging {
                var bolt = Path()
                bolt.move(to: CGPoint(x: c.x, y: c.y - 4.5))
                bolt.addLine(to: CGPoint(x: c.x - 2.8, y: c.y + 0.6))
                bolt.addLine(to: CGPoint(x: c.x - 0.2, y: c.y + 0.6))
                bolt.addLine(to: CGPoint(x: c.x - 1.2, y: c.y + 4.5))
                bolt.addLine(to: CGPoint(x: c.x + 2.8, y: c.y - 0.8))
                bolt.addLine(to: CGPoint(x: c.x + 0.2, y: c.y - 0.8))
                bolt.closeSubpath()
                body.fill(bolt, ink.alpha(0.85))
            }
        }
        if pose.thought > 0.02 {
            // A daydream: two little puffs rising to a cloud with a small heart in it.
            let a = pose.thought
            let bob = CGFloat(sin(t * 1.3)) * 1.5
            let base = CGPoint(x: top.x + fig.headRX * 0.7, y: top.y + 4)
            let cloudC = CGPoint(x: base.x + 22, y: base.y - 26 + bob)
            let white = PetRGB(1, 1, 1, 0.95 * a)
            let edge = PetRGB(0.55, 0.52, 0.62, 0.55 * a)
            for (i, r) in [CGFloat(2.4), 3.6].enumerated() {
                let pt = CGPoint(x: base.x + CGFloat(i) * 7, y: base.y - CGFloat(i) * 8 + bob * 0.5)
                body.fill(PetDraw.ellipse(pt, r, r), white)
                body.stroke(PetDraw.ellipse(pt, r, r), edge, width: 1)
            }
            let cloud = PetDraw.fluffy(cloudC, 15, 10, bumps: 7, depth: 1.8)
            body.fill(cloud, white)
            body.stroke(cloud, edge, width: 1.1)
            heart(body, at: CGPoint(x: cloudC.x, y: cloudC.y + 0.5), size: 4.2, color: PetRGB(0.98, 0.52, 0.58, a))
        }
        if pose.question > 0.02 {
            letter("?", body, at: CGPoint(x: top.x + fig.headRX * 0.85, y: top.y - 4 - CGFloat(pose.question) * 4), size: 20, color: ink.alpha(0.75 * pose.question))
        }
        if pose.exclaim > 0.02 {
            letter("!", body, at: CGPoint(x: top.x + fig.headRX * 0.8, y: top.y - 6 - CGFloat(pose.exclaim) * 5), size: 22, color: ink.alpha(0.8 * pose.exclaim))
        }
    }

    static func letter(_ s: String, _ ctx: GraphicsContext, at p: CGPoint, size: CGFloat, color: PetRGB) {
        ctx.draw(Text(s).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundColor(color.color), at: p)
    }

    static func note(_ ctx: GraphicsContext, at p: CGPoint, color: PetRGB) {
        ctx.fill(PetDraw.ellipse(CGPoint(x: p.x, y: p.y + 6), 3.6, 2.8), color)
        var stem = Path()
        stem.move(to: CGPoint(x: p.x + 3.2, y: p.y + 6))
        stem.addLine(to: CGPoint(x: p.x + 3.2, y: p.y - 6))
        stem.addQuadCurve(to: CGPoint(x: p.x + 8, y: p.y - 1), control: CGPoint(x: p.x + 8, y: p.y - 5))
        ctx.stroke(stem, color, width: 1.8)
    }

    static func heart(_ ctx: GraphicsContext, at c: CGPoint, size s: CGFloat, color: PetRGB) {
        var h = Path()
        h.move(to: CGPoint(x: c.x, y: c.y + s * 0.8))
        h.addCurve(to: CGPoint(x: c.x - s, y: c.y - s * 0.2), control1: CGPoint(x: c.x - s * 0.5, y: c.y + s * 0.45), control2: CGPoint(x: c.x - s, y: c.y + s * 0.2))
        h.addArc(center: CGPoint(x: c.x - s * 0.5, y: c.y - s * 0.25), radius: s * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        h.addArc(center: CGPoint(x: c.x + s * 0.5, y: c.y - s * 0.25), radius: s * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        h.addCurve(to: CGPoint(x: c.x, y: c.y + s * 0.8), control1: CGPoint(x: c.x + s, y: c.y + s * 0.2), control2: CGPoint(x: c.x + s * 0.5, y: c.y + s * 0.45))
        ctx.fill(h, color)
    }

    /// A soap bubble: a thin tinted rim, a faint fill and a highlight.
    static func bubble(_ ctx: GraphicsContext, at c: CGPoint, radius r: CGFloat, alpha a: Double) {
        let circle = PetDraw.ellipse(c, r, r)
        ctx.fill(circle, PetRGB(0.75, 0.9, 1.0, 0.3 * a))
        ctx.stroke(circle, PetRGB(0.45, 0.66, 0.92, 0.95 * a), width: 1.5)
        ctx.fill(PetDraw.ellipse(CGPoint(x: c.x - r * 0.38, y: c.y - r * 0.38), r * 0.24, r * 0.16), PetRGB(1, 1, 1, 0.9 * a))
    }

    static func sparkle(_ ctx: GraphicsContext, at c: CGPoint, size s: CGFloat, color: PetRGB) {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - s * 1.6))
        p.addQuadCurve(to: CGPoint(x: c.x + s * 1.6, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s * 1.6), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x - s * 1.6, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s * 1.6), control: c)
        ctx.fill(p, color)
    }
}
