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
                    LinearGradient(colors: [PipColor.sceneTop, PipColor.sceneBottom], startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Pip")
        .description("Your pet, right here on your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
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
