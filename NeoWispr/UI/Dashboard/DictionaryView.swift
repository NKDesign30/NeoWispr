import SwiftUI

struct DictionaryView: View {

    let store: DictionaryStore

    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            NeonToolbar(title: "Wörterbuch", crumb: "AUTO-KORREKTUR") {
                ToolbarActionButtons(
                    showPlus: !store.entries.isEmpty,
                    onPlus: { showAddSheet = true }
                )
            }

            if store.entries.isEmpty {
                emptyStateRefined
            } else {
                infoHeader
                Rectangle()
                    .fill(Neon.strokeHairline)
                    .frame(height: Neon.hairlineWidth)
                entryList
            }
        }
        .background(Neon.surfaceBackground.ignoresSafeArea())
        .sheet(isPresented: $showAddSheet) {
            AddDictionaryEntrySheet(store: store)
        }
    }

    // MARK: - Header (filled)

    private var infoHeader: some View {
        HStack(spacing: Neon.Space.s2) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(Neon.textTertiary)
                .symbolRenderingMode(.hierarchical)
            Text("Wörter die Whisper falsch erkennt, werden hier automatisch korrigiert.")
                .font(.neonBody(11))
                .foregroundStyle(Neon.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Neon.Space.s4)
        .padding(.vertical, Neon.Space.s2)
        .background(Neon.surfaceSunken)
    }

    // MARK: - Entry List (filled)

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                    DictionaryRow(entry: entry)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.delete(entry)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    if index < store.entries.count - 1 {
                        Rectangle()
                            .fill(Neon.strokeHairline)
                            .frame(height: Neon.hairlineWidth)
                    }
                }
            }
        }
    }

    // MARK: - Empty State (refined, B) — display headline 2-line + brand CTA + hint

    private var emptyStateRefined: some View {
        VStack(spacing: Neon.Space.s4) {
            ZStack {
                RoundedRectangle(cornerRadius: Neon.Radius.xl, style: .continuous)
                    .fill(Neon.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Neon.Radius.xl, style: .continuous)
                            .stroke(Neon.strokeHairline, lineWidth: Neon.hairlineWidth)
                    )
                Image(systemName: "character.book.closed")
                    .font(.system(size: 24))
                    .foregroundStyle(Neon.textTertiary)
            }
            .frame(width: 56, height: 56)
            .padding(.bottom, Neon.Space.s2)

            Text("Lehre Whisper, deine\nWelt zu hören.")
                .font(.neonDisplay(34))
                .foregroundStyle(Neon.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("Eigennamen, Fachbegriffe oder hartnäckige Fehlerkennungen — füge sie hier hinzu, und NeoWispr korrigiert sie automatisch im Hintergrund.")
                .font(.neonBody(13))
                .foregroundStyle(Neon.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .lineSpacing(2)

            primaryCTA(label: "Erstes Wort hinzufügen") { showAddSheet = true }
                .padding(.top, Neon.Space.s2)

            Text("ODER ⌘D AUS DER HISTORIE")
                .neonEyebrow()
                .padding(.top, Neon.Space.s4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Neon.Space.s10)
    }

    private func primaryCTA(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.neonBody(13, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Neon.Space.s4)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: Neon.Radius.md, style: .continuous)
                    .fill(Neon.brandPrimary)
            )
        }
        .buttonStyle(.plain)
    }

    private func kbdSymbol(_ key: String) -> some View {
        Text(key)
            .font(.neonMono(11, weight: .medium))
            .foregroundStyle(Neon.textPrimary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Neon.surfaceElevated)
            )
    }
}

// MARK: - DictionaryRow

private struct DictionaryRow: View {
    let entry: DictionaryEntry

    var body: some View {
        HStack(spacing: Neon.Space.s3) {
            Text(entry.wrongWord)
                .font(.neonBody(13))
                .foregroundStyle(Neon.textSecondary)
                .strikethrough(true, color: Neon.textSecondary.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Neon.textQuaternary)

            Text(entry.correctWord)
                .font(.neonBody(13, weight: .medium))
                .foregroundStyle(Neon.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Neon.Space.s4)
        .padding(.vertical, Neon.Space.s3)
    }
}

// MARK: - AddDictionaryEntrySheet

private struct AddDictionaryEntrySheet: View {

    let store: DictionaryStore

    @State private var wrongWord = ""
    @State private var correctWord = ""
    @Environment(\.dismiss) private var dismiss

    var isValid: Bool {
        !wrongWord.trimmingCharacters(in: .whitespaces).isEmpty &&
        !correctWord.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sheetHeader
            Divider()
            sheetForm
            Divider()
            sheetFooter
        }
        .frame(width: 360)
    }

    private var sheetHeader: some View {
        HStack {
            Text("Eintrag hinzufügen")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var sheetForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Whisper erkennt fälschlicherweise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("z. B. whisper", text: $wrongWord)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Korrekte Schreibweise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("z. B. Whisper", text: $correctWord)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(20)
    }

    private var sheetFooter: some View {
        HStack {
            Button("Abbrechen") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Hinzufügen") {
                store.add(wrongWord: wrongWord, correctWord: correctWord)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
