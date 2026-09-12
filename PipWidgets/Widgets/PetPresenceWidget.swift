import SwiftUI
import WidgetKit

struct PetEntry: TimelineEntry {
    let date: Date
    let identity: PetIdentity
    let state: PetMoodState
}

struct PetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, identity: .placeholder, state: PetStateResolver.resting(identity: .placeholder))
    }
    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .never))
    }
}

struct PetPresenceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.pmanaktala.Pip.presence", provider: PetTimelineProvider()) { entry in
            PetView(identity: entry.identity, state: entry.state)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Pip")
        .description("Your pet, right here.")
        .supportedFamilies([.systemSmall])
    }
}
