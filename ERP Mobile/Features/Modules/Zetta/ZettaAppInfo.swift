import Foundation
#if os(iOS)
import UIKit
#endif
#if canImport(Darwin)
import Darwin
#endif

enum ZettaAppInfo {
    /// Sursa de adevăr pentru versiune (și build). La release: actualizează aici,
    /// `MARKETING_VERSION` în Xcode și `Info.plist` / `web/index.html` (+ `web/privacy.html`).
    /// Build-ul Xcode (`CURRENT_PROJECT_VERSION`) urmează automat `MARKETING_VERSION`.
    static let marketingVersion = "1.0.056"

    static let authorName = "Razvan IVAN"
    static let contactEmail = AppInfo.contactEmail
    static let appName = "Zetta"
    static let defaultBundleIdentifier = "ro.dateconta.zetta"

    /// Subiect mail contact: app + versiune + platformă (Mac / iPhone / iPad + model).
    static var contactMailSubject: String {
        "App \(appName) v\(version) — \(platformDescription)"
    }

    static var contactMailURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = contactEmail
        components.queryItems = [URLQueryItem(name: "subject", value: contactMailSubject)]
        return components.url ?? URL(string: "mailto:\(contactEmail)")!
    }

    /// macOS + versiune + model Mac, sau iOS + versiune pe iPhone/iPad + model.
    static var platformDescription: String {
        #if os(macOS)
        return "macOS \(macOSVersionString), \(macModelName)"
        #elseif os(iOS)
        let kind = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        return "iOS \(UIDevice.current.systemVersion) pe \(kind), \(iosDeviceModelName)"
        #else
        return "Unknown"
        #endif
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? defaultBundleIdentifier
    }

    /// Versiunea afișată (din bundle, altfel `marketingVersion`).
    static var version: String {
        bundleString(for: "CFBundleShortVersionString") ?? marketingVersion
    }

    /// Build number — egal cu versiunea (setat automat în Xcode).
    static var build: String {
        bundleString(for: "CFBundleVersion") ?? version
    }

    private static func bundleString(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    #if os(macOS)
    private static var macOSVersionString: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        if v.patchVersion > 0 {
            return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        }
        return "\(v.majorVersion).\(v.minorVersion)"
    }

    private static var macModelName: String {
        macModelNames[macHardwareModelIdentifier] ?? macHardwareModelIdentifier
    }

    private static var macHardwareModelIdentifier: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }
        var model = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &model, &size, nil, 0) == 0 else { return "Mac" }
        return String(cString: model)
    }

    /// Identificator hw.model → nume comercial (fallback: identificatorul brut).
    private static let macModelNames: [String: String] = [
        "MacBookAir8,1": "MacBook Air (2018)",
        "MacBookAir8,2": "MacBook Air (2018)",
        "MacBookAir9,1": "MacBook Air (2020)",
        "MacBookAir10,1": "MacBook Air (M1)",
        "MacBookPro15,1": "MacBook Pro 15\" (2018)",
        "MacBookPro15,2": "MacBook Pro 13\" (2018)",
        "MacBookPro15,3": "MacBook Pro 15\" (2018)",
        "MacBookPro15,4": "MacBook Pro 13\" (2018)",
        "MacBookPro16,1": "MacBook Pro 16\" (2019)",
        "MacBookPro16,2": "MacBook Pro 16\" (2019)",
        "MacBookPro16,3": "MacBook Pro 13\" (2020)",
        "MacBookPro16,4": "MacBook Pro 13\" (2020)",
        "MacBookPro17,1": "MacBook Pro 13\" (M1)",
        "Mac14,2": "MacBook Air (M2)",
        "Mac14,7": "MacBook Pro 13\" (M2)",
        "Mac14,15": "MacBook Air 15\" (M2)",
        "Mac14,3": "Mac mini (M2)",
        "Mac14,12": "Mac mini (M2 Pro)",
        "Mac14,5": "Mac Studio (M2 Max)",
        "Mac14,6": "Mac Studio (M2 Ultra)",
        "Mac14,13": "Mac Studio (M2 Max)",
        "Mac14,14": "Mac Studio (M2 Ultra)",
        "Mac14,8": "MacBook Pro 14\" (M2 Pro)",
        "Mac14,9": "MacBook Pro 14\" (M2 Pro)",
        "Mac14,10": "MacBook Pro 16\" (M2 Pro)",
        "Mac14,11": "MacBook Pro 16\" (M2 Pro)",
        "Mac15,3": "MacBook Air 13\" (M3)",
        "Mac15,4": "MacBook Pro 14\" (M3)",
        "Mac15,5": "MacBook Pro 14\" (M3 Pro)",
        "Mac15,6": "MacBook Pro 16\" (M3 Pro)",
        "Mac15,7": "MacBook Pro 16\" (M3 Pro)",
        "Mac15,8": "MacBook Pro 14\" (M3 Max)",
        "Mac15,9": "MacBook Pro 14\" (M3 Max)",
        "Mac15,10": "MacBook Pro 16\" (M3 Max)",
        "Mac15,11": "MacBook Pro 16\" (M3 Max)",
        "Mac15,12": "MacBook Air 13\" (M3)",
        "Mac15,13": "MacBook Air 15\" (M3)",
        "Mac16,1": "MacBook Pro 14\" (M4)",
        "Mac16,2": "iMac 24\" (M4)",
        "Mac16,3": "MacBook Pro 14\" (M4 Pro)",
        "Mac16,4": "MacBook Pro 14\" (M4 Pro)",
        "Mac16,5": "MacBook Pro 16\" (M4 Pro)",
        "Mac16,6": "MacBook Pro 16\" (M4 Pro)",
        "Mac16,7": "MacBook Pro 14\" (M4 Max)",
        "Mac16,8": "MacBook Pro 16\" (M4 Max)",
        "Mac16,9": "Mac Studio (M4 Max)",
        "Mac16,10": "Mac mini (M4)",
        "Mac16,11": "Mac mini (M4 Pro)",
        "Mac16,12": "MacBook Air 13\" (M4)",
        "Mac16,13": "MacBook Air 15\" (M4)",
        "iMac21,1": "iMac 24\" (M1)",
        "iMac21,2": "iMac 24\" (M1)",
        "Mac13,1": "Mac Studio (M1 Max)",
        "Mac13,2": "Mac Studio (M1 Ultra)"
    ]
    #endif

    #if os(iOS)
    private static var iosDeviceModelName: String {
        iosModelNames[hardwareMachineIdentifier] ?? hardwareMachineIdentifier
    }

    private static var hardwareMachineIdentifier: String {
        #if targetEnvironment(simulator)
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !sim.isEmpty {
            return sim
        }
        #endif
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }

    /// Identificator → nume comercial (fallback: identificatorul brut).
    private static let iosModelNames: [String: String] = [
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone9,1": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone9,3": "iPhone 7",
        "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone10,4": "iPhone 8",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd gen)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd gen)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPad6,11": "iPad (5th gen)",
        "iPad6,12": "iPad (5th gen)",
        "iPad7,5": "iPad (6th gen)",
        "iPad7,6": "iPad (6th gen)",
        "iPad7,11": "iPad (7th gen)",
        "iPad7,12": "iPad (7th gen)",
        "iPad11,6": "iPad (8th gen)",
        "iPad11,7": "iPad (8th gen)",
        "iPad12,1": "iPad (9th gen)",
        "iPad12,2": "iPad (9th gen)",
        "iPad13,18": "iPad (10th gen)",
        "iPad13,19": "iPad (10th gen)",
        "iPad13,1": "iPad Air (4th gen)",
        "iPad13,2": "iPad Air (4th gen)",
        "iPad13,16": "iPad Air (5th gen)",
        "iPad13,17": "iPad Air (5th gen)",
        "iPad14,8": "iPad Air (6th gen)",
        "iPad14,9": "iPad Air (6th gen)",
        "iPad8,1": "iPad Pro 11-inch (1st gen)",
        "iPad8,2": "iPad Pro 11-inch (1st gen)",
        "iPad8,3": "iPad Pro 11-inch (1st gen)",
        "iPad8,4": "iPad Pro 11-inch (1st gen)",
        "iPad8,9": "iPad Pro 11-inch (2nd gen)",
        "iPad8,10": "iPad Pro 11-inch (2nd gen)",
        "iPad13,4": "iPad Pro 11-inch (3rd gen)",
        "iPad13,5": "iPad Pro 11-inch (3rd gen)",
        "iPad13,6": "iPad Pro 11-inch (3rd gen)",
        "iPad13,7": "iPad Pro 11-inch (3rd gen)",
        "iPad14,3": "iPad Pro 11-inch (4th gen)",
        "iPad14,4": "iPad Pro 11-inch (4th gen)",
        "iPad16,3": "iPad Pro 11-inch (M4)",
        "iPad16,4": "iPad Pro 11-inch (M4)",
        "iPad8,5": "iPad Pro 12.9-inch (3rd gen)",
        "iPad8,6": "iPad Pro 12.9-inch (3rd gen)",
        "iPad8,7": "iPad Pro 12.9-inch (3rd gen)",
        "iPad8,8": "iPad Pro 12.9-inch (3rd gen)",
        "iPad8,11": "iPad Pro 12.9-inch (4th gen)",
        "iPad8,12": "iPad Pro 12.9-inch (4th gen)",
        "iPad13,8": "iPad Pro 12.9-inch (5th gen)",
        "iPad13,9": "iPad Pro 12.9-inch (5th gen)",
        "iPad13,10": "iPad Pro 12.9-inch (5th gen)",
        "iPad13,11": "iPad Pro 12.9-inch (5th gen)",
        "iPad14,5": "iPad Pro 12.9-inch (6th gen)",
        "iPad14,6": "iPad Pro 12.9-inch (6th gen)",
        "iPad16,5": "iPad Pro 13-inch (M4)",
        "iPad16,6": "iPad Pro 13-inch (M4)",
        "iPad11,1": "iPad mini (5th gen)",
        "iPad11,2": "iPad mini (5th gen)",
        "iPad14,1": "iPad mini (6th gen)",
        "iPad14,2": "iPad mini (6th gen)",
        "iPad16,1": "iPad mini (A17 Pro)",
        "iPad16,2": "iPad mini (A17 Pro)"
    ]
    #endif
}
