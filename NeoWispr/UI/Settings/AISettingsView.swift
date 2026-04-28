import AppKit
import SwiftUI

struct AISettingsView: View {

    @Environment(PowerModeStore.self) private var powerModeStore

    @AppStorage(AppSettings.llmEnabled) private var llmEnabled: Bool = false
    @AppStorage(AppSettings.llmProvider) private var llmProvider: String = "groq"
    @AppStorage(AppSettings.dictationStyle) private var dictationStyle: String = DictationStyle.none.rawValue
    @AppStorage(AppSettings.llmAutoDisableOnError) private var autoDisableOnError: Bool = true
    @AppStorage(AppSettings.powerModeEnabled) private var powerModeEnabled: Bool = false
    @AppStorage(AppSettings.removeFillerWords) private var removeFillerWords: Bool = false
    @AppStorage(AppSettings.customPrompt) private var customPrompt: String = ""
    @AppStorage(AppSettings.groqModel) private var groqModel: String = "llama-3.3-70b-versatile"

    @State private var groqApiKey: String = ""
    @State private var groqKeyError: String?
    @State private var probeStatus: ProbeStatus = .idle
    @State private var probeTask: Task<Void, Never>?

    enum ProbeStatus: Equatable {
        case idle
        case running
        case success(ms: Int)
        case failure(String)

        var label: String {
            switch self {
            case .idle:              return "Noch nicht getestet"
            case .running:           return "Teste..."
            case .success(let ms):   return "OK — \(ms) ms"
            case .failure(let msg):  return msg
            }
        }

        var color: Color {
            switch self {
            case .idle:    return .secondary
            case .running: return .secondary
            case .success: return .green
            case .failure: return .orange
            }
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Automatische Verbesserung", isOn: $llmEnabled)

                if llmEnabled {
                    Picker("Provider", selection: $llmProvider) {
                        Text("Groq (kostenlos, schnell — empfohlen)").tag("groq")
                        Text("Claude Haiku (via Max Plan)").tag("claude-haiku")
                        Text("Ollama (100% lokal)").tag("ollama")
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("KI-Verbesserung").neonSectionHeader()
            } footer: {
                if llmEnabled {
                    switch llmProvider {
                    case "groq":
                        Text("Groq läuft kostenlos via Free Tier auf Llama-Modellen — extrem schnell durch LPU-Hardware. API-Key holst du dir auf console.groq.com (kostenlos, Mail-Login reicht).")
                    case "ollama":
                        Text("Ollama läuft lokal — kein Audio oder Text verlässt dein Gerät. Benötigt `brew install ollama` und einmalig `ollama pull llama3.2:3b`.")
                    case "claude-haiku":
                        Text("Claude Haiku läuft über deinen Max Plan. Der Text wird zur Verarbeitung an Anthropic gesendet, nicht gespeichert.")
                    default:
                        EmptyView()
                    }
                } else {
                    Text("Entfernt Füllwörter (ähm, also), setzt Interpunktion und passt optional den Schreibstil an.")
                }
            }

            if llmEnabled && llmProvider == "groq" {
                Section {
                    SecureField("API-Key", text: $groqApiKey, prompt: Text("gsk_..."))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: groqApiKey) { _, newValue in
                            saveGroqAPIKey(newValue)
                        }

                    if let groqKeyError {
                        Text(groqKeyError)
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }

                    Picker("Modell", selection: $groqModel) {
                        Text("Llama 3.3 70B Versatile (beste Qualität)").tag("llama-3.3-70b-versatile")
                        Text("Llama 3.1 8B Instant (schnellste Latenz)").tag("llama-3.1-8b-instant")
                        Text("Llama 3.1 70B Versatile (Legacy)").tag("llama-3.1-70b-versatile")
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Link("API-Key holen (console.groq.com)", destination: URL(string: "https://console.groq.com/keys")!)
                            .font(.system(size: 11))
                        Spacer()
                    }
                } header: {
                    Text("Groq").neonSectionHeader()
                } footer: {
                    Text("Free Tier: ca. 30 Anfragen pro Minute, locker für tägliches Diktat. Bei mehr Volumen Rate-Limit-Warnung — dann Plan upgraden oder auf Ollama wechseln.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if llmEnabled {
                Section {
                    Picker("Stil", selection: $dictationStyle) {
                        ForEach(DictationStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Füllwörter entfernen", isOn: $removeFillerWords)
                } header: {
                    Text("Schreibstil").neonSectionHeader()
                } footer: {
                    Text(customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? styleDescription : "Eigener Prompt ist aktiv und überschreibt den Stil.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    TextEditor(text: $customPrompt)
                        .font(.system(size: 12))
                        .frame(minHeight: 82)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                } header: {
                    Text("Eigener Prompt").neonSectionHeader()
                } footer: {
                    Text("Leer lassen für die Presets. Der Prompt soll nur die gewünschte Ausgabe beschreiben; NeoWispr hängt den diktierten Text darunter.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Toggle("Bei Fehler automatisch deaktivieren", isOn: $autoDisableOnError)

                    HStack {
                        Button("Provider testen", action: runProbe)
                            .buttonStyle(.bordered)
                            .disabled(probeStatus == .running)

                        Spacer()

                        HStack(spacing: 6) {
                            Circle()
                                .fill(probeStatus.color)
                                .frame(width: 6, height: 6)
                            Text(probeStatus.label)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                } header: {
                    Text("Verhalten").neonSectionHeader()
                } footer: {
                    Text("Der Test sendet einen kurzen Beispielsatz an den Provider und misst die Antwortzeit.")
                }

                Section {
                    Toggle("Power Mode aktivieren", isOn: $powerModeEnabled)

                    if powerModeEnabled {
                        powerModeRules
                    }
                } header: {
                    Text("Power Mode — pro App").neonSectionHeader()
                } footer: {
                    Text("Stil pro App überschreiben (z.B. Slack = Locker, Mail = Formell, Xcode = Code). Apps ohne Regel nutzen den globalen Stil.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loadGroqAPIKey)
        .onDisappear {
            probeTask?.cancel()
            probeTask = nil
        }
    }

    // MARK: - Power Mode UI

    @ViewBuilder
    private var powerModeRules: some View {
        if powerModeStore.rules.isEmpty {
            HStack {
                Text("Noch keine App-Regeln.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("App hinzufügen", action: addApp)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        } else {
            ForEach(powerModeStore.rules) { rule in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.appName)
                            .font(.callout)
                        Text(rule.bundleId)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Picker("", selection: styleBinding(for: rule)) {
                        ForEach(DictationStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                    .labelsHidden()
                    Button {
                        powerModeStore.delete(id: rule.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }

            HStack {
                Spacer()
                Button("App hinzufügen", action: addApp)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func styleBinding(for rule: PowerModeStore.Rule) -> Binding<String> {
        Binding(
            get: { rule.styleRaw },
            set: { newRaw in
                let style = DictationStyle(rawValue: newRaw) ?? .none
                powerModeStore.updateStyle(id: rule.id, style: style)
            }
        )
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = "App auswählen"
        panel.message = "Wähle die App, für die ein eigener Stil gelten soll."
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return }

        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        powerModeStore.add(bundleId: bundleId, appName: appName, style: .casual)
    }

    private var styleDescription: String {
        switch DictationStyle(rawValue: dictationStyle) ?? .none {
        case .none:   return "Nur Füllwörter und Interpunktion korrigieren."
        case .formal: return "Umgangssprache wird in gehobene, höfliche Sprache umformuliert."
        case .casual: return "Lockerer Ton, knappe Sätze, Slang erlaubt."
        case .code:   return "Variablennamen in camelCase, keine Satzzeichen am Zeilenende, Code-Fences bei Blöcken."
        }
    }

    private func loadGroqAPIKey() {
        do {
            groqApiKey = try SecretsStore.groq.read() ?? ""
            groqKeyError = nil
        } catch {
            groqKeyError = "Keychain konnte nicht gelesen werden: \(error.localizedDescription)"
        }
    }

    private func saveGroqAPIKey(_ value: String) {
        do {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try SecretsStore.groq.deleteIfExists()
            } else {
                try SecretsStore.groq.save(trimmed)
            }
            UserDefaults.standard.removeObject(forKey: AppSettings.groqApiKey)
            groqKeyError = nil
        } catch {
            groqKeyError = "Keychain konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    private func runProbe() {
        probeTask?.cancel()
        probeStatus = .running
        let processor = LLMPostProcessor()
        let sample = "ähm also das ist ein kurzer test"
        probeTask = Task {
            let startedAt = Date()
            do {
                _ = try await processor.process(text: sample, style: .none)
                let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
                await MainActor.run {
                    probeStatus = .success(ms: ms)
                }
            } catch {
                await MainActor.run {
                    probeStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}
