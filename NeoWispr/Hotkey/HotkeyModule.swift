import Foundation
import KeyboardShortcuts

@MainActor
final class HotkeyModule {

    // MARK: - Diktat-Shortcut (.dictationPrimary)

    /// Gefeuert auf Key-Down. In Toggle-Mode: toggleRecording. In Hold-Mode: startRecording.
    var onPress: (@MainActor () -> Void)?

    /// Gefeuert auf Key-Up. In Hold-Mode: stopRecording. In Toggle-Mode ignoriert.
    var onRelease: (@MainActor () -> Void)?

    // MARK: - Command-Shortcut (.dictationCommand)

    /// Gefeuert auf Key-Down des Command-Shortcuts. Startet Command Mode.
    var onCommandPress: (@MainActor () -> Void)?

    /// Gefeuert auf Key-Up des Command-Shortcuts. Stoppt Command-Aufnahme.
    var onCommandRelease: (@MainActor () -> Void)?

    init() {
        KeyboardShortcuts.onKeyDown(for: .dictationPrimary) { [weak self] in
            Task { @MainActor in self?.onPress?() }
        }
        KeyboardShortcuts.onKeyUp(for: .dictationPrimary) { [weak self] in
            Task { @MainActor in self?.onRelease?() }
        }

        KeyboardShortcuts.onKeyDown(for: .dictationCommand) { [weak self] in
            Task { @MainActor in self?.onCommandPress?() }
        }
        KeyboardShortcuts.onKeyUp(for: .dictationCommand) { [weak self] in
            Task { @MainActor in self?.onCommandRelease?() }
        }
    }
}
