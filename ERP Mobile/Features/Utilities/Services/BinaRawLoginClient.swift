import Foundation
import Network

private final class BinaRawHTTPRequestState: @unchecked Sendable {
    nonisolated(unsafe) private var finished = false
    nonisolated(unsafe) private var responseData = Data()
    private let lock = NSLock()

    nonisolated func appendResponse(_ chunk: Data) {
        lock.lock()
        responseData.append(chunk)
        lock.unlock()
    }

    nonisolated func responseSnapshot() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return responseData
    }

    nonisolated func markFinished() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        finished = true
        return true
    }
}

private final class BinaRawHTTPExecutor: @unchecked Sendable {
    private let host: String
    private let path: String
    private let method: String
    private let headers: [String: String]
    private let cookieHeader: String?
    private let body: Data?
    private let requestState = BinaRawHTTPRequestState()
    nonisolated(unsafe) private var connection: NWConnection!
    nonisolated(unsafe) private var continuation: CheckedContinuation<BinaRawHTTPClient.Response, Error>?

    nonisolated init(
        host: String,
        path: String,
        method: String,
        headers: [String: String],
        cookieHeader: String?,
        body: Data?
    ) {
        self.host = host
        self.path = path
        self.method = method
        self.headers = headers
        self.cookieHeader = cookieHeader
        self.body = body
    }

    nonisolated func run() async throws -> BinaRawHTTPClient.Response {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: 443,
                using: .tls
            )
            self.connection.stateUpdateHandler = { [weak self] update in
                self?.handleState(update)
            }
            self.connection.start(queue: .global(qos: .userInitiated))
        }
    }

    nonisolated private func finish(_ result: Result<BinaRawHTTPClient.Response, Error>) {
        guard requestState.markFinished() else { return }
        connection.cancel()
        continuation?.resume(with: result)
        continuation = nil
    }

    nonisolated private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                self.finish(.failure(error))
                return
            }
            if let data, !data.isEmpty {
                self.requestState.appendResponse(data)
            }
            if isComplete {
                do {
                    let response = try BinaRawHTTPClient.parseHTTPResponse(self.requestState.responseSnapshot())
                    self.finish(.success(response))
                } catch {
                    self.finish(.failure(error))
                }
                return
            }
            self.receiveNext()
        }
    }

    nonisolated private func handleState(_ update: NWConnection.State) {
        switch update {
        case .ready:
            var lines = ["\(method) \(path) HTTP/1.1", "Host: \(host)", "Connection: close", "Accept-Encoding: identity"]
            if let cookieHeader, !cookieHeader.isEmpty {
                lines.append("Cookie: \(cookieHeader)")
            }
            for (key, value) in headers {
                lines.append("\(key): \(value)")
            }
            if let body {
                lines.append("Content-Length: \(body.count)")
            }
            var requestData = Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
            if let body {
                requestData.append(body)
            }
            connection.send(content: requestData, completion: .contentProcessed { [weak self] error in
                guard let self else { return }
                if let error {
                    self.finish(.failure(error))
                } else {
                    self.receiveNext()
                }
            })
        case .failed(let error):
            finish(.failure(error))
        case .cancelled:
            finish(.failure(CashRegisterExtractError.network("Conexiune BINA întreruptă")))
        default:
            break
        }
    }
}

/// Client HTTP BINA — login + request-uri autentificate cu cookie jar complet.
enum BinaRawHTTPClient {
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36"
    private static let acceptLanguage = "ro-RO,ro;q=0.9,en-US;q=0.8,en;q=0.7"

    struct Response {
        let statusCode: Int
        let cookies: [String: String]
        let body: Data
        var bodyText: String { String(data: body, encoding: .utf8) ?? "" }
    }

    // MARK: - Login

    static func login(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        email: String,
        password: String
    ) async throws {
        let host = base.host ?? "app.binasmartbusiness.com"
        let root = "https://\(host)"
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            throw CashRegisterExtractError.network("BINA: email sau parolă lipsă")
        }

        let getResponse = try await request(
            host: host,
            path: "/login?lang=ro",
            method: "GET",
            headers: [
                "User-Agent": userAgent,
                "Accept-Language": acceptLanguage,
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Referer": "\(root)/login?lang=ro",
            ],
            cookies: [:],
            body: nil
        )

        guard (200...399).contains(getResponse.statusCode) else {
            throw CashRegisterExtractError.network("BINA: pagina login HTTP \(getResponse.statusCode)")
        }

        var cookies = getResponse.cookies
        let csrf = cookies["csrftoken"] ?? extractCSRF(from: getResponse.body)
        guard let csrf, !csrf.isEmpty else {
            throw CashRegisterExtractError.unsupportedResponse
        }

        let formBody = formEncoded([
            "csrfmiddlewaretoken": csrf,
            "email": trimmedEmail,
            "password_unhash": trimmedPassword,
            "language": "ro",
            "lang": "ro",
        ])

        let postResponse = try await request(
            host: host,
            path: "/login",
            method: "POST",
            headers: [
                "User-Agent": userAgent,
                "Accept-Language": acceptLanguage,
                "Content-Type": "application/x-www-form-urlencoded; charset=utf-8",
                "Accept": "application/json, text/javascript, */*; q=0.01",
                "X-Requested-With": "XMLHttpRequest",
                "Origin": root,
                "Referer": "\(root)/login?lang=ro",
                "X-CSRFToken": csrf,
            ],
            cookies: cookies,
            body: formBody
        )

        cookies.merge(postResponse.cookies) { _, new in new }
        let bodyText = postResponse.bodyText

        if bodyText.localizedCaseInsensitiveContains("password is wrong") {
            throw CashRegisterExtractError.network("Parolă greșită")
        }
        if postResponse.statusCode == 403 || bodyText.localizedCaseInsensitiveContains("403 forbidden") {
            throw CashRegisterExtractError.network("HTTP 403")
        }
        guard bodyText.contains("\"code\": 200") || bodyText.contains("\"code\":200") else {
            let preview = bodyText.prefix(120)
            throw CashRegisterExtractError.network("BINA login: \(preview)")
        }
        guard cookies["sessionid"] != nil else {
            throw CashRegisterExtractError.network("BINA: login fără sessionid")
        }

        web.replaceCookieJar(cookies)
        web.setRomanianLanguageCookies()
        web.ensureSessionCookies(base: base, email: email)
    }

    // MARK: - Authenticated GET

    static func get(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        path: String,
        extraHeaders: [String: String] = [:]
    ) async throws -> Response {
        let host = base.host ?? "app.binasmartbusiness.com"
        var headers: [String: String] = [
            "User-Agent": userAgent,
            "Accept-Language": acceptLanguage,
            "Accept": "*/*",
            "X-Requested-With": "XMLHttpRequest",
        ]
        for (key, value) in extraHeaders { headers[key] = value }
        if let csrf = web.csrfToken() {
            headers["X-CSRFToken"] = csrf
        }
        return try await request(
            host: host,
            path: path,
            method: "GET",
            headers: headers,
            cookies: web.cookieJarSnapshot(),
            body: nil
        )
    }

    // MARK: - Raw HTTP

    nonisolated static func request(
        host: String,
        path: String,
        method: String,
        headers: [String: String],
        cookies: [String: String],
        body: Data?
    ) async throws -> Response {
        let cookieHeader = cookieHeaderString(from: cookies)
        let executor = BinaRawHTTPExecutor(
            host: host,
            path: path,
            method: method,
            headers: headers,
            cookieHeader: cookieHeader,
            body: body
        )
        return try await executor.run()
    }

    nonisolated static func parseHTTPResponse(_ data: Data) throws -> Response {
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else {
            throw CashRegisterExtractError.unsupportedResponse
        }

        let headerData = data[..<separator.lowerBound]
        let rawBody = Data(data[separator.upperBound...])
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw CashRegisterExtractError.unsupportedResponse
        }

        var statusCode = 0
        var cookies: [String: String] = [:]

        for (index, line) in headerText.split(separator: "\r\n", omittingEmptySubsequences: false).enumerated() {
            if index == 0 {
                let parts = line.split(separator: " ")
                if parts.count >= 2, let code = Int(parts[1]) {
                    statusCode = code
                }
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if name == "set-cookie", let parsed = parseSetCookie(value) {
                cookies[parsed.name] = parsed.value
            }
        }

        let body = decodeBody(rawBody, headerText: headerText)
        return Response(statusCode: statusCode, cookies: cookies, body: body)
    }

    nonisolated private static func decodeBody(_ body: Data, headerText: String) -> Data {
        guard headerText.lowercased().contains("transfer-encoding: chunked") else { return body }

        var result = Data()
        var idx = 0
        let bytes = [UInt8](body)
        while idx < bytes.count {
            let lineStart = idx
            while idx < bytes.count && bytes[idx] != 0x0A { idx += 1 }
            guard idx < bytes.count else { break }
            let sizeLine = String(bytes: bytes[lineStart..<idx], encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ";").first ?? ""
            idx += 1
            guard let size = Int(sizeLine, radix: 16) else { break }
            if size == 0 { break }
            guard idx + size <= bytes.count else { break }
            result.append(contentsOf: bytes[idx..<(idx + size)])
            idx += size
            if idx + 1 < bytes.count, bytes[idx] == 0x0D, bytes[idx + 1] == 0x0A { idx += 2 }
        }
        if !result.isEmpty { return result }

        if let text = String(data: body, encoding: .utf8) {
            if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]") {
                return Data(text[start...end].utf8)
            }
            if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
                return Data(text[start...end].utf8)
            }
        }
        return body
    }

    nonisolated private static func parseSetCookie(_ header: String) -> (name: String, value: String)? {
        let parts = header.split(separator: ";", maxSplits: 1)
        guard let first = parts.first else { return nil }
        let pair = first.split(separator: "=", maxSplits: 1)
        guard pair.count == 2 else { return nil }
        return (String(pair[0]), String(pair[1]))
    }

    nonisolated static func cookieHeaderString(from cookies: [String: String]) -> String? {
        guard !cookies.isEmpty else { return nil }
        return cookies
            .sorted { $0.key < $1.key }
            .map { name, value in
                if name == "sessionid", !value.hasPrefix("\"") {
                    return "\(name)=\"\(value)\""
                }
                return "\(name)=\(value)"
            }
            .joined(separator: "; ")
    }

    private static func extractCSRF(from body: Data) -> String? {
        guard let html = String(data: body, encoding: .utf8) else { return nil }
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

    private static func formEncoded(_ values: [String: String]) -> Data {
        values
            .map { key, value in "\(formEncode(key))=\(formEncode(value))" }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

// Backward compat alias
enum BinaRawLoginClient {
    static func login(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        email: String,
        password: String
    ) async throws -> Bool {
        try await BinaRawHTTPClient.login(web: web, base: base, email: email, password: password)
        return web.hasSessionCookie()
    }
}
