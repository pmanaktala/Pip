import SwiftUI

/// The app icon: Pebble, drawn from the same artwork as the pet. Rendered to PNG by
/// `AppIconRenderTests` and used as the fallback for the layered Icon Composer icon.
public struct AppIconView: View {
    /// When false, only the pet is drawn on a transparent background (Icon Composer layer).
    public var includesBackground: Bool

    public init(includesBackground: Bool = true) {
        self.includesBackground = includesBackground
    }

    public var body: some View {
        let identity = PetIdentity(species: .penguin)
        var state = PetStateResolver.resolve(mood: .happy, intensity: .slight, identity: identity)
        state.rig.eyeArc = 0
        state.rig.mouthOpen = 0.35
        state.rig.mouthCurve = 0.8
        state.rig.tailLift = 0.75
        state.rig.blush = 0.6
        state.rig.gazeX = 0
        state.rig.gazeY = 0
        state.rig.tilt = 0
        return ZStack {
            if includesBackground {
                LinearGradient(colors: [Color(red: 0.56, green: 0.83, blue: 0.76), Color(red: 0.24, green: 0.60, blue: 0.53)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.white.opacity(0.28), .white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.62), startRadius: 0, endRadius: 560)
            }
            PetView(identity: identity, state: state, time: nil, showsShadow: false, framing: .icon)
                .padding(-40)
                .shadow(color: .black.opacity(includesBackground ? 0.18 : 0), radius: 30, y: 24)
        }
        .frame(width: 1024, height: 1024)
    }
}

#Preview {
    AppIconView()
        .clipShape(RoundedRectangle(cornerRadius: 230, style: .continuous))
        .scaleEffect(0.3)
}
