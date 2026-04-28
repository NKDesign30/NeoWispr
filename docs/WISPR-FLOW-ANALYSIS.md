# Wispr Flow — Deep Analysis für NeoWispr-Roadmap

> Scout Research | Stand: 2026-04-20 | Confidence: Hoch
> Quellen: wisprflow.ai/features, docs.wisprflow.ai, wisprflow.ai/data-controls, getvoibe.com, GitHub (VoiceInk, FreeFlow, VoiceTypr, VocaMac)

---

## 1. Feature-Matrix: Wispr Flow vs. NeoWispr (aktuell)

| Feature | Wispr Flow | NeoWispr (Stand heute) |
|---------|-----------|----------------------|
| **Diktieren in beliebiger App** | Ja, universal | Ja (TextInjector via Clipboard+Cmd+V) |
| **Push-to-Talk (Halten)** | Ja, `Fn` Default | Ja (Option+Space, HotKey Library) |
| **Toggle-Modus (Doppeltipp)** | Ja, `Fn+Space` Default | Nein |
| **Hands-free (Auto-Stop bei Pause)** | Ja | Ja (SilenceDetector, 3s RMS) |
| **Konfigurierbarer Hotkey** | Ja, inkl. Maustasten | Nein (hardcoded Option+Space) |
| **Filler-Word-Entfernung** | Ja (um, uh, like) | Nein |
| **Auto-Interpunktion** | Ja | Nein (nur was Whisper liefert) |
| **Backtrack-Korrektur** | Ja ("2... actually 3") | Nein |
| **Listen-Formatierung** | Ja | Nein |
| **Schreibstil-Anpassung (Styles)** | Ja (formal/casual/etc.) | Nein |
| **App-aware Formatting** | Ja (Slack casual, Gmail formal) | Nein |
| **Dictionary / Custom Vocab** | Ja, mit Sterne-Ranking | Ja (DictionaryStore, JSON) |
| **Snippets / Voice Shortcuts** | Ja, team-shared | Ja (SnippetEngine, exact+partial) |
| **Command Mode (Text-Transform)** | Ja (Pro-Feature, Text markieren + Befehl) | Nein |
| **Web-Suche via Voice** | Ja (öffnet Perplexity) | Nein |
| **Whisper-Modus (leises Sprechen)** | Ja | Nicht getestet |
| **100+ Sprachen** | Ja | Ja (Whisper-Basis) |
| **Verlaufs-Historie** | Ja (Flow Notes) | Ja (TranscriptionStore, max 10K) |
| **Cross-Device Sync** | Ja (Mac, Win, iOS, Android) | Nein (lokal only) |
| **IDE-Integration (Cursor/Windsurf)** | Ja (File-Tagging, Syntax-Awareness) | Nein |
| **Shared Dictionary (Team)** | Ja | Nein |
| **Usage Dashboard** | Ja | Ja (StatsTracker: WPM, Streak) |
| **Bis zu 20min Diktat** | Ja (seit März 2026) | Ja (kein Limit) |
| **Mouse Flow (Maustaste als PTT)** | Ja (seit März 2026) | Nein |
| **On-Device STT** | **Nein** — 100% Cloud | **Ja** — whisper.cpp lokal |
| **Privatsphäre (Audio bleibt lokal)** | Nein (Cloud, Privacy Mode = zero retention) | Ja, vollständig offline |
| **Kein Abo nötig** | Nein ($12-15/Monat) | Ja (zero cost to run) |
| **SOC2 / HIPAA** | Ja | N/A (nicht nötig, alles lokal) |

---

## 2. Tech-Stack Deep-Dive

### Wispr Flow (proprietär, Cloud-first)

**STT-Pipeline:**
- Kein lokales Whisper. Alle Audio gehen an Cloud-Server (keine on-device Option).
- STT-Provider: nicht öffentlich benannt, wahrscheinlich OpenAI Whisper API oder eigenes Fine-Tune.
- Post-Processing: LLAMA 3.1 (open-source, selbst-gehosted oder Meta-API) + OpenAI für LLM-Aufgaben.
- Latenz: ~1-2s nach Sprachende (Cloud-Round-Trip).

**Screenshot-Capture für App-Awareness:**
- Wispr nimmt alle paar Sekunden einen Screenshot des aktiven Fensters (bestätigt per Privacy-Policy und Independent Reviews).
- Screenshots werden an Cloud gesendet — auch ohne Diktat aktiv zu sein.
- Zweck: Kontext für App-aware Formatting (welche App, welcher Textfeld-Inhalt).
- **Datenschutz-Implikation**: Selbst mit Privacy Mode werden Screenshots verarbeitet; nur Diktier-Audio/-Transcript wird nicht gespeichert.

**Text-Injection:**
- Dokumentiert als "smarter text insertion" (Beta, 2025 Changelog).
- Wahrscheinlich: Accessibility API (AXUIElement) für direkte Insertion + Clipboard-Fallback.
- Proprietär, kein öffentliches Detail.

**UI-Pattern (Flow Bar):**
- Floating Overlay, ursprünglich als "Pill" bekannt.
- Flow Bar: kompakte Leiste, nicht als Pill-Overlay redesignt. Position: Bildschirmecke oder angedockt.
- Zeigt Sprachen-Optionen beim Hover, Quick-Switch zwischen Sprachen.
- Visual Feedback während Recording: animiert (Details nicht dokumentiert, vermutlich Pulsieren/Waveform).

**Hotkey-Mechanismus:**
- Drei Modi: Push-to-Talk (halten), Toggle (Doppeltipp), Hands-Free.
- Bis zu 8 Custom Shortcuts: 4 für Push-to-Talk/Modes, 4 für Transform Prompts.
- Maustasten-Support: Mouse4, Mouse5, Middle Click als Solo-Modifier.
- Low-Level: vermutlich CGEventTap oder IOKit (Carbon ist deprecated) — nicht öffentlich.

---

### NeoWispr (aktuell) — Differenzen zu Wispr Flow

| Aspekt | Wispr Flow | NeoWispr |
|--------|-----------|----------|
| STT | Cloud (OpenAI Whisper API + proprietary) | whisper.cpp lokal (Process spawn) |
| LLM Post-Processing | LLAMA 3.1 + OpenAI, Cloud | Keins (geplant: claude -p haiku) |
| Text-Injection | AXUIElement + Clipboard-Fallback | NSPasteboard + CGEvent Cmd+V |
| Hotkey | Carbon/CGEventTap, 3 Modi | HotKey Library (Carbon), 1 Modus |
| UI Overlay | Flow Bar (floating, animiert) | Floating Pill (NSPanel) |
| App-Context | Screenshot-Capture an Cloud | Keins |

**Empfehlung STT**: NeoWispr sollte auf WhisperKit wechseln (statt Process spawn). WhisperKit = CoreML + Neural Engine, besser als whisper-cli subprocess, reines Swift/SPM. (Scout Research 2026-03-20 empfohlen.)

---

## 3. UX-Pattern-Details

### Hotkey-Modi (Wispr Flow)

1. **Push-to-Talk**: Halten → Aufnehmen → Loslassen → Transkribieren. Default: `Fn`
2. **Hands-Free / Toggle**: Doppeltipp → Start, nochmal Doppeltipp → Stop. Default: `Fn+Space`
3. **Command Mode**: Eigener Shortcut (Mac: `Fn+Ctrl`). Selektierter Text + Sprachbefehl → Transformation.

Für NeoWispr fehlt: **Toggle-Modus** (Hände frei nach dem Start) und **konfigurierbarer Hotkey**.

### Command Mode — wie es genau funktioniert

1. Text in beliebiger App markieren (1–1000 Wörter).
2. Command-Shortcut halten.
3. Sprachbefehl sprechen: "Make this more concise", "Translate to German", "Rewrite as bullet points".
4. Loslassen → Wispr schickt (markierter Text + Befehl) an LLM → Antwort ersetzt Selektion.
5. Ohne markierten Text: öffnet Perplexity im Browser mit Frage.
6. Spezialfall: "press enter" → automatisches Enter-Tastendruck in Chat-Apps.
7. Undo: Cmd+Z stellt Originaltext wieder her.

**Das ist kein "Agent"** im klassischen Sinne — es ist ein server-seitiger LLM-Call mit Kontext. Keine autonomen Aktionen, kein Email-Draft aus dem Nichts.

### App-Aware Behavior (Stil-Anpassung)

- Wispr erkennt die aktive App und passt Stil an: Slack → kurz/casual, Gmail → formal, VS Code → kein Filler-Removal.
- Basis: Screenshot des aktiven Fensters (jede paar Sekunden) + App-Name via macOS API.
- Benutzerdefinierte "Styles" (Formal Document, Casual Message, Enthusiastic Email) — Desktop+Englisch only.
- "Transform Prompts": bis zu 8 Custom-Shortcuts die vordefinierte LLM-Prompts triggern (z.B. "Apply my disclaimer", "Translate to Spanish").

### Floating Pill / Flow Bar UX

- Die Pill war früher ein kleines Overlay-Element (Kreis/Kapsel, Ecke des Bildschirms).
- Seit "New Flow Bar" (2026): eher eine kompakte Leiste, Hover zeigt Sprach-Optionen.
- Während Recording: visuelles Feedback (Details proprietär — Waveform-Animation vermutet).
- Kein permanentes Dock-Fenster, keine Taskbar-App — reine Menübar + Overlay.

---

## 4. Privacy / Security

| Aspekt | Wispr Flow | NeoWispr |
|--------|-----------|----------|
| Audio-Verarbeitung | Cloud (immer) | Lokal (whisper.cpp) |
| Screenshot-Capture | Ja, für App-Kontext | Nein |
| Drittanbieter | OpenAI, Meta (LLAMA 3.1) | Keine |
| Privacy Mode | Zero Data Retention (Audio + Transcript) — aber Audio reist trotzdem zur Cloud | N/A — Audio verlässt Gerät nie |
| Zertifizierungen | SOC2 Type II, HIPAA, ISO 27001 | N/A (nicht nötig) |
| Datenspeicherung | Lokal in Flow Notes; Cloud-Server für Verarbeitung | ~/Library/Application Support/NeoWispr/ lokal |

**Scout-Fazit Privacy**: NeoWispr hat strukturellen Vorteil. Audio, Text, und Screenshots verlassen nie das Gerät. Kein Trust-Problem mit Drittanbietern. Das ist der stärkste USP gegen Wispr Flow.

---

## 5. Open-Source-Klone — Top 3

### #1: VoiceInk (⭐ 4.300+, GPL v3.0)
**GitHub**: [Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk)

| Kriterium | Details |
|-----------|---------|
| Stack | Swift 99.5%, whisper.cpp, FluidAudio (Parakeet) |
| Hotkey-Lib | KeyboardShortcuts (Sindre Sorhus) |
| STT | Lokal, whisper.cpp + Parakeet-Option |
| Text-Injection | Wahrscheinlich Clipboard (SelectedTextKit für Read) |
| Features | Power Mode (per-App-Config), Dictionary, Custom Vocab |
| Letztes Release | v1.72, März 2026 |
| Lizenz | GPL v3.0 (viral — NeoWispr-Code würde auch GPL) |
| Preis | $39.99 one-time (für Binary mit Updates) |

**Was wir klauen können**: Power Mode-Konzept (pro App eigene Konfiguration), SelectedTextKit für Kontext-Lesen, KeyboardShortcuts-Library für konfigurierbaren Hotkey.

**Warnung**: GPL v3.0. Code nicht direkt übernehmen — Inspiration ja, Copy-Paste nein.

---

### #2: FreeFlow (zachlatta)
**GitHub**: [zachlatta/freeflow](https://github.com/zachlatta/freeflow)

| Kriterium | Details |
|-----------|---------|
| Stack | Swift 99%, kein lokales STT |
| STT | Groq API (Cloud, aber kostenlos-Tier verfügbar) |
| LLM | Groq + optional Ollama (lokal) |
| Text-Injection | Clipboard + Cmd+V |
| Hotkey | Fn halten oder Cmd+Fn für Toggle |
| Features | Kontext-Awareness, custom System-Prompt, gratis |
| Lizenz | Nicht angegeben (assume permissive) |
| Status | Aktiv, kleines Projekt |

**Was wir klauen können**: Ollama-Integration für lokales LLM Post-Processing, Custom System-Prompt-Ansatz. Der Groq-STT-Ansatz ist für NeoWispr irrelevant (wir wollen lokal).

---

### #3: VocaMac (jatinkrmalik)
**GitHub**: [jatinkrmalik/vocamac](https://github.com/jatinkrmalik/vocamac)

| Kriterium | Details |
|-----------|---------|
| Stack | Swift 5.9+, SwiftUI, MenuBarExtra |
| STT | WhisperKit (CoreML/Neural Engine) |
| Text-Injection | Clipboard-Copy + CGEvent (Cmd+V Simulation) |
| Hotkey | CGEventTap (low-level, kein Carbon) |
| Audio | AVAudioEngine, 16kHz mono Float32 |
| Lizenz | MIT |
| Status | Kleines Projekt, lehrreich |

**Was wir klauen können**: WhisperKit-Integration-Muster, CGEventTap-Hotkey (Alternative zur HotKey Library), sauberes MenuBarExtra-Pattern. **MIT-Lizenz** = sicher verwendbar.

---

## 6. Priorisierte Feature-Roadmap für NeoWispr

### Phase 1 — MVP-Parität (1:1 Wispr Flow Core)

| Prio | Feature | Aufwand | Notiz |
|------|---------|---------|-------|
| 1 | **Konfigurierbarer Hotkey** | Mittel | KeyboardShortcuts (sindresorhus) statt hardcoded Option+Space |
| 2 | **Toggle-Modus** | Klein | Zweiter Hotkey → Start/Stop ohne Halten |
| 3 | **Filler-Word-Entfernung** | Mittel | LLM Post-Processing: claude -p haiku oder Ollama lokal |
| 4 | **Auto-Interpunktion verbessern** | Mittel | Whisper liefert Basis, LLM-Pass für Qualität |
| 5 | **Styles / Schreibstil** | Mittel | LLM-Prompt-Parameter: formal/casual/code |
| 6 | **Transform Prompts** (Command Mode Light) | Groß | Markierter Text + Voice-Befehl → LLM-Transformation via AXUIElement |

### Phase 2 — Differenzierung (besser als Wispr Flow durch Privacy)

| Prio | Feature | Aufwand | Notiz |
|------|---------|---------|-------|
| 7 | **WhisperKit statt Process-Spawn** | Mittel | CoreML/Neural Engine, kein whisper-cli subprocess |
| 8 | **Power Mode (per-App-Config)** | Groß | Wie VoiceInk: pro App eigener Stil/Prompt |
| 9 | **Mouse Flow** | Klein | Maustasten als PTT-Trigger (CGEventTap) |
| 10 | **SelectedTextKit** | Klein | Kontext der aktuellen Selektion für besseres LLM-Formatting |

### Phase 3 — Nice-to-Have

| Prio | Feature | Aufwand | Notiz |
|------|---------|---------|-------|
| 11 | **Web-Suche via Voice** | Klein | Voice-Frage → öffne Browser mit Query |
| 12 | **IDE-Integration** | Sehr groß | Cursor/Windsurf Plugin — nicht in Scope für MVP |
| 13 | **iOS Companion** | Sehr groß | Separates Projekt |

---

## 7. Library-Empfehlungen

| Zweck | Empfehlung | Warum |
|-------|-----------|-------|
| Konfigurierbarer Hotkey | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | SwiftUI-native, von VoiceInk genutzt, MIT |
| STT (Upgrade) | [WhisperKit](https://github.com/argmaxinc/WhisperKit) | Neural Engine, Swift-native SPM, Scout-Empfehlung |
| Kontext lesen | [SelectedTextKit](https://github.com/Beingpax/SelectedTextKit) | macOS accessibility-based, von VoiceInk |
| LLM lokal | [Ollama](https://ollama.com) + swift-http-client | FreeFlow-Pattern; kein API-Key, privat |
| LLM cloud-optional | claude -p haiku | Bereits in NeoWispr CLAUDE.md geplant |
| Text-Injection (Upgrade) | AXUIElement direkt | Direkter als Clipboard; kein App-Sandbox (NeoWispr ist eh non-sandbox) |

---

## Quellen

- [Wispr Flow Features](https://wisprflow.ai/features)
- [Wispr Flow What's New (März 2026)](https://wisprflow.ai/whats-new)
- [Wispr Flow Data Controls](https://wisprflow.ai/data-controls)
- [Wispr Flow Privacy Docs](https://docs.wisprflow.ai/articles/6274675613-privacy-mode-data-retention)
- [Wispr Flow Hotkey Docs](https://docs.wisprflow.ai/articles/2612050838-supported-unsupported-keyboard-hotkey-shortcuts)
- [Wispr Flow Command Mode Docs](https://docs.wisprflow.ai/articles/4816967992-how-to-use-command-mode)
- [Wispr Flow Review 2026 (Voibe)](https://www.getvoibe.com/resources/wispr-flow-review/)
- [Wispr Flow vs Alternatives (Voibe)](https://www.getvoibe.com/blog/wispr-flow-alternatives/)
- [GitHub: VoiceInk](https://github.com/Beingpax/VoiceInk)
- [GitHub: FreeFlow](https://github.com/zachlatta/freeflow)
- [GitHub: VoiceTypr](https://github.com/moinulmoin/voicetypr)
- [GitHub: VocaMac](https://github.com/jatinkrmalik/vocamac)
- [Swift Text Injection Methods](https://levelup.gitconnected.com/swift-macos-insert-text-to-other-active-applications-two-ways-9e2d712ae293)
