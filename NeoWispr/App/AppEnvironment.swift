import AppKit
import SwiftUI

@Observable
@MainActor
final class AppEnvironment {

    let permissionGate = PermissionGate()
    let snippetEngine = SnippetEngine()
    let transcriptionStore: TranscriptionStore
    let statsTracker: StatsTracker
    let dictionaryStore: DictionaryStore
    let powerModeStore: PowerModeStore
    let parakeetModelStore: ParakeetModelStore
    let recordingController: RecordingController
    let hotkeyModule: HotkeyModule
    private(set) var floatingPill: FloatingPillPanel?

    init() {
        // Register defaults so Settings UI shows correct values
        Self.registerDefaults()
        Self.migrateVoiceInkDefaultsIfNeeded()
        SecretsStore.groq.migrateGroqAPIKeyFromUserDefaults()

        let audioCapture = AudioCaptureModule()
        let sttPipeline = STTPipeline(config: .fromDefaults())
        let llmPostProcessor = LLMPostProcessor()
        let textInjector = TextInjector()
        let ts = TranscriptionStore()
        let st = StatsTracker()
        let ds = DictionaryStore()
        let pm = PowerModeStore()
        let parakeetStore = ParakeetModelStore(sttPipeline: sttPipeline)

        self.transcriptionStore = ts
        self.statsTracker = st
        self.dictionaryStore = ds
        self.powerModeStore = pm
        self.parakeetModelStore = parakeetStore

        let controller = RecordingController(
            audioCapture: audioCapture,
            sttPipeline: sttPipeline,
            llmPostProcessor: llmPostProcessor,
            snippetEngine: snippetEngine,
            textInjector: textInjector,
            transcriptionStore: ts,
            statsTracker: st,
            dictionaryStore: ds,
            powerModeStore: pm
        )
        recordingController = controller

        let pill = FloatingPillPanel(recordingController: controller)
        self.floatingPill = pill

        // Show/hide floating pill on state changes
        controller.onStateChange = { @MainActor state in
            switch state {
            case .recording, .transcribing, .processing, .injecting:
                if !pill.isVisible { pill.show() }
            case .idle:
                pill.hide()
            case .error:
                if !pill.isVisible { pill.show() }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if case .error = controller.state {
                        pill.hide()
                    }
                }
            }
        }

        hotkeyModule = HotkeyModule()
        hotkeyModule.onPress = { @MainActor [weak controller] in
            Task { @MainActor in
                let mode = UserDefaults.standard.string(forKey: AppSettings.hotkeyMode) ?? "toggle"
                if mode == "hold" {
                    await controller?.startRecording()
                } else {
                    await controller?.toggleRecording()
                }
            }
        }
        hotkeyModule.onRelease = { @MainActor [weak controller] in
            Task { @MainActor in
                let mode = UserDefaults.standard.string(forKey: AppSettings.hotkeyMode) ?? "toggle"
                guard mode == "hold" else { return }
                await controller?.stopRecording()
            }
        }

        // Command Mode ist immer Hold — einfacher fürs Gehirn: halten solange Befehl.
        hotkeyModule.onCommandPress = { @MainActor [weak controller] in
            Task { @MainActor in
                guard UserDefaults.standard.bool(forKey: AppSettings.commandModeEnabled) else { return }
                await controller?.startCommand()
            }
        }
        hotkeyModule.onCommandRelease = { @MainActor [weak controller] in
            Task { @MainActor in
                guard UserDefaults.standard.bool(forKey: AppSettings.commandModeEnabled) else { return }
                await controller?.stopRecording()
            }
        }

        Task { @MainActor in
            await permissionGate.checkMicrophone()
            permissionGate.checkAccessibility()
            try? snippetEngine.load(from: SnippetStore.snippetsFileURL)
            // WhisperKit-Modell im Hintergrund laden, damit das erste Diktat nicht wartet.
            await sttPipeline.prewarmWhisperKitIfNeeded()
            parakeetStore.prewarmIfNeeded()
        }

        // Dashboard öffnen bei Launch und bei Dock-Klick (NSApplicationDelegateAdaptor postet die Notification).
        NotificationCenter.default.addObserver(
            forName: AppDelegate.openDashboardNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openDashboard()
            }
        }

        // Permission-Status refreshen wenn die App vom System-Einstellungen wieder aktiv wird.
        // So sieht der PermissionGate sofort wenn Niko in Settings den Toggle umlegt.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.permissionGate.refreshAll()
            }
        }
    }

    // MARK: - Defaults

    private static func registerDefaults() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NeoWispr/models/ggml-base.bin")

        // Also check Homebrew path directly
        let homebrewPath = "/opt/homebrew/share/whisper-cpp/ggml-base.bin"
        let defaultModelPath: String
        if FileManager.default.fileExists(atPath: appSupport.path) {
            defaultModelPath = appSupport.path
        } else if FileManager.default.fileExists(atPath: homebrewPath) {
            defaultModelPath = homebrewPath
        } else {
            defaultModelPath = appSupport.path
        }

        UserDefaults.standard.register(defaults: [
            "whisper_cli_path": "/opt/homebrew/bin/whisper-cli",
            "model_path": defaultModelPath,
            "language": "de",
            "silence_threshold": 0.01,
            "silence_timeout": 3.0,
            // STT
            AppSettings.sttProvider: "parakeet",
            AppSettings.whisperKitModel: "openai_whisper-base",
            // Hotkey
            AppSettings.hotkeyMode: "toggle",
            AppSettings.commandModeEnabled: false,
            // LLM Post-Processing — Standard ist Groq (kostenlos via Free Tier, schnelle LPU-Inferenz)
            AppSettings.llmEnabled: false,
            AppSettings.llmProvider: "groq",
            AppSettings.groqModel: "llama-3.3-70b-versatile",
            AppSettings.dictationStyle: DictationStyle.none.rawValue,
            AppSettings.llmAutoDisableOnError: true,
            AppSettings.powerModeEnabled: false,
            AppSettings.removeFillerWords: false,
            AppSettings.customPrompt: "",
            AppSettings.includeClipboardContext: true,
        ])
    }

    private static func migrateVoiceInkDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: AppSettings.voiceInkDefaultsMigrated) else { return }

        let currentProvider = UserDefaults.standard.string(forKey: AppSettings.sttProvider)
        if currentProvider == nil || currentProvider == "whisper-cli" {
            UserDefaults.standard.set("parakeet", forKey: AppSettings.sttProvider)
        }

        UserDefaults.standard.set(true, forKey: AppSettings.voiceInkDefaultsMigrated)
    }

    // MARK: - Dashboard Window

    /// `@ObservationIgnored` + `weak` so the @Observable macro doesn't generate a
    /// computed getter that retains a freed NSWindow reference (the cause of the
    /// `dashboardWindow.getter` segfaults during Cmd+Tab / Dock reopen).
    @ObservationIgnored
    private weak var dashboardWindow: NSWindow?

    func openDashboard() {
        if let existing = dashboardWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = DashboardView()
            .environment(self)
            .environment(recordingController)
            .environment(transcriptionStore)
            .environment(statsTracker)
            .environment(dictionaryStore)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 620),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Programmatic NSWindow: Default ist isReleasedWhenClosed=true. Cmd+W würde das Window
        // deallocaten, der weak-Ref wäre dangling während die Close-Animation noch läuft —
        // genau das Pattern aus dem _NSWindowTransformAnimation Crash.
        window.isReleasedWhenClosed = false
        window.title = "NeoWispr"
        window.contentView = NSHostingView(rootView: content)

        // Native Mac-App Polish: dezente Title-Bar, unified Toolbar, persistente Größe/Position.
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .automatic
        window.toolbarStyle = .unified
        window.collectionBehavior = [.fullScreenPrimary]

        // Window-State persistieren — Position + Größe bleiben über App-Neustarts erhalten.
        window.setFrameAutosaveName("NeoWisprDashboardWindow")
        if !window.setFrameUsingName("NeoWisprDashboardWindow") {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        dashboardWindow = window
    }
}
