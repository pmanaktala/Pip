import Foundation
import Testing
@testable import Pip

@MainActor
struct PetInteractionTests {
    @Test func pettingClosesTheEyesAndReleasingSettlesWithAHeart() async throws {
        let suite = "PetInteractionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(container: PipModelContainer.make(inMemory: true), preferences: Preferences(defaults: defaults))
        state.log(mood: .stressed)
        state.startPetting()
        #expect(state.isPetting)
        #expect(state.displayedState.rig.eyeOpen == 0)
        #expect(state.displayedState.rig.sweat == 0, "petting should calm the sweat")
        #expect(state.displayedState.accessory == .heart)
        state.stopPetting()
        #expect(!state.isPetting)
        #expect(state.displayedState.accessory == .heart, "the settle keeps a heart for a moment")
        try await Task.sleep(for: .seconds(2))
        #expect(state.displayedState.mood == .stressed)
        #expect(state.displayedState.rig.sweat > 0, "back to the mood once the hand is gone")
    }

    @Test func fingerFollowingOverridesGaze() throws {
        let suite = "PetInteractionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(container: PipModelContainer.make(inMemory: true), preferences: Preferences(defaults: defaults))
        state.look(at: CGPoint(x: -1, y: 0))
        #expect(state.displayedState.rig.gazeX == -1)
        #expect(state.displayedState.rig.headTurn < 0)
        #expect(state.displayedState.motion.gazeInterval == .infinity, "idle glances pause while a finger is down")
        state.look(at: nil)
        #expect(state.displayedState.motion.gazeInterval.isFinite)
    }

    @Test func rapidTapsEscalateThenReset() async throws {
        let suite = "PetInteractionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(container: PipModelContainer.make(inMemory: true), preferences: Preferences(defaults: defaults))
        for _ in 0..<5 { state.pokePet() }
        #expect(state.tapStreak == 5)
        #expect(state.displayedState.rig.armOut > 0.5, "a giggle spreads the arms")
        state.pokePet()
        #expect(state.tapStreak == 0, "the sixth tap is the dizzy one and resets the streak")
        #expect(state.displayedState.rig.sweat == 1)
    }

    @Test func loggingCancelsAnEarlierHello() async throws {
        let suite = "PetInteractionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(container: PipModelContainer.make(inMemory: true), preferences: Preferences(defaults: defaults))
        state.pokePet()
        let entry = state.log(mood: .sad)
        try await Task.sleep(for: .milliseconds(400))
        // The earlier hello used to replace this reaction with its stale settle pose.
        #expect(state.displayedState.mood == .sad)
        #expect(state.latestEntry?.id == entry.id)
    }
}
