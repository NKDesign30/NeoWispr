import SwiftUI

struct HistoryView: View {

    let store: TranscriptionStore

    @State private var searchText: String = ""
    @State private var selectedEntry: TranscriptionEntry? = nil
    @State private var hoveredEntryID: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            NeonToolbar(title: "Historie", crumb: Self.historyCrumb(total: store.entries.count, ai: aiCount)) {
                ToolbarActionButtons(showSearch: false)
            }

            searchBar

            if filteredGrouped.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .background(Neon.surfaceBackground.ignoresSafeArea())
        .sheet(item: $selectedEntry) { entry in
            HistoryDetailView(entry: entry, onDelete: {
                store.delete(entry)
                selectedEntry = nil
            })
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Neon.Space.s3) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Neon.textTertiary)

            TextField("suche durch deine stimme…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.neonMono(12))
                .foregroundStyle(Neon.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Neon.textTertiary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("\(filtered.count) EINTRÄGE · \(aiFilteredCount) KI")
                .neonEyebrow()
        }
        .padding(.horizontal, Neon.Space.s6)
        .padding(.vertical, Neon.Space.s3)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Neon.strokeHairline).frame(height: Neon.hairlineWidth)
        }
    }

    // MARK: - Entry List

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(filteredGrouped, id: \.0.label) { group, entries in
                    Section {
                        ForEach(entries) { entry in
                            HistoryRowDense(
                                entry: entry,
                                isHovered: hoveredEntryID == entry.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { selectedEntry = entry }
                            .onHover { hovering in
                                hoveredEntryID = hovering ? entry.id : nil
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.delete(entry)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            Rectangle()
                                .fill(Neon.strokeHairline)
                                .frame(height: Neon.hairlineWidth)
                                .padding(.leading, Neon.Space.s6)
                        }
                    } header: {
                        sectionHeader(group: group, count: entries.count)
                    }
                }
            }
        }
    }

    private func sectionHeader(group: HistoryGroup, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Neon.Space.s3) {
            Text(group.label)
                .font(.neonDisplay(20))
                .foregroundStyle(Neon.textPrimary)

            if let sub = group.subLabel {
                Text(sub)
                    .neonEyebrow(color: Neon.textTertiary)
            }

            Text("\(count) EINTRÄGE")
                .neonEyebrow()

            Spacer()
        }
        .padding(.horizontal, Neon.Space.s6)
        .padding(.top, Neon.Space.s5)
        .padding(.bottom, Neon.Space.s2)
        .background(Neon.surfaceBackground)
    }

    private var emptyState: some View {
        Group {
            if searchText.isEmpty {
                ContentUnavailableView(
                    "Keine Transkriptionen",
                    systemImage: "clock",
                    description: Text("Diktate erscheinen hier nach der Aufnahme.")
                )
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Crumbs / Counters

    static func historyCrumb(total: Int, ai: Int) -> String {
        "\(total) DIKTATE · \(ai) KI-VERFEINERT"
    }

    private var aiCount: Int {
        store.entries.filter { $0.rawText != nil }.count
    }

    private var aiFilteredCount: Int {
        filtered.filter { $0.rawText != nil }.count
    }

    // MARK: - Computed

    private var filtered: [TranscriptionEntry] {
        guard !searchText.isEmpty else { return store.entries }
        let query = searchText.lowercased()
        return store.entries.filter { $0.text.lowercased().contains(query) }
    }

    private var filteredGrouped: [(HistoryGroup, [TranscriptionEntry])] {
        let calendar = Calendar.current
        var groups: [(HistoryGroup, [TranscriptionEntry])] = []
        var seen: [String: Int] = [:]

        for entry in filtered {
            let group = HistoryGroup.from(entry.timestamp, calendar: calendar)
            if let idx = seen[group.label] {
                groups[idx].1.append(entry)
            } else {
                seen[group.label] = groups.count
                groups.append((group, [entry]))
            }
        }
        return groups
    }
}

// MARK: - HistoryGroup

struct HistoryGroup {
    var label: String
    var subLabel: String?

    static func from(_ date: Date, calendar: Calendar) -> HistoryGroup {
        if calendar.isDateInToday(date) {
            return HistoryGroup(label: "Heute", subLabel: nil)
        }
        if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            formatter.dateFormat = "dd.MM."
            return HistoryGroup(label: "Gestern", subLabel: "· " + formatter.string(from: date))
        }
        let now = Date()
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        if days < 7 {
            formatter.dateFormat = "EEEE"
            let dateFmt = DateFormatter()
            dateFmt.locale = Locale(identifier: "de_DE")
            dateFmt.dateFormat = "dd.MM."
            return HistoryGroup(label: formatter.string(from: date), subLabel: "· " + dateFmt.string(from: date))
        }
        formatter.dateFormat = "dd.MM.yyyy"
        return HistoryGroup(label: formatter.string(from: date), subLabel: nil)
    }
}

// MARK: - HistoryRowDense

private struct HistoryRowDense: View {
    let entry: TranscriptionEntry
    let isHovered: Bool

    var body: some View {
        HStack(spacing: Neon.Space.s3) {
            Text(entry.timestamp, style: .time)
                .font(.neonMono(11))
                .foregroundStyle(Neon.textTertiary)
                .frame(width: 54, alignment: .leading)

            Circle()
                .fill(entry.rawText != nil ? Neon.brandPrimary : Neon.textQuaternary)
                .frame(width: 6, height: 6)

            if entry.rawText != nil {
                Text("KI")
                    .font(.neonMono(10, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(Neon.brandPrimary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: Neon.Radius.sm, style: .continuous)
                            .stroke(Neon.brandMuted, lineWidth: Neon.hairlineWidth)
                    )
            }

            Text(entry.text)
                .font(.neonBody(13))
                .foregroundStyle(Neon.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: Neon.Space.s2)

            if let appName = entry.appName, !appName.isEmpty {
                Text(appName.uppercased())
                    .font(.neonMono(10))
                    .tracking(0.6)
                    .foregroundStyle(Neon.textQuaternary)
                    .lineLimit(1)
                    .frame(maxWidth: 90, alignment: .trailing)
            }
        }
        .padding(.horizontal, Neon.Space.s6)
        .padding(.vertical, Neon.Space.s3)
        .background(isHovered ? Neon.surfaceRowHover : Color.clear)
    }
}

// MARK: - HistoryDetailView

struct HistoryDetailView: View {

    let entry: TranscriptionEntry
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var showRaw = false

    private var hasRaw: Bool { entry.rawText != nil }

    private var displayedText: String {
        if showRaw, let raw = entry.rawText { return raw }
        return entry.text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader
            if hasRaw {
                rawToggle
            }
            Divider()
            ScrollView {
                Text(displayedText)
                    .font(.neonBody(15))
                    .lineSpacing(4)
                    .foregroundStyle(Neon.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Neon.Space.s5)
            }
            Divider()
            detailFooter
        }
        .frame(minWidth: 480, minHeight: 320)
        .background(Neon.surfaceBackground)
    }

    private var rawToggle: some View {
        HStack {
            Picker("", selection: $showRaw) {
                Text("Verbessert").tag(false)
                Text("Original").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            Spacer()
        }
        .padding(.horizontal, Neon.Space.s5)
        .padding(.bottom, Neon.Space.s2)
    }

    private var detailHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.timestamp, style: .date)
                    .font(.neonDisplay(20))
                    .foregroundStyle(Neon.textPrimary)
                Text(entry.timestamp, style: .time)
                    .font(.neonMono(11))
                    .foregroundStyle(Neon.textTertiary)
            }
            Spacer()
            if let appName = entry.appName, !appName.isEmpty {
                Text(appName.uppercased())
                    .neonEyebrow()
                    .padding(.trailing, Neon.Space.s2)
            }
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Neon.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Neon.Space.s5)
        .padding(.vertical, Neon.Space.s4)
    }

    private var detailFooter: some View {
        HStack {
            Text("\(entry.wordCount) Wörter".uppercased())
                .neonEyebrow()
            Spacer()
            Button(action: copyText) {
                Label(
                    copied ? "Kopiert" : "Kopieren",
                    systemImage: copied ? "checkmark" : "doc.on.doc"
                )
                .font(.neonBody(12))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .animation(.easeOut(duration: 0.15), value: copied)

            Button(role: .destructive, action: onDelete) {
                Label("Löschen", systemImage: "trash")
                    .font(.neonBody(12))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.horizontal, Neon.Space.s5)
        .padding(.vertical, Neon.Space.s3)
    }

    private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayedText, forType: .string)
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copied = false }
        }
    }
}
