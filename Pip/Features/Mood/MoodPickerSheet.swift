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
    @Environment(\.colorScheme) private var scheme

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 2 : 4)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PipSpacing.l) {
                    if let logged {
                        loggedHeader(for: logged)
                        refinement(for: logged)
                    } else {
                        picker
                            .padding(.top, PipSpacing.s)
                    }
                }
                .padding(.horizontal, PipSpacing.m)
                .padding(.bottom, PipSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)
            .navigationTitle(logged == nil ? "How are you feeling?" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if logged != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") { dismiss() }
                            .font(PipFont.headline)
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
            }
        }
        .onDisappear {
            if let logged { commitNote(logged) }
            appState.pet.preview(nil)
        }
    }

    // MARK: Step 1

    private var picker: some View {
        GlassEffectContainer(spacing: 20) {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(Mood.allCases) { mood in
                    MoodChoice(mood: mood, identity: appState.identity) {
                        choose(mood)
                    }
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

    /// After logging, the pet reacts on the Pet tab above the sheet; here a single line confirms it.
    private func loggedHeader(for entry: MoodEntry) -> some View {
        HStack(spacing: 12) {
            PetView(species: appState.identity.species, mood: entry.mood, intensity: intensity)
                .frame(width: 52, height: 52)
                .padding(5)
                .background(MoodColor.soft(entry.mood, scheme: scheme), in: Circle())
                .overlay(Circle().strokeBorder(MoodColor.bold(entry.mood).opacity(0.5), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.mood.displayName)
                    .font(PipFont.title2)
                Text("Logged. \(appState.identity.name) \(entry.mood.petDescription).")
                    .font(PipFont.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, PipSpacing.s)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.mood.displayName) logged.")
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
            .pipTabsPickerStyle()
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
                    .buttonStyle(.plain)
                    .foregroundStyle(on ? MoodColor.onBold : .primary)
                    .background(on ? MoodColor.bold(entry.mood) : Color(.secondarySystemGroupedBackground), in: Capsule())
                    .animation(.smooth(duration: 0.2), value: on)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }

        VStack(alignment: .leading, spacing: PipSpacing.s) {
            Text("A note? (optional)")
                .font(PipFont.caption)
                .foregroundStyle(.secondary)
            TextField("What made this moment feel this way?", text: $note, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: PipRadius.chip, style: .continuous))
                .focused($noteFocused)
                .onSubmit { commitNote(entry) }
                .onChange(of: note) { _, _ in appState.pet.listen() }
                .onChange(of: noteFocused) { _, focused in if !focused { commitNote(entry) } }
        }
    }

    private func commitNote(_ entry: MoodEntry) {
        appState.update(entry, note: .some(note.nilIfEmpty))
    }
}

/// One mood: a glass token holding the pet's face in that mood, tinted with the mood's colour,
/// with a small badge for the glyph. Face, colour and word together; the glass catches the room
/// behind the sheet and answers the touch, so the choice feels like picking up something real.
struct MoodChoice: View {
    var mood: Mood
    var identity: PetIdentity
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    PetView(species: identity.species, mood: mood)
                        .frame(width: 66, height: 66)
                        .padding(3)
                        .background(MoodColor.bold(mood).opacity(scheme == .dark ? 0.12 : 0.1), in: Circle())
                        .glassEffect(.regular.interactive(), in: .circle)
                        .overlay(Circle().strokeBorder(MoodColor.bold(mood).opacity(0.75), lineWidth: 2))
                    Image(systemName: mood.symbolName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MoodColor.onBold)
                        .symbolColorRenderingMode(.gradient)
                        .frame(width: 20, height: 20)
                        .background(MoodColor.bold(mood), in: Circle())
                        .overlay(Circle().strokeBorder(Color(.systemBackground).opacity(0.9), lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                }
                Text(mood.displayName)
                    .font(PipFont.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
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
