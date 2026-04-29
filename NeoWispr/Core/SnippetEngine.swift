import Foundation

final class SnippetEngine {

    private var snippets: [String: String] = [:]
    private var orderedTriggers: [(trigger: String, expansion: String)] = []

    private static let trimSet: CharacterSet = .whitespacesAndNewlines
        .union(CharacterSet(charactersIn: ".,!?;:…\"'"))

    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let items = try JSONDecoder().decode([Snippet].self, from: data)
        update(snippets: items)
    }

    func update(snippets: [Snippet]) {
        let pairs = snippets.map { (Self.normalize($0.trigger), $0.expansion) }
        self.snippets = Dictionary(pairs, uniquingKeysWith: { first, _ in first })
        self.orderedTriggers = pairs
            .filter { !$0.0.isEmpty }
            .sorted { $0.0.count > $1.0.count }
    }

    func expand(_ text: String) -> String {
        let normalized = Self.normalize(text)

        // Exakter Match (punctuation-tolerant): ganzer Text ist ein Trigger
        if let expansion = snippets[normalized] {
            return expansion
        }

        // Partieller Match: längste Trigger zuerst, jeder Trigger einmal
        var result = text
        for (trigger, expansion) in orderedTriggers {
            if let range = result.range(of: trigger, options: .caseInsensitive) {
                result.replaceSubrange(range, with: expansion)
            }
        }
        return result
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: trimSet)
    }
}
