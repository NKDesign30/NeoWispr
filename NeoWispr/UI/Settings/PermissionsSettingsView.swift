import SwiftUI

struct PermissionsSettingsView: View {

    @Environment(PermissionGate.self) private var permissionGate

    var body: some View {
        Form {
            Section {
                permissionRow(
                    icon: "mic.fill",
                    iconColor: microphoneIconColor,
                    title: "Mikrofon",
                    description: "Pflicht für die Aufnahme. Ohne Mikrofon-Zugriff kann NeoWispr nicht diktieren.",
                    status: permissionGate.microphoneStatus,
                    actionLabel: microphoneActionLabel,
                    action: requestMicrophonePermission
                )
            } header: {
                Text("Erforderliche Berechtigungen").neonSectionHeader()
            }

            Section {
                permissionRow(
                    icon: "accessibility",
                    iconColor: accessibilityIconColor,
                    title: "Bedienungshilfen",
                    description: "Optional. Ermöglicht direktes Einfügen in Textfelder. Ohne diese Berechtigung wird der Umweg über die Zwischenablage genutzt.",
                    status: permissionGate.accessibilityStatus,
                    actionLabel: accessibilityActionLabel,
                    action: requestAccessibilityPermission
                )
            } header: {
                Text("Optionale Berechtigungen").neonSectionHeader()
            } footer: {
                Text("Ohne Bedienungshilfen funktioniert NeoWispr weiterhin, benutzt aber Cmd+V zum Einfügen.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            refreshPermissions()
        }
        .task {
            await refreshPermissionsWhileVisible()
        }
    }

    // MARK: - Permission Row

    private func permissionRow(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        status: PermissionGate.PermissionStatus,
        actionLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    statusBadge(for: status)
                }

                Spacer()

                Button(actionLabel, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(status == .granted)
            }

            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status Badge

    private func statusBadge(for status: PermissionGate.PermissionStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(for: status))
                .frame(width: 6, height: 6)
            Text(statusText(for: status))
                .font(.system(size: 11))
                .foregroundStyle(statusColor(for: status))
        }
    }

    // MARK: - Helpers

    private func statusColor(for status: PermissionGate.PermissionStatus) -> Color {
        switch status {
        case .granted:    return .green
        case .denied:     return .red
        case .restricted: return .orange
        case .unknown:    return .secondary
        }
    }

    private func statusText(for status: PermissionGate.PermissionStatus) -> String {
        switch status {
        case .granted:    return "Erlaubt"
        case .denied:     return "Verweigert"
        case .restricted: return "Eingeschränkt"
        case .unknown:    return "Unbekannt"
        }
    }

    private var microphoneIconColor: Color {
        statusColor(for: permissionGate.microphoneStatus) == .secondary
            ? .blue
            : statusColor(for: permissionGate.microphoneStatus)
    }

    private var accessibilityIconColor: Color {
        statusColor(for: permissionGate.accessibilityStatus) == .secondary
            ? .purple
            : statusColor(for: permissionGate.accessibilityStatus)
    }

    private var microphoneActionLabel: String {
        switch permissionGate.microphoneStatus {
        case .granted:
            return "Erlaubt"
        case .denied, .restricted:
            return "Öffne Systemeinstellungen"
        case .unknown:
            return "Erlauben"
        }
    }

    private var accessibilityActionLabel: String {
        permissionGate.accessibilityStatus == .granted ? "Erlaubt" : "Erlauben"
    }

    // MARK: - Actions

    private func requestMicrophonePermission() {
        permissionGate.refreshMicrophone()

        switch permissionGate.microphoneStatus {
        case .denied, .restricted:
            openMicrophoneSettings()
        case .unknown:
            Task { @MainActor in
                await permissionGate.checkMicrophone()
            }
        case .granted:
            break
        }
    }

    private func openMicrophoneSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        )
    }

    private func requestAccessibilityPermission() {
        permissionGate.checkAccessibility()
        guard permissionGate.accessibilityStatus != .granted else { return }
        permissionGate.requestAccessibility()
    }

    private func refreshPermissions() {
        permissionGate.refreshAll()
    }

    @MainActor
    private func refreshPermissionsWhileVisible() async {
        refreshPermissions()

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            refreshPermissions()
        }
    }
}
