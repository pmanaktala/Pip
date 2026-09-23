import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Home Screen

/// Small: the pet in its room. Medium: the pet, what it is doing, four faces. Large: all eight.
struct PetHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.pmanaktala.Pip.pet", provider: PetTimelineProvider()) { entry in
            PetHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetRoom(moment: entry.moment)
                }
        }
        .configurationDisplayName("Pip")
        .description("Your pet, getting on with its day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// The widget's ground: the pet's room, lit for the entry's time and tinted by a fresh mood.
struct WidgetRoom: View {
    var moment: PetWidgetMoment
    @Environment(\.widgetFamily) private var family

    var body: some View {
        PetRoom(mood: moment.freshMood, date: moment.date, horizon: PetHomeWidgetView.floor(for: family), showsFoliage: family == .systemLarge)
    }
}

struct PetHomeWidgetEntryView: View {
    var entry: PetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.showsWidgetContainerBackground) private var showsBackground

    var body: some View {
        PetHomeWidgetView(moment: entry.moment, family: family, showsBackground: showsBackground)
    }
}

// MARK: - Lock Screen

struct PetLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.pmanaktala.Pip.lockscreen", provider: PetTimelineProvider()) { entry in
            PetAccessoryView(moment: entry.moment, family: .accessoryCircular)
                .modifier(AccessoryFamily(moment: entry.moment))
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Pip")
        .description("Your pet’s face on the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct AccessoryFamily: ViewModifier {
    var moment: PetWidgetMoment
    @Environment(\.widgetFamily) private var family
    func body(content: Content) -> some View {
        PetAccessoryView(moment: moment, family: family)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    PetHomeWidget()
} timeline: {
    PetEntry(date: .now, moment: PetWidgetMoment(snapshot: PetSnapshot(identity: PetIdentity(species: .cat), mood: .happy, intensity: .moderate, loggedAt: .now), date: .now))
}

#Preview("Medium", as: .systemMedium) {
    PetHomeWidget()
} timeline: {
    PetEntry(date: .now, moment: PetWidgetMoment(snapshot: PetSnapshot(identity: PetIdentity(species: .dog), mood: .calm, intensity: .moderate, loggedAt: .now), date: .now))
}

#Preview("Large", as: .systemLarge) {
    PetHomeWidget()
} timeline: {
    PetEntry(date: .now, moment: PetWidgetMoment(snapshot: PetSnapshot(identity: PetIdentity(species: .penguin)), date: .now))
}
