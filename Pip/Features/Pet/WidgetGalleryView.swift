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
        .background(Color(white: 0.9))
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
