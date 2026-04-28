import Foundation

@Observable
@MainActor
final class DictionaryStore {

    private(set) var entries: [DictionaryEntry] = []

    var llmVocabularyContext: String {
        entries
            .filter { !$0.wrongWord.isEmpty || !$0.correctWord.isEmpty }
            .map { entry in
                if entry.wrongWord.isEmpty {
                    return entry.correctWord
                }
                return "\(entry.wrongWord) -> \(entry.correctWord)"
            }
            .joined(separator: "\n")
    }

    private static var dictionaryFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NeoWispr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("dictionary.json")
    }

    init() {
        load()
    }

    // MARK: - Apply

    func apply(to text: String) -> String {
        var result = text
        for entry in entries {
            guard !entry.wrongWord.isEmpty else { continue }
            result = result.replacingOccurrences(
                of: entry.wrongWord,
                with: entry.correctWord,
                options: .caseInsensitive
            )
        }
        return result
    }

    // MARK: - CRUD

    func add(wrongWord: String, correctWord: String) {
        let entry = DictionaryEntry(
            wrongWord: wrongWord.trimmingCharacters(in: .whitespaces),
            correctWord: correctWord.trimmingCharacters(in: .whitespaces)
        )
        entries.append(entry)
        persist()
    }

    func update(_ updated: DictionaryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == updated.id }) else { return }
        entries[index] = updated
        persist()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func delete(_ entry: DictionaryEntry) {
        delete(id: entry.id)
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        persist()
    }

    // MARK: - Persistence

    private func load() {
        let url = Self.dictionaryFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            entries = Self.mockEntries
            return
        }
        do {
            let data = try Data(contentsOf: url)
            entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
        } catch {
            entries = Self.mockEntries
        }
    }

    private func persist() {
        let url = Self.dictionaryFileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // Generische Defaults — App-Begriffe + universelle Tech-Schreibweisen.
    // Eigene Projekt-Namen, Brand-Begriffe und Wortlisten legt der User
    // selbst über Settings → Wörterbuch an.
    private static let mockEntries: [DictionaryEntry] = [
        // STT-Provider / App-Begriffe
        DictionaryEntry(wrongWord: "whisper", correctWord: "Whisper"),
        DictionaryEntry(wrongWord: "whisperkit", correctWord: "WhisperKit"),
        DictionaryEntry(wrongWord: "parakeet", correctWord: "Parakeet"),
        DictionaryEntry(wrongWord: "neowispr", correctWord: "NeoWispr"),
        DictionaryEntry(wrongWord: "neowisper", correctWord: "NeoWispr"),

        // Tech-Stack — universelle Schreibweisen die Whisper oft falsch raushaut
        DictionaryEntry(wrongWord: "swiftui", correctWord: "SwiftUI"),
        DictionaryEntry(wrongWord: "swift ui", correctWord: "SwiftUI"),
        DictionaryEntry(wrongWord: "typescript", correctWord: "TypeScript"),
        DictionaryEntry(wrongWord: "type script", correctWord: "TypeScript"),
        DictionaryEntry(wrongWord: "macos", correctWord: "macOS"),
        DictionaryEntry(wrongWord: "mac os", correctWord: "macOS"),
        DictionaryEntry(wrongWord: "xcode", correctWord: "Xcode"),
        DictionaryEntry(wrongWord: "github", correctWord: "GitHub"),
        DictionaryEntry(wrongWord: "gitlab", correctWord: "GitLab"),
        DictionaryEntry(wrongWord: "anthropic", correctWord: "Anthropic"),
    ]
}
