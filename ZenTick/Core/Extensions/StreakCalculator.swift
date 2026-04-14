import Foundation

enum StreakCalculator {
    static func currentStreak(from days: Set<Date>) -> Int {
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

    static func longestStreak(from days: Set<Date>) -> Int {
        let sortedDays = days.sorted()
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
}
