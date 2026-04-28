import Foundation

final class SnippetEngine {

    private var snippets: [String: String] = [:]

    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let items = try JSONDecoder().decode([Snippet].self, from: data)
        snippets = Dictionary(
            items.map { ($0.trigger.lowercased(), $0.expansion) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func update(snippets: [Snippet]) {
        self.snippets = Dictionary(
            snippets.map { ($0.trigger.lowercased(), $0.expansion) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func expand(_ text: String) -> String {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exakter Match: ganzer Text ist ein Snippet-Trigger
        if let expansion = snippets[lowercased] {
            return expansion
        }

        // Partieller Match: Trigger kommt im Text vor (case-insensitive, letzter Treffer)
        var result = text
        for (trigger, expansion) in snippets {
            if let range = result.range(of: trigger, options: [.caseInsensitive, .backwards]) {
                result.replaceSubrange(range, with: expansion)
                break
            }
        }

        return result
    }
}
