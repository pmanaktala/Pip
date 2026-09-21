import AppIntents
import SwiftUI
import WidgetKit

/// Lock Screen / StandBy banner for a pet moment. The pet sits on a mood-coloured disc, the
/// message is the headline, a live timer keeps the card moving, and a wave button lets the
/// user poke back. Pose changes arrive as state updates and are animated by the system.
public struct PetMomentBanner: View {
    public var identity: PetIdentity
    public var state: PetMomentAttributes.ContentState

    public init(identity: PetIdentity, state: PetMomentAttributes.ContentState) {
        self.identity = identity
        self.state = state
    }

    private var color: Color { MoodColor.bold(state.mood) }
    private var sitting: Bool { state.kind == .company || state.kind == .breather || state.kind == .windDown }

    public var body: some View {
        let petState = state.petState(identity: identity)
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.14))
                Circle().strokeBorder(color.opacity(0.3), lineWidth: 1).padding(3)
                PetView(identity: identity, state: petState, showsShadow: false)
                    .padding(4)
                    .id(state.pose)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                if let accessory = petState.accessory, state.kind != .breather {
                    AccessoryOverlay(kind: accessory, time: Double(state.pose) * 1.3, palette: PetPalette.palette(for: identity.species))
                        .padding(4)
                }
            }
            .frame(width: 88, height: 88)
            .animation(.spring(duration: 0.5, bounce: 0.3), value: state.pose)

            VStack(alignment: .leading, spacing: 4) {
                Text(sitting ? "A LITTLE COMPANY" : "A LITTLE MOMENT")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Text(state.message)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .lineLimit(2)
                if sitting {
                    HStack(spacing: 4) {
                        Text("With you for")
                        Text(timerInterval: state.startedAt...state.endsAt, countsDown: false, showsHours: false)
                            .monospacedDigit()
                    }
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                } else {
                    Text(state.startedAt, style: .relative)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)

            Button(intent: WaveAtPetIntent()) {
                Image(systemName: "hand.wave.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MoodColor.onBold)
                    .frame(width: 44, height: 44)
                    .background(color, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Wave at \(identity.name)")
        }
        .padding(14)
        .widgetURL(URL(string: sitting ? "pip://sit" : "pip://home"))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(identity.name): \(state.message)")
    }
}
