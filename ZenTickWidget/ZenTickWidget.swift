import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct MeditationEntry: TimelineEntry {
    let date: Date
    let streakCount: Int
    let todayCompleted: Bool
    let weekDots: [Bool] // last 7 days, index 0 = 6 days ago, index 6 = today
}

// MARK: - Timeline Provider

struct MeditationTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeditationEntry {
        MeditationEntry(
            date: Date(),
            streakCount: 3,
            todayCompleted: true,
            weekDots: [true, false, true, true, true, false, true]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MeditationEntry) -> Void) {
        let entry = fetchEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeditationEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchEntry() -> MeditationEntry {
        var streakCount = 0
        var todayCompleted = false
        var weekDots = [Bool](repeating: false, count: 7)

        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: MeditationSession.self, configurations: config)
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<MeditationSession>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            let sessions = try context.fetch(descriptor)
            let sessionDays = Set(sessions.map { Calendar.current.startOfDay(for: $0.startDate) })

            let today = Calendar.current.startOfDay(for: Date())
            todayCompleted = sessionDays.contains(today)

            // Week dots (last 7 days)
            for i in 0..<7 {
                let day = Calendar.current.date(byAdding: .day, value: -(6 - i), to: today)!
                weekDots[i] = sessionDays.contains(day)
            }

            // Streak
            var current = today
            if !sessionDays.contains(current) {
                current = Calendar.current.date(byAdding: .day, value: -1, to: current)!
                guard sessionDays.contains(current) else {
                    return MeditationEntry(date: Date(), streakCount: 0, todayCompleted: false, weekDots: weekDots)
                }
            }
            while sessionDays.contains(current) {
                streakCount += 1
                current = Calendar.current.date(byAdding: .day, value: -1, to: current)!
            }
        } catch {
            // Return defaults on error
        }

        return MeditationEntry(
            date: Date(),
            streakCount: streakCount,
            todayCompleted: todayCompleted,
            weekDots: weekDots
        )
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: MeditationEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.todayCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title)
                .foregroundStyle(entry.todayCompleted ? .green : .secondary)

            Text(entry.todayCompleted ? "Done" : "Not yet")
                .font(.caption.weight(.medium))

            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("\(entry.streakCount)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: MeditationEntry
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 16) {
            // Left side: streak info
            VStack(spacing: 4) {
                Image(systemName: entry.todayCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(entry.todayCompleted ? .green : .secondary)

                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(entry.streakCount)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }

                Text("day streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)
                .padding(.vertical, 8)

            // Right side: 7-day dots
            VStack(spacing: 6) {
                Text("Last 7 days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 3) {
                            Circle()
                                .fill(entry.weekDots[index] ? Color.green : Color.secondary.opacity(0.3))
                                .frame(width: 12, height: 12)
                            Text(dayLabel(for: index))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func dayLabel(for index: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -(6 - index), to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let label = formatter.string(from: date)
        return String(label.prefix(1))
    }
}

// MARK: - Widget Definition

struct ZenTickWidget: Widget {
    let kind = "ZenTickWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeditationTimelineProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Meditation")
        .description("Today's meditation status and streak.")
        .supportedFamilies([.systemSmall])
    }
}

struct ZenTickMediumWidget: Widget {
    let kind = "ZenTickMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeditationTimelineProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Weekly Meditation")
        .description("7-day overview and streak count.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct ZenTickWidgetBundle: WidgetBundle {
    var body: some Widget {
        ZenTickWidget()
        ZenTickMediumWidget()
    }
}
