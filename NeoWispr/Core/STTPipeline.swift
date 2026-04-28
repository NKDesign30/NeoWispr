import Foundation
@preconcurrency import FluidAudio
@preconcurrency import WhisperKit

actor STTPipeline {

    enum Provider: String {
        case whisperCLI = "whisper-cli"
        case whisperKit = "whisperkit"
        case parakeet = "parakeet"

        static var current: Provider {
            let raw = UserDefaults.standard.string(forKey: AppSettings.sttProvider) ?? "parakeet"
            return Provider(rawValue: raw) ?? .parakeet
        }
    }

    struct Config {
        let whisperCliPath: String
        let modelPath: String
        let language: String

        static func fromDefaults() -> Config {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("NeoWispr/models/ggml-base.bin")

            return Config(
                whisperCliPath: UserDefaults.standard.string(forKey: "whisper_cli_path")
                    ?? "/opt/homebrew/bin/whisper-cli",
                modelPath: UserDefaults.standard.string(forKey: "model_path")
                    ?? appSupport.path,
                language: UserDefaults.standard.string(forKey: "language") ?? "de"
            )
        }
    }

    private let config: Config
    private let timeoutSeconds: Double = 30
    private var whisperKit: WhisperKit?
    private var loadedWhisperKitModel: String?
    private var parakeetManager: AsrManager?
    private var parakeetLoadTask: Task<AsrManager, Error>?

    init(config: Config) {
        self.config = config
    }

    /// Dispatch basierend auf aktueller Provider-Auswahl in Settings.
    /// Bei WhisperKit-Fehler fällt automatisch auf whisper-cli zurück — wir verlieren
    /// lieber Neural-Engine-Speed als die Transkription.
    func transcribe(wavURL: URL) async throws -> String {
        let provider = Provider.current
        switch provider {
        case .whisperCLI:
            return try await transcribeViaCLI(wavURL: wavURL)
        case .whisperKit:
            do {
                return try await transcribeViaKit(wavURL: wavURL)
            } catch {
                NSLog("WhisperKit failed, falling back to whisper-cli: \(error.localizedDescription)")
                return try await transcribeViaCLI(wavURL: wavURL)
            }
        case .parakeet:
            do {
                return try await transcribeViaParakeet(wavURL: wavURL)
            } catch {
                NSLog("Parakeet failed, falling back to whisper-cli: \(error.localizedDescription)")
                return try await transcribeViaCLI(wavURL: wavURL)
            }
        }
    }

    // MARK: - whisper-cli (Subprocess)

    private func transcribeViaCLI(wavURL: URL) async throws -> String {
        defer {
            try? FileManager.default.removeItem(at: wavURL)
        }

        let currentConfig = Config.fromDefaults()
        let whisperPath = currentConfig.whisperCliPath
        guard FileManager.default.fileExists(atPath: whisperPath) else {
            throw STTError.whisperNotFound(whisperPath)
        }

        guard FileManager.default.fileExists(atPath: currentConfig.modelPath) else {
            throw STTError.modelNotFound(currentConfig.modelPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)
        process.arguments = [
            "--model", currentConfig.modelPath,
            "--language", currentConfig.language,
            "--output-txt",
            "--no-timestamps",
            "--no-prints",
            wavURL.path
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let timedOut = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await Task.detached(priority: .userInitiated) {
                    process.waitUntilExit()
                }.value
                return false
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(self.timeoutSeconds * 1_000_000_000))
                return true
            }

            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        if timedOut {
            process.terminate()
            throw STTError.timeout
        }

        guard process.terminationStatus == 0 else {
            let errorOutput = String(
                data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "Unknown error"
            throw STTError.whisperFailed(errorOutput)
        }

        let output = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw STTError.transcriptionEmpty
        }

        return trimmed
    }

    // MARK: - WhisperKit (Neural Engine, SPM)

    /// Erste Transkription laedt das Modell (~150 MB bei base) und cached die Instanz.
    /// Folgende Calls sind deutlich schneller — Neural Engine statt Process-Spawn.
    private func transcribeViaKit(wavURL: URL) async throws -> String {
        defer {
            try? FileManager.default.removeItem(at: wavURL)
        }

        let kit = try await ensureWhisperKit()
        let results = try await kit.transcribe(audioPath: wavURL.path)
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw STTError.transcriptionEmpty
        }
        return text
    }

    private func ensureWhisperKit() async throws -> WhisperKit {
        let modelName = UserDefaults.standard.string(forKey: AppSettings.whisperKitModel)
            ?? "openai_whisper-base"

        if let kit = whisperKit, loadedWhisperKitModel == modelName {
            return kit
        }

        let kit = try await WhisperKit(model: modelName)
        whisperKit = kit
        loadedWhisperKitModel = modelName
        return kit
    }

    /// Pre-warm: WhisperKit laden ohne zu transkribieren — ruft z.B. AppEnvironment
    /// beim Start auf wenn Provider "whisperkit" aktiv ist, damit das erste Diktat
    /// nicht den Modell-Download trägt.
    func prewarmWhisperKitIfNeeded() async {
        guard Provider.current == .whisperKit, whisperKit == nil else { return }
        _ = try? await ensureWhisperKit()
    }

    // MARK: - Parakeet via FluidAudio (lokal, VoiceInk-Parität)

    private func transcribeViaParakeet(wavURL: URL) async throws -> String {
        defer {
            try? FileManager.default.removeItem(at: wavURL)
        }

        let manager = try await ensureParakeetManager()
        var decoderState = TdtDecoderState.make()
        let result = try await manager.transcribe(
            wavURL,
            decoderState: &decoderState,
            language: fluidAudioLanguageHint()
        )
        let text = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw STTError.transcriptionEmpty
        }
        return text
    }

    private func ensureParakeetManager() async throws -> AsrManager {
        try await ensureParakeetManager(progressHandler: nil)
    }

    private func ensureParakeetManager(
        progressHandler: DownloadUtils.ProgressHandler?
    ) async throws -> AsrManager {
        if let parakeetManager { return parakeetManager }

        if let parakeetLoadTask {
            return try await parakeetLoadTask.value
        }

        let task = Task {
            let models = try await AsrModels.downloadAndLoad(
                version: .v3,
                progressHandler: progressHandler
            )
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            return manager
        }
        parakeetLoadTask = task

        do {
            let manager = try await task.value
            parakeetManager = manager
            parakeetLoadTask = nil
            return manager
        } catch {
            parakeetLoadTask = nil
            throw error
        }
    }

    func prewarmParakeetIfNeeded(progressHandler: DownloadUtils.ProgressHandler? = nil) async throws {
        guard Provider.current == .parakeet else { return }
        _ = try await ensureParakeetManager(progressHandler: progressHandler)
    }

    private func fluidAudioLanguageHint() -> Language? {
        switch UserDefaults.standard.string(forKey: AppSettings.language) ?? config.language {
        case "de":
            return .german
        case "en":
            return .english
        default:
            return nil
        }
    }
}
