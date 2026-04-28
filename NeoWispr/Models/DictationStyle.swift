import Foundation

enum DictationStyle: String, CaseIterable, Identifiable, Equatable {
    case none
    case formal
    case casual
    case code

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:   return "Kein Stil"
        case .formal: return "Formell"
        case .casual: return "Locker"
        case .code:   return "Code"
        }
    }

    /// Prompt-Fragment für LLM-Post-Processing. Wird in den LLMPostProcessor-Prompt eingesetzt.
    var promptHeader: String {
        promptHeader(removeFillerWords: UserDefaults.standard.bool(forKey: AppSettings.removeFillerWords))
    }

    func promptHeader(removeFillerWords: Bool) -> String {
        let cleanup = removeFillerWords
            ? "Entferne klare Füllwörter wie ähm, also und quasi, aber lösche keine inhaltlich nötigen Wörter."
            : "Entferne keine Füllwörter automatisch; korrigiere nur offensichtliche Wiederholungen, wenn sie den Satz kaputt machen."

        switch self {
        case .none:
            return "Bereinige den folgenden diktierten Text: \(cleanup) Korrigiere Interpunktion und Groß-/Kleinschreibung. Ändere NICHTS am Inhalt, keine Umformulierungen, keine Erklärungen. Gib nur den bereinigten Text zurück."
        case .formal:
            return "Bereinige den folgenden diktierten Text und formuliere ihn formell um: \(cleanup) Ersetze Umgangssprache durch gehobene, höfliche Sprache. Inhalt bleibt identisch. Gib nur den finalen Text zurück, keine Erklärungen."
        case .casual:
            return "Bereinige den folgenden diktierten Text in lockerem Ton: \(cleanup) Halte knappe Sätze, Umgangssprache ist erlaubt. Inhalt bleibt identisch. Gib nur den finalen Text zurück, keine Erklärungen."
        case .code:
            return "Wandle den folgenden diktierten Text in Code-freundliche Notation: \(cleanup) Variablennamen in camelCase beibehalten, KEINE normalen Satzzeichen am Zeilenende, Code-Fences (```) wenn ein Code-Block erkennbar ist. Gib nur den finalen Text zurück, keine Erklärungen."
        }
    }

    /// Liest den aktuell konfigurierten Stil aus UserDefaults (Fallback: .none).
    static var current: DictationStyle {
        let raw = UserDefaults.standard.string(forKey: AppSettings.dictationStyle) ?? ""
        return DictationStyle(rawValue: raw) ?? .none
    }
}
