import Foundation

// MARK: - DailyWordCount (für Dashboard Activity-Chart, 30-Tage-Trend)

struct DailyWordCount: Identifiable, Sendable {
    let day: Date
    let words: Int
    var id: Date { day }
}

// MARK: - TranscriptionEntry

struct TranscriptionEntry: Identifiable, Codable, Sendable {
    let id: UUID
    var text: String
    /// Rohtext vor LLM-Post-Processing. `nil` wenn LLM nicht lief oder nichts verändert hat.
    var rawText: String?
    var timestamp: Date
    var appName: String?
    var language: String
    var wordCount: Int
    var durationMs: Int

    init(id: UUID = UUID(), text: String, rawText: String? = nil, timestamp: Date = Date(), appName: String? = nil, language: String = "de", wordCount: Int? = nil, durationMs: Int = 0) {
        self.id = id
        self.text = text
        self.rawText = rawText
        self.timestamp = timestamp
        self.appName = appName
        self.language = language
        self.wordCount = wordCount ?? text.split(separator: " ").count
        self.durationMs = durationMs
    }
}

// MARK: - DictionaryEntry

struct DictionaryEntry: Identifiable, Codable, Sendable {
    let id: UUID
    var wrongWord: String
    var correctWord: String

    init(id: UUID = UUID(), wrongWord: String, correctWord: String) {
        self.id = id
        self.wrongWord = wrongWord
        self.correctWord = correctWord
    }
}

// MARK: - Dashboard Navigation

enum DashboardSection: String, CaseIterable, Identifiable {
    case home       = "home"
    case history    = "history"
    case snippets   = "snippets"
    case dictionary = "dictionary"
    case scratchpad = "scratchpad"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home:       return "Übersicht"
        case .history:    return "Historie"
        case .snippets:   return "Ersetzungen"
        case .dictionary: return "Wörterbuch"
        case .scratchpad: return "Notizblock"
        }
    }

    var icon: String {
        switch self {
        case .home:       return "house"
        case .history:    return "clock"
        case .snippets:   return "text.badge.plus"
        case .dictionary: return "character.book.closed"
        case .scratchpad: return "note.text"
        }
    }

    var iconFilled: String {
        switch self {
        case .home:       return "house.fill"
        case .history:    return "clock.fill"
        case .snippets:   return "text.badge.plus"
        case .dictionary: return "character.book.closed.fill"
        case .scratchpad: return "note.text"
        }
    }
}
