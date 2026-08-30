import Foundation

struct HelpManualSection: Identifiable, Hashable {
    let id: String
    let title: String
    let paragraphs: [String]
    let bullets: [String]
    let screenshotAssetNames: [String]
    let tip: String?

    init(
        id: String,
        title: String,
        paragraphs: [String],
        bullets: [String],
        screenshotAssetNames: [String] = [],
        tip: String? = nil
    ) {
        self.id = id
        self.title = title
        self.paragraphs = paragraphs
        self.bullets = bullets
        self.screenshotAssetNames = screenshotAssetNames
        self.tip = tip
    }
}

struct HelpManualDocument {
    let pageTitle: String
    let subtitle: String
    let versionLine: String
    let lastUpdated: String
    let footer: String
    let sections: [HelpManualSection]
}
