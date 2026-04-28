# NeoWispr — Research Report
> Scout Research | Stand: 2026-03-20 | Confidence: Hoch

---

## 1. Swift whisper.cpp Integration

### Optionen im Überblick

| Option | Typ | Aufwand | Apple Silicon | Maintenance |
|--------|-----|---------|---------------|-------------|
| **WhisperKit** (argmaxinc) | Swift-native SPM | Niedrig | Neural Engine (optimal) | Aktiv, 5k+ Stars |
| **SwiftWhisper** (exPHAT) | C++ Wrapper SPM | Mittel | Metal/CPU | Aktiv, ~1k Stars |
| **whisper.spm** (ggerganov) | C++ Wrapper SPM | Mittel | Metal/CPU | Offizielle ggml-Variante |
| **CLI Process Spawning** | subprocess via `Process` | Niedrig | via Homebrew | Kein Package nötig |

### ✅ EMPFOHLEN: WhisperKit (argmaxinc)

**Warum**: Kompiliert Whisper-Modelle in CoreML und nutzt Apples Neural Engine. Kein C++ Bridging, keine Bridging-Header, reines Swift-SPM-Package. Aktiv maintained mit Apple-Support.

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0")
]
```

```swift
import WhisperKit

// Initialisierung
let whisper = try await WhisperKit(model: "openai_whisper-base")

// Transkription
let results = try await whisper.transcribe(audioPath: "/tmp/recording.wav")
let text = results.map { $0.text }.joined()
```

**Performance** (Apple Silicon M1+):
- Neural Engine: weniger Power, schneller als CPU/GPU
- base-Modell: Real-Time oder schneller
- large-v2: ~1–2x Real-Time auf M1

**Einschränkung**: Erster Start lädt Modell herunter (~150MB für base). Beim Shipping in App bundeln.

---

### ✅ EMPFOHLEN (Alternative): whisper-cli via Process (Homebrew bereits installiert)

Da `whisper-cli` bereits via Homebrew installiert ist, ist das der **schnellste Einstieg** ohne jede Dependency:

```swift
import Foundation

func transcribe(audioURL: URL, completion: @escaping (String) -> Void) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cli")
    process.arguments = [
        "--model", "/opt/homebrew/share/whisper.cpp/models/ggml-base.en.bin",
        "--output-txt",
        "--no-prints",
        audioURL.path
    ]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe() // stderr suppressen

    process.terminationHandler = { _ in
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        completion(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    try? process.run()
}
```

**Vorteile**: Null Dependencies, Homebrew-Modelle bereits da, sofort lauffähig.
**Nachteile**: Kein Streaming, subprocess-Overhead (~200ms), App-Sandboxing macht Probleme (→ App NICHT sandboxen für direkten CLI-Aufruf).

---

### ⚠️ ALTERNATIVE: SwiftWhisper (exPHAT)

```swift
// Package.swift
.package(url: "https://github.com/exPHAT/SwiftWhisper", branch: "master")
```

```swift
import SwiftWhisper

let model = Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin")!
let whisper = Whisper(fromFileURL: model)

let segments = try await whisper.transcribe(audioFrames: frames)
```

Gut als Mittelweg wenn CoreML nicht gewünscht, aber direkte C++ Integration ohne subprocess.

---

### ❌ NICHT EMPFOHLEN: whisper.spm (ggerganov official SPM)

Offizielle ggml-Variante, aber primär für iOS/visionOS/tvOS. macOS-Support existiert, aber Dokumentation dünn. Keine Native-Swift-API — rohe C-Bindings.

---

### Empfehlung für NeoWispr

**Phase 1** (MVP): CLI Process Spawning — läuft sofort, keine Dependencies.
**Phase 2** (Production): Migration zu WhisperKit für Native-Integration + Neural Engine.

---

## 2. macOS Global Hotkey

### Optionen im Überblick

| Option | User-konfigurierbar | SwiftUI-nativ | Sandbox-safe | Maintenance |
|--------|--------------------|--------------:|-------------|-------------|
| **KeyboardShortcuts** (sindresorhus) | ✅ Ja | ✅ Recorder View | ✅ App Store kompatibel | Sehr aktiv |
| **HotKey** (soffes) | ❌ Nur hardcoded | ⚠️ Manuell | ✅ | Stabil, selten updates |
| **Carbon Events** (CGEvent) | Custom | ❌ Manuell | ❌ Nur außerhalb Sandbox | Deprecated API |
| **MASShortcut** | ✅ Ja | ❌ AppKit | ⚠️ | Kaum maintained |

### ✅ EMPFOHLEN: KeyboardShortcuts (sindresorhus)

**Warum**: User können den Hotkey in den Settings selbst konfigurieren (wichtig für Diktier-Apps!). Eingebauter `KeyboardShortcuts.Recorder` View. Vollständig SwiftUI-kompatibel. App Store safe.

```swift
// Package.swift
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
```

```swift
import KeyboardShortcuts

// Shortcut definieren
extension KeyboardShortcuts.Name {
    static let startDictation = Self("startDictation", default: .init(.space, modifiers: [.option]))
}

// In AppDelegate oder @main
KeyboardShortcuts.onKeyDown(for: .startDictation) {
    // Aufnahme starten
    DictationManager.shared.startRecording()
}

KeyboardShortcuts.onKeyUp(for: .startDictation) {
    // Aufnahme stoppen (Push-to-Talk Modus)
    DictationManager.shared.stopRecording()
}
```

```swift
// Settings View mit eingebautem Recorder
struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Diktier-Hotkey:", name: .startDictation)
        }
    }
}
```

**Push-to-Talk** (Halten zum Sprechen, Loslassen = Stop): keyDown + keyUp Handler reicht.

---

### ⚠️ ALTERNATIVE: HotKey (soffes)

Gut für hardcoded Shortcuts ohne User-Konfiguration. Einfacher, weniger Code — aber kein UI-Recorder.

```swift
import HotKey

let hotKey = HotKey(key: .space, modifiers: [.option])
hotKey.keyDownHandler = { DictationManager.shared.startRecording() }
hotKey.keyUpHandler  = { DictationManager.shared.stopRecording() }
```

Sinnvoll wenn MVP ohne Settings-UI gewünscht.

---

### ❌ NICHT EMPFOHLEN: Carbon Events / CGEvent direkt

Carbon API ist deprecated (macOS 12+). CGEvent-Taps benötigen Accessibility-Permissions UND `com.apple.security.temporary-exception.apple-events` Entitlement. Komplex, fragil.

---

### MenuBarExtra Integration

```swift
@main
struct NeoWisprApp: App {
    @StateObject private var dictationManager = DictationManager()

    var body: some Scene {
        MenuBarExtra("NeoWispr", systemImage: "mic.fill") {
            ContentView()
                .environmentObject(dictationManager)
        }
        .menuBarExtraStyle(.window)
    }
}
```

KeyboardShortcuts funktioniert problemlos mit MenuBarExtra — der Hotkey ist global und greift auch wenn das MenuBarExtra-Fenster geschlossen ist.

---

## 3. Text-Injection ins aktive Fenster

### Optionen im Überblick

| Methode | Zuverlässigkeit | Permissions | Kompatibilität | Sandbox |
|---------|----------------|-------------|----------------|---------|
| **NSPasteboard + CGEvent Cmd+V** | Hoch | Accessibility | 99% aller Apps | ❌ |
| **AXUIElement.setValue** | Mittel | Accessibility | Nur Standard-Textfelder | ❌ |
| **AppleScript keystroke** | Niedrig | Automation | Variiert stark | ❌ |

**Wichtig**: Alle drei Methoden erfordern **kein App Sandbox** (`com.apple.security.app-sandbox = NO`). NeoWispr sollte NICHT sandboxed sein — passt zu Direct Distribution (kein App Store).

### ✅ EMPFOHLEN: NSPasteboard + CGEvent (Cmd+V simulieren)

Zuverlässigste Methode. Funktioniert in praktisch jeder App (Browser, Slack, Terminal, VS Code, Word...).

```swift
import AppKit
import Carbon

func injectText(_ text: String) {
    // 1. Alten Clipboard-Inhalt sichern
    let pasteboard = NSPasteboard.general
    let oldContents = pasteboard.string(forType: .string)

    // 2. Text in Clipboard schreiben
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)

    // 3. Cmd+V simulieren
    let source = CGEventSource(stateID: .hidSystemState)

    let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
    cmdDown?.flags = .maskCommand
    cmdDown?.post(tap: .cghidEventTap)

    let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
    cmdUp?.flags = .maskCommand
    cmdUp?.post(tap: .cghidEventTap)

    // 4. Kurze Pause, dann alten Clipboard wiederherstellen
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        pasteboard.clearContents()
        if let old = oldContents {
            pasteboard.setString(old, forType: .string)
        }
    }
}
```

**Entitlement** in `.entitlements` Datei:
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

---

### ⚠️ ALTERNATIVE: AXUIElement (Accessibility API)

Präziser als Clipboard (kein Zwischenablage-Klau), aber funktioniert nur in Apps die Standard-Textfelder nutzen. Terminal, Electron-Apps (VS Code, Slack) — oft Probleme.

```swift
import ApplicationServices

func injectViaAccessibility(_ text: String) -> Bool {
    guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
    let pid = frontApp.processIdentifier
    let app = AXUIElementCreateApplication(pid)

    var focusedElement: AnyObject?
    AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElement)

    guard let element = focusedElement else { return false }

    let result = AXUIElementSetAttributeValue(
        element as! AXUIElement,
        kAXSelectedTextAttribute as CFString,
        text as CFTypeRef
    )

    return result == .success
}
```

**Empfehlung**: Als Fallback nach NSPasteboard+CGEvent probieren wenn Paste nicht funktioniert (z.B. in Apps die Paste deaktiviert haben).

---

### Kombinierter Ansatz (Production-Pattern)

```swift
func injectText(_ text: String) {
    // Versuche zuerst Accessibility
    if injectViaAccessibility(text) {
        return
    }
    // Fallback: Clipboard + Cmd+V
    injectViaClipboard(text)
}
```

---

### ❌ NICHT EMPFOHLEN: AppleScript keystroke

```applescript
tell application "System Events" to keystroke "..."
```

Langsam (~200ms Startup), erfordert Automation-Permission, fehlerhaft bei Sonderzeichen und Umlauten. Nur als letzter Fallback.

---

## 4. Ähnliche Open-Source Referenzprojekte

### ✅ EMPFOHLEN als primäre Referenz: OpenSuperWhisper

**GitHub**: https://github.com/Starmel/OpenSuperWhisper
**Lizenz**: MIT
**Stack**: Swift, whisper.cpp (lokaler Binary), globale Shortcuts, Hold-to-Record

Was wir direkt übernehmen können:
- Hold-to-record Pattern (Halten = Aufnehmen, Loslassen = Stop + Inject)
- Modifier-Key-Only Shortcuts (Left Cmd, Right Option, Fn) — sehr ergonomisch für Diktier-Apps
- Microphone-Auswahl-UI

### ✅ EMPFOHLEN als Referenz: open-wispr

**GitHub**: https://github.com/human37/open-wispr
**Lizenz**: MIT
**Stack**: Push-to-talk, whisper.cpp, macOS-nativ

Schlankere Codebase als OpenSuperWhisper — gut um die Core-Logik zu verstehen.

### Weitere Referenzen

| Projekt | Stars | Besonderheit |
|---------|-------|-------------|
| **Buzz** | ~13k | Vollständigste Features, aber heavy (Python-Basis!) |
| **Aiko** | ~3k | SwiftUI + WhisperKit, iOS/macOS |
| **MacWhisper** | Commercial | Gumroad, Referenz für UX |
| **whisper-mac** | ~500 | Einfach, leicht lesbar |

---

## 5. Audio Recording in Swift

### ✅ EMPFOHLEN: AVAudioEngine

**Warum**: Niedrig-latenz, Echtzeit-Tap auf Mikrofon-Input, kein Schreiben in Datei nötig (direkt Buffer → Whisper), macOS-native.

```swift
import AVFoundation

class AudioRecorder: ObservableObject {
    private var audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var outputURL: URL?

    func startRecording() throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Whisper braucht 16kHz Mono — Konvertierung
        let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: whisperFormat.settings
        )

        // Konverter für Sample Rate
        let converter = AVAudioConverter(from: format, to: whisperFormat)!

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self = self, let file = self.audioFile else { return }

            let ratio = whisperFormat.sampleRate / format.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: capacity)!

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, status in
                status.pointee = .haveData
                return buffer
            }

            try? file.write(from: convertedBuffer)
        }

        try audioEngine.start()
        outputURL = tempURL
        return tempURL
    }

    func stopRecording() -> URL? {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioFile = nil
        return outputURL
    }
}
```

**Info.plist** Eintrag nötig:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>NeoWispr benötigt Mikrofon-Zugriff für Diktierfunktion.</string>
```

---

### Silence Detection / VAD

Für Auto-Stop nach Sprechpause (optional, aber nice-to-have):

```swift
// Einfacher RMS-basierter Silence Detector
func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData?[0] else { return 0 }
    let frameLength = Int(buffer.frameLength)
    let sumOfSquares = (0..<frameLength).reduce(0.0) { $0 + channelData[$1] * channelData[$1] }
    return sqrt(sumOfSquares / Float(frameLength))
}

// In der installTap closure:
let rms = calculateRMS(buffer: buffer)
let isSilent = rms < 0.01 // Threshold anpassen
```

Für robustere VAD: **Silero VAD** (Swift-Port via CoreML) — ~40μs pro Chunk, sehr effizient. Aber für MVP ist RMS-Threshold ausreichend.

---

### ⚠️ ALTERNATIVE: AVAudioRecorder

Simpler als AVAudioEngine, direkt in Datei schreiben. Kein Echtzeit-Tap.

```swift
let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 16000,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
recorder.record()
// ... later:
recorder.stop()
```

**Empfehlung**: AVAudioRecorder für MVP (simpler), AVAudioEngine für finale Version (mehr Kontrolle für VAD und Echtzeit-Feedback).

---

## 6. Distribution ohne App Store

### Vergleich 2026

| Plattform | Fee | MoR | App Licensing | Empfehlung |
|-----------|-----|-----|---------------|------------|
| **Lemon Squeezy** | 5% + 50¢ | ✅ Ja | ✅ Ja | ⚠️ Post-Stripe-Akquisition |
| **Gumroad** | 10% + 50¢ | ✅ Ja | ✅ Ja | ❌ Zu teuer |
| **Paddle** | ~5% (alles inkl.) | ✅ Ja | ✅ Ja | ✅ Stabil |
| **Dodo Payments** | Niedrigste MoR-Fees (Beta) | ✅ Ja | ✅ Ja | ✅ für neue Projekte |
| **Direct (Stripe)** | 2.9% + 30¢ | ❌ Nein | Custom | ⚠️ Steuer-Handling selbst |

### ✅ EMPFOHLEN: Paddle

**Warum**: All-Inclusive-Pricing (~5%), kein nachträgliches Gebühren-Chaos, bewährt für macOS-Apps, Merchant of Record (MoR = kein VAT-Stress), gute License-Key-Verwaltung built-in.

**Konkret für NeoWispr**: Paddle + Gumroad als Storefront (Gumroad für Entdeckbarkeit, Paddle für Checkout).

---

### ✅ EMPFOHLEN (Alternative): Dodo Payments

Niedrigste Fees im MoR-Segment, schnelles Onboarding (vs. Lemon Squeezy Post-Akquisition). Noch Beta — etwas riskanter, aber interessant für 2026.

---

### ⚠️ HINWEIS: App-Notarisierung (PFLICHT)

Auch ohne App Store muss die App von Apple notarisiert werden — sonst Gatekeeper-Block auf allen Macs ab macOS 10.15:

```bash
# Xcode Archive → Organizer → Distribute App → Direct Distribution → Notarize
# Oder via CLI:
xcrun notarytool submit NeoWispr.dmg \
  --apple-id "your@apple.com" \
  --password "@keychain:AC_PASSWORD" \
  --team-id "XXXXXXXXXX" \
  --wait
```

Kosten: Apple Developer Program = 99€/Jahr (Pflicht für Notarisierung).

---

## Technologie-Entscheidung: Finaler Stack

```
┌─────────────────────────────────────────┐
│           NeoWispr — Tech Stack         │
├─────────────────────────────────────────┤
│ UI             │ SwiftUI + MenuBarExtra  │
│ Hotkey         │ KeyboardShortcuts (SPM) │
│ Audio          │ AVAudioEngine (nativ)   │
│ STT (MVP)      │ whisper-cli (Homebrew)  │
│ STT (v2)       │ WhisperKit (SPM)        │
│ Text-Injection │ NSPasteboard + CGEvent  │
│ Distribution   │ Paddle / Dodo Payments  │
│ Notarisierung  │ Apple Developer Program │
└─────────────────────────────────────────┘
```

### Implementierungs-Reihenfolge (MVP)

1. **Xcode-Projekt** — macOS App Target, kein Sandbox, MenuBarExtra
2. **AVAudioRecorder** — Mikrofon → WAV-Datei (simpelste Form)
3. **whisper-cli** via `Process` — WAV → Text (sofort lauffähig)
4. **NSPasteboard + CGEvent** — Text → aktives Fenster
5. **KeyboardShortcuts** — Globaler Hotkey (Push-to-Talk)
6. **Settings Window** — Hotkey-Konfiguration, Modell-Auswahl
7. **Migration zu WhisperKit** — Bessere Performance + kein CLI

---

## Quellen

- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit)
- [SwiftWhisper GitHub](https://github.com/exPHAT/SwiftWhisper)
- [whisper.spm (Official SPM)](https://github.com/ggerganov/whisper.spm)
- [WhisperKit macOS Integration Blog](https://www.helrabelo.dev/blog/whisperkit-on-macos-integrating-on-device-ml)
- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts)
- [HotKey GitHub](https://github.com/soffes/HotKey)
- [Text Injection in Swift — Level Up Coding](https://levelup.gitconnected.com/swift-macos-insert-text-to-other-active-applications-two-ways-9e2d712ae293)
- [OpenSuperWhisper GitHub](https://github.com/Starmel/OpenSuperWhisper)
- [open-wispr GitHub](https://github.com/human37/open-wispr)
- [AVAudioEngine WWDC23 VAD](https://developer.apple.com/videos/play/wwdc2023/10235/)
- [Silero VAD in Swift (Feb 2026)](https://blog.ivan.digital/speaker-diarization-and-voice-activity-detection-on-apple-silicon-native-swift-with-mlx-92ea0c9aca0f)
- [Paddle vs Lemon Squeezy 2025](https://devmystify.com/blog/choosing-a-merchant-of-record-in-2025-lemon-squeezy-vs-paddle-vs-dodo-payments-my-experience)
- [Indie macOS Distribution Vergleich](https://veloxthemes.com/blog/polar-vs-lemonsqueezy-vs-gumroad)
- [mac-whisper-speedtest Benchmark](https://github.com/anvanvan/mac-whisper-speedtest)
