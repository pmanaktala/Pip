import SwiftUI

/// A small piece of glass that drifts through the room: a soap bubble, a heart. It lives in the
/// same glass container as the screen's buttons, so when it floats up to one they flow into each
/// other like two drops of liquid, then part. (Apple keeps glass to controls; these are brief,
/// interactive moments you set off yourself, and there are only ever a handful.) Drops use the
/// same regular glass as the buttons: glass only flows together with glass of the same kind.
struct GlassDrop: Identifiable {
    enum Shape { case bubble, heart }
    var id: Int
    var center: CGPoint
    var size: CGFloat
    var shape: Shape
    var opacity: Double = 1
}

/// The floating glass buttons at the top right of a full-screen room, sized like toolbar buttons
/// (44 pt, 12 apart), together with any drops drifting through: one glass container for all of
/// them, so drops and buttons merge when they meet. Coordinates are the full screen's, top-left.
struct GlassChrome<Buttons: View>: View {
    /// The drops for a full-screen size (width, height including the safe areas).
    var drops: (CGSize) -> [GlassDrop] = { _ in [] }
    @ViewBuilder var buttons: Buttons

    var body: some View {
        // Read the safe area here, then let the glass run edge to edge in screen coordinates.
        GeometryReader { outer in
            let top = outer.safeAreaInsets.top
            let screen = CGSize(width: outer.size.width + outer.safeAreaInsets.leading + outer.safeAreaInsets.trailing,
                                height: outer.size.height + top + outer.safeAreaInsets.bottom)
            GlassEffectContainer(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    ForEach(drops(screen)) { drop in
                        dropView(drop)
                            .frame(width: drop.size, height: drop.size)
                            .position(drop.center)
                            .opacity(drop.opacity)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    HStack(spacing: 12) { buttons }
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.tint)
                        .buttonStyle(.plain)
                        .padding(.top, top + 4)
                        .padding(.trailing, 16)
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func dropView(_ drop: GlassDrop) -> some View {
        switch drop.shape {
        case .bubble:
            Color.clear.glassEffect(.regular, in: Circle())
        case .heart:
            Color.clear.glassEffect(.regular.tint(Color(red: 0.98, green: 0.45, blue: 0.55).opacity(0.6)), in: HeartShape())
        }
    }
}

/// One round glass button for `GlassChrome`.
struct GlassChromeButton: View {
    var systemImage: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.95))
        p.addCurve(to: CGPoint(x: x, y: y + h * 0.36), control1: CGPoint(x: x + w * 0.3, y: y + h * 0.78), control2: CGPoint(x: x, y: y + h * 0.6))
        p.addArc(center: CGPoint(x: x + w * 0.25, y: y + h * 0.3), radius: w * 0.25, startAngle: .degrees(160), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: x + w * 0.75, y: y + h * 0.3), radius: w * 0.25, startAngle: .degrees(180), endAngle: .degrees(20), clockwise: false)
        p.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.95), control1: CGPoint(x: x + w, y: y + h * 0.6), control2: CGPoint(x: x + w * 0.7, y: y + h * 0.78))
        p.closeSubpath()
        return p
    }
}
