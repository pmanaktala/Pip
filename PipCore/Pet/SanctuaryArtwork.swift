import SwiftUI

/// Resolution-independent scenery shared by the living scene, widgets and icon.
/// A small paper-cut world; the character remains the only continuously animated layer.
public struct SanctuaryArtwork: View {
    public var mood: Mood
    @Environment(\.colorScheme) private var scheme

    public init(mood: Mood) { self.mood = mood }

    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let dark = scheme == .dark
            let accent = MoodColor.bold(mood)
            ZStack {
                RoundedRectangle(cornerRadius: size.width * 0.46)
                    .fill(LinearGradient(colors: [accent.opacity(dark ? 0.24 : 0.22), PipColor.sceneBottom], startPoint: .top, endPoint: .bottom))
                // An inset arch catches the light like the edge of a ceramic alcove.
                RoundedRectangle(cornerRadius: size.width * 0.46)
                    .strokeBorder(.white.opacity(dark ? 0.09 : 0.65), lineWidth: 1.5)
                    .padding(8)
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(dark ? 0.7 : 0.95), Color(red: 1, green: 0.88, blue: 0.63)], center: .topLeading, startRadius: 0, endRadius: size.width * 0.17))
                    .frame(width: size.width * 0.19, height: size.width * 0.19)
                    .position(x: size.width * 0.73, y: size.height * 0.25)
                Canvas { context, canvas in
                    let w = canvas.width, h = canvas.height
                    for layer in 0..<3 {
                        let n = CGFloat(layer)
                        var hill = Path()
                        hill.move(to: CGPoint(x: 0, y: h * (0.64 + n * 0.09)))
                        hill.addCurve(to: CGPoint(x: w, y: h * (0.66 + n * 0.08)),
                                      control1: CGPoint(x: w * 0.35, y: h * (0.40 + n * 0.18)),
                                      control2: CGPoint(x: w * 0.64, y: h * (0.89 - n * 0.06)))
                        hill.addLine(to: CGPoint(x: w, y: h))
                        hill.addLine(to: CGPoint(x: 0, y: h))
                        hill.closeSubpath()
                        let colors = [accent.opacity(dark ? 0.13 : 0.16), PipColor.sceneFloor.opacity(0.65), PipColor.sceneBottom]
                        context.fill(hill, with: .color(colors[layer]))
                    }
                    // Quiet botanical silhouettes ground the landscape at either side.
                    for side in [0, 1] {
                        let x = w * (side == 0 ? 0.13 : 0.88)
                        let base = h * 0.90
                        let direction: CGFloat = side == 0 ? 1 : -1
                        var stem = Path()
                        stem.move(to: CGPoint(x: x, y: base))
                        stem.addQuadCurve(to: CGPoint(x: x + direction * w * 0.035, y: base - h * 0.22), control: CGPoint(x: x - direction * w * 0.03, y: base - h * 0.12))
                        context.stroke(stem, with: .color(accent.opacity(0.45)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        for leaf in 0..<4 {
                            let y = base - CGFloat(leaf + 1) * h * 0.042
                            let d: CGFloat = leaf.isMultiple(of: 2) ? direction : -direction
                            var shape = Path()
                            shape.move(to: CGPoint(x: x, y: y))
                            shape.addQuadCurve(to: CGPoint(x: x + d * w * 0.09, y: y - h * 0.045), control: CGPoint(x: x + d * w * 0.09, y: y + h * 0.015))
                            shape.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + d * w * 0.025, y: y - h * 0.065))
                            context.fill(shape, with: .color(accent.opacity(dark ? 0.3 : 0.26)))
                        }
                    }
                    for i in 0..<14 {
                        let x = PetAnimator.hash01(Double(i) * 7.1) * w
                        let y = PetAnimator.hash01(Double(i) * 3.7 + 9) * h * 0.6
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.6)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: size.width * 0.46))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
