import Foundation

enum SnippetStore {

    static var snippetsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NeoWispr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("snippets.json")
    }

    static func load() throws -> [Snippet] {
        let url = snippetsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            let defaults = defaultSnippets()
            try save(defaults)
            return defaults
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Snippet].self, from: data)
    }

    static func save(_ snippets: [Snippet]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snippets)
        try data.write(to: snippetsFileURL, options: .atomic)
    }

    static func defaultSnippets() -> [Snippet] {
        // Generische Defaults — universell auf Deutsch nutzbar.
        // Persönliche Snippets (Email, Name, Brand-Begriffe, Personen) legt der User
        // selbst über Settings → Snippets an.
        [
            // Grüße / Closings
            Snippet(trigger: "mfg", expansion: "Mit freundlichen Grüßen"),
            Snippet(trigger: "lg", expansion: "Liebe Grüße"),
            Snippet(trigger: "vg", expansion: "Viele Grüße"),
            Snippet(trigger: "bg", expansion: "Beste Grüße"),
            Snippet(trigger: "hzg", expansion: "Herzliche Grüße"),

            // Anrede
            Snippet(trigger: "sgdh", expansion: "Sehr geehrte Damen und Herren,"),
            Snippet(trigger: "hihi", expansion: "Hallo zusammen,"),
            Snippet(trigger: "moin", expansion: "Moin,"),

            // Antwort-Phrasen
            Snippet(trigger: "dafs", expansion: "Danke für die schnelle Rückmeldung!"),
            Snippet(trigger: "dvfa", expansion: "Danke vorab für deine Antwort."),
            Snippet(trigger: "lmw", expansion: "Lass mich wissen, ob das so passt."),
            Snippet(trigger: "kdmf", expansion: "Kann ich dir noch was schicken?"),
            Snippet(trigger: "alklar", expansion: "Alles klar, dann mach ich das so."),
            Snippet(trigger: "passt", expansion: "Passt für mich, danke!"),

            // Allgemeine Tech-Phrasen
            Snippet(trigger: "kvjs", expansion: "Kannst du mir den Link nochmal schicken?"),
            Snippet(trigger: "callvb", expansion: "Sollen wir das kurz callen?"),
        ]
    }
}
