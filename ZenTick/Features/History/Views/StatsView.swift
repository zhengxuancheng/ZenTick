import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(StoreService.self) private var storeService
    @Query(sort: \MeditationSession.startDate, order: .reverse)
    private var sessions: [MeditationSession]

    var body: some View {
        NavigationStack {
            List {
                overviewSection
                streaksSection
                if storeService.isPro {
                    trendSection
                } else {
                    Section("Monthly Trend") {
                        ProUpsellRow(text: "Unlock stats trends with Pro")
                    }
                }
            }
            .navigationTitle("Statistics")
        }
    }
}

// MARK: - Sections

private extension StatsView {
    var overviewSection: some View {
        Section("Overview") {
            HStack {
                StatCard(value: "\(sessions.count)", label: "Sessions")
                StatCard(value: formatTotalDuration(), label: "Total Time")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    var streaksSection: some View {
        Section("Streaks") {
            HStack {
                StatCard(value: "\(currentStreak)", label: "Current")
                StatCard(value: "\(longestStreak)", label: "Longest")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    var trendSection: some View {
        Section("Monthly Trend") {
            if monthlyData.isEmpty {
                Text("Not enough data yet.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(monthlyData) { item in
                    BarMark(
                        x: .value("Month", item.label),
                        y: .value("Minutes", item.totalMinutes)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Computed Data

private extension StatsView {
    var sessionDays: Set<Date> {
        Set(sessions.map { $0.startDate.startOfDay })
    }

    var currentStreak: Int {
        let days = sessionDays
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

    var longestStreak: Int {
        let sortedDays = sessionDays.sorted()
        guard sortedDays.count > 1 else { return sortedDays.count }

        var longest = 1
        var current = 1

        for i in 1..<sortedDays.count {
            let diff = Calendar.current.dateComponents(
                [.day], from: sortedDays[i - 1], to: sortedDays[i]
            ).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else if diff > 1 {
                current = 1
            }
        }
        return longest
    }

    struct MonthlyDataPoint: Identifiable {
        let id = UUID()
        let label: String
        let totalMinutes: Int
    }

    var monthlyData: [MonthlyDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        return (0..<6).reversed().compactMap { monthsAgo -> MonthlyDataPoint? in
            guard let month = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else {
                return nil
            }

            let components = calendar.dateComponents([.year, .month], from: month)
            let total = sessions.filter { session in
                let sc = calendar.dateComponents([.year, .month], from: session.startDate)
                return sc.year == components.year && sc.month == components.month
            }.reduce(0) { $0 + $1.duration }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let label = formatter.string(from: month)

            return MonthlyDataPoint(label: label, totalMinutes: Int(total / 60))
        }
    }

    func formatTotalDuration() -> String {
        let total = sessions.reduce(0) { $0 + $1.duration }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
