import SwiftUI
import WidgetKit

/// The pet on the watch face: circular and corner show the face, rectangular adds what it is
/// doing, inline is one line. Same moments, poses and schedule as the phone's widgets.
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
        .description("Your pet, and what it’s up to, on your watch face.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct PetComplicationView: View {
    var entry: PetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        PetAccessoryView(moment: entry.moment, family: family)
    }
}

struct PetEntry: TimelineEntry {
    let date: Date
    let moment: PetWidgetMoment
}

struct PetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, moment: PetWidgetMoment(snapshot: .placeholder, date: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(PetEntry(date: .now, moment: PetWidgetMoment(snapshot: context.isPreview ? .placeholder : current, date: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        let moments = PetWidgetMoment.timeline(for: current, step: 5)
        completion(Timeline(entries: moments.map { PetEntry(date: $0.date, moment: $0) }, policy: .atEnd))
    }

    private var current: PetSnapshot {
        SharedStateStore.shared.snapshot ?? PetSnapshot(identity: .placeholder)
    }
}

#Preview("Circular", as: .accessoryCircular) {
    PetComplication()
} timeline: {
    PetEntry(date: .now, moment: PetWidgetMoment(snapshot: .placeholder, date: .now))
}
