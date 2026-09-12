import SwiftUI
import WidgetKit

struct PetEntry: TimelineEntry {
    let date: Date
    let snapshot: PetSnapshot
    /// True for placeholders and gallery previews.
    var isPreview = false

    var identity: PetIdentity { snapshot.identity }
    var state: PetMoodState { snapshot.state(at: date) }
}

/// Reads the App Group snapshot; never opens the store. Entries every hour so the pet
/// drifts (fades, sleeps at night) without any background work.
struct PetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, snapshot: .placeholder, isPreview: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        if context.isPreview {
            completion(PetEntry(date: .now, snapshot: .placeholder, isPreview: true))
        } else {
            completion(PetEntry(date: .now, snapshot: current))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        let snapshot = current
        let calendar = Calendar.current
        var entries = [PetEntry(date: .now, snapshot: snapshot)]
        var next = calendar.nextDate(after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
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
