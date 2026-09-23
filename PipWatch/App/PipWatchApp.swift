import SwiftData
import SwiftUI

/// Pip on the wrist: the pet, a two-tap mood log, a minute of sitting together, and the
/// complications. It shares PipCore and the same SwiftData + CloudKit store as the iPhone app,
/// so a mood logged here is on the phone the next time iCloud syncs, and vice versa.
@main
struct PipWatchApp: App {
    @State private var state = WatchState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(state)
                .modelContainer(state.container)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { state.refresh(); state.pet.arrive(now: .now.addingTimeInterval(0.3)) }
        }
    }
}
