import SwiftData
import SwiftUI

/// History: this week as a strip of colour tiles, the month as a grid, and a recap of the
/// selected day. Colour is the mood; the pet's face confirms it. No charts.
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var entries: [MoodEntry]
    @State private var month: Date = .now
    @State private var selectedDay: Date?
    @Environment(\.colorScheme) private var scheme

    private var stamps: [MoodStamp] {
        entries.map { MoodStamp(id: $0.id, mood: $0.mood, intensity: $0.intensity, time: $0.timestamp) }
    }

    private var days: [Date: [MoodStamp]] { MoodHistory.byDay(stamps) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PipSpacing.l) {
                section("This week") { weekStrip }
                section(month.formatted(.dateTime.month(.wide).year()), trailing: { monthControls }) { monthGrid }
                recapCard(for: selectedDay ?? .now)
            }
            .padding(.horizontal, PipSpacing.m)
            .padding(.bottom, PipSpacing.xl)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("History")
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day, entries: entries.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: day) })
                .presentationDetents([.medium, .large])
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

    private var weekStrip: some View {
        let cal = Calendar.current
        return HStack(spacing: 6) {
            ForEach(MoodHistory.recentDays(count: 7), id: \.self) { day in
                let stamp = MoodHistory.dominant(days[day] ?? [])
                Button {
                    if stamp != nil { selectedDay = day }
                } label: {
                    VStack(spacing: 4) {
                        if let stamp {
                            PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: stamp.mood, intensity: stamp.intensity, identity: appState.identity), showsShadow: false, framing: .badge)
                                .frame(width: 30, height: 30)
                                .padding(3)
                                .background(MoodColor.soft(stamp.mood, scheme: scheme), in: Circle())
                        } else {
                            Circle().fill(Color(.tertiarySystemFill)).frame(width: 8, height: 8).frame(height: 36)
                        }
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(PipFont.caption)
                    }
                    .foregroundStyle(cal.isDateInToday(day) ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: PipRadius.chip, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(stamp == nil)
                .accessibilityLabel(dayLabel(day, stamp))
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
                ForEach(ordered, id: \.self) { s in
                    Text(s).font(PipFont.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(Array(MoodHistory.monthGrid(for: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        let stamp = MoodHistory.dominant(days[cal.startOfDay(for: day)] ?? [])
                        DayCell(day: day, stamp: stamp, identity: appState.identity, isSelected: selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false) {
                            if stamp != nil { selectedDay = day }
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

    // MARK: Recap

    @ViewBuilder
    private func recapCard(for day: Date) -> some View {
        if let recap = MoodHistory.recap(for: day, stamps: stamps, petName: appState.identity.name) {
            let mood = MoodHistory.dominant(days[Calendar.current.startOfDay(for: day)] ?? [])?.mood ?? .neutral
            VStack(alignment: .leading, spacing: PipSpacing.m) {
                Text(recap.title)
                    .font(PipFont.title2)
                HStack(spacing: PipSpacing.m) {
                    ForEach(recap.scenes, id: \.stamp.id) { scene in
                        VStack(spacing: 2) {
                            PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: scene.stamp.mood, intensity: scene.stamp.intensity, identity: appState.identity), showsShadow: false)
                                .frame(width: 84, height: 84)
                            Text(scene.part.displayName).font(PipFont.caption).opacity(0.8)
                            Text(scene.stamp.mood.displayName).font(PipFont.headline)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(scene.part.displayName): \(scene.stamp.intensity.phrase(for: scene.stamp.mood))")
                    }
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(.white)
            .padding(PipSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MoodColor.bold(mood), in: RoundedRectangle(cornerRadius: PipRadius.card, style: .continuous))
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
            .padding(.top, PipSpacing.l)
        }
    }
}

/// One day in the month grid: the number on a soft mood tint with a small dot, or a quiet number.
struct DayCell: View {
    var day: Date
    var stamp: MoodStamp?
    var identity: PetIdentity
    var isSelected: Bool
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color(.tertiarySystemFill) : Color.clear)
                VStack(spacing: 3) {
                    Text(day, format: .dateTime.day())
                        .font(PipFont.caption)
                        .foregroundStyle(textColor)
                    Circle()
                        .fill(stamp.map { MoodColor.bold($0.mood) } ?? Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(stamp == nil)
        .accessibilityLabel(accessibilityText)
    }

    private var textColor: Color {
        if Calendar.current.isDateInToday(day) { return .accentColor }
        return stamp == nil ? Color(.tertiaryLabel) : .primary
    }

    private var accessibilityText: String {
        let date = day.formatted(.dateTime.weekday(.wide).month().day())
        if let stamp { return "\(date): \(stamp.intensity.phrase(for: stamp.mood))" }
        return "\(date): nothing logged"
    }
}

/// Entries for a single day, with context and notes. Swipe to delete.
struct DayDetailView: View {
    @Environment(AppState.self) private var appState
    var day: Date
    var entries: [MoodEntry]

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: entry.mood, intensity: entry.intensity, identity: appState.identity), showsShadow: false, framing: .badge)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
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
                    .padding(.vertical, 4)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) { appState.delete(entry) }
                    }
                }
            }
            .navigationTitle(day.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSinceReferenceDate }
}
