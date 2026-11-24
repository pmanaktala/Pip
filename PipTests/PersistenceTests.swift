import Foundation
import SwiftData
import Testing
@testable import Pip

@MainActor
struct PersistenceTests {
    private func makeStore() -> (ModelContainer, SharedStateStore) {
        let container = PipModelContainer.make(inMemory: true)
        let store = SharedStateStore(suiteName: "PersistenceTests.\(UUID().uuidString)")
        return (container, store)
    }

    @Test func loggingPersistsAndRefreshesSnapshot() throws {
        let (container, store) = makeStore()
        let context = container.mainContext
        context.insert(PetProfile(identity: PetIdentity(species: .dog, name: "Biscuit")))
        let logger = MoodLogger(context: context, sharedStore: store)

        let entry = try logger.log(mood: .stressed, intensity: .strong, contexts: [.work], note: "Deploy broke")
        #expect(PipQueries.allEntries(in: context).count == 1)
        #expect(entry.contexts == [.work])

        let snapshot = try #require(store.snapshot)
        #expect(snapshot.identity.name == "Biscuit")
        #expect(snapshot.mood == .stressed)
        #expect(snapshot.intensity == .strong)
        #expect(snapshot.today.count == 1)

        try logger.update(entry, intensity: .slight, note: .some(nil))
        #expect(entry.intensity == .slight)
        #expect(entry.note == nil)
        #expect(entry.modifiedAt >= entry.createdAt)
        #expect(store.snapshot?.intensity == .slight)
    }

    @Test func failedWritesRollBackAndCanBeRetried() throws {
        let (container, store) = makeStore()
        let context = container.mainContext
        let effect = LogCounter()
        var logger = MoodLogger(context: context, sharedStore: store, sideEffects: [effect])
        logger.saveContext = { _ in throw CocoaError(.fileWriteOutOfSpace) }

        #expect(throws: MoodSaveError.writeFailed) { try logger.log(mood: .happy) }
        #expect(PipQueries.allEntries(in: context).isEmpty)
        #expect(store.snapshot == nil)
        #expect(effect.count == 0)

        let entry = try MoodLogger(context: context, sharedStore: store, sideEffects: [effect])
            .log(mood: .stressed, note: "Before")
        let saved = store.snapshot
        #expect(effect.count == 1)
        let savedModifiedAt = entry.modifiedAt
        #expect(throws: MoodSaveError.writeFailed) {
            try logger.update(entry, intensity: .strong, contexts: [.work], note: "Draft")
        }
        #expect(entry.note == "Before")
        #expect(entry.intensity == .moderate)
        #expect(entry.contexts.isEmpty)
        #expect(entry.modifiedAt == savedModifiedAt)
        #expect(!context.hasChanges)
        #expect(throws: MoodSaveError.writeFailed) { try logger.delete(entry) }
        #expect(PipQueries.entry(id: entry.id, in: context) != nil)
        #expect(store.snapshot == saved)

        logger.saveContext = { try $0.save() }
        try logger.update(entry, intensity: .strong, note: "Draft")
        #expect(entry.note == "Draft")
        #expect(store.snapshot?.intensity == .strong)
        try logger.delete(entry)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<MoodEntry>()) == 0)
    }

    @Test func unavailableStoreRefusesToConfirmMood() throws {
        let blockedParent = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data().write(to: blockedParent)
        defer { try? FileManager.default.removeItem(at: blockedParent) }
        let setup = PipModelContainer.makePersistent(at: blockedParent.appending(path: "Pip.store"))
        let store = SharedStateStore(suiteName: "PersistenceTests.\(UUID().uuidString)")
        let effect = LogCounter()
        let logger = MoodLogger(context: setup.container.mainContext, sharedStore: store, sideEffects: [effect])

        #expect(setup.mode == .unavailable)
        #expect(throws: MoodSaveError.storageUnavailable) { try logger.log(mood: .happy) }
        logger.refreshSnapshot()
        #expect(store.snapshot == nil)
        #expect(effect.count == 0)
    }

    @MainActor
    private final class LogCounter: MoodLogSideEffect {
        var count = 0

        func moodLogged(_ entry: MoodEntry, identity: PetIdentity, snapshot: PetSnapshot) {
            count += 1
        }
    }

    @Test func watchDeletionBeforeFirstDeliverySurvivesStoreReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Pip.store")
        let oldSchema = Schema([MoodEntry.self, PetProfile.self])
        let oldConfig = ModelConfiguration("Pip", schema: oldSchema, url: url, cloudKitDatabase: .none)
        let schema = PipModelContainer.schema
        let config = ModelConfiguration("Pip", schema: schema, url: url, cloudKitDatabase: .none)
        let delayed = MoodEntry(mood: .sad, note: "Queued")
        let deletion = ["deleted": delayed.id.uuidString]

        // Start with the shipping schema and make sure upgrading preserves unrelated history.
        let existingID: UUID
        do {
            let container = try ModelContainer(for: oldSchema, configurations: [oldConfig])
            let existing = MoodEntry(mood: .calm)
            existingID = existing.id
            container.mainContext.insert(existing)
            try container.mainContext.save()
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            #expect(PipQueries.entry(id: existingID, in: container.mainContext)?.mood == .calm)
            #expect(try DeviceSync.mergeMoodChange(deletion, into: container.mainContext))
        }

        let reopened = try ModelContainer(for: schema, configurations: [config])
        let context = reopened.mainContext
        #expect(try !DeviceSync.mergeMoodChange(["entry": DeviceSync.Payload(delayed).dictionary], into: context))
        #expect(try !DeviceSync.mergeMoodChange(deletion, into: context))
        #expect(try context.fetchCount(FetchDescriptor<MoodDeletion>()) == 1)
        #expect(PipQueries.allEntries(in: context).map(\.id) == [existingID])
    }

    @Test func delayedWatchEditAndCloudDuplicateStayDeleted() throws {
        let (container, store) = makeStore()
        let context = container.mainContext
        let logger = MoodLogger(context: context, sharedStore: store)
        let entry = try logger.log(mood: .happy)
        let id = entry.id
        var lateEdit = DeviceSync.Payload(entry)
        lateEdit.modifiedAt = .now.addingTimeInterval(30)
        lateEdit.note = "Edited offline"
        try logger.delete(entry)

        #expect(try !DeviceSync.mergeMoodChange(["entry": lateEdit.dictionary], into: context))
        // A late CloudKit import can hold a second row with the same app-level UUID.
        let duplicate = MoodEntry(mood: .happy, note: "Cloud copy")
        duplicate.id = id
        context.insert(duplicate)
        try context.save()
        #expect(PipQueries.latestEntry(in: context) == nil)
        #expect(PipQueries.entries(on: .now, in: context).isEmpty)
        #expect(logger.refreshSnapshot().mood == nil)
        #expect(try DeviceSync.mergeMoodChange(["deleted": id.uuidString], into: context))
        #expect(try context.fetchCount(FetchDescriptor<MoodEntry>()) == 0)
    }

    @Test func duplicateProfilesConvergeOnNewest() throws {
        let (container, _) = makeStore()
        let context = container.mainContext
        let older = PetProfile(identity: PetIdentity(species: .cat))
        older.modifiedAt = Date(timeIntervalSinceNow: -1000)
        let newer = PetProfile(identity: PetIdentity(species: .penguin, name: "Pebble"))
        context.insert(older)
        context.insert(newer)
        try context.save()

        let winner = try #require(PipQueries.petProfile(in: context))
        #expect(winner.species == .penguin)
        #expect(try context.fetchCount(FetchDescriptor<PetProfile>()) == 1)
    }

    @Test func entriesNeedingHealthSyncRespectEnableDate() {
        let (container, _) = makeStore()
        let context = container.mainContext
        let old = MoodEntry(mood: .calm)
        old.createdAt = Date(timeIntervalSinceNow: -7200)
        let fresh = MoodEntry(mood: .happy)
        let synced = MoodEntry(mood: .sad)
        synced.healthKitSampleID = UUID().uuidString
        synced.healthKitSyncedAt = .now.addingTimeInterval(10)
        context.insert(old); context.insert(fresh); context.insert(synced)

        let pending = PipQueries.entriesNeedingHealthSync(since: Date(timeIntervalSinceNow: -3600), in: context)
        #expect(pending.map(\.id) == [fresh.id])
        #expect(synced.isHealthSyncCurrent)
    }

    @Test func healthSyncGoesStaleAfterEdit() {
        let entry = MoodEntry(mood: .happy)
        entry.healthKitSampleID = "abc"
        entry.healthKitSyncedAt = .now
        #expect(entry.isHealthSyncCurrent)
        entry.intensity = .strong
        entry.modifiedAt = .now.addingTimeInterval(5)
        #expect(!entry.isHealthSyncCurrent)
    }
}
