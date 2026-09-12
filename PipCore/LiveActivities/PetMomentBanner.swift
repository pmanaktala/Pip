import SwiftUI
import WidgetKit

/// Lock Screen banner for a pet moment. Shared so the app can preview it.
public struct PetMomentBanner: View {
    public var identity: PetIdentity
    public var state: PetMomentAttributes.ContentState

    public init(identity: PetIdentity, state: PetMomentAttributes.ContentState) {
        self.identity = identity
        self.state = state
    }

    public var body: some View {
        let petState = PetStateResolver.resolve(mood: state.mood, intensity: state.intensity, identity: identity)
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(PetPalette.ambient(for: state.mood).opacity(0.3))
                PetView(identity: identity, state: petState, showsShadow: false)
                    .padding(2)
                if let accessory = petState.accessory, state.kind != .breather {
                    AccessoryOverlay(kind: accessory, time: nil, palette: PetPalette.palette(for: identity.species))
                }
            }
            .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(state.message)
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(2)
                if state.kind == .company || state.kind == .breather {
                    Text("Tap to sit together")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .widgetURL(URL(string: state.kind == .company || state.kind == .breather ? "pip://sit" : "pip://home"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(identity.name): \(state.message)")
    }
}
