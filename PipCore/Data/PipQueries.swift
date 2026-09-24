import Foundation
import SwiftData

/// Small, focused fetch helpers. Not a repository layer — just the queries the app actually needs.
public enum PipQueries {

    /// The single pet profile, reconciling duplicates that can appear after multi-device CloudKit setup.
    /// Keeps the most recently modified profile (ties broken by id so every device converges).
    @discardableResult
    public static func petProfile(in context: ModelContext, createIfMissing: Bool = true) -> PetProfile? {
        let descriptor = FetchDescriptor<PetProfile>(sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)])
        let profiles = (try? context.fetch(descriptor)) ?? []
        if profiles.count > 1 {
            let winner = profiles.max { a, b in
                if a.modifiedAt != b.modifiedAt { return a.modifiedAt < b.modifiedAt }
                return a.id.uuidString < b.id.uuidString
            }!
            for p in profiles where p !== winner { context.delete(p) }
            try? context.save()
            return winner
        }
        if let first = profiles.first { return first }
        guard createIfMissing else { return nil }
        let profile = PetProfile(identity: .placeholder)
        context.insert(profile)
        try? context.save()
        return profile
    }

    public static func latestEntry(in context: ModelContext) -> MoodEntry? {
        var d = FetchDescriptor<MoodEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    public static func entries(on day: Date, calendar: Calendar = .current, in context: ModelContext) -> [MoodEntry] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return entries(from: start, to: end, in: context)
    }

    public static func entries(from start: Date, to end: Date, in context: ModelContext) -> [MoodEntry] {
        let d = FetchDescriptor<MoodEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp)])
        return (try? context.fetch(d)) ?? []
    }

    public static func allEntries(in context: ModelContext) -> [MoodEntry] {
        let d = FetchDescriptor<MoodEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return (try? context.fetch(d)) ?? []
    }

    /// Entries that still need a Health write (or a rewrite after editing).
    public static func entriesNeedingHealthSync(since: Date?, in context: ModelContext) -> [MoodEntry] {
        let all = allEntries(in: context)
        return all.filter { entry in
            if let since, entry.createdAt < since { return false }
            return !entry.isHealthSyncCurrent
        }
    }

    public static func entry(id: UUID, in context: ModelContext) -> MoodEntry? {
        let d = FetchDescriptor<MoodEntry>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(d).first
    }

    /// Builds the widget snapshot from the store.
    public static func buildSnapshot(in context: ModelContext, now: Date = .now) -> PetSnapshot {
        let profile = petProfile(in: context)
        let identity = profile?.identity ?? .placeholder
        let latest = latestEntry(in: context)
        let today = entries(on: now, in: context).map { MoodStamp(id: $0.id, mood: $0.mood, intensity: $0.intensity, time: $0.timestamp) }
        return PetSnapshot(identity: identity, mood: latest?.mood, intensity: latest?.intensity, loggedAt: latest?.timestamp, today: today, updatedAt: now,
                           adoptedAt: profile?.createdAt, roughYesterday: roughYesterday(before: now, in: context))
    }

    /// Whether the day before `date` was rough (see `PetSnapshot.wasRough`).
    public static func roughYesterday(before date: Date = .now, calendar: Calendar = .current, in context: ModelContext) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
        return PetSnapshot.wasRough(entries(on: yesterday, calendar: calendar, in: context).map(\.mood))
    }
}
