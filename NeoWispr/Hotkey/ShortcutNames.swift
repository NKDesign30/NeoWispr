import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Haupt-Shortcut zum Diktieren. Default: Option+Space.
    static let dictationPrimary = Self(
        "dictationPrimary",
        default: .init(.space, modifiers: [.option])
    )

    /// Command Mode: Markierten Text per Sprachbefehl transformieren.
    /// Default: Ctrl+Shift+D.
    static let dictationCommand = Self(
        "dictationCommand",
        default: .init(.d, modifiers: [.control, .shift])
    )
}
