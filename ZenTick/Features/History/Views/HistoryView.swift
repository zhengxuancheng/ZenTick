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
        calculateStreak(from: sessionDays)
    }

    var body: some View {
        NavigationStack {
            List {
                streakSection
                calendarSection
                sessionsSection
            }
            .navigationTitle("History")
        }
    }
}

// MARK: - Sections

private extension HistoryView {
    var streakSection: some View {
        Section {
            HStack {
                StatCard(value: "\(currentStreak)", label: "Day Streak")
                StatCard(
                    value: formatDuration(sessions.reduce(0) { $0 + $1.duration }),
                    label: "This Week"
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    var calendarSection: some View {
        Section("Calendar") {
            CalendarGridView(
                displayedMonth: $displayedMonth,
                sessionDays: sessionDays
            )
        }
    }

    var sessionsSection: some View {
        Section("Recent Sessions") {
            if sessions.isEmpty {
                Text("No sessions yet. Start meditating!")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                }
            }

            if !storeService.isPro && allSessions.count > sessions.count {
                ProUpsellRow(text: "Unlock full history")
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

    func calculateStreak(from days: Set<Date>) -> Int {
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var current = Date().startOfDay

        if !days.contains(current) {
            current = current.adding(days: -1)
            guard days.contains(current) else { return 0 }
        }

        while days.contains(current) {
            streak += 1
            current = current.adding(days: -1)
        }
        return streak
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: MeditationSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startDate, style: .date)
                    .font(.subheadline.weight(.medium))
                Text(session.startDate, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(session.duration / 60)) min")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
    }
}

// MARK: - Calendar Grid

struct CalendarGridView: View {
    @Binding var displayedMonth: Date
    let sessionDays: Set<Date>

    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
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
                displayedMonth = displayedMonth.adding(months: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)

            Spacer()

            Button {
                displayedMonth = displayedMonth.adding(months: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
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
    }
}
