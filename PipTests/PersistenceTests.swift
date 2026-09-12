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

        let entry = logger.log(mood: .stressed, intensity: .strong, contexts: [.work], note: "Deploy broke")
        #expect(PipQueries.allEntries(in: context).count == 1)
        #expect(entry.contexts == [.work])

        let snapshot = try #require(store.snapshot)
        #expect(snapshot.identity.name == "Biscuit")
        #expect(snapshot.mood == .stressed)
        #expect(snapshot.intensity == .strong)
        #expect(snapshot.today.count == 1)

        logger.update(entry, intensity: .slight, note: .some(nil))
        #expect(entry.intensity == .slight)
        #expect(entry.note == nil)
        #expect(entry.modifiedAt >= entry.createdAt)
        #expect(store.snapshot?.intensity == .slight)
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
