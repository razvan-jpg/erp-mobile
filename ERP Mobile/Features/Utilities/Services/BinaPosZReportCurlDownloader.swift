import Foundation

/// Pe macOS nativ poate folosi `curl`; pe Mac Catalyst revine la URLSession (Process e blocat).
enum BinaPosZReportCurlDownloader {
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36"
    private static let acceptLanguage = "ro-RO,ro;q=0.9,en-US;q=0.8,en;q=0.7"

    #if os(macOS)
    /// Login BINA prin curl — fallback pe macOS dacă raw HTTP eșuează.
    static func login(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        email: String,
        password: String
    ) async -> Bool {
        let cookieJar = FileManager.default.temporaryDirectory
            .appendingPathComponent("bina-login-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: cookieJar) }

        let root = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let loginPage = "\(root)/login?lang=ro"
        let loginPost = "\(root)/login"

        let getHTML = await runCurlText(args: [
            "curl", "-sS", "-L", "--max-time", "45",
            "-c", cookieJar.path,
            "-b", cookieJar.path,
            "-H", "User-Agent: \(userAgent)",
            "-H", "Accept-Language: \(acceptLanguage)",
            "-H", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            loginPage,
        ]) ?? ""

        let csrf = cookieCSRFToken(at: cookieJar)
            ?? extractCSRF(from: getHTML)
        guard let csrf, !csrf.isEmpty else { return false }

        let body = [
            "csrfmiddlewaretoken=\(formEncode(csrf))",
            "email=\(formEncode(email.trimmingCharacters(in: .whitespacesAndNewlines)))",
            "password_unhash=\(formEncode(password))",
            "language=ro",
            "lang=ro",
        ].joined(separator: "&")

        let responseBody = await runCurlText(args: [
            "curl", "-sS", "-L", "--max-time", "45",
            "-c", cookieJar.path,
            "-b", cookieJar.path,
            "-X", "POST",
            "-H", "User-Agent: \(userAgent)",
            "-H", "Accept-Language: \(acceptLanguage)",
            "-H", "Content-Type: application/x-www-form-urlencoded; charset=utf-8",
            "-H", "Accept: application/json, text/javascript, */*; q=0.01",
            "-H", "X-Requested-With: XMLHttpRequest",
            "-H", "Origin: \(root)",
            "-H", "Referer: \(loginPage)",
            "-H", "X-CSRFToken: \(csrf)",
            "--data-binary", body,
            loginPost,
        ]) ?? ""

        guard responseBody.contains("\"code\": 200") || responseBody.contains("\"code\":200") else {
            return false
        }

        web.importNetscapeCookieJar(at: cookieJar, base: base)
        web.setRomanianLanguageCookies()
        return web.hasSessionCookie()
    }

    private static func cookieCSRFToken(at jar: URL) -> String? {
        guard let text = try? String(contentsOf: jar, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") {
            guard !line.hasPrefix("#") else { continue }
            let parts = line.split(separator: "\t")
            guard parts.count >= 7, parts[5] == "csrftoken" else { continue }
            return String(parts[6])
        }
        return nil
    }

    private static func extractCSRF(from html: String) -> String? {
        let patterns = [
            #"name=['\"]csrfmiddlewaretoken['\"][^>]*value=['\"]([^'\"]+)['\"]"#,
            #"value=['\"]([^'\"]+)['\"][^>]*name=['\"]csrfmiddlewaretoken['\"]"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        return nil
    }

    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func runCurlText(args: [String]) async -> String? {
        guard let data = await runCurl(args: args) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    #endif

    static func downloadPDF(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        url: URL,
        referer: URL,
        useXHR: Bool
    ) async -> Data? {
        #if os(macOS)
        web.refreshRomanianCookies(base: base)
        let cookieHeader = web.cookieHeaderValue(for: url)
        guard cookieHeader.localizedCaseInsensitiveContains("sessionid=") else {
            return nil
        }

        var args = [
            "curl", "-sS", "-L", "--max-time", "60",
            "-H", "Accept: application/pdf,application/octet-stream;q=0.9,*/*;q=0.8",
            "-H", "Accept-Language: ro-RO,ro;q=0.9,en-US;q=0.8,en;q=0.7",
            "-H", "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36",
            "-H", "Referer: \(referer.absoluteString)",
            "-b", cookieHeader,
            url.absoluteString,
        ]

        if useXHR, let csrf = web.csrfToken() {
            args.insert(contentsOf: ["-H", "X-Requested-With: XMLHttpRequest", "-H", "X-CSRFToken: \(csrf)"], at: args.count - 1)
        }

        return await runCurl(args: args).flatMap { data in
            data.starts(with: [0x25, 0x50, 0x44, 0x46]) ? data : nil
        }
        #else
        return nil
        #endif
    }

    #if os(macOS)
    private static func runCurl(args: [String]) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = args
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }

                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: data.isEmpty ? nil : data)
            }
        }
    }
    #endif
}

extension BinaSmartBusinessSessionClient.WebSession {
    func refreshRomanianCookies(base: URL) {
        rememberBase(base)
        ensureRomanianLanguageCookie(base: base)
        syncTrackedCookies()
    }

}
