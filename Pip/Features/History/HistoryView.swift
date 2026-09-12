import SwiftData
import SwiftUI

/// Lightweight history: a month of tiny pet faces, a week strip, and a recap. No charts.
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var entries: [MoodEntry]
    @State private var month: Date = .now
    @State private var selectedDay: Date?
    @State private var scope: Scope = .month

    private enum Scope: String, CaseIterable, Identifiable {
        case month = "Month", week = "Week"
        var id: String { rawValue }
    }

    private var stamps: [MoodStamp] {
        entries.map { MoodStamp(id: $0.id, mood: $0.mood, intensity: $0.intensity, time: $0.timestamp) }
    }

    private var days: [Date: [MoodStamp]] { MoodHistory.byDay(stamps) }

    var body: some View {
        ScrollView {
            VStack(spacing: PipSpacing.l) {
                scopePicker
                    .padding(.horizontal, PipSpacing.m)

                if scope == .month {
                    monthHeader
                    monthGrid
                } else {
                    weekStrip
                }

                recapCard(for: selectedDay ?? .now)
            }
            .padding(.vertical, PipSpacing.m)
        }
        .scrollContentBackground(.hidden)
        .background(LinearGradient(colors: [PipColor.sceneTop, PipColor.sceneBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day, entries: entries.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: day) })
                .presentationDetents([.medium, .large])
        }
    }

    private var scopePicker: some View {
        Picker("Scope", selection: $scope) {
            ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
        }
        .pipTabsPickerStyle()
    }

    // MARK: Month

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
            Spacer()
            Text(month, format: .dateTime.month(.wide).year())
                .font(PipFont.headline)
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                .disabled(Calendar.current.isDate(month, equalTo: .now, toGranularity: .month))
                .accessibilityLabel("Next month")
        }
        .buttonStyle(.glass)
        .padding(.horizontal, PipSpacing.m)
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(MoodHistory.monthGrid(for: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(day: day, stamp: MoodHistory.dominant(days[cal.startOfDay(for: day)] ?? []), identity: appState.identity, isSelected: selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false) {
                            if !(days[cal.startOfDay(for: day)] ?? []).isEmpty { selectedDay = day }
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(.horizontal, PipSpacing.m)
    }

    private func shiftMonth(_ delta: Int) {
        if let m = Calendar.current.date(byAdding: .month, value: delta, to: month) { month = m }
    }

    // MARK: Week

    private var weekStrip: some View {
        let cal = Calendar.current
        return HStack(spacing: 6) {
            ForEach(MoodHistory.recentDays(count: 7), id: \.self) { day in
                VStack(spacing: 4) {
                    DayCell(day: day, stamp: MoodHistory.dominant(days[day] ?? []), identity: appState.identity, isSelected: false, large: true) {
                        if !(days[day] ?? []).isEmpty { selectedDay = day }
                    }
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(PipFont.caption)
                        .foregroundStyle(cal.isDateInToday(day) ? Color.accentColor : .secondary)
                }
            }
        }
        .padding(.horizontal, PipSpacing.m)
    }

    // MARK: Recap

    @ViewBuilder
    private func recapCard(for day: Date) -> some View {
        if let recap = MoodHistory.recap(for: day, stamps: stamps, petName: appState.identity.name) {
            VStack(alignment: .leading, spacing: PipSpacing.m) {
                Text(recap.title)
                    .font(PipFont.title)
                HStack(spacing: PipSpacing.m) {
                    ForEach(recap.scenes, id: \.stamp.id) { scene in
                        VStack(spacing: 2) {
                            PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: scene.stamp.mood, intensity: scene.stamp.intensity, identity: appState.identity), showsShadow: false)
                                .frame(width: 84, height: 84)
                            Text(scene.part.displayName).font(PipFont.caption).foregroundStyle(.secondary)
                            Text(scene.stamp.mood.displayName).font(PipFont.footnote)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(scene.part.displayName): \(scene.stamp.intensity.phrase(for: scene.stamp.mood))")
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(PipSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, PipSpacing.m)
        } else if entries.isEmpty {
            VStack(spacing: PipSpacing.s) {
                PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: .calm, intensity: .slight, identity: appState.identity))
                    .frame(width: 140, height: 140)
                Text("Nothing here yet. \(appState.identity.name) is in no hurry.")
                    .font(PipFont.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, PipSpacing.l)
        }
    }
}

/// One day: a tiny pet face for the dominant mood, or a soft dot.
struct DayCell: View {
    var day: Date
    var stamp: MoodStamp?
    var identity: PetIdentity
    var isSelected: Bool
    var large = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: large ? 14 : 10, style: .continuous)
                    .fill(stamp.map { PetPalette.ambient(for: $0.mood).opacity(0.22) } ?? Color.clear)
                if let stamp {
                    PetView(identity: identity, state: PetStateResolver.resolve(mood: stamp.mood, intensity: stamp.intensity, identity: identity), showsShadow: false, framing: .face)
                        .padding(2)
                    if !large {
                        Text(day, format: .dateTime.day())
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(3)
                    }
                } else {
                    Text(day, format: .dateTime.day())
                        .font(PipFont.caption)
                        .foregroundStyle(Calendar.current.isDateInToday(day) ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                }
            }
            .frame(height: large ? 52 : 44)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: large ? 14 : 10, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(stamp == nil)
        .accessibilityLabel(accessibilityText)
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
                        PetView(identity: appState.identity, state: PetStateResolver.resolve(mood: entry.mood, intensity: entry.intensity, identity: appState.identity), showsShadow: false, framing: .face)
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
