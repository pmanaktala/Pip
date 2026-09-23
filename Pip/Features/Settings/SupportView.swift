import SwiftUI

/// Where to turn when a feeling is bigger than a pet can hold. Plain, reachable in two taps,
/// and honest about what Pip is: company for noticing how you feel, not care.
struct SupportView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: PipSpacing.m) {
                    PetView(species: appState.identity.species, mood: .calm, intensity: .slight)
                        .frame(width: 56, height: 56)
                    Text("Pip is a companion for noticing how you feel. It isn’t therapy, a diagnosis, or a substitute for care from a person who knows you. If things feel heavy, reaching out is always the right move.")
                        .font(PipFont.body)
                }
                .padding(.vertical, 4)
            }

            Section {
                Link(destination: URL(string: "tel:988")!) {
                    row("Call or text 988", detail: "Suicide & Crisis Lifeline · United States, 24/7", symbol: "phone.fill")
                }
                Link(destination: URL(string: "sms:741741&body=HOME")!) {
                    row("Text HOME to 741741", detail: "Crisis Text Line · United States", symbol: "message.fill")
                }
                Link(destination: URL(string: "https://findahelpline.com")!) {
                    row("Find a helpline", detail: "Free, confidential support in your country", symbol: "globe")
                }
            } header: {
                Text("If you need someone now")
            } footer: {
                Text("If you or someone else is in immediate danger, contact your local emergency number.")
            }

            Section {
                Link(destination: URL(string: "https://www.apple.com/health/")!) {
                    row("Apple Health", detail: "Your State of Mind entries live alongside your other health data", symbol: "heart.text.square")
                }
                Link(destination: URL(string: "https://www.who.int/health-topics/mental-health")!) {
                    row("World Health Organization", detail: "What mental health is, and how to look after it", symbol: "book")
                }
            } header: {
                Text("Learn more")
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, detail: String, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(detail).font(PipFont.footnote).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
        }
    }
}
