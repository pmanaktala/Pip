import SwiftUI

/// The season in the room: snow in winter, leaves drifting in autumn, blossom in spring,
/// fireflies on summer evenings, and confetti for a celebration. Quiet and sparse; it never
/// competes with the pet. Still on widgets (`live: false`), drifting in the app.
public struct PetSeasonLayer: View {
    public var season: PetSeason
    public var confetti: Bool
    public var live: Bool
    public var date: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(season: PetSeason, confetti: Bool = false, live: Bool = true, date: Date = .now) {
        self.season = season
        self.confetti = confetti
        self.live = live
        self.date = date
    }

    public var body: some View {
        if live && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                canvas(t: context.date.timeIntervalSince1970)
            }
        } else {
            canvas(t: 1000)
        }
    }

    private func canvas(t: Double) -> some View {
        let hour = Calendar.current.component(.hour, from: date)
        return Canvas { ctx, size in
            if confetti { Self.confetti(ctx, size, t) }
            switch season {
            case .winter: Self.snow(ctx, size, t)
            case .autumn: Self.leaves(ctx, size, t)
            case .spring: Self.petals(ctx, size, t)
            case .summer: if hour >= 19 || hour < 5 { Self.fireflies(ctx, size, t) }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A particle's position: falls through the height over `period` seconds, drifting sideways.
    private static func fall(_ i: Int, _ size: CGSize, _ t: Double, period: Double, sway: Double) -> (CGPoint, Double) {
        let seed = Double(i) * 7.31
        let phase = (t / period + PetMath.hash01(seed)).truncatingRemainder(dividingBy: 1)
        let x = PetMath.hash01(seed + 1) * size.width + sin(t * 0.6 + seed) * sway
        let y = -20 + phase * (size.height + 40)
        return (CGPoint(x: x, y: y), phase)
    }

    static func snow(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        for i in 0..<34 {
            let (p, _) = fall(i, size, t, period: 14 + PetMath.hash01(Double(i)) * 8, sway: 14)
            let r = 1.4 + PetMath.hash01(Double(i) * 3.3) * 2.2
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.85)))
        }
    }

    static func leaves(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let colors = [Color(red: 0.93, green: 0.55, blue: 0.25), Color(red: 0.85, green: 0.36, blue: 0.24), Color(red: 0.80, green: 0.62, blue: 0.30)]
        for i in 0..<10 {
            let (p, phase) = fall(i, size, t, period: 16 + PetMath.hash01(Double(i)) * 8, sway: 30)
            var leaf = ctx
            leaf.translateBy(x: p.x, y: p.y)
            leaf.rotate(by: .radians(sin(t * 1.3 + Double(i)) * 0.9 + phase * 3))
            var shape = Path()
            shape.move(to: CGPoint(x: -7, y: 0))
            shape.addQuadCurve(to: CGPoint(x: 7, y: 0), control: CGPoint(x: 0, y: -6))
            shape.addQuadCurve(to: CGPoint(x: -7, y: 0), control: CGPoint(x: 0, y: 6))
            leaf.fill(shape, with: .color(colors[i % colors.count].opacity(0.8)))
        }
    }

    static func petals(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        for i in 0..<14 {
            let (p, phase) = fall(i, size, t, period: 15 + PetMath.hash01(Double(i)) * 8, sway: 26)
            var petal = ctx
            petal.translateBy(x: p.x, y: p.y)
            petal.rotate(by: .radians(phase * 5 + Double(i)))
            petal.fill(Path(ellipseIn: CGRect(x: -4, y: -2.6, width: 8, height: 5.2)), with: .color(Color(red: 1.0, green: 0.78, blue: 0.84).opacity(0.85)))
        }
    }

    static func fireflies(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        for i in 0..<12 {
            let seed = Double(i) * 4.7
            let x = PetMath.hash01(seed) * size.width + sin(t * 0.4 + seed) * 18
            let y = size.height * (0.45 + PetMath.hash01(seed + 2) * 0.4) + cos(t * 0.5 + seed) * 12
            let glow = 0.4 + 0.6 * max(0, sin(t * 1.4 + seed))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 7, y: y - 7, width: 14, height: 14)), with: .color(Color(red: 1, green: 0.92, blue: 0.5).opacity(0.18 * glow)))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(Color(red: 1, green: 0.95, blue: 0.6).opacity(0.9 * glow)))
        }
    }

    static func confetti(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let colors: [Color] = [.pink, .orange, .yellow, .mint, .cyan, .purple]
        for i in 0..<28 {
            let (p, phase) = fall(i, size, t, period: 7 + PetMath.hash01(Double(i)) * 5, sway: 16)
            var bit = ctx
            bit.translateBy(x: p.x, y: p.y)
            bit.rotate(by: .radians(phase * 9 + Double(i)))
            bit.fill(Path(CGRect(x: -3, y: -1.5, width: 6, height: 3)), with: .color(colors[i % colors.count].opacity(0.85)))
        }
    }
}
