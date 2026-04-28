import Foundation
import Observation

/// Power Mode: Pro App (bundleIdentifier) einen anderen Diktat-Stil erzwingen.
/// Beispiele: Slack -> .casual, Mail -> .formal, Xcode -> .code.
///
/// Persistenz: JSON in ~/Library/Application Support/NeoWispr/power-mode.json.
/// Shape: [ { bundleId: String, appName: String, style: String } ]
@Observable
@MainActor
final class PowerModeStore {

    struct Rule: Identifiable, Codable, Sendable, Equatable {
        let id: UUID
        var bundleId: String
        var appName: String
        var styleRaw: String

        var style: DictationStyle {
            DictationStyle(rawValue: styleRaw) ?? .none
        }

        init(id: UUID = UUID(), bundleId: String, appName: String, style: DictationStyle) {
            self.id = id
            self.bundleId = bundleId
            self.appName = appName
            self.styleRaw = style.rawValue
        }
    }

    private(set) var rules: [Rule] = []

    private static var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NeoWispr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("power-mode.json")
    }

    init() {
        load()
    }

    // MARK: - Lookup

    /// Resolve style for a bundleId. Returns nil if no rule matches — caller faellt auf
    /// DictationStyle.current zurück.
    func style(for bundleId: String?) -> DictationStyle? {
        guard let bundleId, !bundleId.isEmpty else { return nil }
        return rules.first { $0.bundleId == bundleId }?.style
    }

    // MARK: - CRUD

    func add(bundleId: String, appName: String, style: DictationStyle) {
        guard !bundleId.isEmpty else { return }
        // Update falls existiert
        if let idx = rules.firstIndex(where: { $0.bundleId == bundleId }) {
            rules[idx] = Rule(id: rules[idx].id, bundleId: bundleId, appName: appName, style: style)
        } else {
            rules.append(Rule(bundleId: bundleId, appName: appName, style: style))
        }
        persist()
    }

    func delete(id: UUID) {
        rules.removeAll { $0.id == id }
        persist()
    }

    func updateStyle(id: UUID, style: DictationStyle) {
        guard let idx = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[idx].styleRaw = style.rawValue
        persist()
    }

    // MARK: - Persistence

    private func load() {
        let url = Self.storeURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            rules = try JSONDecoder().decode([Rule].self, from: data)
        } catch {
            rules = []
        }
    }

    private func persist() {
        let url = Self.storeURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(rules) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
