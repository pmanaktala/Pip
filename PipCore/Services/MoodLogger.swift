import Foundation
import SwiftData

public enum MoodSaveError: LocalizedError {
    case storageUnavailable
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .storageUnavailable: "Mood storage is unavailable. Reopen Pip to try again."
        case .writeFailed: "Your change couldn’t be saved. Please try again."
        }
    }
}

/// Something that reacts to a mood being logged (Live Activity, Health, notifications…).
/// Side effects are registered by the process that can perform them; the widget
/// extension, for instance, registers none and relies on the app to reconcile later.
public protocol MoodLogSideEffect: Sendable {
    @MainActor func moodLogged(_ entry: MoodEntry, identity: PetIdentity, snapshot: PetSnapshot)
}

/// The one place a mood selection becomes persisted state and side effects.
@MainActor
public struct MoodLogger {
    public var context: ModelContext
    public var sharedStore: SharedStateStore
    public var sideEffects: [any MoodLogSideEffect]
    var saveContext: (ModelContext) throws -> Void = { try $0.save() }

    public init(context: ModelContext, sharedStore: SharedStateStore = .shared, sideEffects: [any MoodLogSideEffect] = []) {
        self.context = context
        self.sharedStore = sharedStore
        self.sideEffects = sideEffects
    }

    /// Persists a new entry, refreshes the shared snapshot and notifies side effects.
    @discardableResult
    public func log(mood: Mood, intensity: MoodIntensity = .moderate, contexts: [MoodContext] = [], note: String? = nil, at timestamp: Date = .now) throws -> MoodEntry {
        let entry = MoodEntry(mood: mood, intensity: intensity, contexts: contexts, note: note, timestamp: timestamp)
        try commit { context.insert(entry) }
        let snapshot = refreshSnapshot()
        for effect in sideEffects { effect.moodLogged(entry, identity: snapshot.identity, snapshot: snapshot) }
        return entry
    }

    /// Updates an existing entry (intensity / context / note refinements right after logging).
    public func update(_ entry: MoodEntry, intensity: MoodIntensity? = nil, contexts: [MoodContext]? = nil, note: String?? = nil) throws {
        try commit {
            if let intensity { entry.intensity = intensity }
            if let contexts { entry.contexts = contexts }
            if let note { entry.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            entry.touch()
        }
        refreshSnapshot()
    }

    public func delete(_ entry: MoodEntry) throws {
        try commit { context.delete(entry) }
        refreshSnapshot()
    }

    private func commit(_ change: () -> Void) throws {
        guard !PipModelContainer.isUnavailable(context.container) else { throw MoodSaveError.storageUnavailable }
        change()
        do {
            try saveContext(context)
        } catch {
            context.rollback()
            throw MoodSaveError.writeFailed
        }
    }

    /// Rebuilds and saves the App Group snapshot from the store.
    @discardableResult
    public func refreshSnapshot() -> PetSnapshot {
        let snapshot = PipQueries.buildSnapshot(in: context)
        if !PipModelContainer.isUnavailable(context.container) { sharedStore.save(snapshot) }
        return snapshot
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
