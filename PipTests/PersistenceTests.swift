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
        #expect(throws: MoodSaveError.writeFailed) { try logger.update(entry, intensity: .strong, note: "Draft") }
        #expect(entry.note == "Before")
        #expect(entry.intensity == .moderate)
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
