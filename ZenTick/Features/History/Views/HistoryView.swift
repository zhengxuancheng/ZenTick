import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(StoreService.self) private var storeService
    @Query(sort: \MeditationSession.startDate, order: .reverse)
    private var allSessions: [MeditationSession]

    @State private var displayedMonth = Date()

    private var sessions: [MeditationSession] {
        if storeService.isPro {
            return allSessions
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allSessions.filter { $0.startDate >= cutoff }
    }

    private var sessionDays: Set<Date> {
        Set(allSessions.map { $0.startDate.startOfDay })
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: sessionDays)
    }

    var body: some View {
        NavigationStack {
            List {
                if allSessions.isEmpty {
                    emptyStateSection
                } else {
                    streakSection
                    calendarSection
                    sessionsSection
                }
            }
            .navigationTitle(String(localized: "history_title"))
        }
    }
}

// MARK: - Sections

private extension HistoryView {
    var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)

                Text(String(localized: "history_empty_title"))
                    .font(.title3.weight(.medium))

                Text(String(localized: "history_empty_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    var streakSection: some View {
        Section {
            HStack {
                StatCard(
                    value: "\(currentStreak)",
                    label: String(localized: "streak_label"),
                    icon: "flame.fill",
                    iconColor: .orange
                )
                StatCard(
                    value: formatDuration(sessions.reduce(0) { $0 + $1.duration }),
                    label: String(localized: "this_week"),
                    icon: "clock.fill",
                    iconColor: .accentColor
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    var calendarSection: some View {
        Section(String(localized: "calendar")) {
            CalendarGridView(
                displayedMonth: $displayedMonth,
                sessionDays: sessionDays
            )
        }
    }

    var sessionsSection: some View {
        Section(String(localized: "recent_sessions")) {
            ForEach(sessions) { session in
                SessionRow(session: session)
            }

            if !storeService.isPro && allSessions.count > sessions.count {
                ProUpsellRow(text: String(localized: "unlock_history"))
            }
        }
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    var icon: String? = nil
    var iconColor: Color = .accentColor

    var body: some View {
        VStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
            }
            Text(value)
                .font(.title.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: MeditationSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.startDate, style: .date)
                        .font(.subheadline.weight(.medium))
                    Text(session.startDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(localized: "duration_display \(Int(session.duration / 60))"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let note = session.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "a11y_session \(session.startDate.formatted(date: .abbreviated, time: .shortened)) \(Int(session.duration / 60))"))
    }
}

// MARK: - Pro Upsell Row

struct ProUpsellRow: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityLabel(text)
    }
}

// MARK: - Calendar Grid

struct CalendarGridView: View {
    @Binding var displayedMonth: Date
    let sessionDays: Set<Date>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            daysGrid
        }
        .padding(.horizontal, 4)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                HapticService.selection()
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = displayedMonth.adding(months: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(String(localized: "a11y_prev_month"))

            Spacer()

            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)

            Spacer()

            Button {
                HapticService.selection()
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = displayedMonth.adding(months: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(String(localized: "a11y_next_month"))
        }
    }

    private var weekdayHeader: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return LazyVGrid(columns: columns) {
            ForEach(symbols, id: \.self) { day in
                Text(day)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }

    private var daysGrid: some View {
        let days = generateDays()
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    DayCell(
                        day: Calendar.current.component(.day, from: day),
                        hasSession: sessionDays.contains(day),
                        isToday: day.isSameDay(as: Date())
                    )
                } else {
                    Text("")
                        .frame(height: 32)
                }
            }
        }
    }

    private func generateDays() -> [Date?] {
        let calendar = Calendar.current
        let monthStart = displayedMonth.startOfMonth
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
        let daysInMonth = displayedMonth.daysInMonth

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: monthStart) {
                days.append(date.startOfDay)
            }
        }
        return days
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let day: Int
    let hasSession: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? Color.accentColor : .primary)

            Circle()
                .fill(hasSession ? Color.accentColor : Color.clear)
                .frame(width: 6, height: 6)
        }
        .frame(height: 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day), \(hasSession ? String(localized: "a11y_has_session") : String(localized: "a11y_no_session"))")
    }
}
