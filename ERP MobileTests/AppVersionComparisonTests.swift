import Foundation
import Testing
@testable import ERPMobile

struct AppVersionComparisonTests {
    @Test func detectsNewerStoreVersion() {
        #expect(AppVersionComparison.compare("1.0.014", "1.0.015") == .orderedAscending)
        #expect(AppVersionComparison.compare("1.0.015", "1.0.016") == .orderedAscending)
        #expect(AppVersionComparison.compare("1.0.9", "1.0.10") == .orderedAscending)
    }

    @Test func detectsSameOrNewerInstalledVersion() {
        #expect(AppVersionComparison.compare("1.0.015", "1.0.015") == .orderedSame)
        #expect(AppVersionComparison.compare("1.0.016", "1.0.015") == .orderedDescending)
        #expect(AppVersionComparison.compare("1.0.10", "1.0.9") == .orderedDescending)
    }

    @Test func buildsPreferredUpdateURLFromTrackId() {
        let url = AppStoreVersionService.preferredUpdateURL(trackId: 6777165137)
        #expect(url?.absoluteString.contains("6777165137") == true)
    }

    @Test func buildsPreferredUpdateURLFromTrackViewURL() {
        let url = AppStoreVersionService.preferredUpdateURL(
            trackViewUrl: "https://apps.apple.com/ro/app/erp-mobile-by-dateconta/id6777165137"
        )
        #expect(url?.absoluteString.contains("6777165137") == true)
    }
}
