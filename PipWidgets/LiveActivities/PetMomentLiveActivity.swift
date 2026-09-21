import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Lock Screen banner and Dynamic Island for a pet moment.
struct PetMomentLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetMomentAttributes.self) { context in
            PetMomentBanner(identity: context.attributes.identity, state: context.state)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.9))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            let identity = context.attributes.identity
            let state = context.state
            let petState = state.petState(identity: identity)
            let color = MoodColor.bold(state.mood)
            let sitting = state.kind == .company || state.kind == .breather || state.kind == .windDown
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ZStack {
                        Circle().fill(color.opacity(0.28))
                        PetView(identity: identity, state: petState, showsShadow: false, framing: .face)
                            .padding(3)
                            .id(state.pose)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                    .frame(width: 60, height: 60)
                    .animation(.spring(duration: 0.5, bounce: 0.3), value: state.pose)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: WaveAtPetIntent()) {
                        Image(systemName: "hand.wave.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MoodColor.onBold)
                            .frame(width: 44, height: 44)
                            .background(color, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Wave at \(identity.name)")
                    .frame(width: 60, height: 60)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(state.message)
                            .font(.system(.callout, design: .rounded, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        if sitting {
                            Text(timerInterval: state.startedAt...state.endsAt, countsDown: false, showsHours: false)
                                .monospacedDigit()
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                PetView(identity: identity, state: petState, showsShadow: false, framing: .badge)
                    .frame(width: 24, height: 24)
                    .id(state.pose)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(duration: 0.4, bounce: 0.3), value: state.pose)
            } compactTrailing: {
                if sitting {
                    Text(timerInterval: state.startedAt...state.endsAt, countsDown: false, showsHours: false)
                        .monospacedDigit()
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                        .frame(maxWidth: 44)
                } else {
                    Image(systemName: state.mood.symbolName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                }
            } minimal: {
                PetView(identity: identity, state: petState, showsShadow: false, framing: .badge)
                    .frame(width: 22, height: 22)
            }
            .widgetURL(URL(string: sitting ? "pip://sit" : "pip://home"))
            .keylineTint(color)
        }
    }
}
