import Foundation

enum OfflineNetwork {
    static func isTransient(_ error: Error) -> Bool {
        if error is OfflineQueuedError { return false }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .timedOut, .networkConnectionLost,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
                 .internationalRoamingOff, .dataNotAllowed, .resourceUnavailable:
                return true
            default:
                break
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost, NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed:
                return true
            default:
                break
            }
        }
        let message = error.localizedDescription.lowercased()
        if message.contains("offline") { return true }
        if message.contains("network connection was lost") { return true }
        if message.contains("the internet connection appears to be offline") { return true }
        if message.contains("could not connect to the server") { return true }
        if message.contains("timed out") { return true }
        return false
    }
}

/// Thrown when a write was accepted locally and queued for sync (not a hard failure).
struct OfflineQueuedError: LocalizedError {
    var errorDescription: String? {
        L10n.tr("offline.saved_pending_sync")
    }
}
