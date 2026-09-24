import SwiftUI
import WidgetKit

struct PetEntry: TimelineEntry {
    let date: Date
    let moment: PetWidgetMoment
}

/// Reads the App Group snapshot; never opens the store. Entries every half hour and at each
/// change in the pet's day, so the pet shifts and keeps its schedule without background work.
struct PetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, moment: PetWidgetMoment(snapshot: .placeholder, date: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : current
        completion(PetEntry(date: .now, moment: PetWidgetMoment(snapshot: snapshot, date: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        let moments = PetWidgetMoment.timeline(for: current, pettedAt: SharedStateStore.shared.pettedAt)
        completion(Timeline(entries: moments.map { PetEntry(date: $0.date, moment: $0) }, policy: .atEnd))
    }

    private var current: PetSnapshot {
        SharedStateStore.shared.snapshot ?? PetSnapshot(identity: .placeholder)
    }
}
