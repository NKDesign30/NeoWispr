import Foundation

@Observable
@MainActor
final class TranscriptionStore {

    private(set) var entries: [TranscriptionEntry] = []

    static let maxEntries = 10_000

    private static var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NeoWispr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    init(entries seedEntries: [TranscriptionEntry]? = nil) {
        if let seedEntries {
            entries = seedEntries
        } else {
            load()
        }
    }

    func add(_ entry: TranscriptionEntry) {
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        persist()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func delete(_ entry: TranscriptionEntry) {
        delete(id: entry.id)
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        persist()
    }

    func search(query: String) -> [TranscriptionEntry] {
        guard !query.isEmpty else { return entries }
        let lower = query.lowercased()
        return entries.filter { $0.text.lowercased().contains(lower) }
    }

    // MARK: - Computed Stats (für Dashboard HomeView)

    var wordsTotal: Int {
        entries.reduce(0) { $0 + $1.wordCount }
    }

    var averageWPM: Int {
        let withDuration = entries.filter { $0.durationMs > 0 }
        guard !withDuration.isEmpty else { return 0 }
        let total = withDuration.reduce(0.0) { acc, entry in
            let minutes = Double(entry.durationMs) / 60_000.0
            guard minutes > 0 else { return acc }
            return acc + Double(entry.wordCount) / minutes
        }
        return Int(total / Double(withDuration.count))
    }

    var streak: Int {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var days: Set<String> = []
        for entry in entries {
            days.insert(formatter.string(from: entry.timestamp))
        }
        var streakCount = 0
        var date = calendar.startOfDay(for: Date())
        while days.contains(formatter.string(from: date)) {
            streakCount += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return streakCount
    }

    /// Gesamte Sprechzeit über alle Diktate (in Millisekunden).
    var totalSpeechMs: Int {
        entries.reduce(0) { $0 + $1.durationMs }
    }

    /// Geschätzte gesparte Zeit gegenüber Tippen (Annahme: 40 WPM Tippgeschwindigkeit).
    /// Formel: typedTime - spokenTime, niemals negativ.
    var timeSavedMs: Int {
        let typingWPM = 40.0
        var saved: Double = 0
        for entry in entries where entry.wordCount > 0 {
            let typingMs = Double(entry.wordCount) / typingWPM * 60_000.0
            let spokenMs = Double(entry.durationMs)
            saved += max(0, typingMs - spokenMs)
        }
        return Int(saved)
    }

    /// Wie oft schneller als Tippen — Faktor wie VoiceInk's "3.7×".
    var speedFactor: Double {
        let totalSpeechMin = Double(totalSpeechMs) / 60_000.0
        guard totalSpeechMin > 0 else { return 0 }
        let typedMin = Double(wordsTotal) / 40.0
        return typedMin / totalSpeechMin
    }

    /// Diktatzahl gesamt (alle Entries).
    var sessionsTotal: Int {
        entries.count
    }

    /// Tagesweise Wörter-Summe für die letzten N Tage (heute zurück), inklusive leerer Tage.
    func wordsByDay(lastDays days: Int = 30) -> [DailyWordCount] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var counts: [Date: Int] = [:]

        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            counts[day, default: 0] += entry.wordCount
        }

        return (0..<days).reversed().compactMap { offset -> DailyWordCount? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyWordCount(day: day, words: counts[day] ?? 0)
        }
    }

    func entriesGroupedByDay() -> [(day: Date, entries: [TranscriptionEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, entries: $0.value) }
    }

    // MARK: - Persistence

    private func load() {
        let url = Self.historyFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            entries = Self.mockEntries
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([TranscriptionEntry].self, from: data)
        } catch {
            entries = Self.mockEntries
        }
    }

    private func persist() {
        let url = Self.historyFileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Mock-Daten (nur wenn noch keine echten Daten vorhanden)

    private static let mockEntries: [TranscriptionEntry] = [
        TranscriptionEntry(text: "Schreibe mir bitte einen kurzen Bericht über die heutige Sitzung.", appName: "Mail", language: "de", durationMs: 8200),
        TranscriptionEntry(text: "Ruf mich morgen früh um neun an, ich habe Zeit für das Meeting.", timestamp: Date().addingTimeInterval(-3600), appName: "Slack", language: "de", durationMs: 7100),
        TranscriptionEntry(text: "Die neue Funktion sieht sehr gut aus, kannst du noch den Dark Mode hinzufügen?", timestamp: Date().addingTimeInterval(-7200), appName: "Xcode", language: "de", durationMs: 9300),
        TranscriptionEntry(text: "Vergiss nicht, die Rechnung bis Ende der Woche zu senden.", timestamp: Date().addingTimeInterval(-86400), appName: "Mail", language: "de", durationMs: 6400),
        TranscriptionEntry(text: "Ich brauche noch die Zugangsdaten für den Server.", timestamp: Date().addingTimeInterval(-86400 - 3600), appName: "Terminal", language: "de", durationMs: 5100),
    ]
}
