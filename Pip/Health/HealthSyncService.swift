import Foundation
import HealthKit
import Observation
import OSLog
import SwiftData

/// Optional Apple Health integration. Writes State of Mind samples for entries logged
/// after the user turned the feature on; never reads anything but its own samples.
@MainActor
@Observable
final class HealthSyncService {
    private let store = HKHealthStore()
    private let log = Logger(subsystem: "com.pmanaktala.Pip", category: "Health")
    private var isSyncing = false

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var authorizationStatus: HKAuthorizationStatus {
        guard isAvailable else { return .notDetermined }
        return store.authorizationStatus(for: .stateOfMindType())
    }

    var isAuthorized: Bool { authorizationStatus == .sharingAuthorized }

    /// Requests write access for State of Mind only. Returns whether sharing is authorized afterwards.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [.stateOfMindType()], read: [])
        } catch {
            log.error("Authorization failed: \(error.localizedDescription)")
        }
        return isAuthorized
    }

    /// Writes (or rewrites) every entry that is out of date in Health. Safe to call often.
    func syncPending(context: ModelContext, preferences: Preferences) async {
        guard preferences.healthSyncEnabled, isAvailable, isAuthorized, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let pending = PipQueries.entriesNeedingHealthSync(since: preferences.healthSyncEnabledAt, in: context)
        guard !pending.isEmpty else { return }
        for entry in pending {
            do {
                try await sync(entry)
            } catch {
                log.error("Health write failed for \(entry.id): \(error.localizedDescription)")
            }
        }
        try? context.save()
    }

    private func sync(_ entry: MoodEntry) async throws {
        // Remove the stale sample if the entry was edited after being written.
        if let old = entry.healthKitSampleID, let uuid = UUID(uuidString: old) {
            try await deleteSample(uuid: uuid)
        } else if let existing = try await existingSample(for: entry.id) {
            // Written before a reinstall but never recorded locally: adopt or replace it.
            if existing.startDate == entry.timestamp && existing.valence == HealthMapping.valence(for: entry.mood, intensity: entry.intensity) {
                entry.healthKitSampleID = existing.uuid.uuidString
                entry.healthKitSyncedAt = .now
                return
            }
            try await store.delete(existing)
        }

        let sample = HealthMapping.sample(for: entry)
        try await store.save(sample)
        entry.healthKitSampleID = sample.uuid.uuidString
        entry.healthKitSyncedAt = .now
    }

    private func existingSample(for entryID: UUID) async throws -> HKStateOfMind? {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID, allowedValues: [entryID.uuidString])
        let descriptor = HKSampleQueryDescriptor(predicates: [.stateOfMind(predicate)], sortDescriptors: [], limit: 1)
        return try await descriptor.result(for: store).first
    }

    private func deleteSample(uuid: UUID) async throws {
        let descriptor = HKSampleQueryDescriptor(predicates: [.stateOfMind(HKQuery.predicateForObject(with: uuid))], sortDescriptors: [], limit: 1)
        let samples = try await descriptor.result(for: store)
        if !samples.isEmpty { try await store.delete(samples) }
    }
}

/// Side effect registered by the app: writes to Health right after a log.
/// Main-actor bound members; the conformance is unchecked because the protocol is `Sendable`.
struct HealthMoodSideEffect: MoodLogSideEffect, @unchecked Sendable {
    let service: HealthSyncService
    let context: ModelContext
    let preferences: Preferences

    func moodLogged(_ entry: MoodEntry, identity: PetIdentity, snapshot: PetSnapshot) {
        Task { @MainActor in
            // Give the optional refinement step a moment so we don't write, then rewrite.
            try? await Task.sleep(for: .seconds(20))
            await service.syncPending(context: context, preferences: preferences)
        }
    }
}
