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
        // A calm, direct look: no arc-eyes, no head tilt, beak just open, flippers resting.
        state.rig.eyeArc = 0
        state.rig.mouthOpen = 0.2
        state.rig.mouthCurve = 0.7
        state.rig.armRaise = 0
        state.rig.blush = 0.5
        state.rig.gazeX = 0
        state.rig.gazeY = 0
        state.rig.tilt = 0
        state.rig.squash = 1
        return ZStack {
            if includesBackground {
                LinearGradient(colors: [Color(red: 0.47, green: 0.82, blue: 0.74), Color(red: 0.17, green: 0.53, blue: 0.50)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.white.opacity(0.22), .white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.45), startRadius: 0, endRadius: 600)
            }
            // Head-and-shoulders crop: the body runs off the bottom edge on purpose.
            PetView(identity: identity, state: state, time: nil, showsShadow: false, framing: .icon)
                .frame(width: 1024, height: 1024)
                .shadow(color: .black.opacity(includesBackground ? 0.2 : 0), radius: 36, y: 28)
        }
        .frame(width: 1024, height: 1024)
    }
}

#Preview {
    AppIconView()
        .clipShape(RoundedRectangle(cornerRadius: 230, style: .continuous))
        .scaleEffect(0.3)
}
