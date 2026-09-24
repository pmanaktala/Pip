#if DEBUG
import SwiftUI
import WidgetKit

/// Developer gallery: widget and Live Activity content at their real sizes.
struct WidgetGalleryView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let moment = PetWidgetMoment(snapshot: appState.snapshot, date: .now)
        let company = PetCompanyAttributes.ContentState(mood: appState.latestEntry?.mood ?? .sad, intensity: .moderate,
                                                        line: PetCompanyWords.line(for: appState.latestEntry?.mood ?? .sad, name: appState.identity.name, seed: 0),
                                                        startedAt: .now.addingTimeInterval(-600))
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    PetAccessoryView(moment: moment, family: .accessoryCircular)
                        .frame(width: 72, height: 72)
                    PetAccessoryView(moment: moment, family: .accessoryRectangular)
                        .frame(width: 172, height: 72)
                }
                .padding(12)
                .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
                .environment(\.colorScheme, .dark)
                // The Dynamic Island's compact and expanded layouts, drawn with the same views.
                let look = PetCompanyLook.pose(company, species: appState.identity.species, stale: false).0
                HStack(spacing: 0) {
                    PetPoseView(species: appState.identity.species, pose: look, framing: .badge, showsShadow: false)
                        .frame(width: 26, height: 26)
                    Spacer()
                    Image(systemName: company.mood.symbolName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MoodColor.bold(company.mood))
                }
                .padding(.horizontal, 12)
                .frame(width: 250, height: 37)
                .background(.black, in: Capsule())
                HStack(spacing: 8) {
                    PetPoseView(species: appState.identity.species, pose: look, framing: .face, showsShadow: false)
                        .frame(width: 58, height: 58)
                    VStack(spacing: 2) {
                        Text(appState.identity.name).font(.system(.caption, design: .rounded, weight: .bold)).foregroundStyle(.secondary)
                        Text(company.line).font(.system(.callout, design: .rounded, weight: .bold)).multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    Circle().fill(MoodColor.bold(company.mood).opacity(0.25)).frame(width: 44, height: 44)
                        .overlay(Image(systemName: "pawprint.fill").foregroundStyle(MoodColor.bold(company.mood)))
                }
                .foregroundStyle(.white)
                .padding(16)
                .frame(width: 370)
                .background(.black, in: RoundedRectangle(cornerRadius: 44, style: .continuous))
                .environment(\.colorScheme, .dark)
                ForEach([false, true], id: \.self) { stale in
                    PetCompanyBanner(identity: appState.identity, state: company, stale: stale)
                        .frame(width: 364)
                        .background(Color(.systemBackground).opacity(0.92), in: RoundedRectangle(cornerRadius: 24))
                }
                HStack(spacing: 16) {
                    widget(.systemSmall, moment, width: 158, height: 158)
                    widget(.systemSmall, PetWidgetMoment(snapshot: appState.snapshot, date: .now, hold: 1), width: 158, height: 158)
                }
                widget(.systemMedium, moment, width: 338, height: 158)
                widget(.systemLarge, moment, width: 338, height: 354)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Widgets")
    }

    private func widget(_ family: WidgetFamily, _ moment: PetWidgetMoment, width: CGFloat, height: CGFloat) -> some View {
        PetHomeWidgetView(moment: moment, family: family)
            .frame(width: width, height: height)
            .background(PetRoom(mood: moment.freshMood, date: moment.date, horizon: PetHomeWidgetView.floor(for: family), showsFoliage: family == .systemLarge))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
#endif
