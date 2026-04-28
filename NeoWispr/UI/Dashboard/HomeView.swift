import SwiftUI

struct HomeView: View {

    let store: TranscriptionStore

    var body: some View {
        VStack(spacing: 0) {
            NeonToolbar(title: "Übersicht", crumb: Self.todayCrumb()) {
                ToolbarActionButtons(showSearch: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Neon.Space.s8) {
                    hero
                    statsRow
                    recentSection
                }
                .padding(.horizontal, Neon.Space.s6)
                .padding(.top, Neon.Space.s6)
                .padding(.bottom, Neon.Space.s10)
            }
        }
        .background(Neon.surfaceBackground.ignoresSafeArea())
    }

    // MARK: - Hero — eyebrow → display number → body line

    private var hero: some View {
        let factor = store.speedFactor
        let factorString = factor >= 1
            ? String(format: "%.1f×", factor).replacingOccurrences(of: ".", with: ",")
            : "—"

        return VStack(alignment: .leading, spacing: Neon.Space.s2) {
            Text("DU SPRICHST").neonEyebrow()

            HStack(alignment: .lastTextBaseline, spacing: Neon.Space.s4) {
                Text(factorString)
                    .font(.neonDisplay(80))
                    .foregroundStyle(Neon.brandPrimary)
                    .monospacedDigit()

                Text("schneller, als du tippen kannst.")
                    .font(.neonBody(15))
                    .foregroundStyle(Neon.textSecondary)
                    .padding(.bottom, 8)
            }
        }
        .padding(.top, Neon.Space.s2)
    }

    // MARK: - Stats row — three separate tile cards

    private var statsRow: some View {
        let savedDelta = "+\(Self.formatDelta(ms: max(0, store.timeSavedMs / 30)))"

        return HStack(spacing: Neon.Space.s3) {
            statTile(
                eyebrow: "ZEIT GESPART · 7 TAGE",
                value: Self.formatDuration(ms: store.timeSavedMs),
                caption: "\(savedDelta) heute",
                emphasis: false
            )
            statTile(
                eyebrow: "WÖRTER",
                value: Self.compactNumber(store.wordsTotal),
                caption: store.averageWPM > 0 ? "Ø \(store.averageWPM) WPM" : nil,
                emphasis: false
            )
            statTile(
                eyebrow: "STREAK",
                value: "\(store.streak)",
                caption: store.streak == 1 ? "Tag in Folge" : "Tage in Folge",
                emphasis: store.streak > 0
            )
        }
    }

    private func statTile(eyebrow: String, value: String, caption: String?, emphasis: Bool) -> some View {
        VStack(alignment: .leading, spacing: Neon.Space.s3) {
            Text(eyebrow).neonEyebrow()

            Text(value)
                .font(.neonDisplay(44))
                .foregroundStyle(emphasis ? Neon.brandPrimary : Neon.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let caption {
                Text(caption)
                    .font(.neonBody(12))
                    .foregroundStyle(Neon.textTertiary)
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Neon.Space.s5)
        .padding(.vertical, Neon.Space.s5)
        .background(Neon.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Neon.Radius.xl, style: .continuous))
        .neonHairline(radius: Neon.Radius.xl)
    }

    // MARK: - Recent — display section title with mono crumb, then rows

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Neon.Space.s3) {
            HStack(alignment: .firstTextBaseline) {
                Text("Zuletzt diktiert")
                    .font(.neonDisplay(24))
                    .foregroundStyle(Neon.textPrimary)
                Spacer()
                Text(Self.recentCrumb(count: min(store.entries.count, 5)))
                    .neonEyebrow()
            }

            if store.entries.isEmpty {
                emptyRecent
            } else {
                VStack(spacing: 0) {
                    let visible = Array(store.entries.prefix(5).enumerated())
                    ForEach(visible, id: \.element.id) { index, entry in
                        RecentEntryRow(entry: entry)
                        if index < visible.count - 1 {
                            Rectangle()
                                .fill(Neon.strokeHairline)
                                .frame(height: Neon.hairlineWidth)
                        }
                    }
                }
                .background(Neon.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Neon.Radius.xl, style: .continuous))
                .neonHairline(radius: Neon.Radius.xl)
            }
        }
    }

    private var emptyRecent: some View {
        Text("Noch keine Diktate — halte ⌥ Leertaste gedrückt um zu beginnen.")
            .font(.neonBody(13))
            .foregroundStyle(Neon.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Neon.Space.s5)
            .background(Neon.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Neon.Radius.xl, style: .continuous))
            .neonHairline(radius: Neon.Radius.xl)
    }

    // MARK: - Crumbs

    static func todayCrumb() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE · d. MMMM"
        return formatter.string(from: Date()).uppercased()
    }

    static func recentCrumb(count: Int) -> String {
        "HEUTE · \(count) EINTRÄGE"
    }

    // MARK: - Formatting helpers

    static func formatDuration(ms: Int) -> String {
        let totalSeconds = ms / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    static func formatDelta(ms: Int) -> String {
        let seconds = ms / 1000
        if seconds >= 60 { return "\(seconds / 60)m" }
        return "\(seconds)s"
    }

    static func compactNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            let m = Double(n) / 1_000_000.0
            return String(format: m.truncatingRemainder(dividingBy: 1) == 0 ? "%.0fM" : "%.1fM", m)
        }
        if n >= 1_000 {
            let k = Double(n) / 1_000.0
            return String(format: k.truncatingRemainder(dividingBy: 1) == 0 ? "%.0fk" : "%.1fk", k)
                .replacingOccurrences(of: ".", with: ",")
        }
        return "\(n)"
    }
}

// MARK: - RecentEntryRow

private struct RecentEntryRow: View {
    let entry: TranscriptionEntry
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Neon.Space.s3) {
            Text(entry.timestamp, style: .time)
                .font(.neonMono(11))
                .foregroundStyle(Neon.textTertiary)
                .frame(width: 48, alignment: .leading)

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
        .padding(.horizontal, Neon.Space.s5)
        .padding(.vertical, Neon.Space.s3)
        .background(isHovered ? Neon.surfaceRowHover : Color.clear)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}
