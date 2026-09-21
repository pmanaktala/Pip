import Foundation
import Testing
@testable import Pip

@MainActor
struct PetInteractionTests {
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
