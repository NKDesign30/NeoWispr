# NeoWispr Release-Pipeline — Plan

> Status: Planungsphase. Sparkle ist im Code verdrahtet (`SPUStandardUpdaterController`), `SUFeedURL` im Info.plist gesetzt, alles andere fehlt noch.
> Ziel: `git tag v0.x.y && git push --tags` produziert ein signiertes, notarisiertes DMG plus appcast-Eintrag, User mit installierter App bekommen automatisch das Update angeboten.

## Was heute schon da ist

- `Sparkle 2.9.1` als SPM-Dep in `Package.swift`
- `NeoWispr/App/UpdaterController.swift` — `SPUStandardUpdaterController` Wrapper
- `MenuBarView` — "Auf Updates prüfen…" Menü-Eintrag verdrahtet
- `Info.plist`:
  - `CFBundleVersion = 1` (statisch — muss dynamisch werden)
  - `CFBundleShortVersionString = 0.1.0`
  - `SUFeedURL` zeigt auf eine alte Test-URL und muss umgestellt werden (siehe Schritt 2)

## Was fehlt — Bauliste

### 1. Sparkle EdDSA-Keypair (einmalig, ~5 Min)

Sparkle 2 nutzt EdDSA statt DSA für Update-Signaturen. Private Key bleibt geheim, Public Key wird in `Info.plist` gepinnt.

```bash
# Einmal generieren, in 1Password ablegen
~/neon-projects/NeoWispr/.build/checkouts/Sparkle/bin/generate_keys
```

- Private Key → 1Password "NeoWispr — Sparkle EdDSA Private Key"
- Public Key → `Info.plist` als `SUPublicEDKey` (commit-bar, ist gewollt)

### 2. SUFeedURL umstellen (~2 Min)

Weg von `nidani.shop` (gehört zu vsemoraven). Optionen:

- **a) GitHub Pages** auf NeoWispr-Repo — `gh-pages` Branch, `appcast.xml` im Root → URL: `https://nkdesign30.github.io/NeoWispr/appcast.xml`
- **b) Eigene Domain** wenn gewünscht — eigene Subdomain auf den Repo-Pages mappen
- **c) Direkter Repo-Raw-Link** — funktioniert, aber GitHub serviert mit `Cache-Control` der Sparkle nervt

Empfehlung: **a) GitHub Pages**. Kostet nichts, immer da, perfekt für so was.

Im Info.plist: `SUFeedURL` auf neue URL.

### 3. DMG-Tooling (~5 Min)

```bash
brew install create-dmg
```

Schreibt das in den Pipeline-Schritt rein, kein App-Code-Change.

### 4. Apple Notarization-Credentials in GitHub Secrets

Niko hat schon Apple Dev Account (Team ID `33494M52P6`). Was zusätzlich nötig:

- **App-specific Password** auf appleid.apple.com erstellen (für `notarytool`)
- **Developer ID Application Certificate** als `.p12` exportieren aus Keychain
- Drei GitHub Secrets im Repo:
  - `APPLE_ID` — Apple-ID Email
  - `APPLE_ID_PASSWORD` — das App-specific Password
  - `APPLE_TEAM_ID` — `33494M52P6`
  - `APPLE_CERT_P12_BASE64` — base64-encoded .p12
  - `APPLE_CERT_P12_PASSWORD` — Passwort fürs .p12
  - `SPARKLE_PRIVATE_KEY` — Private EdDSA Key (aus 1Password)

### 5. Build-Skript releasewürdig machen

`scripts/build-app.sh` baut aktuell `debug` und kopiert nach `/Applications`. Für Release brauchen wir ein zweites Script `scripts/build-release.sh`:

- `swift build -c release`
- App-Bundle assemblen (wie bisher)
- Code-Sign mit `codesign --force --options runtime --sign "$DEV_ID" --entitlements ...`
- DMG bauen mit `create-dmg`
- Notarize: `xcrun notarytool submit … --wait`
- Staple: `xcrun stapler staple …`
- Sparkle-Signature: `sign_update Path/To/NeoWispr-0.1.0.dmg`
- Output: `dist/NeoWispr-<version>.dmg` + `dist/sparkle-signature.txt`

CFBundleVersion muss dynamisch sein — entweder über env-var im Build (`AGV_BUILD_NUMBER=$GITHUB_RUN_NUMBER`) oder über `agvtool`.

### 6. GitHub Actions Workflow

`.github/workflows/release.yml`:

- Trigger: `on: push: tags: ['v*']`
- macOS-Runner (`macos-14` oder neuer)
- Steps:
  1. Checkout
  2. Cert + Sparkle-Key aus Secrets in temporären Keychain importieren
  3. `scripts/build-release.sh` mit Version aus Tag
  4. `gh release create $GITHUB_REF_NAME dist/*.dmg` — published das DMG
  5. `appcast.xml` aus Template generieren mit:
     - Tag-Name als Version
     - DMG-Download-URL aus GitHub Release
     - Sparkle-Signature aus `dist/sparkle-signature.txt`
     - Release Notes aus Tag-Body
  6. Push appcast.xml auf `gh-pages` Branch

### 7. Release-Workflow für Niko (manuell)

```bash
# In Source
agvtool new-marketing-version 0.2.0   # Falls neue Public-Version
git commit -am "release: v0.2.0"
git tag v0.2.0
git push origin main --tags
# → GitHub Action läuft, ~10-15 Min später ist Release live
```

Das ist's. Drei Befehle, Rest macht die Pipeline.

## Reihenfolge

| # | Schritt | Dauer | Blocker für |
|---|---------|-------|-------------|
| 1 | EdDSA-Keypair generieren | 5 min | 6 |
| 2 | GitHub Pages aufsetzen + SUFeedURL umstellen | 15 min | 6 |
| 3 | App-specific Password + Cert-Export | 20 min | 6 |
| 4 | GitHub Secrets eintragen | 10 min | 6 |
| 5 | `scripts/build-release.sh` schreiben | 1-2 h | 6 |
| 6 | `.github/workflows/release.yml` | 1-2 h | — |
| 7 | Test-Release `v0.1.0` | 30 min | — |

Total: ~4-5 Stunden Arbeit, in einer Session machbar.

## Was NICHT in dieser Pipeline ist

- **Homebrew Cask** — separat, kommt wenn echte User da sind. Cask-Formula kann auf die GitHub-Releases zeigen, ist trivial nach Pipeline.
- **Beta/Stable-Channels** — Sparkle kann das, aber für eine 1-Person-App overkill. Erstmal ein Channel.
- **Auto-Crash-Reports** — separates Thema. Sentry oder TelemetryDeck wenn relevant.
- **Versioning-Bump als Action** — Niko bumped manuell, dann Tag pushen. Conventional-Commits-Bot wäre Bloat für Solo-Repo.

## Nächster konkreter Schritt

Wenn du loslegen willst: Schritte 1-4 sind die "Setup-Phase" (Keys, Secrets, GitHub Pages) — kann ich mit dir zusammen in einer Session machen, ich brauche dabei nur den EdDSA-Key-Output und die App-specific-Password-Anweisung. Die `.p12`-Export-Schritte muss du selbst klicken (Keychain Access).

Schritt 5+6 (Build-Script + Action) baue ich danach autonom — sind reine Skript-Arbeit, kein Niko-Klicken nötig.
