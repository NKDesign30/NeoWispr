import SwiftUI

/// Editorial toolbar — display-title + mono-crumb (left) + actions (right).
///
/// Used at the top of every detail view in the dashboard. Mirrors the design
/// signature: a serif headline like "Übersicht" sitting next to a mono caption
/// like "MITTWOCH · 27. APRIL", separated by a hairline divider.
struct NeonToolbar<Trailing: View>: View {

    let title: String
    var crumb: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.neonDisplay(22))
                .foregroundStyle(Neon.textPrimary)

            if let crumb {
                Text(crumb)
                    .neonEyebrow()
                    .padding(.leading, Neon.Space.s3)
                    .padding(.leading, Neon.Space.s2)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Neon.strokeHairline)
                            .frame(width: Neon.hairlineWidth, height: 14)
                            .padding(.leading, Neon.Space.s3)
                    }
            }

            Spacer()
            trailing()
        }
        .padding(.horizontal, Neon.Space.s4)
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Neon.strokeHairline)
                .frame(height: Neon.hairlineWidth)
        }
    }
}

extension NeonToolbar where Trailing == EmptyView {
    init(title: String, crumb: String? = nil) {
        self.title = title
        self.crumb = crumb
        self.trailing = { EmptyView() }
    }
}
