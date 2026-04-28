import SwiftUI

struct DashboardView: View {

    @Environment(RecordingController.self) private var recordingController
    @Environment(TranscriptionStore.self) private var transcriptionStore
    @Environment(DictionaryStore.self) private var dictionaryStore
    @Environment(\.openSettings) private var openSettings
    @AppStorage(AppSettings.language) private var language: String = "de"
    @AppStorage(AppSettings.sttProvider) private var sttProvider: String = "parakeet"
    @State private var selection: DashboardSection = .home

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .environment(\.dashboardActions, .init(
                    openSettings: { openSettings() },
                    selection: $selection
                ))
                .toolbar(.hidden, for: .windowToolbar)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 880, idealWidth: 980, minHeight: 600, idealHeight: 700)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            brandHeader
            navList
            Spacer(minLength: 0)
            footerStack
        }
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 240)
        .background(Neon.surfaceSunken.ignoresSafeArea())
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
    }

    // Brand header — pulse-mark + "Neo" + "Wispr" lockup (Neo grey, Wispr mint italic)
    private var brandHeader: some View {
        HStack(spacing: Neon.Space.s2) {
            PulseMark(size: 22)
            HStack(spacing: 1) {
                Text("Neo")
                    .font(.neonBody(20, weight: .medium))
                    .foregroundStyle(Color(hex: 0x8E8E8A))
                    .tracking(-0.4)
                Text("Wispr")
                    .font(.neonDisplay(22, italic: true))
                    .foregroundStyle(Neon.brandMint)
                    .tracking(-0.4)
            }
            .baselineOffset(-2)
            Spacer()
        }
        .padding(.horizontal, Neon.Space.s4)
        .padding(.top, Neon.Space.s5)
        .padding(.bottom, Neon.Space.s5)
    }

    // Nav list — section-eyebrow "HAUPT" + items with optional count-badge
    private var navList: some View {
        VStack(alignment: .leading, spacing: Neon.Space.s1) {
            Text("HAUPT")
                .neonEyebrow(color: Neon.textQuaternary)
                .padding(.horizontal, Neon.Space.s4)
                .padding(.bottom, 6)

            ForEach(DashboardSection.allCases) { section in
                navItem(section)
            }
        }
        .padding(.horizontal, Neon.Space.s2)
    }

    private func navItem(_ section: DashboardSection) -> some View {
        let isOn = selection == section
        return Button {
            selection = section
        } label: {
            HStack(spacing: Neon.Space.s3) {
                Image(systemName: isOn ? section.iconFilled : section.icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isOn ? Neon.textPrimary : Neon.textSecondary)
                    .frame(width: 18, alignment: .center)

                Text(section.label)
                    .font(.neonBody(13, weight: isOn ? .medium : .regular))
                    .foregroundStyle(isOn ? Neon.textPrimary : Neon.textSecondary)

                Spacer()

                if let count = badgeCount(for: section) {
                    Text("\(count)")
                        .font(.neonMono(10))
                        .foregroundStyle(Neon.textQuaternary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, Neon.Space.s3)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: Neon.Radius.md, style: .continuous)
                    .fill(isOn ? Color.white.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func badgeCount(for section: DashboardSection) -> Int? {
        switch section {
        case .history:
            let n = transcriptionStore.entries.count
            return n > 0 ? n : nil
        case .snippets:
            return nil
        default:
            return nil
        }
    }

    // Footer — three meta-rows + avatar row
    private var footerStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Neon.strokeHairline).frame(height: Neon.hairlineWidth)

            VStack(spacing: 8) {
                metaRow(label: "HOTKEY", value: hotkeyValue)
                metaRow(label: "MODELL", value: modelLabel)
                metaRow(label: "SPRACHE", value: language.uppercased())
            }
            .padding(.horizontal, Neon.Space.s4)
            .padding(.vertical, Neon.Space.s3)

            Rectangle().fill(Neon.strokeHairline).frame(height: Neon.hairlineWidth)

            avatarRow
                .padding(.horizontal, Neon.Space.s4)
                .padding(.vertical, Neon.Space.s3)
        }
    }

    private func metaRow(label: String, value: AnyView) -> some View {
        HStack {
            Text(label).neonEyebrow()
            Spacer()
            value
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        metaRow(label: label, value: AnyView(
            Text(value)
                .font(.neonMono(11))
                .foregroundStyle(Neon.textSecondary)
        ))
    }

    private var hotkeyValue: AnyView {
        AnyView(
            HStack(spacing: 4) {
                kbd("⌥")
                kbd("Space")
            }
        )
    }

    private func kbd(_ text: String) -> some View {
        Text(text)
            .font(.neonMono(10, weight: .medium))
            .foregroundStyle(Neon.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Neon.strokeHairline, lineWidth: Neon.hairlineWidth)
            )
    }

    private var modelLabel: String {
        switch sttProvider {
        case "parakeet": return "Parakeet V3"
        case "whisper":  return "Whisper"
        default:         return sttProvider.capitalized
        }
    }

    private var avatarRow: some View {
        HStack(spacing: Neon.Space.s2) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Neon.brandPrimary, Color(hex: 0x1F8E5C)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Text("NK")
                    .font(.neonBody(10, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 24, height: 24)

            Text("Niko")
                .font(.neonBody(13))
                .foregroundStyle(Neon.textPrimary)

            Spacer()
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .home:
            HomeView(store: transcriptionStore)
        case .history:
            HistoryView(store: transcriptionStore)
        case .snippets:
            SnippetSettingsView()
        case .dictionary:
            DictionaryView(store: dictionaryStore)
        case .scratchpad:
            ScratchpadView()
        }
    }
}

// MARK: - Toolbar action context (passed via Environment)

struct DashboardActions {
    var openSettings: () -> Void
    var selection: Binding<DashboardSection>
}

private struct DashboardActionsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = DashboardActions(
        openSettings: {},
        selection: .constant(.home)
    )
}

extension EnvironmentValues {
    var dashboardActions: DashboardActions {
        get { self[DashboardActionsKey.self] }
        set { self[DashboardActionsKey.self] = newValue }
    }
}

// MARK: - Toolbar action buttons (live-pill, search, plus, settings)

struct ToolbarActionButtons: View {

    var showSearch: Bool = false
    var showPlus: Bool = false
    var onPlus: (() -> Void)? = nil
    var onSearch: (() -> Void)? = nil

    @Environment(RecordingController.self) private var recordingController
    @Environment(\.dashboardActions) private var actions

    var body: some View {
        HStack(spacing: 6) {
            livePill
            if showSearch {
                iconButton("magnifyingglass", action: onSearch ?? {})
            }
            if showPlus {
                iconButton("plus", action: onPlus ?? {})
            }
            iconButton("gearshape", action: actions.openSettings)
        }
    }

    private var livePill: some View {
        let isActive = recordingController.state.isRecording || recordingController.state.isProcessing
        return Button {
            Task { @MainActor in
                if recordingController.state.isRecording {
                    await recordingController.stopRecording()
                } else if !recordingController.state.isProcessing {
                    await recordingController.startRecording()
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Neon.Radius.md, style: .continuous)
                    .fill(isActive ? Neon.statusError : Neon.brandPrimary)
                Image(systemName: isActive ? "stop.fill" : "mic.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help(isActive ? "Aufnahme beenden" : "Aufnahme starten (⌥ Leertaste)")
    }

    private func iconButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Neon.textSecondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
