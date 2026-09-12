import SwiftUI

/// Tap a mood → it is logged and the pet reacts. Refinements are optional and live.
struct MoodPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var logged: MoodEntry?
    @State private var intensity: MoodIntensity = .moderate
    @State private var contexts: Set<MoodContext> = []
    @State private var note = ""
    @FocusState private var noteFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 150 : 72), spacing: 10)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PipSpacing.l) {
                    if let logged {
                        refinement(for: logged)
                    } else {
                        picker
                    }
                }
                .padding(.horizontal, PipSpacing.m)
                .padding(.top, PipSpacing.s)
                .padding(.bottom, PipSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(logged == nil ? "How are you feeling?" : "\(appState.identity.name) \(logged!.mood.petDescription)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if logged != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .onDisappear { appState.preview = nil }
    }

    // MARK: Step 1

    private var picker: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Mood.allCases) { mood in
                MoodChoice(mood: mood, identity: appState.identity) {
                    choose(mood)
                }
            }
        }
    }

    private func choose(_ mood: Mood) {
        Haptics.selection()
        withAnimation(.spring(duration: 0.7, bounce: 0.3)) {
            logged = appState.log(mood: mood, intensity: intensity)
        }
    }

    // MARK: Step 2 (optional)

    @ViewBuilder
    private func refinement(for entry: MoodEntry) -> some View {
        VStack(alignment: .leading, spacing: PipSpacing.s) {
            Text("How much?")
                .font(PipFont.caption)
                .foregroundStyle(.secondary)
            Picker("Intensity", selection: $intensity) {
                Text("A little").tag(MoodIntensity.slight)
                Text(entry.mood.displayName).tag(MoodIntensity.moderate)
                Text("Very").tag(MoodIntensity.strong)
            }
            .pickerStyle(.segmented)
            .onChange(of: intensity) { _, new in
                Haptics.selection()
                withAnimation(.spring(duration: 0.6, bounce: 0.3)) { appState.update(entry, intensity: new) }
            }
        }

        VStack(alignment: .leading, spacing: PipSpacing.s) {
            Text("Why? (optional)")
                .font(PipFont.caption)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(MoodContext.allCases) { context in
                    let on = contexts.contains(context)
                    Button {
                        Haptics.selection()
                        if on { contexts.remove(context) } else { contexts.insert(context) }
                        appState.update(entry, contexts: Array(contexts))
                    } label: {
                        Label(context.displayName, systemImage: context.symbolName)
                            .font(PipFont.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .tint(on ? Color.accentColor : nil)
                    .glassEffect(on ? .regular.tint(Color.accentColor.opacity(0.35)) : .identity, in: .capsule)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }

        VStack(alignment: .leading, spacing: PipSpacing.s) {
            Text("A note? (optional)")
                .font(PipFont.caption)
                .foregroundStyle(.secondary)
            TextField("Deployment broke again. Great dinner tonight.", text: $note, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(12)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
                .focused($noteFocused)
                .onSubmit { commitNote(entry) }
                .onChange(of: noteFocused) { _, focused in if !focused { commitNote(entry) } }
        }
    }

    private func commitNote(_ entry: MoodEntry) {
        appState.update(entry, note: .some(note.nilIfEmpty))
    }
}

/// One large, visual mood choice: a tiny pet face in that mood plus its name.
struct MoodChoice: View {
    var mood: Mood
    var identity: PetIdentity
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                PetView(identity: identity, state: PetStateResolver.resolve(mood: mood, identity: identity), showsShadow: false, framing: .badge)
                    .frame(width: 56, height: 56)
                Text(mood.displayName)
                    .font(PipFont.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(PetPalette.ambient(for: mood).opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.displayName)
        .accessibilityHint("Logs this mood.")
    }
}

/// Minimal wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
