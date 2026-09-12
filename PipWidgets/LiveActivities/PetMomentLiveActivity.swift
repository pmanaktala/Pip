import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen banner and Dynamic Island for a pet moment.
struct PetMomentLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetMomentAttributes.self) { context in
            PetMomentBanner(identity: context.attributes.identity, state: context.state)
                .activityBackgroundTint(PipColor.sceneBottom.opacity(0.85))
                .activitySystemActionForegroundColor(PipColor.ink)
        } dynamicIsland: { context in
            let identity = context.attributes.identity
            let petState = PetStateResolver.resolve(mood: context.state.mood, intensity: context.state.intensity, identity: identity)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PetView(identity: identity, state: petState, showsShadow: false, framing: .face)
                        .frame(width: 56, height: 56)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.mood.symbolName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, height: 56)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message)
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                PetView(identity: identity, state: petState, showsShadow: false, framing: .face)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                Image(systemName: context.state.mood.symbolName)
                    .font(.caption)
            } minimal: {
                PetView(identity: identity, state: petState, showsShadow: false, framing: .face)
                    .frame(width: 22, height: 22)
            }
        }
    }
}

