import Foundation

/// Zetta was originally split across native macOS and iOS targets.
/// ERP Mobile runs on Mac via Catalyst, so desktop file panels apply only to native macOS.
enum ZettaPlatform {
    static var isNativeMac: Bool {
        #if os(macOS) && !targetEnvironment(macCatalyst)
        true
        #else
        false
        #endif
    }
}
