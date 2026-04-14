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
                if sessions.isEmpty {
                    emptyStateSection
                } else {
                    overviewSection
                    streaksSection
                    if storeService.isPro {
                        trendSection
                    } else {
                        Section(String(localized: "monthly_trend")) {
                            ProUpsellRow(text: String(localized: "unlock_trends"))
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "stats_title"))
        }
    }
}

// MARK: - Sections

private extension StatsView {
    var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)

                Text(String(localized: "stats_empty_title"))
                    .font(.title3.weight(.medium))

                Text(String(localized: "stats_empty_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    var overviewSection: some View {
        Section(String(localized: "overview")) {
            HStack {
                StatCard(
                    value: "\(sessions.count)",
                    label: String(localized: "sessions"),
                    icon: "circle.fill",
                    iconColor: .accentColor
                )
                StatCard(
                    value: formatTotalDuration(),
                    label: String(localized: "total_time"),
                    icon: "hourglass",
                    iconColor: .purple
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    var streaksSection: some View {
        Section(String(localized: "streaks")) {
            HStack {
                StatCard(
                    value: "\(currentStreak)",
                    label: String(localized: "current"),
                    icon: "flame.fill",
                    iconColor: .orange
                )
                StatCard(
                    value: "\(longestStreak)",
                    label: String(localized: "longest"),
                    icon: "trophy.fill",
                    iconColor: .yellow
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    var trendSection: some View {
        Section(String(localized: "monthly_trend")) {
            if monthlyData.isEmpty {
                Text(String(localized: "not_enough_data"))
                    .foregroundStyle(.secondary)
            } else {
                Chart(monthlyData) { item in
                    BarMark(
                        x: .value(String(localized: "month"), item.label),
                        y: .value(String(localized: "chart_minutes"), item.totalMinutes)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .chartYAxisLabel(String(localized: "chart_minutes"))
                .frame(height: 200)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "a11y_trend_chart"))
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
        StreakCalculator.currentStreak(from: sessionDays)
    }

    var longestStreak: Int {
        StreakCalculator.longestStreak(from: sessionDays)
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
