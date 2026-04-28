# NeoWispr — Architektur-Dokument

> Stand: 2026-03-20 | Autor: Rex (System Architect)
> macOS 14.0+ (Sonoma) | Swift 6 | SwiftUI | LSUIElement = true

---

## 1. System-Überblick

NeoWispr ist eine **lokale, offline-first Menübar-App** für Diktat auf macOS. Kein Server, kein Account, kein Cloud-Upload. Der Datenfluss ist bewusst linear gehalten: Mikrofon-Input → lokale Transkription → Text-Output ins aktive Fenster.

### Design-Philosophie

- **Boring & Reliable**: AVAudioEngine + Process + Pasteboard. Kein Framework-Overhead.
- **Stateless Audio Pipeline**: Jede Aufnahme ist eine isolierte Session. Kein geteilter State zwischen Aufnahmen.
- **Permission-First**: App startet nicht ohne Mikrofon-Permission. Accessibility ist optional aber sauber degradiert.
- **<2 Sekunden Ende-zu-Ende**: Stop-Recording → Text im Fenster. Erreichbar auf M1 mit whisper-base.

---

## 2. Modul-Diagramm

```
┌─────────────────────────────────────────────────────────────────┐
│                        NeoWisprApp                              │
│                    (App Entry Point)                            │
└─────────────────────────┬───────────────────────────────────────┘
                          │ owns
          ┌───────────────┼───────────────────┐
          │               │                   │
          ▼               ▼                   ▼
┌─────────────────┐ ┌──────────────┐ ┌────────────────────┐
│  MenuBarModule  │ │ SettingsView │ │  HotkeyModule      │
│                 │ │              │ │                    │
│ NSStatusItem    │ │ SwiftUI      │ │ CGEventTap (global)│
│ MenuBarExtra    │ │ @AppStorage  │ │                    │
└────────┬────────┘ └──────────────┘ └────────┬───────────┘
         │                                     │
         │ listens to                          │ triggers
         │                                     ▼
         │                        ┌────────────────────────┐
         │                        │   RecordingController  │
         │◄── observes ───────────│   @Observable          │
         │                        │   (Central State)      │
         │                        └──────────┬─────────────┘
         │                                   │
         │                    ┌──────────────┼──────────────┐
         │                    │              │              │
         │                    ▼              ▼              ▼
         │         ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
         │         │ AudioCapture │  │  STTPipeline │  │TextInjector  │
         │         │ Module       │  │  Module      │  │Module        │
         │         │              │  │              │  │              │
         │         │ AVAudioEngine│  │Process spawn │  │ Pasteboard + │
         │         │ Buffer Mgmt  │  │whisper-cli   │  │ CGEvent paste│
         │         │ Silence Det. │  │              │  │              │
         │         └──────────────┘  └──────────────┘  └──────────────┘
         │                                   │
         │                                   ▼
         │                        ┌────────────────────────┐
         │                        │   SnippetEngine        │
         │                        │                        │
         │                        │ Pattern Matching       │
         │                        │ Text Expansion         │
         │                        └────────────────────────┘
         │
         ▼
┌─────────────────┐
│ PermissionGate  │
│                 │
│ Mikrofon Check  │
│ Accessibility   │
│ Check           │
└─────────────────┘
```

---

## 3. Datenfluss (Ende-zu-Ende)

```
[User drückt Cmd+Shift+D]
        │
        ▼
HotkeyModule.handleKeyEvent()
        │ RecordingState == .idle?
        ▼
RecordingController.startRecording()
        │
        ├─► AudioCaptureModule.start()
        │       │
        │       AVAudioEngine.start()
        │       AVAudioInputNode.installTap(bufferSize: 4096)
        │       Buffer → [Float] PCM-Daten sammeln
        │       SilenceDetector: RMS < threshold > 3s → auto-stop
        │
[User drückt Cmd+Shift+D erneut ODER Silence-Timeout]
        │
        ▼
RecordingController.stopRecording()
        │
        ├─► AudioCaptureModule.stop()
        │       │
        │       AVAudioFile nach /tmp/neowispr-{uuid}.wav schreiben
        │       (16kHz, mono, PCM — whisper.cpp erwartet das)
        │
        ├─► STTPipeline.transcribe(url: wavURL, language: .de)
        │       │
        │       Process: /opt/homebrew/bin/whisper-cli \
        │                --model /path/to/ggml-base.bin \
        │                --language de \
        │                --output-txt \
        │                --no-prints \
        │                /tmp/neowispr-{uuid}.wav
        │       │
        │       stdout parsen → String
        │       Temp-Datei löschen
        │
        ├─► SnippetEngine.expand(text: rawTranscript)
        │       │
        │       Pattern-Matching: "meine adresse" → expandieren
        │       Return: finalText
        │
        ├─► TextInjector.paste(text: finalText)
        │       │
        │       1. UIPasteboard/NSPasteboard.general.string = finalText
        │       2a. Accessibility API verfügbar → AXUIElement setValue
        │       2b. Fallback → CGEvent(keyboardEventSource: .cmdV)
        │
        ▼
[Text erscheint im aktiven Fenster]
```

### Timing-Budget (Ziel: <2 Sekunden)

| Phase | Budget | Methode |
|-------|--------|---------|
| Audio-Flush + WAV-Export | ~50ms | AVAudioFile async |
| Process-Start + whisper-cli | ~1200ms | base.bin, M1 |
| Snippet-Matching | ~1ms | Dictionary Lookup |
| Clipboard + CGEvent paste | ~50ms | |
| **Total** | **~1300ms** | Gut im Budget |

> Mit `ggml-base.bin` (~150MB) realistisch auf M1. `ggml-small.bin` (~500MB) braucht ~2.5s — dann Ziel verfehlt. Default: base.

---

## 4. State Management

### Zentraler State: `RecordingController`

```swift
// RecordingController.swift
@Observable
final class RecordingController {

    // MARK: - Public State (MenuBar observiert das)
    private(set) var state: RecordingState = .idle
    private(set) var lastTranscript: String = ""
    private(set) var errorMessage: String? = nil

    // MARK: - Dependencies (injiziert, nicht intern erzeugt)
    private let audioCapture: AudioCaptureModule
    private let sttPipeline: STTPipeline
    private let snippetEngine: SnippetEngine
    private let textInjector: TextInjector

    // MARK: - Actions
    @MainActor
    func toggleRecording() async { ... }

    @MainActor
    func startRecording() async throws { ... }

    @MainActor
    func stopRecording() async { ... }
}

enum RecordingState {
    case idle
    case recording(startedAt: Date)
    case transcribing
    case injecting
    case error(RecordingError)
}
```

### State-Flow-Regeln

1. `RecordingController` ist **@Observable** — SwiftUI beobachtet es direkt, kein `@Published` nötig (Swift 6).
2. State-Mutationen **nur** auf `@MainActor` — kein Race Condition möglich.
3. Audio-Capture und STT-Pipeline laufen auf **Background-Tasks**, schreiben aber nur via `await MainActor.run { }` in den State.
4. `SnippetEngine` und `TextInjector` sind **synchron** — zu schnell für async overhead.

### Settings: AppStorage (kein SwiftData)

```swift
// AppSettings.swift — kein Singleton, kein @EnvironmentObject
// Direkt @AppStorage in Views oder Settings-ViewModel

struct AppSettings {
    static let hotkey = "hotkey"                     // "cmd+shift+d"
    static let modelPath = "model_path"              // "/path/to/ggml-base.bin"
    static let language = "language"                 // "de" | "en"
    static let autoStartEnabled = "auto_start"       // Bool
    static let silenceThreshold = "silence_threshold" // Float (0.01)
    static let silenceTimeout = "silence_timeout"    // Double (3.0 seconds)
}
```

**Begründung für UserDefaults/AppStorage statt SwiftData**: Snippets sind flach (String → String), Settings sind primitive Typen. SwiftData-Overhead ist hier reine Komplexität ohne Nutzen. SwiftData lohnt sich erst wenn Relations oder Queries nötig sind.

### Snippets: JSON-Datei

```swift
// ~/Library/Application Support/NeoWispr/snippets.json
// [{"trigger": "meine adresse", "expansion": "Musterstraße 1, 12345 Berlin"}]

struct Snippet: Codable, Identifiable {
    let id: UUID
    var trigger: String      // lowercase, wird immer lowercased verglichen
    var expansion: String
}
```

---

## 5. Concurrency-Strategie

```
MainActor (UI Thread)
├── RecordingController (State)
├── MenuBarView
├── SettingsView
└── HotkeyModule.eventCallback (kurz, nur toggleRecording() aufrufen)

Background Task (unstructured, Task { })
├── AudioCaptureModule.captureLoop()   — AVAudioEngine callbacks
├── STTPipeline.transcribe()           — Process.launch() + stdout lesen
└── TextInjector.paste()               — CGEvent dispatch (kurz, kann auf Main sein)
```

### Konkrete Regeln

```swift
// RICHTIG: Background Task → MainActor für State
func transcribe(url: URL) async throws -> String {
    // Läuft im aufrufenden Task-Context (Background)
    let process = Process()
    // ... setup ...
    try process.run()
    process.waitUntilExit()

    let result = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return result
    // State-Update passiert im Caller auf @MainActor
}

// RICHTIG: AVAudioEngine Tap → Daten sammeln, State nur auf MainActor
node.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
    guard let self else { return }
    self.audioBuffers.append(buffer) // nur lokales Buffer-Array, kein @Observable zugriff
}
```

### Was NIE auf MainActor läuft

- `Process.waitUntilExit()` — blockiert! Immer in `Task { }` oder eigenen Thread
- `AVAudioEngine.start()` — kann auf Any-Thread, aber AVAudioEngine-Callbacks kommen auf eigenen Thread
- Datei-I/O (WAV schreiben, Temp-Datei löschen)

---

## 6. Audio Pipeline — Details

### AVAudioEngine Setup

```swift
// AudioCaptureModule.swift
final class AudioCaptureModule {
    private let engine = AVAudioEngine()
    private var audioBuffers: [AVAudioPCMBuffer] = []

    // whisper.cpp erwartet: 16kHz, mono, Float32 PCM
    private let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    func start() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Format-Konvertierung: Hardware-Format → 16kHz mono
        guard let converter = AVAudioConverter(from: inputFormat, to: whisperFormat) else {
            throw AudioError.formatConversionFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer, converter: converter)
        }

        try engine.start()
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * whisperFormat.sampleRate / buffer.format.sampleRate
        )
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: whisperFormat,
            frameCapacity: frameCapacity
        ) else { return }

        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if error == nil {
            audioBuffers.append(convertedBuffer)
            checkSilence(convertedBuffer)
        }
    }

    func stop() throws -> URL {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return try writeToWAV()
    }
}
```

### Silence Detection

```swift
// SilenceDetector.swift
struct SilenceDetector {
    let threshold: Float       // Default: 0.01 (RMS-Wert)
    let timeoutSeconds: Double // Default: 3.0

    private var silenceStart: Date? = nil

    mutating func process(buffer: AVAudioPCMBuffer) -> Bool {
        let rms = calculateRMS(buffer: buffer)

        if rms < threshold {
            if silenceStart == nil {
                silenceStart = Date()
            } else if Date().timeIntervalSince(silenceStart!) > timeoutSeconds {
                return true // → Auto-Stop
            }
        } else {
            silenceStart = nil
        }
        return false
    }

    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        return sqrt(sum / Float(frameLength))
    }
}
```

### WAV Export

```swift
private func writeToWAV() throws -> URL {
    let tempURL = FileManager.default
        .temporaryDirectory
        .appendingPathComponent("neowispr-\(UUID().uuidString).wav")

    let outputFile = try AVAudioFile(
        forWriting: tempURL,
        settings: whisperFormat.settings
    )

    for buffer in audioBuffers {
        try outputFile.write(from: buffer)
    }

    audioBuffers.removeAll() // Memory freigeben
    return tempURL
}
```

---

## 7. whisper.cpp Integration: Process vs. C-Binding

### Entscheidung: Process Spawning (CLI)

**Nicht** C-Binding (libwhisper.dylib direkt via Swift).

| Kriterium | Process Spawn | C-Binding |
|-----------|---------------|-----------|
| Implementierungsaufwand | 20 Zeilen | ~200 Zeilen Bridging Header + unsafe Swift |
| Absturz-Isolation | Crash in whisper isoliert vom App-Prozess | Crash killt App |
| Update whisper.cpp | `brew upgrade whisper-cpp` | Neu kompilieren |
| Performance-Overhead | ~50ms Startup | ~0ms |
| Memory | Eigener Prozess, gibt frei | In App-Heap |
| **Urteil** | **Wählen** | Skip |

**Begründung**: 50ms Process-Startup sind im 1300ms Budget irrelevant. Absturz-Isolation ist bei nativer Bibliothek im App-Prozess ein echtes Risiko (whisper.cpp ist C-Code, kann segfaulten). Process Spawn ist die reversible, wartbare Entscheidung.

### STTPipeline Implementation

```swift
// STTPipeline.swift
actor STTPipeline {

    struct Config {
        let whisperCliPath: String    // "/opt/homebrew/bin/whisper-cli"
        let modelPath: String         // "~/Library/Application Support/NeoWispr/models/ggml-base.bin"
        let language: String          // "de" | "en" | "auto"
    }

    private let config: Config

    func transcribe(wavURL: URL) async throws -> String {
        defer {
            try? FileManager.default.removeItem(at: wavURL) // Temp-Datei immer löschen
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: config.whisperCliPath)
        process.arguments = [
            "--model", config.modelPath,
            "--language", config.language,
            "--output-txt",     // Text-Output statt JSON (einfacher zu parsen)
            "--no-timestamps",  // Keine [00:00:00] Prefixes
            "--no-prints",      // Kein Modell-Loading-Output auf stderr
            wavURL.path
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // waitUntilExit in async context — blockiert, aber wir sind in einem Actor/Task
        await Task.detached(priority: .userInitiated) {
            process.waitUntilExit()
        }.value

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

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

> **Warum `actor` statt `class`?** STTPipeline darf nur einen Process gleichzeitig spawnen. Actor garantiert das ohne Locks.

### Modell-Management

```
~/Library/Application Support/NeoWispr/
└── models/
    ├── ggml-base.bin      (~150MB, Default — <2s auf M1)
    └── ggml-small.bin     (~500MB, optional — bessere Qualität, ~2.5s)
```

Modell-Download beim ersten Start via HTTPS direkt von `huggingface.co/ggerganov/whisper.cpp` — kein eigener Server nötig.

---

## 8. Text Injection

### Strategie: Pasteboard + CGEvent Fallback

```swift
// TextInjector.swift
@MainActor
struct TextInjector {

    enum InjectionMethod {
        case accessibility    // Via AXUIElement (beste Methode)
        case pasteboardEvent  // Via Clipboard + Cmd+V simulieren (Fallback)
    }

    func inject(text: String) {
        // Vorherigen Clipboard-Inhalt merken
        let previousContent = NSPasteboard.general.string(forType: .string)

        // Text in Clipboard schreiben
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        // Accessibility-Methode versuchen
        if PermissionGate.hasAccessibilityPermission,
           let focusedElement = getFocusedElement() {
            injectViaAccessibility(text: text, element: focusedElement)
        } else {
            // Fallback: Cmd+V Event simulieren
            simulatePaste()
        }

        // Kurze Verzögerung, dann Clipboard wiederherstellen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let previous = previousContent {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(previous, forType: .string)
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)

        guard let app = focusedApp else { return nil }
        var focusedElement: CFTypeRef?
        AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        return focusedElement as! AXUIElement?
    }

    private func injectViaAccessibility(text: String, element: AXUIElement) {
        // Aktuellen Value lesen und Text anhängen
        var currentValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)

        let existing = (currentValue as? String) ?? ""
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, (existing + text) as CFString)
    }
}
```

---

## 9. Permission Handling

### PermissionGate

```swift
// PermissionGate.swift
@Observable
final class PermissionGate {

    private(set) var microphoneStatus: PermissionStatus = .unknown
    private(set) var accessibilityStatus: PermissionStatus = .unknown

    enum PermissionStatus {
        case unknown, granted, denied, restricted
    }

    // Mikrofon: PFLICHT — App startet Recording nicht ohne das
    @MainActor
    func checkMicrophone() async {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .granted
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphoneStatus = granted ? .granted : .denied
        case .denied, .restricted:
            microphoneStatus = .denied
        @unknown default:
            microphoneStatus = .denied
        }
    }

    // Accessibility: OPTIONAL — Text-Injection funktioniert via Clipboard-Fallback
    @MainActor
    func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        accessibilityStatus = trusted ? .granted : .denied
    }

    // Accessibility-Permission anfordern (User-Prompt öffnet Systemeinstellungen)
    @MainActor
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    var canRecord: Bool {
        microphoneStatus == .granted
    }

    var hasAccessibilityPermission: Bool {
        accessibilityStatus == .granted
    }
}
```

### Graceful Degradation

```
Mikrofon denied
    → RecordingButton disabled
    → "Mikrofon-Zugriff erforderlich" Banner in MenuBar
    → Klick öffnet Systemeinstellungen → Datenschutz

Accessibility denied
    → Alles funktioniert, aber via Clipboard-Fallback (Cmd+V)
    → Settings zeigt "Accessibility für direktes Einfügen aktivieren"
    → Kein Banner, kein Fehler — nur weniger elegant
```

---

## 10. Globaler Hotkey

```swift
// HotkeyModule.swift
// CGEventTap — einzige zuverlässige Methode für systemweite Hotkeys in macOS 14+
// Alternative MASShortcut ist ein Dependency, Carbon ist deprecated

final class HotkeyModule {

    private var eventTap: CFMachPort?
    private let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    func register(hotkey: KeyCombo) {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let module = Unmanaged<HotkeyModule>.fromOpaque(refcon).takeUnretainedValue()

                if module.matches(event: event) {
                    DispatchQueue.main.async { module.callback() }
                    return nil // Event konsumieren (nicht weiterleiten)
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func matches(event: CGEvent) -> Bool {
        // Hotkey-Matching aus UserDefaults laden
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        // TODO: aus AppSettings lesen
        return keyCode == 0x02 && flags.contains([.maskCommand, .maskShift]) // Cmd+Shift+D
    }
}

struct KeyCombo {
    let keyCode: Int64
    let modifiers: CGEventFlags
}
```

> **Wichtig**: CGEventTap braucht **Accessibility Permission**, um systemweite Events zu intercepten. Ohne Accessibility-Permission nur App-interne Hotkeys möglich (KeyboardShortcut in SwiftUI). Das muss dem User klar kommuniziert werden.

---

## 11. Snippet Engine

```swift
// SnippetEngine.swift
// Bewusst einfach: Dictionary-Lookup, O(n) über Snippets, reicht für <100 Einträge

final class SnippetEngine {

    private var snippets: [String: String] = [:]  // trigger → expansion

    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let items = try JSONDecoder().decode([Snippet].self, from: data)
        snippets = Dictionary(
            items.map { ($0.trigger.lowercased(), $0.expansion) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func expand(_ text: String) -> String {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exakter Match: ganzer Text ist ein Snippet-Trigger
        if let expansion = snippets[lowercased] {
            return expansion
        }

        // Partieller Match: letzte Worte sind ein Trigger
        // "Hallo, meine adresse ist" → "Hallo, Musterstraße 1, 12345 Berlin ist"
        var result = text
        for (trigger, expansion) in snippets {
            if let range = result.range(of: trigger, options: [.caseInsensitive, .backwards]) {
                result.replaceSubrange(range, with: expansion)
                break // Nur ersten Match ersetzen
            }
        }

        return result
    }
}
```

---

## 12. KI-Verbesserung (Optional, Phase 2)

```swift
// AIEnhancer.swift — wird in RecordingController nach SnippetEngine eingeklinkt
// Nutzt claude -p haiku (Max Plan, kein API-Key nötig)

actor AIEnhancer {

    enum Mode {
        case off
        case correctOnly    // Nur Fehler korrigieren
        case improve        // Stil verbessern
        case formal         // Formalisieren
    }

    func enhance(text: String, mode: Mode) async throws -> String {
        guard mode != .off else { return text }

        let prompt = buildPrompt(for: mode, text: text)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")
        process.arguments = ["-p", "--model", "claude-haiku-4-5-20251001", prompt]

        // Gleiche Process-Pattern wie STTPipeline
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()

        return String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? text
    }
}
```

**Timing-Hinweis**: claude -p Haiku braucht ~500ms–1s (Netzwerk). Damit überschreiten wir das 2s-Ziel. Lösung: KI-Verbesserung ist **asynchron optional** — Text wird sofort eingefügt, verbesserter Text kann per Notification angeboten werden ("Verbesserte Version verfügbar → Ersetzen?").

---

## 13. Ordner-Struktur (Xcode-Projekt)

```
NeoWispr/
├── NeoWispr.xcodeproj/
├── NeoWispr/
│   ├── App/
│   │   ├── NeoWisprApp.swift          // @main, App Entry Point
│   │   └── AppEnvironment.swift       // DI: alle Module instanziieren + verbinden
│   │
│   ├── Core/
│   │   ├── RecordingController.swift  // @Observable, zentraler State
│   │   ├── AudioCaptureModule.swift   // AVAudioEngine, Buffer, WAV Export
│   │   ├── STTPipeline.swift          // actor, whisper-cli Process
│   │   ├── TextInjector.swift         // Pasteboard + CGEvent
│   │   ├── SnippetEngine.swift        // Pattern Matching, JSON Load
│   │   └── SilenceDetector.swift      // RMS-Berechnung, Timeout
│   │
│   ├── Hotkey/
│   │   ├── HotkeyModule.swift         // CGEventTap Registration
│   │   └── KeyCombo.swift             // Struct für Hotkey-Konfiguration
│   │
│   ├── Permissions/
│   │   └── PermissionGate.swift       // @Observable, Mikrofon + Accessibility
│   │
│   ├── UI/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarView.swift      // MenuBarExtra Content
│   │   │   └── StatusIcon.swift       // NSStatusItem Icon (idle/recording/transcribing)
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift     // Haupt-Settings Tab-View
│   │   │   ├── HotkeySettingsView.swift
│   │   │   ├── ModelSettingsView.swift
│   │   │   ├── SnippetSettingsView.swift
│   │   │   └── PermissionsSettingsView.swift
│   │   └── Overlays/
│   │       └── RecordingIndicatorView.swift // Floating Overlay (optional, Phase 2)
│   │
│   ├── Models/
│   │   ├── Snippet.swift              // Codable, Identifiable
│   │   ├── RecordingState.swift       // Enum
│   │   └── AppError.swift             // RecordingError, STTError, AudioError
│   │
│   ├── Storage/
│   │   └── SnippetStore.swift         // JSON Load/Save in Application Support
│   │
│   └── Resources/
│       ├── Assets.xcassets/
│       └── Info.plist
│
└── docs/
    └── architecture.md               // dieses Dokument
```

---

## 14. App Entry Point & DI

```swift
// NeoWisprApp.swift
@main
struct NeoWisprApp: App {

    @State private var env = AppEnvironment()

    var body: some Scene {
        MenuBarExtra("NeoWispr", systemImage: statusIcon) {
            MenuBarView()
                .environment(env.recordingController)
                .environment(env.permissionGate)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(env.recordingController)
                .environment(env.snippetEngine)
                .environment(env.permissionGate)
        }
    }

    private var statusIcon: String {
        switch env.recordingController.state {
        case .idle:          return "mic"
        case .recording:     return "mic.fill"
        case .transcribing:  return "waveform"
        case .injecting:     return "checkmark.circle"
        case .error:         return "exclamationmark.triangle"
        }
    }
}

// AppEnvironment.swift — zentrales DI
@Observable
final class AppEnvironment {

    let permissionGate = PermissionGate()
    let snippetEngine = SnippetEngine()
    let hotkeyModule: HotkeyModule
    let recordingController: RecordingController

    init() {
        let audioCapture = AudioCaptureModule()
        let sttPipeline = STTPipeline(config: .fromAppStorage())
        let textInjector = TextInjector()

        recordingController = RecordingController(
            audioCapture: audioCapture,
            sttPipeline: sttPipeline,
            snippetEngine: snippetEngine,
            textInjector: textInjector
        )

        hotkeyModule = HotkeyModule {
            Task { @MainActor in
                await recordingController.toggleRecording()
            }
        }

        Task { @MainActor in
            await permissionGate.checkMicrophone()
            permissionGate.checkAccessibility()
            hotkeyModule.register(hotkey: .fromAppStorage())
            try? snippetEngine.load(from: .snippetsFile)
        }
    }
}
```

---

## 15. Info.plist Keys

```xml
<!-- Pflicht-Entries -->
<key>LSUIElement</key>
<true/>                          <!-- Kein Dock-Icon -->

<key>NSMicrophoneUsageDescription</key>
<string>NeoWispr benötigt Mikrofon-Zugriff für Diktat.</string>

<key>NSAppleEventsUsageDescription</key>
<string>NeoWispr nutzt Accessibility für direktes Text-Einfügen.</string>

<!-- Autostart via LaunchAgent (separat, nicht SMAppService für maximale Kompatibilität) -->
<!-- ~/Library/LaunchAgents/de.neon.neowispr.plist -->
```

---

## 16. Erweiterbarkeit (wie fügen wir KI hinzu?)

Das System ist als **Pipeline** designed — neue Schritte lassen sich zwischen SnippetEngine und TextInjector einklinken:

```swift
// RecordingController.stopRecording() — Pipeline-Erweiterung
let rawText = try await sttPipeline.transcribe(wavURL: wavURL)
let expandedText = snippetEngine.expand(rawText)

// Phase 2: AI-Schritt optional einklinken
let finalText: String
if aiEnhancer.isEnabled {
    finalText = try await aiEnhancer.enhance(expandedText, mode: .correctOnly)
} else {
    finalText = expandedText
}

await textInjector.inject(text: finalText)
```

Kein Refactoring nötig. Kein Interface gebrochen. Pipeline wächst linear.

---

## 17. ADR-Zusammenfassung

| Entscheidung | Gewählt | Verworfen | Grund |
|---|---|---|---|
| whisper.cpp Integration | Process Spawn | C-Binding | Absturz-Isolation, einfachere Updates |
| State Management | @Observable | Combine/ObservableObject | Swift 6 Standard, kein Boilerplate |
| Settings Persistence | UserDefaults/@AppStorage | SwiftData, CoreData | Primitive Typen, kein Overhead nötig |
| Snippets Persistence | JSON-Datei | UserDefaults, SwiftData | Strukturierte Liste, menschenlesbar, einfach editierbar |
| Text Injection | Pasteboard+CGEvent | Pure Accessibility API | Accessibility optional, Fallback immer nötig |
| Hotkey System | CGEventTap | Carbon Hotkey, MASShortcut | Carbon deprecated, Dependency vermieden |
| MenuBar | MenuBarExtra (SwiftUI) | NSStatusItem+AppKit | SwiftUI-nativ, macOS 13+ Standard |
| Concurrency | async/await + Actor | DispatchQueue + Locks | Swift 6, sicherer Concurrency |
| KI-Verbesserung | Phase 2, async optional | Synchron im Pipeline | <2s Ziel einhalten, Erweiterung non-breaking |

---

## 18. Risiken & Mitigations

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|--------------------|---------|----|
| whisper-cli nicht installiert | Mittel | Hoch | Beim Start prüfen, Download-Anleitung im Onboarding |
| Falsches Modell-Format | Niedrig | Hoch | Modell-Validierung beim Laden (Magic Bytes checken) |
| CGEventTap wird vom System geblockt | Niedrig | Hoch | Accessibility-Permission-Check vor Registration |
| Clipboard-Clash (User kopiert gleichzeitig) | Niedrig | Mittel | 300ms Restore-Delay + User Communication |
| AVAudioEngine Format-Mismatch | Niedrig | Hoch | Format-Converter immer einsetzen (nie direkter Tap) |
| macOS Permission Reset nach Update | Mittel | Mittel | Beim Start Permission-Status neu prüfen |
| STTPipeline-Absturz blockiert App | Niedrig | Hoch | Process hat eigenen Timeout (30s), danach kill() |

---

*Dieses Dokument ist die einzige Quelle der Wahrheit für die NeoWispr-Architektur. Änderungen werden hier zuerst dokumentiert, bevor sie implementiert werden.*
