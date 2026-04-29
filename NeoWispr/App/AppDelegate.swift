import AppKit
import Foundation

/// Brücke zwischen macOS App-Lifecycle und unserem AppEnvironment.
/// - Beim ersten Launch das Dashboard öffnen
/// - Bei Dock-Klick (reopen) das Dashboard öffnen statt nichts zu tun
final class AppDelegate: NSObject, NSApplicationDelegate {

    static let openDashboardNotification = Notification.Name("NeoWispr.openDashboard")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NeonFontRegistrar.register()

        // Erstes sichtbares Fenster nach Launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: Self.openDashboardNotification, object: nil)
        }
    }

    /// Klick auf Dock-Icon, wenn keine sichtbaren Fenster offen sind.
    ///
    /// AppKit dispatched diese Methode aus dem Apple-Event-Handler — Swift 6's strict
    /// concurrency runtime crashed wenn `@MainActor`-isolated Code von dort gerufen wird,
    /// daher `nonisolated` + expliziter Hop auf den main thread.
    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.openDashboardNotification, object: nil)
            }
        }
        return true
    }

    /// Menübar-App: Cmd+W oder Window-Close darf die App NICHT terminieren.
    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
