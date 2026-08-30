import SwiftUI

struct WhatsNewView: View {
    var useNavigationView = true

    private let document = WhatsNewContent.document
    private let accentBlue = Color(red: 0, green: 0.2, blue: 0.6)

    var body: some View {
        if useNavigationView {
            NavigationView { contentBody }
        } else {
            contentBody
        }
    }

    private var contentBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("whats_new.heading_ro"))
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    Text(L10n.tr("whats_new.heading_en"))
                        .font(.title3.weight(.semibold))
                        .foregroundColor(accentBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

                if let upcoming = document.upcoming, !upcoming.romanianItems.isEmpty {
                    upcomingSection(upcoming)
                }

                ForEach(document.releases) { release in
                    releaseSection(release)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(document.footerRomanian)
                        .foregroundColor(.primary)
                    Text(document.footerEnglish)
                        .foregroundColor(accentBlue)
                }
                .font(.footnote)
                .padding(.top, 8)
                .padding(.bottom, AppChrome.bottomStatusBarHeight + 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .navigationTitle(L10n.tr("tab.whats_new"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func upcomingSection(_ upcoming: WhatsNewUpcoming) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("whats_new.upcoming_title_ro", upcoming.targetVersionLabel))
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                Text(L10n.tr("whats_new.upcoming_title_en", upcoming.targetVersionLabel))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentBlue)
                Text(L10n.tr("whats_new.upcoming_note_ro"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(L10n.tr("whats_new.upcoming_note_en"))
                    .font(.caption)
                    .foregroundColor(accentBlue.opacity(0.85))
            }

            bulletList(upcoming.romanianItems, color: .primary, symbol: "○")
            bulletList(upcoming.englishItems, color: accentBlue, symbol: "○")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accentBlue.opacity(0.35), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground).opacity(0.6))
                )
        )
        .padding(.bottom, 8)
    }

    private func releaseSection(_ release: WhatsNewRelease) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(release.versionTitle)
                .font(.headline.bold())
                .foregroundColor(accentBlue)

            bulletList(release.romanianItems, color: .primary, symbol: "•")
            bulletList(release.englishItems, color: accentBlue, symbol: "•")
        }
        .padding(.vertical, 4)
    }

    private func bulletList(_ items: [String], color: Color, symbol: String = "•") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text(symbol)
                        .font(.body.bold())
                        .foregroundColor(color)
                    Text(item)
                        .font(.subheadline)
                        .foregroundColor(color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
