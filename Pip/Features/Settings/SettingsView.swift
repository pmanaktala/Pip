import HealthKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(HealthSyncService.self) private var health
    @Environment(NotificationService.self) private var notifications
    @Environment(\.openURL) private var openURL
    @State private var showDeleteConfirmation = false
    @State private var showHealthDenied = false

    var body: some View {
        @Bindable var prefs = appState.preferences

        List {
            Section {
                NavigationLink {
                    PetSelectorView()
                } label: {
                    HStack(spacing: PipSpacing.m) {
                        PetView(species: appState.identity.species, mood: .happy, intensity: .slight)
                            .frame(width: 72, height: 72)
                            .background(Color(.tertiarySystemFill), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.identity.name).font(PipFont.title2)
                            Text("\(appState.identity.species.displayName) · \(appState.identity.personality.displayName)").font(PipFont.callout).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                }
            }

            Section {
                if health.isAvailable {
                    Toggle("Save moods to Apple Health", isOn: Binding(
                        get: { prefs.healthSyncEnabled && health.isAuthorized },
                        set: { on in
                            if on {
                                Task {
                                    let ok = await health.requestAuthorization()
                                    prefs.healthSyncEnabled = ok
                                    if !ok { showHealthDenied = true }
                                    await health.syncPending(context: appState.context, preferences: prefs)
                                }
                            } else {
                                prefs.healthSyncEnabled = false
                            }
                        }))
                    if health.authorizationStatus == .sharingDenied {
                        Text("Health access is off for Pip. You can allow it in the Health app under Sharing › Apps.")
                            .font(PipFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Apple Health isn’t available on this device.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text("Each mood becomes a State of Mind entry. Pip only writes entries it created and never reads your Health data. Entries already in Health stay there if you turn this off; manage them in the Health app.")
            }

            Section {
                Toggle("Mood changes", isOn: $prefs.liveActivitiesEnabled)
                Toggle("Pet moments", isOn: $prefs.petMomentsEnabled)
            } header: {
                Text("Live Activities")
            } footer: {
                Text("Short Lock Screen moments after you log a mood, and the occasional invitation to sit together. They end on their own.")
            }

            Section {
                notificationToggle("Company", "“\(appState.identity.name) wants some company.”", $prefs.notificationsCompany)
                notificationToggle("Wind-down", "“\(appState.identity.name) looks sleepy.”", $prefs.notificationsSleepy)
                notificationToggle("Little moments", "“\(appState.identity.name) is watching something out the window.”", $prefs.notificationsMoments)
            } header: {
                Text("Notifications")
            } footer: {
                Text("At most one a day, often none. Never a reminder to log your mood.")
            }

            Section {
                Toggle("\(appState.identity.name)’s words", isOn: $prefs.petWordsEnabled)
                    .disabled(!PetWords.isAvailable)
                    .onChange(of: prefs.petWordsEnabled) { _, on in if !on { PetWords.clearCache() } }
                if let reason = PetWords.unavailableReason {
                    Text(reason).font(PipFont.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Apple Intelligence")
            } footer: {
                Text("\(appState.identity.name) writes the History sentences from your entries, in its own voice, using the on-device model. Nothing leaves your iPhone. Off, or where Apple Intelligence isn’t available, Pip uses its fixed phrases.")
            }

            Section {
                Toggle("Haptics", isOn: $prefs.hapticsEnabled)
                Toggle("Ambient sound while sitting together", isOn: $prefs.soundEnabled)
            } header: {
                Text("Feel & Sound")
            }

            Section {
                NavigationLink {
                    SupportView()
                } label: {
                    Label("Support and crisis resources", systemImage: "lifepreserver")
                }
            } footer: {
                Text("Pip is a companion for noticing how you feel, not therapy or medical advice. If things feel heavy, there are people who can help.")
            }

            Section {
                LabeledContent("iCloud", value: PipModelContainer.isCloudKitEnabled ? "On" : "Unavailable")
                if !PipModelContainer.isCloudKitEnabled {
                    Text("Without iCloud, your history is stored only on this device and won’t survive deleting the app.")
                        .font(PipFont.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Privacy policy") { openURL(URL(string: "https://github.com/pmanaktala/Pip/blob/main/PRIVACY.md")!) }
            } header: {
                Text("Privacy")
            } footer: {
                Text("No accounts, no analytics, no tracking. Your moods live on your device and in your private iCloud, where only you can see them.")
            }

            Section {
                ShareLink(item: MoodExport(context: appState.context), preview: SharePreview("Pip moods", image: Image(systemName: "doc.text"))) {
                    Label("Export My Data", systemImage: "square.and.arrow.up")
                }
                Button("Delete All App Data", role: .destructive) { showDeleteConfirmation = true }
            } header: {
                Text("Your data")
            } footer: {
                Text("Export writes every mood, note and your pet to a JSON file you can keep or open elsewhere. Delete removes your mood history, pet and preferences from this device and your private iCloud; entries already saved to Apple Health are not affected.")
            }

            Section {
                LabeledContent("Version", value: Bundle.main.versionString)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("You")
        .confirmationDialog("Delete all app data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { appState.deleteAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your mood history, pet and preferences will be deleted from this device and your private iCloud. This can’t be undone. Apple Health entries are kept; manage them in the Health app.")
        }
        .alert("Health access wasn’t granted", isPresented: $showHealthDenied) {
            Button("OK") {}
        } message: {
            Text("You can allow Pip in the Health app under Sharing › Apps › Pip.")
        }
        .onChange(of: prefs.anyNotificationsEnabled) { _, _ in
            Task { await notifications.reschedule(preferences: prefs, identity: appState.identity) }
        }
    }

    private func notificationToggle(_ title: String, _ example: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { binding.wrappedValue && notifications.isAuthorized },
            set: { on in
                if on, !notifications.isAuthorized {
                    Task {
                        let ok = await notifications.requestAuthorization()
                        binding.wrappedValue = ok
                    }
                } else {
                    binding.wrappedValue = on
                }
            })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(example).font(PipFont.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

extension Bundle {
    var versionString: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
