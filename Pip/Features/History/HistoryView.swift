import SwiftData
import SwiftUI

/// History: the week as a strip of dated tiles, the month as a grid, and the selected day's
/// entries inline. Colour is the mood; the pet's face confirms it. No charts, streaks or scores.
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var entries: [MoodEntry]
    @State private var month: Date = .now
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    @State private var entryToDelete: MoodEntry?
    @State private var weekWords: String?
    @State private var dayWords: [String: String] = [:]
    @Environment(\.colorScheme) private var scheme

    private var stamps: [MoodStamp] {
        entries.map { MoodStamp(id: $0.id, mood: $0.mood, intensity: $0.intensity, time: $0.timestamp) }
    }

    private var days: [Date: [MoodStamp]] { MoodHistory.byDay(stamps) }

    private var selectedEntries: [MoodEntry] {
        entries.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: selectedDay) }.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PipSpacing.l) {
                weekSummary
                section("This week") { weekStrip }
                section(month.formatted(.dateTime.month(.wide).year()), trailing: { monthControls }) { monthGrid }
                daySection
            }
            .padding(.horizontal, PipSpacing.m)
            .padding(.bottom, PipSpacing.xl)
        }
        .pipSwipeActionsContainer()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("History")
        .task(id: wordsKey(.week, day: nil)) { await writeWords(.week, day: nil) }
        .task(id: wordsKey(.day, day: selectedDay)) { await writeWords(.day, day: selectedDay) }
        .confirmationDialog("Delete this entry?", isPresented: Binding(get: { entryToDelete != nil }, set: { if !$0 { entryToDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    withAnimation(.smooth) { appState.delete(entry) }
                }
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            Text("This removes the moment from Pip. If it was saved to Apple Health, it stays there.")
        }
    }

    private func section<Content: View, Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PipSpacing.s) {
            HStack {
                Text(title).font(PipFont.title2)
                Spacer()
                trailing()
            }
            content()
        }
    }

    // MARK: Week

    // MARK: The pet's words

    /// A stable key for a set of entries: the pet writes once per distinct set, never per render.
    private func wordsKey(_ kind: PetWords.Kind, day: Date?) -> String {
        let cal = Calendar.current
        let scoped: [MoodEntry]
        switch kind {
        case .week:
            let days = MoodHistory.recentDays(count: 7)
            scoped = entries.filter { $0.timestamp >= (days.first ?? .distantPast) }
        case .day:
            scoped = entries.filter { cal.isDate($0.timestamp, inSameDayAs: day ?? .now) }
        }
        var hasher = Hasher()
        for e in scoped { hasher.combine(e.id); hasher.combine(e.moodRaw); hasher.combine(e.intensityRaw); hasher.combine(e.contextsRaw); hasher.combine(e.note ?? "") }
        hasher.combine(appState.identity.name)
        let stamp = kind == .week ? (MoodHistory.recentDays(count: 7).first ?? .now).formatted(.iso8601.year().month().day()) : (day ?? .now).formatted(.iso8601.year().month().day())
        return "\(kind.rawValue).\(stamp).\(hasher.finalize())"
    }

    private func writeWords(_ kind: PetWords.Kind, day: Date?) async {
        guard appState.preferences.petWordsEnabled else { return }
        let key = wordsKey(kind, day: day)
        let cal = Calendar.current
        let scoped = entries.filter {
            kind == .week ? $0.timestamp >= (MoodHistory.recentDays(count: 7).first ?? .distantPast) : cal.isDate($0.timestamp, inSameDayAs: day ?? .now)
        }.sorted { $0.timestamp < $1.timestamp }
        guard scoped.count >= (kind == .week ? 2 : 1) else { return }
        let input = scoped.map {
            PetWords.Entry(dayName: cal.isDateInToday($0.timestamp) ? "Today" : $0.timestamp.formatted(.dateTime.weekday(.wide)),
                           partOfDay: MoodHistory.DayPart.part(of: $0.timestamp).displayName.lowercased(),
                           mood: $0.mood.displayName.lowercased(),
                           intensity: $0.intensity.adverb ?? "",
                           contexts: $0.contexts.map { $0.displayName.lowercased() },
                           note: $0.note)
        }
        let text = await PetWords.line(kind: kind, key: key, petName: appState.identity.name, species: appState.identity.species.displayName.lowercased(), entries: input)
        guard let text, !Task.isCancelled else { return }
        withAnimation(.smooth) {
            if kind == .week { weekWords = text } else { dayWords[key] = text }
        }
    }

    /// A single descriptive sentence; absent until there is enough to describe.
    @ViewBuilder
    private var weekSummary: some View {
        if let summary = weekWords ?? MoodHistory.weekSummary(stamps: stamps, petName: appState.identity.name) {
            HStack(alignment: .top, spacing: 12) {
                PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: .calm, intensity: .slight, identity: appState.identity), showsShadow: false, framing: .face)
                    .frame(width: 44, height: 44)
                Text(summary)
                    .font(PipFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
            }
            .padding(PipSpacing.m)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: PipRadius.card, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private var weekStrip: some View {
        let cal = Calendar.current
        return HStack(spacing: 6) {
            ForEach(MoodHistory.recentDays(count: 7), id: \.self) { day in
                let stamp = MoodHistory.dominant(days[day] ?? [])
                let selected = cal.isDate(day, inSameDayAs: selectedDay)
                Button {
                    Haptics.selection()
                    withAnimation(.smooth(duration: 0.3)) { selectedDay = day }
                } label: {
                    VStack(spacing: 6) {
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(PipFont.caption)
                            .foregroundStyle(cal.isDateInToday(day) ? Color.accentColor : Color.secondary)
                        if let stamp {
                            PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: stamp.mood, intensity: stamp.intensity, identity: appState.identity), showsShadow: false, framing: .face)
                                .frame(width: 32, height: 32)
                                .padding(2)
                                .background(Color(.secondarySystemGroupedBackground).opacity(0.7), in: Circle())
                        } else {
                            Circle().fill(Color(.tertiarySystemFill)).frame(width: 8, height: 8).frame(height: 36)
                        }
                        Text(day, format: .dateTime.day())
                            .font(PipFont.caption)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(stamp.map { MoodColor.soft($0.mood, scheme: scheme) } ?? Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: PipRadius.chip, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: PipRadius.chip, style: .continuous).strokeBorder(Color.accentColor, lineWidth: selected ? 2 : 0))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(dayLabel(day, stamp))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: Month

    private var monthControls: some View {
        HStack(spacing: 4) {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 32) }
                .accessibilityLabel("Previous month")
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 32) }
                .disabled(Calendar.current.isDate(month, equalTo: .now, toGranularity: .month))
                .accessibilityLabel("Next month")
        }
        .font(.headline.weight(.bold))
        .buttonStyle(.plain)
    }

    private var monthGrid: some View {
        let cal = Calendar.current
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let ordered = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
        return VStack(spacing: 6) {
            HStack {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(PipFont.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(Array(MoodHistory.monthGrid(for: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        let stamp = MoodHistory.dominant(days[cal.startOfDay(for: day)] ?? [])
                        DayCell(day: day, stamp: stamp, isSelected: cal.isDate(selectedDay, inSameDayAs: day)) {
                            Haptics.selection()
                            withAnimation(.smooth(duration: 0.3)) { selectedDay = cal.startOfDay(for: day) }
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(PipSpacing.s)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: PipRadius.card, style: .continuous))
    }

    private func shiftMonth(_ delta: Int) {
        if let m = Calendar.current.date(byAdding: .month, value: delta, to: month) { month = m }
    }

    private func dayLabel(_ day: Date, _ stamp: MoodStamp?) -> String {
        let date = day.formatted(.dateTime.weekday(.wide).month().day())
        if let stamp { return "\(date): \(stamp.intensity.phrase(for: stamp.mood))" }
        return "\(date): nothing logged"
    }

    // MARK: Selected day

    private var dayTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDay) { return "Today" }
        if cal.isDateInYesterday(selectedDay) { return "Yesterday" }
        return selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    @ViewBuilder
    private var daySection: some View {
        VStack(alignment: .leading, spacing: PipSpacing.s) {
            Text(dayTitle)
                .font(PipFont.title2)
                .contentTransition(.numericText())

            if let recap = MoodHistory.recap(for: selectedDay, stamps: stamps, petName: appState.identity.name) {
                let mood = MoodHistory.dominant(days[selectedDay] ?? [])?.mood ?? .neutral
                Text(dayWords[wordsKey(.day, day: selectedDay)] ?? recap.title)
                    .font(PipFont.headline)
                    .foregroundStyle(MoodColor.text(mood, scheme: scheme))
                    .contentTransition(.opacity)
                    .padding(.horizontal, PipSpacing.m)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MoodColor.soft(mood, scheme: scheme), in: RoundedRectangle(cornerRadius: PipRadius.tile, style: .continuous))

                VStack(spacing: 1) {
                    ForEach(selectedEntries) { entry in
                        entryRow(entry)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: PipRadius.card, style: .continuous))
            } else if entries.isEmpty {
                VStack(spacing: PipSpacing.s) {
                    PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: .calm, intensity: .slight, identity: appState.identity))
                        .frame(width: 140, height: 140)
                    Text("Nothing here yet. \(appState.identity.name) is in no hurry.")
                        .font(PipFont.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PipSpacing.l)
            } else {
                Text("Nothing logged \(Calendar.current.isDateInToday(selectedDay) ? "yet today" : "on this day").")
                    .font(PipFont.callout)
                    .foregroundStyle(.secondary)
                    .padding(PipSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: PipRadius.card, style: .continuous))
            }
        }
        .animation(.smooth(duration: 0.3), value: selectedDay)
    }

    /// One moment: the pet's face on its mood tint, the phrase and time, then why and the note.
    /// Swipe to delete on iOS 27; the context menu works everywhere.
    private func entryRow(_ entry: MoodEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: entry.mood, intensity: entry.intensity, identity: appState.identity), showsShadow: false, framing: .face)
                .frame(width: 40, height: 40)
                .padding(4)
                .background(MoodColor.soft(entry.mood, scheme: scheme), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.intensity.phrase(for: entry.mood).capitalizedFirst).font(PipFont.headline)
                    Spacer()
                    Text(entry.timestamp, style: .time).font(PipFont.caption).foregroundStyle(.secondary)
                }
                if !entry.contexts.isEmpty {
                    Text(entry.contexts.map(\.displayName).joined(separator: " · "))
                        .font(PipFont.footnote)
                        .foregroundStyle(.secondary)
                }
                if let note = entry.note, !note.isEmpty {
                    Text(note).font(PipFont.callout)
                }
            }
        }
        .padding(PipSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) { entryToDelete = entry }
        }
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) { entryToDelete = entry }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Delete") { entryToDelete = entry }
    }
}

/// One day in the month grid: the number with a mood dot. Past days without an entry read as
/// quiet, not disabled; future days are out of reach.
struct DayCell: View {
    var day: Date
    var stamp: MoodStamp?
    var isSelected: Bool
    var action: () -> Void

    private var isFuture: Bool { day > Date.now && !Calendar.current.isDateInToday(day) }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                VStack(spacing: 3) {
                    Text(day, format: .dateTime.day())
                        .font(Calendar.current.isDateInToday(day) ? PipFont.caption.weight(.heavy) : PipFont.caption)
                        .foregroundStyle(textColor)
                    Circle()
                        .fill(stamp.map { MoodColor.bold($0.mood) } ?? Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var textColor: Color {
        if Calendar.current.isDateInToday(day) { return .accentColor }
        if isFuture { return Color(.quaternaryLabel) }
        return stamp == nil ? .secondary : .primary
    }

    private var accessibilityText: String {
        let date = day.formatted(.dateTime.weekday(.wide).month().day())
        if let stamp { return "\(date): \(stamp.intensity.phrase(for: stamp.mood))" }
        return "\(date): nothing logged"
    }
}
