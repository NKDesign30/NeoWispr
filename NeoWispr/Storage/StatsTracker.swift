import Foundation

@Observable
@MainActor
final class StatsTracker {

    private let defaults = UserDefaults.standard

    // MARK: - Computed Stats

    var wordsToday: Int {
        let key = dailyKey(for: Date())
        return defaults.integer(forKey: key)
    }

    var wordsThisWeek: Int {
        let calendar = Calendar.current
        var total = 0
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            total += defaults.integer(forKey: dailyKey(for: date))
        }
        return total
    }

    var wordsTotal: Int {
        get { defaults.integer(forKey: "stats_words_total") }
    }

    var streak: Int {
        let calendar = Calendar.current
        var streakCount = 0
        var checkDate = calendar.startOfDay(for: Date())

        while true {
            let key = dailyKey(for: checkDate)
            guard defaults.integer(forKey: key) > 0 else { break }
            streakCount += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }

        return streakCount
    }

    var averageWPM: Double {
        let total = defaults.double(forKey: "stats_total_duration_ms")
        guard total > 0 else { return 0 }
        let totalMinutes = total / 60_000
        return Double(wordsTotal) / totalMinutes
    }

    // MARK: - Tracking

    func track(wordCount: Int, durationMs: Int) {
        let key = dailyKey(for: Date())
        let current = defaults.integer(forKey: key)
        defaults.set(current + wordCount, forKey: key)

        let currentTotal = defaults.integer(forKey: "stats_words_total")
        defaults.set(currentTotal + wordCount, forKey: "stats_words_total")

        let currentDuration = defaults.double(forKey: "stats_total_duration_ms")
        defaults.set(currentDuration + Double(durationMs), forKey: "stats_total_duration_ms")
    }

    // MARK: - Private

    private func dailyKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "stats_daily_\(formatter.string(from: date))"
    }
}
