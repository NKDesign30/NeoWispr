import SwiftUI

struct MenuBarView: View {

    @Environment(RecordingController.self) private var recordingController
    @Environment(PermissionGate.self) private var permissionGate
    @Environment(ParakeetModelStore.self) private var parakeetModelStore

    @AppStorage(AppSettings.language) private var language: String = "de"
    @AppStorage(AppSettings.llmEnabled) private var llmEnabled: Bool = false
    @AppStorage(AppSettings.dictationStyle) private var dictationStyle: String = DictationStyle.none.rawValue
    @AppStorage(AppSettings.sttProvider) private var sttProvider: String = "parakeet"

    @Environment(\.openSettings) private var openSettings
    @Environment(AppEnvironment.self) private var appEnvironment
    @EnvironmentObject private var updaterController: UpdaterController

    var body: some View {
        VStack(spacing: 0) {
            statusHeader
            Divider()
                .padding(.horizontal, 12)
            recordButton
            if sttProvider == "parakeet", parakeetModelStore.status != .ready {
                parakeetStatusRow
            }
            languageRow
            if llmEnabled {
                styleRow
            }
            if !recordingController.lastTranscript.isEmpty {
                Divider()
                    .padding(.horizontal, 12)
                lastTranscriptSection
            }
            Divider()
                .padding(.horizontal, 12)
            footerActions
        }
        .frame(width: 288)
        .padding(.vertical, 6)
    }

    private var parakeetStatusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("Parakeet V3")
                    .font(.callout)
                    .foregroundStyle(.primary)
                Text(parakeetModelStore.label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if parakeetModelStore.isWorking {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 8) {
            statusIndicator
            Text(statusLabel)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var statusIndicator: some View {
        ZStack {
            if recordingController.state.isRecording {
                Circle()
                    .fill(statusColor.opacity(0.18))
                    .frame(width: 18, height: 18)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: recordingController.state.isRecording
                    )
            }
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
        }
        .frame(width: 18, height: 18)
    }

    private var statusLabel: String {
        switch recordingController.state {
        case .idle:           return "Bereit"
        case .recording:      return "Aufnahme läuft"
        case .transcribing:   return "Transkribiere..."
        case .processing:     return "Verbessere..."
        case .injecting:      return "Wird eingefügt..."
        case .error(let msg): return msg
        }
    }

    private var statusColor: Color {
        switch recordingController.state {
        case .idle:          return Neon.textTertiary
        case .recording:     return Neon.statusError
        case .transcribing:  return Neon.brandPrimary
        case .processing:    return Neon.brandPrimary
        case .injecting:     return Neon.brandBright
        case .error:         return Neon.statusWarning
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button(action: toggleRecording) {
            HStack(spacing: 10) {
                Image(systemName: micIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(micIconColor)
                    .frame(width: 20)
                    .symbolEffect(.pulse, isActive: recordingController.state.isRecording)
                Text(recordButtonLabel)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer()
                kbdHint("⌥ Space")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(recordButtonBg)
        .disabled(!permissionGate.canRecord || recordingController.state.isProcessing)
        .opacity((!permissionGate.canRecord || recordingController.state.isProcessing) ? 0.4 : 1)
        .animation(.easeOut(duration: 0.15), value: recordingController.state.isProcessing)
    }

    private var recordButtonBg: some View {
        RoundedRectangle(cornerRadius: Neon.Radius.md, style: .continuous)
            .fill(recordingController.state.isRecording
                ? Neon.statusError.opacity(0.10)
                : Color.clear
            )
            .padding(.horizontal, 8)
            .animation(.easeOut(duration: 0.2), value: recordingController.state.isRecording)
    }

    private var micIcon: String {
        switch recordingController.state {
        case .idle:          return "mic"
        case .recording:     return "stop.circle.fill"
        case .transcribing:  return "waveform"
        case .processing:    return "sparkles"
        case .injecting:     return "checkmark.circle"
        case .error:         return "exclamationmark.triangle"
        }
    }

    private var micIconColor: Color {
        switch recordingController.state {
        case .idle:          return Neon.textPrimary
        case .recording:     return Neon.statusError
        case .transcribing:  return Neon.brandPrimary
        case .processing:    return Neon.brandPrimary
        case .injecting:     return Neon.brandBright
        case .error:         return Neon.statusWarning
        }
    }

    private var recordButtonLabel: String {
        switch recordingController.state {
        case .idle:          return "Aufnahme starten"
        case .recording:     return "Aufnahme stoppen"
        case .transcribing:  return "Transkribiere..."
        case .processing:    return "Verbessere..."
        case .injecting:     return "Wird eingefügt..."
        case .error:         return "Erneut versuchen"
        }
    }

    // MARK: - Language Row

    private var languageRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text("Sprache")
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
            Picker("", selection: $language) {
                Text("DE").tag("de")
                Text("EN").tag("en")
            }
            .pickerStyle(.segmented)
            .frame(width: 72)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    // MARK: - Style Row (nur wenn KI aktiv)

    private var styleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "textformat")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text("Stil")
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
            Picker("", selection: $dictationStyle) {
                ForEach(DictationStyle.allCases) { style in
                    Text(style.displayName).tag(style.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 130, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    // MARK: - Letzte Transkription

    private var lastTranscriptSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Zuletzt")
                .neonEyebrow()
                .padding(.horizontal, 16)
                .padding(.top, 10)

            Text(recordingController.lastTranscript)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
    }

    // MARK: - Footer

    private var footerActions: some View {
        VStack(spacing: 0) {
            menuItem(icon: "square.grid.2x2", label: "Dashboard") {
                appEnvironment.openDashboard()
            }
            menuItem(icon: "gear", label: "Einstellungen...") {
                openSettings()
            }
            menuItem(icon: "arrow.triangle.2.circlepath", label: "Nach Updates suchen...") {
                updaterController.checkForUpdates()
            }
            Divider()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            menuItem(icon: "power", label: "Beenden", foregroundStyle: .secondary) {
                NSApp.terminate(nil)
            }
        }
        .padding(.top, 2)
    }

    private func menuItem(
        icon: String,
        label: String,
        foregroundStyle: HierarchicalShapeStyle = .primary,
        action: @escaping () -> Void
    ) -> some View {
        MenuItemButton(icon: icon, label: label, action: action)
    }

    // MARK: - Helpers

    private func kbdHint(_ text: String) -> some View {
        Text(text)
            .font(.neonMono(10, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(Neon.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: Neon.Radius.sm, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: Neon.Radius.sm, style: .continuous)
                            .stroke(Neon.strokeHairline, lineWidth: Neon.hairlineWidth)
                    )
            )
    }

    // MARK: - Actions

    private func toggleRecording() {
        Task { @MainActor in
            await recordingController.toggleRecording()
        }
    }
}

// MARK: - MenuItemButton

private struct MenuItemButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
                .padding(.horizontal, 8)
                .animation(.easeOut(duration: 0.1), value: isHovered)
        )
        .onHover { isHovered = $0 }
    }
}
