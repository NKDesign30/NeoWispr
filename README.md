# NeoWispr

Native macOS-Diktier-App. Hotkey drücken → sprechen → Text landet im aktiven Fenster. 100 % offline möglich, kein Cloud-Zwang, kein Abo.

> Status: Frühe Version, läuft im Alltag stabil. Nur für macOS 14+ (Apple Silicon getestet, Intel sollte gehen).

## Features

- **Hotkey-Diktat** (Default `Option+Space`, konfigurierbar) — Toggle- oder Hold-Modus
- **STT-Engines:**
  - [Parakeet](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) (Default, NVIDIA, 600M-Modell)
  - [WhisperKit](https://github.com/argmaxinc/WhisperKit) — alle Whisper-Größen, on-device
  - whisper-cli ([whisper.cpp](https://github.com/ggerganov/whisper.cpp)) — externes Binary
- **Optionales LLM-Postprocessing** für Filler-Removal, Style-Anpassung (Groq Llama 3.3 70B per Free-Tier oder eigene Anthropic/OpenAI-Keys)
- **Snippets** — `mfg` → "Mit freundlichen Grüßen" (eigene Trigger anlegbar)
- **Wörterbuch** — Wort-Korrekturen pro User
- **Floating Pill** — Recording-Indikator über allen Spaces, klaut keinen Fokus
- **Power Mode** — pro App eigener Stil (z. B. formal in Mail, locker in Slack)
- **Command Mode** (Beta) — Hold-Hotkey für Sprach-Befehle auf Selektion
- 100 % offline-fähig (Parakeet/WhisperKit), Cloud nur wenn explizit aktiviert

## Installation (aus Source)

Voraussetzungen:

- macOS 14 (Sonoma) oder neuer
- Xcode 15+ oder Swift 6 Toolchain
- Optional: `whisper-cli` via Homebrew (`brew install whisper-cpp`) wenn du den whisper-cli-Provider nutzen willst

```bash
git clone https://github.com/NKDesign30/NeoWispr.git
cd NeoWispr
./scripts/build-app.sh
```

Das Script baut, signiert (mit deiner lokalen Apple Dev Identity), kopiert nach `/Applications/NeoWispr.app` und startet die App. Beim ersten Start fragt macOS nach Mikrofon- und Bedienungshilfen-Berechtigung — beide werden gebraucht.

Nur builden ohne Install: `swift build -c release`.

## Erste Schritte

1. App starten — Menüleisten-Icon erscheint
2. **Permissions** unter Einstellungen → Berechtigungen erteilen (Mikrofon + Bedienungshilfen)
3. **Modell laden** — STT-Tab, Provider auswählen. Parakeet/WhisperKit lädt das Modell automatisch beim ersten Start
4. **Optional: LLM-Postprocessing** — eigenen Groq-API-Key in den KI-Tab eintragen (Free-Tier reicht für normale Nutzung)
5. **Hotkey drücken** (Default `Option+Space`), sprechen, loslassen — Text wird im aktiven Fenster eingefügt

## Daten

Alles lokal in `~/Library/Application Support/NeoWispr/`:

```
├── snippets.json      # Trigger → Expansion
├── history.json       # Transkriptions-Historie
├── dictionary.json    # Wort-Korrekturen
└── models/            # Symlink → /opt/homebrew/share/whisper-cpp (für whisper-cli)
```

Groq-API-Key liegt in macOS Keychain, nicht in Klartext-Files.

## Hotkey-Modi

- **Toggle** (Default): Hotkey drücken zum Starten, nochmal drücken zum Beenden
- **Hold**: Hotkey gedrückt halten zum Aufnehmen, loslassen beendet

Konfigurierbar unter Einstellungen → Hotkey.

## Bekannte Einschränkungen

- Bei manchen Electron-Apps (Teams, Slack, Discord, Browser) wird Cmd+V als Fallback genutzt — Accessibility-Inject klappt da nicht zuverlässig
- Sparkle-Auto-Updater ist verdrahtet, aber Release-Pipeline noch nicht aktiv → vorerst manuelle Updates via `git pull && ./scripts/build-app.sh`
- Notarization noch nicht eingerichtet — beim ersten Start ggf. "Unidentifizierter Entwickler" → Rechtsklick → Öffnen

## Stack

Swift 6 / SwiftUI / SPM / macOS 14+ · `LSUIElement = true` (Menüleisten-App) · HotKey-Library (Carbon Events) · NSPasteboard + CGEvent für Text-Injection · Sparkle 2 für (zukünftige) Updates.

## Lizenz

[MIT](LICENSE) — nutze, forke, baue weiter. Kein Support-Versprechen, kein Garantie-Anspruch.

---

Built by [Niko Knez](https://github.com/NKDesign30) als Teil des NEON-Projekts. Issues und Pull Requests gerne, ich antworte unregelmäßig.
