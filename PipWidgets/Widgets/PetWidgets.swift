import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Home Screen

/// Small: pet presence. Medium: scene + quick moods. Large: scene + today's progression.
struct PetHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.pmanaktala.Pip.pet", provider: PetTimelineProvider()) { entry in
            PetHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetCanvas(snapshot: entry.snapshot, date: entry.date)
                }
        }
        .configurationDisplayName("Pip")
        .description("Your pet, right here on your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// The widget's ground: the pet's room, lit for the entry's time of day and tinted by a fresh mood.
struct WidgetCanvas: View {
    var snapshot: PetSnapshot
    var date: Date
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let mood: Mood? = {
            guard let m = snapshot.mood, let at = snapshot.loggedAt, date.timeIntervalSince(at) < PetSnapshot.freshness else { return nil }
            return m
        }()
        // Horizon where each family's pet scene puts the feet (see PetHomeWidgetView).
        let horizon: CGFloat = family == .systemMedium ? 0.82 : 0.77
        PetRoom(mood: mood, date: date, horizon: horizon, showsFoliage: family == .systemLarge)
    }
}

struct PetHomeWidgetEntryView: View {
    var entry: PetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.showsWidgetContainerBackground) private var showsBackground

    var body: some View {
        PetHomeWidgetView(snapshot: entry.snapshot, date: entry.date, family: family, showsBackground: showsBackground)
    }
}

// MARK: - Lock Screen

struct PetLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.pmanaktala.Pip.lockscreen", provider: PetTimelineProvider()) { entry in
            PetLockScreenEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Pip")
        .description("A tiny pet face on your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct PetLockScreenEntryView: View {
    var entry: PetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        PetLockScreenView(snapshot: entry.snapshot, date: entry.date, family: family)
    }
}

// MARK: - Previews
#Preview("Small", as: .systemSmall) {
    PetHomeWidget()
} timeline: {
    PetEntry(date: .now, snapshot: PetSnapshot(identity: PetIdentity(species: .cat), mood: .happy, intensity: .moderate, loggedAt: .now))
    PetEntry(date: .now, snapshot: PetSnapshot(identity: PetIdentity(species: .penguin), mood: .tired, intensity: .strong, loggedAt: .now))
}

#Preview("Medium", as: .systemMedium) {
    PetHomeWidget()
} timeline: {
    PetEntry(date: .now, snapshot: PetSnapshot(identity: PetIdentity(species: .dog), mood: .calm, intensity: .moderate, loggedAt: .now))
}

#Preview("Large", as: .systemLarge) {
    PetHomeWidget()
} timeline: {
    PetEntry(date: .now, snapshot: PetSnapshot(identity: PetIdentity(species: .redPanda), mood: .stressed, intensity: .moderate, loggedAt: .now, today: [
        MoodStamp(mood: .tired, intensity: .moderate, time: .now.addingTimeInterval(-30000)),
        MoodStamp(mood: .happy, intensity: .strong, time: .now.addingTimeInterval(-12000)),
        MoodStamp(mood: .stressed, intensity: .moderate, time: .now),
    ]))
}

#Preview("Circular", as: .accessoryCircular) {
    PetLockScreenWidget()
} timeline: {
    PetEntry(date: .now, snapshot: .placeholder)
}
