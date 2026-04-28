import SwiftUI

struct ScratchpadView: View {

    @AppStorage("scratchpad_text") private var text: String = ""

    private var wordCount: Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.split(whereSeparator: { $0.isWhitespace }).count
    }

    private var charCount: Int { text.count }

    /// Approx. reading time at 220 WPM, rounded up to whole minutes (≥1 if any words).
    private var readingMinutes: Int {
        guard wordCount > 0 else { return 0 }
        return max(1, Int(ceil(Double(wordCount) / 220.0)))
    }

    var body: some View {
        VStack(spacing: 0) {
            NeonToolbar(title: "Notizblock", crumb: "DIKTIERE DIREKT HIERMIT") {
                ToolbarActionButtons(showSearch: false)
            }

            statsBar

            editor
        }
        .background(Neon.surfaceBackground.ignoresSafeArea())
    }

    // MARK: - Stats bar — mono uppercase + actions on the right

    private var statsBar: some View {
        HStack(spacing: Neon.Space.s4) {
            Text("\(wordCount) WÖRTER").neonEyebrow()
            dot
            Text("\(charCount) ZEICHEN").neonEyebrow()
            dot
            Text(readingMinutes > 0 ? "\(readingMinutes) MIN LESEZEIT" : "—").neonEyebrow()

            Spacer()

            actionButton(label: "Kopieren", systemImage: "doc.on.doc", action: copyAll)
                .disabled(text.isEmpty)
            actionButton(label: "Löschen", systemImage: "trash", danger: true, action: clearAll)
                .disabled(text.isEmpty)
        }
        .padding(.horizontal, Neon.Space.s6)
        .padding(.vertical, Neon.Space.s3)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Neon.strokeHairline).frame(height: Neon.hairlineWidth)
        }
    }

    private var dot: some View {
        Text("·")
            .font(.neonMono(11))
            .foregroundStyle(Neon.textQuaternary)
    }

    private func actionButton(label: String, systemImage: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 10))
                Text(label)
                    .font(.neonBody(11))
            }
            .foregroundStyle(Neon.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: Neon.Radius.md, style: .continuous)
                    .stroke(Neon.strokeHairline, lineWidth: Neon.hairlineWidth)
            )
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty)
    }

    // MARK: - Editor area with date marker

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Neon.Space.s4) {
                Text(Self.dateMarker())
                    .neonEyebrow()
                    .frame(maxWidth: .infinity, alignment: .center)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.neonBody(15))
                        .foregroundStyle(Neon.textPrimary)
                        .lineSpacing(6)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 360)

                    if text.isEmpty {
                        Text("Tippe hier oder diktiere direkt in dieses Feld…")
                            .font(.neonBody(15))
                            .foregroundStyle(Neon.textTertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding(.horizontal, Neon.Space.s8)
            .padding(.top, Neon.Space.s6)
            .padding(.bottom, Neon.Space.s8)
        }
    }

    static func dateMarker() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMMM · HH:mm"
        return "— " + formatter.string(from: Date()) + " —"
    }

    // MARK: - Actions

    private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func clearAll() {
        text = ""
    }
}
