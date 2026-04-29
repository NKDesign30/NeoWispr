import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class RecordingController {

    private(set) var state: RecordingState = .idle {
        didSet { onStateChange?(state) }
    }
    private(set) var lastTranscript: String = ""
    private(set) var errorMessage: String? = nil

    /// Im Command Mode (markierter Text + Voice-Befehl) haelt der Controller
    /// den Original-Selection-Kontext. `nil` wenn normaler Dictate-Flow.
    private(set) var commandContext: CommandContext? = nil

    struct CommandContext: Equatable {
        let selection: String
        let startedAt: Date
    }

    /// Called whenever state changes — used by FloatingPillPanel
    var onStateChange: (@MainActor (RecordingState) -> Void)?

    private let audioCapture: AudioCaptureModule
    private let sttPipeline: STTPipeline
    private let llmPostProcessor: LLMPostProcessor
    private let snippetEngine: SnippetEngine
    private let textInjector: TextInjector
    private let transcriptionStore: TranscriptionStore
    private let statsTracker: StatsTracker
    private let dictionaryStore: DictionaryStore
    private let powerModeStore: PowerModeStore

    init(
        audioCapture: AudioCaptureModule,
        sttPipeline: STTPipeline,
        llmPostProcessor: LLMPostProcessor,
        snippetEngine: SnippetEngine,
        textInjector: TextInjector,
        transcriptionStore: TranscriptionStore,
        statsTracker: StatsTracker,
        dictionaryStore: DictionaryStore,
        powerModeStore: PowerModeStore
    ) {
        self.audioCapture = audioCapture
        self.sttPipeline = sttPipeline
        self.llmPostProcessor = llmPostProcessor
        self.snippetEngine = snippetEngine
        self.textInjector = textInjector
        self.transcriptionStore = transcriptionStore
        self.statsTracker = statsTracker
        self.dictionaryStore = dictionaryStore
        self.powerModeStore = powerModeStore

        setupSilenceDetection()
    }

    /// Resolved DictationStyle basierend auf PowerMode + aktuelle App.
    /// PowerMode off -> DictationStyle.current aus Settings.
    /// PowerMode on + Rule für bundleId -> diese Rule.
    /// PowerMode on + keine Rule -> DictationStyle.current aus Settings.
    private func resolveStyleForActiveApp() -> DictationStyle {
        guard UserDefaults.standard.bool(forKey: AppSettings.powerModeEnabled) else {
            return DictationStyle.current
        }
        let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return powerModeStore.style(for: bundleId) ?? DictationStyle.current
    }

    private func setupSilenceDetection() {
        let threshold = Float(UserDefaults.standard.double(forKey: "silence_threshold").nonZeroOr(0.01))
        let timeout = UserDefaults.standard.double(forKey: "silence_timeout").nonZeroOr(3.0)

        audioCapture.configure(threshold: threshold, timeoutSeconds: timeout) { @Sendable [weak self] in
            let captured = self
            Task { @MainActor in
                guard let self = captured, case .recording = self.state else { return }
                // Im Hold-Mode kontrolliert der User Start/Stop manuell via Taste.
                // Command Mode ist immer Hold.
                if self.commandContext != nil { return }
                let mode = UserDefaults.standard.string(forKey: AppSettings.hotkeyMode) ?? "toggle"
                if mode == "hold" { return }
                await self.stopRecording()
            }
        }
    }

    func toggleRecording() async {
        switch state {
        case .idle:
            await startRecording()
        case .recording:
            await stopRecording()
        case .error:
            state = .idle
            await startRecording()
        default:
            break
        }
    }

    func startRecording() async {
        guard case .idle = state else { return }

        do {
            try audioCapture.start()
            state = .recording(startedAt: Date())
            errorMessage = nil
        } catch {
            await showStartFailure(error)
        }
    }

    /// Command Mode: Liest die aktuelle Selektion aus der fokussierten App, startet
    /// dann die Aufnahme für den Sprachbefehl. Nach stopRecording() wird der
    /// markierte Text mit dem Befehl an das LLM geschickt und die Selektion
    /// durch das Ergebnis ersetzt.
    func startCommand() async {
        guard case .idle = state else { return }
        guard UserDefaults.standard.bool(forKey: AppSettings.commandModeEnabled) else { return }

        // Selection lesen BEVOR wir aufnehmen — sonst verlieren wir Fokus.
        guard let selection = textInjector.getSelectedText(),
              !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .error("Kein markierter Text gefunden.")
            errorMessage = "Kein markierter Text gefunden."
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if case .error = state { state = .idle }
            return
        }

        commandContext = CommandContext(selection: selection, startedAt: Date())

        do {
            try audioCapture.start()
            state = .recording(startedAt: Date())
            errorMessage = nil
        } catch {
            commandContext = nil
            await showStartFailure(error)
        }
    }

    private func showStartFailure(_ error: Error) async {
        let message = userFacingStartError(error)
        state = .error(message)
        errorMessage = message
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if case .error = state {
            state = .idle
        }
    }

    private func userFacingStartError(_ error: Error) -> String {
        if case RecordingError.microphonePermissionDenied = error {
            return "Mikrofon-Zugriff fehlt"
        }
        return error.localizedDescription
    }

    func stopRecording() async {
        guard case .recording(let startedAt) = state else { return }

        state = .transcribing
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)

        // Command Mode: Separater Flow — Voice-Befehl auf Selektion anwenden.
        if let context = commandContext {
            await runCommandFlow(context: context, durationMs: durationMs)
            return
        }

        do {
            let wavURL = try audioCapture.stop()
            let rawText = try await sttPipeline.transcribe(wavURL: wavURL)
            let correctedText = dictionaryStore.apply(to: rawText)

            // LLM Post-Processing (opt-in) räumt Whisper-Fehler auf,
            // BEVOR Snippets matchen — sonst kann ein "Gira-Ticket" nie als
            // "/jira"-Trigger erkannt werden.
            let llmText: String
            if UserDefaults.standard.bool(forKey: AppSettings.llmEnabled) {
                state = .processing
                do {
                    llmText = try await llmPostProcessor.process(
                        text: correctedText,
                        style: resolveStyleForActiveApp(),
                        customVocabulary: dictionaryStore.llmVocabularyContext,
                        clipboardContext: clipboardContextForLLM(),
                        currentWindowContext: currentWindowContextForLLM()
                    )
                } catch {
                    NSLog("LLM post-processing failed: \(error.localizedDescription)")
                    llmText = correctedText
                }
            } else {
                llmText = correctedText
            }

            // Snippet-Expansion als letzter Schritt — operiert auf bereinigtem Text.
            let processedText = snippetEngine.expand(llmText)
            let rawForHistory: String? = (processedText == correctedText) ? nil : correctedText

            lastTranscript = processedText
            state = .injecting

            textInjector.inject(text: processedText)

            let wordCount = processedText.split(separator: " ").count
            let language = UserDefaults.standard.string(forKey: AppSettings.language) ?? "de"
            let frontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName

            let entry = TranscriptionEntry(
                id: UUID(),
                text: processedText,
                rawText: rawForHistory,
                timestamp: Date(),
                appName: frontmostApp,
                language: language,
                wordCount: wordCount,
                durationMs: durationMs
            )
            transcriptionStore.add(entry)
            statsTracker.track(wordCount: wordCount, durationMs: durationMs)

            state = .idle
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription

            // Nach Fehler nach kurzer Zeit zurück zu idle
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .error = state {
                state = .idle
            }
        }
    }

    // MARK: - Command Mode Flow

    private func runCommandFlow(context: CommandContext, durationMs: Int) async {
        defer { commandContext = nil }

        do {
            let wavURL = try audioCapture.stop()
            let voiceCommand = try await sttPipeline.transcribe(wavURL: wavURL)
            let cleanedCommand = dictionaryStore.apply(to: voiceCommand)

            state = .processing
            let transformed = try await llmPostProcessor.transform(
                text: context.selection,
                command: cleanedCommand
            )

            lastTranscript = transformed
            state = .injecting
            textInjector.replaceSelection(with: transformed)

            // Command Mode nicht in History/Stats — das ist ein Editor-Befehl, kein Diktat.
            _ = durationMs
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .error = state {
                state = .idle
            }
        }
    }

    private func currentWindowContextForLLM() -> String {
        let app = NSWorkspace.shared.frontmostApplication
        return [
            app?.localizedName.map { "App: \($0)" },
            app?.bundleIdentifier.map { "Bundle-ID: \($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private func clipboardContextForLLM() -> String? {
        guard UserDefaults.standard.bool(forKey: AppSettings.includeClipboardContext) else { return nil }
        guard let value = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty else {
            return nil
        }
        return String(value.prefix(2_000))
    }
}

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}
