import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
struct TextInjector {

    /// Bundle-IDs wo der AX-Pfad lügt: API meldet success, aber die App's eigener
    /// Input-Handler (Electron/React/Browser DOM) hat den Wert nicht übernommen.
    /// Hier IMMER auf Cmd+V fallen lassen — robuster.
    private static let axBlacklistedBundleIDs: Set<String> = [
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.microsoft.edgemac",
        "com.tinyspeck.slackmacgap",       // Slack
        "com.hnc.Discord",
        "com.google.Chrome",
        "company.thebrowser.Browser",       // Arc
        "org.mozilla.firefox",
        "com.brave.Browser",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",   // Cursor
        "com.figma.Desktop",
        "notion.id",
    ]

    func inject(text: String) {
        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let axGranted = hasAccessibilityPermission
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let frontmost = frontmostApp?.localizedName ?? "?"
        let bundleID = frontmostApp?.bundleIdentifier ?? ""
        let axBlocked = Self.axBlacklistedBundleIDs.contains(bundleID)
        NSLog("[NeoWispr.inject] ax=\(axGranted) frontmost=\(frontmost) bundle=\(bundleID) blocked=\(axBlocked) len=\(text.count)")

        var injected = false
        if axGranted, !axBlocked, let element = getFocusedElement() {
            injected = injectViaAccessibility(text: text, element: element)
            NSLog("[NeoWispr.inject] axPath=\(injected)")
        } else {
            let reason = !axGranted ? "ax-denied" : axBlocked ? "bundle-blacklist" : "no-element"
            NSLog("[NeoWispr.inject] axPath skipped — \(reason)")
        }
        if !injected {
            NSLog("[NeoWispr.inject] fallback simulatePaste")
            simulatePaste()
        }

        // Clipboard nach 300ms wiederherstellen — aber nur wenn AX gepasted hat.
        // Bei simulatePaste läuft Cmd+V asynchron; das vorzeitige Clear war ein Bug.
        if injected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let previous = previousContent {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                } else {
                    pasteboard.clearContents()
                }
            }
        } else {
            // Clipboard-Restore deutlich spaeter, damit Cmd+V sicher durch ist
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if let previous = previousContent {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                }
            }
        }
    }

    private var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        // Virtual key 0x09 = V
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            NSLog("[NeoWispr.simulatePaste] CGEvent creation failed")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        // 20ms Pause damit das System das keyDown verarbeiten kann
        usleep(20_000)
        keyUp.post(tap: .cghidEventTap)
        NSLog("[NeoWispr.simulatePaste] posted Cmd+V")
    }

    private func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard appResult == .success, let app = focusedApp else { return nil }

        var focusedElement: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(
            // swiftlint:disable force_cast
            app as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        guard elementResult == .success, let element = focusedElement else { return nil }
        return (element as! AXUIElement)
    }

    /// Versucht Text direkt via AX ins fokussierte Element einzufuegen.
    /// Liefert `true` nur wenn das Element sowohl kAXValueAttribute lesen
    /// als auch schreiben kann — andernfalls `false` und der Caller fällt auf Cmd+V zurück.
    private func injectViaAccessibility(text: String, element: AXUIElement) -> Bool {
        // 1) Schreibbar?
        var isSettable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &isSettable
        )
        guard settableResult == .success, isSettable.boolValue else {
            return false
        }

        // 2) Aktuellen Wert lesen (für Append). Wenn Read fehlschlägt -> kein AX-Pfad.
        var currentValue: CFTypeRef?
        let readResult = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &currentValue
        )
        guard readResult == .success, let existing = currentValue as? String else {
            return false
        }

        // 3) Set + Ergebnis pruefen.
        let setResult = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            (existing + text) as CFString
        )
        return setResult == .success
    }

    // MARK: - Selection (Command Mode)

    /// Liest den aktuell markierten Text im fokussierten UI-Element.
    /// Primaer via `kAXSelectedTextAttribute`; Fallback auf Clipboard-Copy (Cmd+C) wenn AX
    /// keine Selektion liefert (z.B. in Web-Views).
    func getSelectedText() -> String? {
        if hasAccessibilityPermission, let element = getFocusedElement() {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                element,
                kAXSelectedTextAttribute as CFString,
                &value
            )
            if result == .success, let str = value as? String, !str.isEmpty {
                return str
            }
        }
        return copySelectionViaPasteboard()
    }

    /// Ersetzt die aktuelle Selektion durch `text`. AX-Pfad setzt
    /// `kAXSelectedTextAttribute` — Cmd+Z bleibt als Undo im Zielprogramm erhalten.
    /// Fallback: Paste über CGEvent (überschreibt selektierten Text automatisch).
    func replaceSelection(with text: String) {
        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)

        if hasAccessibilityPermission, let element = getFocusedElement() {
            let result = AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextAttribute as CFString,
                text as CFString
            )
            if result == .success { return }
        }

        // Fallback: Clipboard + Paste
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        simulatePaste()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let previous = previousContent {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            } else {
                pasteboard.clearContents()
            }
        }
    }

    /// Fallback-Selection-Read: Cmd+C in die Ziel-App simulieren und danach Pasteboard auslesen.
    /// Nur nutzen wenn AX leer ist — restauriert Clipboard danach.
    private func copySelectionViaPasteboard() -> String? {
        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        pasteboard.clearContents()

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)  // 0x08 = C
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Kurz auf Pasteboard-Update warten (max ~200ms)
        let deadline = Date().addingTimeInterval(0.2)
        while pasteboard.changeCount == previousChangeCount && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }

        let copied = pasteboard.string(forType: .string)

        // Clipboard wiederherstellen
        pasteboard.clearContents()
        if let previous = previousContent {
            pasteboard.setString(previous, forType: .string)
        }

        guard let copied, !copied.isEmpty else { return nil }
        return copied
    }
}
