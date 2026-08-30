import Foundation

struct WhatsNewUpcoming: Sendable {
    /// Etichetă versiune țintă (ex. „1.0.023”) — doar orientativ.
    let targetVersionLabel: String
    let romanianItems: [String]
    let englishItems: [String]
}

struct WhatsNewRelease: Identifiable, Hashable, Sendable {
    let version: String
    let dateLabel: String
    let romanianItems: [String]
    let englishItems: [String]

    var id: String { version }

    var versionTitle: String {
        "Ver \(version) — \(dateLabel)"
    }
}

struct WhatsNewDocument: Sendable {
    /// Planificat pentru versiunea următoare — la release, mută itemii implementați în `releases` și actualizează lista.
    let upcoming: WhatsNewUpcoming?
    let releases: [WhatsNewRelease]
    let footerRomanian: String
    let footerEnglish: String
}
