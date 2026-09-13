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
        Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PipSpacing.l) {
                    if let logged {
                        loggedHeader(for: logged)
                        refinement(for: logged)
                    } else {
                        Text("How are you feeling?")
                            .font(PipFont.title)
                            .padding(.top, PipSpacing.s)
                        picker
                    }
                }
                .padding(.horizontal, PipSpacing.m)
                .padding(.bottom, PipSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(logged == nil ? "" : "\(appState.identity.name) \(logged!.mood.petDescription)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if logged != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .font(PipFont.headline)
                    }
                }
            }
        }
        .onDisappear { appState.preview = nil }
    }

    // MARK: Step 1

    private var picker: some View {
        LazyVGrid(columns: columns, spacing: 12) {
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

    /// The pet, reacting, on a card in the mood's colour. This is the reward for logging.
    private func loggedHeader(for entry: MoodEntry) -> some View {
        HStack(spacing: PipSpacing.m) {
            AnimatedPetView(identity: appState.identity, state: PetStateResolver.resolve(mood: entry.mood, intensity: intensity, identity: appState.identity), showsShadow: false)
                .frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mood.displayName)
                    .font(PipFont.title)
                Text("\(appState.identity.name) \(entry.mood.petDescription).")
                    .font(PipFont.callout)
                    .opacity(0.9)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(PipSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoodColor.bold(entry.mood), in: RoundedRectangle(cornerRadius: PipRadius.card, style: .continuous))
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .accessibilityHidden(true)
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
                    .buttonStyle(.plain)
                    .foregroundStyle(on ? .white : .primary)
                    .background(on ? MoodColor.bold(entry.mood) : Color(.secondarySystemFill), in: Capsule())
                    .animation(.smooth(duration: 0.2), value: on)
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

/// One mood: a colour card with the pet's face in that mood and the name. Colour and face together.
struct MoodChoice: View {
    var mood: Mood
    var identity: PetIdentity
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                PetView(identity: identity, state: PetStateResolver.resolve(mood: mood, identity: identity), showsShadow: false, framing: .badge)
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.28), in: Circle())
                Text(mood.displayName)
                    .font(PipFont.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MoodColor.bold(mood), in: RoundedRectangle(cornerRadius: PipRadius.tile, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
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
