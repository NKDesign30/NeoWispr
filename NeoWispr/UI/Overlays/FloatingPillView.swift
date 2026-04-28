import SwiftUI

struct FloatingPillView: View {

    let controller: RecordingController
    let onCancel: () -> Void

    @State private var animating = false

    var body: some View {
        HStack(spacing: 16) {
            cancelButton
            statusContent
                .frame(maxWidth: .infinity)
            actionButton
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(pillBackground)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.65).repeatForever(autoreverses: true)
            ) {
                animating = true
            }
        }
    }

    // MARK: - Cancel Button

    private var cancelButton: some View {
        Button(action: {
            Task { @MainActor in
                if controller.state.isRecording {
                    await controller.stopRecording()
                }
                onCancel()
            }
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Neon.textSecondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.10))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Content

    @ViewBuilder
    private var statusContent: some View {
        switch controller.state {
        case .recording:
            if let ctx = controller.commandContext {
                commandRecordingView(selection: ctx.selection)
            } else {
                WaveformView(animating: animating)
                    .frame(height: 20)
            }
        case .transcribing:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Neon.textSecondary)
                        .frame(width: 4, height: 4)
                        .opacity(animating ? 1.0 : 0.25)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever()
                                .delay(Double(i) * 0.16),
                            value: animating
                        )
                }
            }
        case .processing:
            HStack(spacing: 6) {
                Image(systemName: controller.commandContext != nil ? "wand.and.stars" : "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Neon.brandPrimary)
                    .symbolEffect(.pulse, options: .repeating, isActive: animating)
                Text(controller.commandContext != nil ? "Transformiere..." : "Verbessere...")
                    .font(.neonMono(11))
                    .foregroundStyle(Neon.textSecondary)
            }
        case .injecting:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Neon.brandPrimary)
                .transition(.scale(0.5).combined(with: .opacity))
        case .error(let message):
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Neon.statusWarning)
                Text(message)
                    .font(.neonBody(11, weight: .medium))
                    .foregroundStyle(Neon.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Command Mode Visual

    private func commandRecordingView(selection: String) -> some View {
        HStack(spacing: Neon.Space.s2) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Neon.brandPrimary)
                .symbolEffect(.pulse, options: .repeating, isActive: animating)
            Text(truncated(selection))
                .font(.neonBody(11))
                .foregroundStyle(Neon.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func truncated(_ text: String, words: Int = 4) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ")
        if parts.count <= words { return trimmed }
        return parts.prefix(words).joined(separator: " ") + "..."
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: {
            Task { @MainActor in
                if case .error = controller.state {
                    onCancel()
                    return
                }
                await controller.toggleRecording()
                if case .idle = controller.state {
                    onCancel()
                }
            }
        }) {
            Image(systemName: actionIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(actionColor)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: controller.state.isRecording)
    }

    private var actionIcon: String {
        switch controller.state {
        case .recording:
            return "stop.fill"
        case .error:
            return "xmark"
        default:
            return "ellipsis"
        }
    }

    private var actionColor: Color {
        switch controller.state {
        case .recording:
            return Neon.statusError
        case .error:
            return Neon.statusWarning
        default:
            return Neon.brandPrimary
        }
    }

    // MARK: - Background

    // Background is now handled by NSVisualEffectView in FloatingPillPanel.
    // We only keep a subtle inner shape for structure — no material, no shadow.
    private var pillBackground: some View {
        Color.clear
    }
}

// MARK: - Waveform

struct WaveformView: View {
    let animating: Bool
    private let barCount = 7

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Neon.brandPrimary.opacity(0.85))
                    .frame(width: 3, height: barHeight(index: i))
                    .animation(
                        .easeInOut(duration: 0.35 + Double(i) * 0.06)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.05),
                        value: animating
                    )
            }
        }
    }

    private func barHeight(index: Int) -> CGFloat {
        let heights: [CGFloat]    = [5, 10, 16, 22, 16, 10, 5]
        let amplitudes: [CGFloat] = [3,  5,  7,  8,  7,  5, 3]
        let base = heights[index]
        let amp = amplitudes[index]
        return animating ? base + amp : base
    }
}
