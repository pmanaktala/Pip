import ActivityKit
import SwiftUI
import WidgetKit

/// The pet keeping you company: Lock Screen, Dynamic Island and (small family) the watch.
struct PetCompanyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetCompanyAttributes.self) { context in
            LockScreenCompany(context: context)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.92))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            let identity = context.attributes.identity
            let state = context.state
            let stale = context.isStale
            let (pose, _) = PetCompanyLook.pose(state, species: identity.species, stale: stale)
            let color = MoodColor.bold(state.mood)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PetPoseView(species: identity.species, pose: pose, framing: .face, showsShadow: false)
                        .frame(width: 58, height: 58)
                        .animation(.smooth(duration: 0.9), value: state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PetButton(identity: identity, mood: state.mood, petted: state.petted)
                        .frame(width: 58, height: 58)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(identity.name)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(PetCompanyLook.line(state, name: identity.name, stale: stale))
                            .font(.system(.callout, design: .rounded, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                PetPoseView(species: identity.species, pose: pose, framing: .badge, showsShadow: false)
                    .frame(width: 26, height: 26)
                    .animation(.smooth(duration: 0.8), value: state)
            } compactTrailing: {
                Image(systemName: state.petted ? "heart.fill" : (stale ? "moon.zzz.fill" : state.mood.symbolName))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                    .contentTransition(.symbolEffect(.replace))
            } minimal: {
                PetPoseView(species: identity.species, pose: pose, framing: .badge, showsShadow: false)
                    .frame(width: 24, height: 24)
            }
            .widgetURL(URL(string: "pip://home"))
            .keylineTint(color)
        }
        .supplementalActivityFamilies([.small])
    }
}

private struct LockScreenCompany: View {
    var context: ActivityViewContext<PetCompanyAttributes>
    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small:
            PetCompanySmall(identity: context.attributes.identity, state: context.state, stale: context.isStale)
        default:
            PetCompanyBanner(identity: context.attributes.identity, state: context.state, stale: context.isStale)
        }
    }
}
