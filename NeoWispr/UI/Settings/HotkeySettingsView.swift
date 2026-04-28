import KeyboardShortcuts
import SwiftUI

struct HotkeySettingsView: View {

    @AppStorage(AppSettings.hotkeyMode) private var hotkeyMode: String = "toggle"
    @AppStorage(AppSettings.commandModeEnabled) private var commandModeEnabled: Bool = false

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Diktat-Hotkey", name: .dictationPrimary)
            } header: {
                Text("Diktat-Shortcut").neonSectionHeader()
            } footer: {
                Text("Standard: ⌥ + Leertaste. Klicke auf das Feld und drücke die gewünschte Kombination.")
            }

            Section {
                Picker("Modus", selection: $hotkeyMode) {
                    Text("Umschalten").tag("toggle")
                    Text("Gedrückt halten").tag("hold")
                }
                .pickerStyle(.radioGroup)

                Text(modeDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Aufnahme-Modus").neonSectionHeader()
            } footer: {
                Text("Im Halten-Modus wird der Stille-Timeout ignoriert — die Aufnahme endet erst, wenn du die Taste loslässt.")
            }

            Section {
                Toggle("Command Mode aktivieren", isOn: $commandModeEnabled)

                if commandModeEnabled {
                    KeyboardShortcuts.Recorder("Command-Hotkey", name: .dictationCommand)
                }
            } header: {
                Text("Command Mode").neonSectionHeader()
            } footer: {
                Text("Markiere Text in beliebiger App, halte den Command-Hotkey und sprich einen Befehl (z.B. \"formuliere das professioneller\", \"übersetze ins Englische\"). Der markierte Text wird durch das Ergebnis ersetzt. Cmd+Z macht den Replace rückgängig. Standard: ⌃⇧D.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private var modeDescription: String {
        if hotkeyMode == "hold" {
            return "Solange du den Hotkey hältst, wird aufgenommen. Loslassen stoppt sofort."
        } else {
            return "Tippen startet die Aufnahme, erneutes Tippen stoppt sie. Auto-Stop durch Stille ist aktiv."
        }
    }
}
