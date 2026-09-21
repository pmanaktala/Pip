import SwiftUI
import WidgetKit

/// The pet on the watch face. Circular and corner: the face; rectangular: face, name and how
/// they feel; inline: one line. Reads the watch's App Group snapshot that the watch app keeps
/// fresh; never opens the store.
@main
struct PipWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PetComplication()
    }
}

struct PetComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.pmanaktala.Pip.watch.pet", provider: PetTimelineProvider()) { entry in
            PetComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Pip")
        .description("Your pet, and how they feel, on your watch face.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct PetComplicationView: View {
    var entry: PetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCorner:
            // The face, with the mood colour as the corner gauge so the watch face carries a hint.
            PetView(identity: entry.identity, state: entry.state, showsShadow: false, framing: .badge)
                .padding(2)
                .widgetLabel {
                    Text(entry.state.mood.displayName)
                        .foregroundStyle(MoodColor.bold(entry.state.mood))
                }
                .accessibilityLabel("\(entry.identity.name) \(entry.state.mood.petDescription).")
        default:
            PetLockScreenView(snapshot: entry.snapshot, date: entry.date, family: family)
        }
    }
}

struct PetEntry: TimelineEntry {
    let date: Date
    let snapshot: PetSnapshot
    var identity: PetIdentity { snapshot.identity }
    var state: PetMoodState { snapshot.state(at: date) }
}

/// Hourly entries so the pet drifts through the day without background work.
struct PetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(PetEntry(date: .now, snapshot: context.isPreview ? .placeholder : current))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        let snapshot = current
        var entries = [PetEntry(date: .now, snapshot: snapshot)]
        var next = Calendar.current.nextDate(after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
        for _ in 0..<8 {
            entries.append(PetEntry(date: next, snapshot: snapshot))
            next = next.addingTimeInterval(3600)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private var current: PetSnapshot {
        SharedStateStore.shared.snapshot ?? PetSnapshot(identity: .placeholder)
    }
}

#Preview("Circular", as: .accessoryCircular) {
    PetComplication()
} timeline: {
    PetEntry(date: .now, snapshot: PetSnapshot(identity: PetIdentity(species: .penguin), mood: .happy, intensity: .moderate, loggedAt: .now))
}

#Preview("Rectangular", as: .accessoryRectangular) {
    PetComplication()
} timeline: {
    PetEntry(date: .now, snapshot: PetSnapshot(identity: PetIdentity(species: .cat), mood: .calm, intensity: .moderate, loggedAt: .now))
}
