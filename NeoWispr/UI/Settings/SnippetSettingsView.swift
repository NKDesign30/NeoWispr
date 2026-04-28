import SwiftUI

struct SnippetSettingsView: View {

    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var snippets: [Snippet] = []
    @State private var showAddSheet = false
    @State private var editingSnippet: Snippet? = nil
    @State private var hoveredID: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            NeonToolbar(title: "Ersetzungen", crumb: "TRIGGER → EXPANSION") {
                ToolbarActionButtons(showPlus: true, onPlus: { showAddSheet = true })
            }

            if snippets.isEmpty {
                emptyState
            } else {
                snippetList
            }
            Rectangle()
                .fill(Neon.strokeHairline)
                .frame(height: Neon.hairlineWidth)
            toolbar
        }
        .background(Neon.surfaceBackground.ignoresSafeArea())
        .onAppear { loadSnippets() }
        .sheet(isPresented: $showAddSheet) {
            SnippetEditSheet(snippet: nil) { newSnippet in
                snippets.append(newSnippet)
                saveSnippets()
            }
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditSheet(snippet: snippet) { updated in
                if let index = snippets.firstIndex(where: { $0.id == updated.id }) {
                    snippets[index] = updated
                    saveSnippets()
                }
            }
        }
    }

    // MARK: - List — Two-Column with chip-styled trigger

    private var snippetList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(snippets.enumerated()), id: \.element.id) { index, snippet in
                    snippetRow(snippet, isLast: index == snippets.count - 1)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func snippetRow(_ snippet: Snippet, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Neon.Space.s4) {
                triggerChip(snippet.trigger)
                    .frame(width: 140, alignment: .leading)

                Text(snippet.expansion)
                    .font(.neonBody(13))
                    .foregroundStyle(Neon.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    editingSnippet = snippet
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(Neon.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(hoveredID == snippet.id ? 1.0 : 0.4)
            }
            .padding(.horizontal, Neon.Space.s4)
            .padding(.vertical, Neon.Space.s3)
            .background(hoveredID == snippet.id ? Neon.surfaceRowHover : Color.clear)
            .contentShape(Rectangle())
            .onHover { hoveredID = $0 ? snippet.id : nil }
            .onTapGesture { editingSnippet = snippet }

            if !isLast {
                Rectangle()
                    .fill(Neon.strokeHairline)
                    .frame(height: Neon.hairlineWidth)
                    .padding(.leading, Neon.Space.s4)
            }
        }
    }

    private func triggerChip(_ trigger: String) -> some View {
        HStack(spacing: 6) {
            Text("\\")
                .font(.neonMono(12, weight: .medium))
                .foregroundStyle(Neon.brandBright.opacity(0.55))
            Text(trigger)
                .font(.neonMono(12, weight: .medium))
                .foregroundStyle(Neon.brandBright)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: Neon.Radius.md, style: .continuous)
                .fill(Neon.brandFaint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Neon.Radius.md, style: .continuous)
                .stroke(Neon.brandMuted, lineWidth: Neon.hairlineWidth)
        )
    }

    private var emptyState: some View {
        VStack(spacing: Neon.Space.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: Neon.Radius.xl, style: .continuous)
                    .fill(Neon.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: Neon.Radius.xl, style: .continuous)
                            .stroke(Neon.strokeHairline, lineWidth: Neon.hairlineWidth)
                    )
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 24))
                    .foregroundStyle(Neon.textTertiary)
            }
            .frame(width: 56, height: 56)

            Text("Schreib weniger,\nsag mehr.")
                .font(.neonDisplay(34))
                .foregroundStyle(Neon.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("Erstelle Kürzel und Wort-Ersetzungen für häufige Texte. Trigger sind kleingeschrieben und beginnen mit Backslash.")
                .font(.neonBody(13))
                .foregroundStyle(Neon.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button {
                showAddSheet = true
            } label: {
                Label("Ersetzung hinzufügen", systemImage: "plus")
                    .font(.neonBody(12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(Neon.brandPrimary)
            .controlSize(.small)
            .padding(.top, Neon.Space.s1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Neon.Space.s8)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 0) {
            toolbarButton(systemImage: "plus") {
                showAddSheet = true
            }

            toolbarButton(systemImage: "minus") {
                if let index = snippets.indices.last {
                    snippets.remove(at: index)
                    saveSnippets()
                }
            }
            .disabled(snippets.isEmpty)

            Spacer()

            Text("\(snippets.count) Ersetzung\(snippets.count == 1 ? "" : "en")")
                .font(.neonMono(11))
                .foregroundStyle(Neon.textTertiary)
                .padding(.trailing, Neon.Space.s4)
        }
        .padding(.leading, 6)
        .frame(height: 28)
    }

    private func toolbarButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Neon.textSecondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Persistence

    private func loadSnippets() {
        guard let loaded = try? SnippetStore.load() else {
            snippets = SnippetStore.defaultSnippets()
            return
        }
        snippets = loaded
    }

    private func saveSnippets() {
        try? SnippetStore.save(snippets)
        appEnvironment.snippetEngine.update(snippets: snippets)
    }
}

// MARK: - SnippetEditSheet

private struct SnippetEditSheet: View {

    let snippet: Snippet?
    let onSave: (Snippet) -> Void

    @State private var trigger: String = ""
    @State private var expansion: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
            Divider()
            footer
        }
        .frame(width: 400)
        .onAppear {
            trigger = snippet?.trigger ?? ""
            expansion = snippet?.expansion ?? ""
        }
    }

    private var header: some View {
        HStack {
            Text(snippet == nil ? "Ersetzung hinzufügen" : "Ersetzung bearbeiten")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Auslöser")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("z.B. meine adresse", text: $trigger)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Erweiterung")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextEditor(text: $expansion)
                    .font(.system(size: 12))
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            Button("Abbrechen") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Button("Speichern") {
                let saved = Snippet(
                    id: snippet?.id ?? UUID(),
                    trigger: trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                    expansion: expansion.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                onSave(saved)
                dismiss()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      expansion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
