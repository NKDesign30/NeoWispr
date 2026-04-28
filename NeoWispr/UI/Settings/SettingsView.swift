import SwiftUI

struct SettingsView: View {

    @Environment(PermissionGate.self) private var permissionGate

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("Allgemein", systemImage: "gearshape")
                }

            HotkeySettingsView()
                .tabItem {
                    Label("Hotkey", systemImage: "keyboard")
                }

            ModelSettingsView()
                .tabItem {
                    Label("Erkennung", systemImage: "waveform")
                }

            AISettingsView()
                .tabItem {
                    Label("KI", systemImage: "sparkles")
                }

            SnippetSettingsView()
                .tabItem {
                    Label("Ersetzungen", systemImage: "text.quote")
                }

            PermissionsSettingsView()
                .tabItem {
                    Label("Berechtigungen", systemImage: "lock.shield")
                }
        }
        .frame(width: 600, height: 500)
        .background(Neon.surfaceBackground)
        .preferredColorScheme(.dark)
        .tint(Neon.brandPrimary)
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {

    @AppStorage(AppSettings.language) private var language: String = "de"
    @AppStorage(AppSettings.autoStartEnabled) private var autoStartEnabled: Bool = false
    @AppStorage(AppSettings.silenceTimeout) private var silenceTimeout: Double = 3.0
    @AppStorage(AppSettings.silenceThreshold) private var silenceThreshold: Double = 0.01

    var body: some View {
        Form {
            Section {
                Picker("Erkennungssprache", selection: $language) {
                    Text("Deutsch").tag("de")
                    Text("Englisch").tag("en")
                    Text("Automatisch").tag("auto")
                }
                .pickerStyle(.menu)

                Toggle("Beim Anmelden starten", isOn: $autoStartEnabled)
            } header: {
                Text("Aufnahme").neonSectionHeader()
            }

            Section {
                LabeledContent("Stille-Timeout") {
                    HStack(spacing: 8) {
                        Slider(value: $silenceTimeout, in: 1.0...10.0, step: 0.5)
                            .frame(width: 120)
                        Text("\(silenceTimeout, specifier: "%.1f") Sek.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                LabeledContent("Stille-Schwellwert") {
                    HStack(spacing: 8) {
                        Slider(value: $silenceThreshold, in: 0.001...0.05, step: 0.001)
                            .frame(width: 120)
                        Text(String(format: "%.3f", silenceThreshold))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            } header: {
                Text("Automatisch stoppen").neonSectionHeader()
            } footer: {
                Text("Nach dieser Stille-Dauer wird die Aufnahme automatisch gestoppt.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Model Settings

private struct ModelSettingsView: View {

    @Environment(ParakeetModelStore.self) private var parakeetModelStore

    @AppStorage(AppSettings.modelPath) private var modelPath: String = ""
    @AppStorage(AppSettings.sttProvider) private var sttProvider: String = "parakeet"
    @AppStorage(AppSettings.whisperKitModel) private var whisperKitModel: String = "openai_whisper-base"

    @State private var selectedModelFile: String = "ggml-base.bin"
    @State private var download: DownloadState = .idle
    @State private var downloadTask: Task<Void, Never>?

    enum DownloadState: Equatable {
        case idle
        /// progress == nil wenn Total unbekannt (CDN-Redirect ohne Content-Length).
        /// receivedMB für Anzeige als Fallback.
        case downloading(progress: Double?, receivedMB: Double, filename: String)
        case failed(String)
    }

    private let availableModels = [
        ("ggml-tiny.bin", "Tiny (~75 MB) — Schnellste, niedrigste Qualität"),
        ("ggml-base.bin", "Base (~150 MB) — Empfohlen, <2s auf M1"),
        ("ggml-small.bin", "Small (~500 MB) — Bessere Qualität, ~2.5s"),
        ("ggml-medium.bin", "Medium (~1.5 GB) — Hohe Qualität, langsam"),
    ]

    private let whisperKitModels = [
        ("openai_whisper-tiny", "Tiny — Klein & schnell"),
        ("openai_whisper-base", "Base — Empfohlen (Standard)"),
        ("openai_whisper-small", "Small — Bessere Qualität"),
        ("openai_whisper-large-v3-turbo", "Large v3 Turbo — Beste Qualität"),
    ]

    var body: some View {
        Form {
            Section {
                Picker("STT-Provider", selection: $sttProvider) {
                    Text("Parakeet V3 (lokal, VoiceInk-Style)").tag("parakeet")
                    Text("WhisperKit (Neural Engine)").tag("whisperkit")
                    Text("whisper-cli (Subprocess)").tag("whisper-cli")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Transkriptions-Engine").neonSectionHeader()
            } footer: {
                if sttProvider == "parakeet" {
                    Text("Parakeet V3 läuft lokal über FluidAudio/CoreML und lädt das Modell beim ersten Einsatz. Das ist der VoiceInk-nahe Modus.")
                } else if sttProvider == "whisperkit" {
                    Text("WhisperKit nutzt die Neural Engine — kein brew/CLI nötig. Modelle werden beim ersten Start automatisch geladen (~150 MB für Base).")
                } else {
                    Text("whisper-cli spawnt whisper.cpp als Subprocess — robust und getestet, braucht `brew install whisper-cpp`.")
                }
            }

            if sttProvider == "whisperkit" {
                Section {
                    Picker("WhisperKit-Modell", selection: $whisperKitModel) {
                        ForEach(whisperKitModels, id: \.0) { model in
                            Text(model.1).tag(model.0)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("WhisperKit-Modell").neonSectionHeader()
                } footer: {
                    Text("Änderung greift beim nächsten Diktat. Modelle werden nach ~/Library/Application Support/argmaxinc/ gecached.")
                }
            }

            if sttProvider == "parakeet" {
                Section {
                    LabeledContent("Aktives Modell") {
                        Text("Parakeet V3")
                            .font(.system(size: 12, weight: .medium))
                    }

                    LabeledContent("Status") {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(parakeetStatusColor)
                                .frame(width: 6, height: 6)
                            Text(parakeetModelStore.label)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            if parakeetModelStore.isWorking {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }

                    if let progress = parakeetModelStore.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                    }

                    if case .failed = parakeetModelStore.status {
                        Button("Erneut laden") {
                            parakeetModelStore.refreshStatus()
                            parakeetModelStore.prewarmIfNeeded()
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("Parakeet V3").neonSectionHeader()
                } footer: {
                    Text(parakeetModelStore.detail)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if sttProvider == "whisper-cli" {
                Section {
                    LabeledContent("whisper-cli Pfad") {
                        Text("/opt/homebrew/bin/whisper-cli")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Picker("whisper.cpp-Modell", selection: $selectedModelFile) {
                        ForEach(availableModels, id: \.0) { model in
                            Text(model.1).tag(model.0)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedModelFile) { _, newFile in
                        applyModelSelection(filename: newFile)
                    }

                    if case .downloading(let progress, let receivedMB, let filename) = download {
                        downloadRow(progress: progress, receivedMB: receivedMB, filename: filename)
                    }

                    if case .failed(let msg) = download {
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }

                    LabeledContent("Modell-Pfad") {
                        HStack(spacing: 6) {
                            TextField("Pfad zum Modell", text: $modelPath)
                                .font(.system(size: 11, design: .monospaced))
                            Button {
                                chooseModelFile()
                            } label: {
                                Image(systemName: "folder")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    modelStatusRow
                } header: {
                    Text("whisper.cpp").neonSectionHeader()
                } footer: {
                    Text("Modelle werden automatisch gesucht in Homebrew und ~/Library/Application Support/NeoWispr/models/. Fehlende Modelle werden beim Umschalten von HuggingFace (~huggingface.co/ggerganov/whisper.cpp) nach App Support geladen.")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if modelPath.isEmpty || !FileManager.default.fileExists(atPath: modelPath) {
                modelPath = autoDetectModel() ?? ""
            }
            selectedModelFile = currentModelFilename()
            parakeetModelStore.refreshStatus()
            if sttProvider == "parakeet" {
                parakeetModelStore.prewarmIfNeeded()
            }
        }
        .onChange(of: sttProvider) { _, newProvider in
            if newProvider == "parakeet" {
                parakeetModelStore.refreshStatus()
                parakeetModelStore.prewarmIfNeeded()
            }
        }
        .onDisappear {
            downloadTask?.cancel()
        }
    }

    private var parakeetStatusColor: Color {
        switch parakeetModelStore.status {
        case .ready:
            return Neon.brandBright
        case .failed:
            return Neon.statusWarning
        case .unknown, .notDownloaded, .downloading, .loading:
            return Neon.brandPrimary
        }
    }

    /// Leitet aus dem aktuellen modelPath die Modell-Datei ab (fallback: base).
    private func currentModelFilename() -> String {
        let name = (modelPath as NSString).lastPathComponent
        return availableModels.contains { $0.0 == name } ? name : "ggml-base.bin"
    }

    // MARK: - Download-UI

    @ViewBuilder
    private func downloadRow(progress: Double?, receivedMB: Double, filename: String) -> some View {
        HStack(spacing: 10) {
            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text(String(format: "%.1f MB · %.1f%%", receivedMB, progress * 100))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 130, alignment: .trailing)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                Text(String(format: "%.1f MB", receivedMB))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            Button {
                downloadTask?.cancel()
                download = .idle
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    /// Wenn lokal vorhanden: nur modelPath setzen. Sonst Download nach App Support.
    private func applyModelSelection(filename: String) {
        let resolved = resolveModelPath(for: filename)
        if FileManager.default.fileExists(atPath: resolved) {
            modelPath = resolved
            download = .idle
            return
        }

        // Nicht lokal -> Download nach App Support
        let target = appSupportModelPath(for: filename)
        downloadTask?.cancel()
        downloadTask = Task {
            await downloadModel(filename: filename, to: target)
        }
    }

    private func downloadModel(filename: String, to targetPath: String) async {
        let urlString = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)"
        guard let url = URL(string: urlString) else {
            await MainActor.run { download = .failed("Ungültige URL") }
            return
        }

        // Zielordner anlegen
        let targetURL = URL(fileURLWithPath: targetPath)
        try? FileManager.default.createDirectory(
            at: targetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        await MainActor.run { download = .downloading(progress: nil, receivedMB: 0, filename: filename) }

        do {
            let (bytes, response) = try await URLSession.shared.bytes(from: url)
            // HuggingFace CDN-Redirect verliert oft den Content-Length-Header — dann Fallback auf MB-Zähler.
            let total = response.expectedContentLength > 0 ? response.expectedContentLength : -1
            var received: Int64 = 0
            var lastUpdate = Date()

            // Temporär in .partial schreiben, am Ende atomar verschieben.
            let partialURL = targetURL.appendingPathExtension("partial")
            FileManager.default.createFile(atPath: partialURL.path, contents: nil)
            guard let handle = try? FileHandle(forWritingTo: partialURL) else {
                await MainActor.run { download = .failed("Datei konnte nicht angelegt werden") }
                return
            }
            defer { try? handle.close() }

            var buffer = Data()
            buffer.reserveCapacity(64 * 1024)
            for try await byte in bytes {
                if Task.isCancelled {
                    try? handle.close()
                    try? FileManager.default.removeItem(at: partialURL)
                    await MainActor.run { download = .idle }
                    return
                }
                buffer.append(byte)
                received += 1
                if buffer.count >= 64 * 1024 {
                    try handle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                }
                if Date().timeIntervalSince(lastUpdate) > 0.2 {
                    let progress: Double? = total > 0 ? Double(received) / Double(total) : nil
                    let mb = Double(received) / 1_048_576.0
                    await MainActor.run {
                        download = .downloading(progress: progress, receivedMB: mb, filename: filename)
                    }
                    lastUpdate = Date()
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
            }
            try handle.close()

            try? FileManager.default.removeItem(at: targetURL)
            try FileManager.default.moveItem(at: partialURL, to: targetURL)

            await MainActor.run {
                modelPath = targetURL.path
                download = .idle
            }
        } catch {
            await MainActor.run {
                download = .failed("Download fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }

    @ViewBuilder
    private var modelStatusRow: some View {
        let exists = FileManager.default.fileExists(atPath: modelPath)
        LabeledContent("Status") {
            HStack(spacing: 6) {
                Circle()
                    .fill(exists ? Neon.brandBright : Neon.statusError)
                    .frame(width: 6, height: 6)
                Text(exists ? "Modell gefunden" : "Modell nicht gefunden")
                    .font(.system(size: 11))
                    .foregroundStyle(exists ? .primary : .secondary)
            }
        }
    }

    /// Auto-detect: Sucht das Modell in allen bekannten Pfaden.
    /// Reihenfolge: App Support → Homebrew symlink → Homebrew Cellar → /usr/local
    private func autoDetectModel() -> String? {
        let fm = FileManager.default
        let filename = "ggml-base.bin"

        let searchPaths = [
            // 1. App Support (User hat es manuell dort abgelegt)
            appSupportModelPath(for: filename),
            // 2. Homebrew symlink (standard auf Apple Silicon)
            "/opt/homebrew/share/whisper-cpp/\(filename)",
            // 3. Homebrew models/ Unterordner
            "/opt/homebrew/share/whisper-cpp/models/\(filename)",
            // 4. Intel Mac Homebrew
            "/usr/local/share/whisper-cpp/\(filename)",
            "/usr/local/share/whisper-cpp/models/\(filename)",
        ]

        // Exakte Treffer zuerst
        if let found = searchPaths.first(where: { fm.fileExists(atPath: $0) }) {
            return found
        }

        // Fallback: Homebrew Cellar durchsuchen (Version im Pfad)
        let cellarPaths = ["/opt/homebrew/Cellar/whisper-cpp", "/usr/local/Cellar/whisper-cpp"]
        for cellar in cellarPaths {
            guard let versions = try? fm.contentsOfDirectory(atPath: cellar) else { continue }
            for version in versions.sorted().reversed() {  // Neueste Version zuerst
                let path = "\(cellar)/\(version)/share/whisper-cpp/\(filename)"
                if fm.fileExists(atPath: path) { return path }
            }
        }

        return nil
    }

    /// Löst den Pfad für ein Modell auf — sucht in allen bekannten Locations.
    private func resolveModelPath(for filename: String) -> String {
        let fm = FileManager.default
        let candidates = [
            appSupportModelPath(for: filename),
            "/opt/homebrew/share/whisper-cpp/\(filename)",
            "/opt/homebrew/share/whisper-cpp/models/\(filename)",
            "/usr/local/share/whisper-cpp/\(filename)",
        ]
        if let found = candidates.first(where: { fm.fileExists(atPath: $0) }) {
            return found
        }
        // Cellar-Suche
        for cellar in ["/opt/homebrew/Cellar/whisper-cpp", "/usr/local/Cellar/whisper-cpp"] {
            guard let versions = try? fm.contentsOfDirectory(atPath: cellar) else { continue }
            for version in versions.sorted().reversed() {
                let path = "\(cellar)/\(version)/share/whisper-cpp/\(filename)"
                if fm.fileExists(atPath: path) { return path }
            }
        }
        return appSupportModelPath(for: filename)
    }

    private func appSupportModelPath(for filename: String) -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("NeoWispr/models/\(filename)")
            .path
    }

    private func chooseModelFile() {
        let panel = NSOpenPanel()
        panel.title = "Whisper-Modell auswählen"
        panel.allowedContentTypes = [.data]
        panel.allowsOtherFileTypes = true
        panel.message = "Wähle eine ggml-*.bin Datei aus"

        if panel.runModal() == .OK, let url = panel.url {
            modelPath = url.path
        }
    }
}
