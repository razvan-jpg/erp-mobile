import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

enum BinaSmartBusinessSessionClient {
    private struct LoginResult {
        let companies: [CompanyOption]
        /// `true` when BINA returned code 204 and expects a second login with `company`.
        let requiresCompanyLogin: Bool
        /// `true` when first login already finished (`data: "ok"`) — never send a second login.
        let loginComplete: Bool
    }

    private struct LoginResponse: Decodable {
        let code: Int
        let companies: [CompanyOption]
        let message: String?
        let requiresCompanyLogin: Bool
        let loginComplete: Bool

        enum CodingKeys: String, CodingKey {
            case code, data, message
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let intCode = try? container.decode(Int.self, forKey: .code) {
                code = intCode
            } else if let stringCode = try? container.decode(String.self, forKey: .code), let intCode = Int(stringCode) {
                code = intCode
            } else {
                throw DecodingError.dataCorruptedError(forKey: .code, in: container, debugDescription: "Missing login code")
            }
            message = try container.decodeIfPresent(String.self, forKey: .message)

            if let status = try? container.decode(String.self, forKey: .data),
               status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "ok" {
                companies = []
                requiresCompanyLogin = false
                loginComplete = true
            } else if let options = try? container.decode([CompanyOption].self, forKey: .data) {
                companies = options
                requiresCompanyLogin = code == 204
                loginComplete = false
            } else {
                companies = []
                requiresCompanyLogin = code == 204
                loginComplete = code == 200 && (message?.isEmpty ?? true)
            }
        }
    }

    private struct CompanyOption: Decodable {
        let id: Int
        let nm: String?

        enum CodingKeys: String, CodingKey {
            case id, nm, name
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let intID = try? container.decode(Int.self, forKey: .id) {
                id = intID
            } else if let stringID = try? container.decode(String.self, forKey: .id), let intID = Int(stringID) {
                id = intID
            } else {
                throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing company id")
            }
            nm = try container.decodeIfPresent(String.self, forKey: .nm)
                ?? container.decodeIfPresent(String.self, forKey: .name)
        }
    }

    final class WebSession: @unchecked Sendable {
        private var trackedCSRF: String?
        private var trackedSessionID: String?
        private var trackedBase: URL?
        private var cookieJar: [String: String] = [:]

        let cookieStorage = HTTPCookieStorage()
        lazy var urlSession: URLSession = {
            let config = URLSessionConfiguration.default
            config.httpCookieStorage = cookieStorage
            config.httpCookieAcceptPolicy = .always
            config.httpShouldSetCookies = false
            config.timeoutIntervalForRequest = 45
            config.timeoutIntervalForResource = 120
            config.httpAdditionalHeaders = [
                "Accept-Language": BinaSmartBusinessSessionClient.romanianAcceptLanguage,
                "User-Agent": BinaSmartBusinessSessionClient.browserUserAgent,
            ]
            return URLSession(configuration: config)
        }()

        init() {
            cookieStorage.cookieAcceptPolicy = .always
        }

        func rememberBase(_ base: URL) {
            trackedBase = base
        }

        func rememberCSRF(_ token: String, base: URL) {
            trackedCSRF = token
            cookieJar["csrftoken"] = token
        }

        func csrfToken() -> String? {
            cookieJar["csrftoken"] ?? trackedCSRF ?? cookieStorage.cookies?.first(where: { $0.name == "csrftoken" })?.value
        }

        func hasSessionCookie() -> Bool {
            cookieJar["sessionid"] != nil || trackedSessionID != nil ||
                cookieStorage.cookies?.contains(where: { $0.name == "sessionid" }) == true
        }

        func cookieJarSnapshot() -> [String: String] { cookieJar }

        func replaceCookieJar(_ cookies: [String: String]) {
            cookieJar = cookies
            syncTrackedCookies()
        }

        func setRomanianLanguageCookies() {
            cookieJar["django_language"] = "ro"
            cookieJar["lang"] = "ro"
            cookieJar["current_program"] = "z_reports"
        }

        func mergeResponseCookies(_ cookies: [String: String]) {
            for (key, value) in cookies { cookieJar[key] = value }
            syncTrackedCookies()
        }

        func importNetscapeCookieJar(at fileURL: URL, base: URL) {
            guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
            for line in text.split(separator: "\n") {
                guard !line.hasPrefix("#"), !line.isEmpty else { continue }
                let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard parts.count >= 7 else { continue }
                cookieJar[String(parts[5])] = String(parts[6])
            }
            syncTrackedCookies()
        }

        func cookieHeaderValue(for url: URL) -> String {
            BinaRawHTTPClient.cookieHeaderString(from: cookieJar) ?? ""
        }

        func applyCookieHeader(to request: inout URLRequest) {
            let header = cookieHeaderValue(for: request.url ?? URL(string: "https://app.binasmartbusiness.com")!)
            guard !header.isEmpty else { return }
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }

        func syncTrackedCookies() {
            trackedCSRF = cookieJar["csrftoken"] ?? trackedCSRF
            trackedSessionID = cookieJar["sessionid"] ?? trackedSessionID
        }

        func ensureRomanianLanguageCookie(base: URL) {
            setRomanianLanguageCookies()
        }

        func ensureSessionCookies(base: URL, email: String) {
            ensureRomanianLanguageCookie(base: base)
            rememberFrontEmail(email, base: base)
            syncTrackedCookies()
        }

        func rememberFrontEmail(_ email: String, base: URL) {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            setSessionCookie(base: base, name: "front_email", value: trimmed, paths: ["/"])
        }

        private func setSessionCookie(base: URL, name: String, value: String, paths: [String]) {
            let domain = base.host ?? "app.binasmartbusiness.com"
            let secure = (base.scheme ?? "https") == "https"
            for path in paths {
                let properties: [HTTPCookiePropertyKey: Any] = [
                    .name: name,
                    .value: value,
                    .domain: domain,
                    .path: path,
                    .secure: secure,
                ]
                guard let cookie = HTTPCookie(properties: properties) else { continue }
                cookieStorage.setCookie(cookie)
            }
        }

        func applyRomanianPDFRequestHeaders(to request: inout URLRequest, referer: URL) {
            request.setValue(BinaSmartBusinessSessionClient.browserUserAgent, forHTTPHeaderField: "User-Agent")
            request.setValue(BinaSmartBusinessSessionClient.romanianAcceptLanguage, forHTTPHeaderField: "Accept-Language")
            request.setValue("application/pdf,application/octet-stream;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            applyCookieHeader(to: &request)
            if let csrfToken = csrfToken() {
                request.setValue(csrfToken, forHTTPHeaderField: "X-CSRFToken")
            }
            request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }

        func applyAuthenticatedHeaders(to request: inout URLRequest, referer: URL?) {
            request.setValue(BinaSmartBusinessSessionClient.browserUserAgent, forHTTPHeaderField: "User-Agent")
            request.setValue(BinaSmartBusinessSessionClient.romanianAcceptLanguage, forHTTPHeaderField: "Accept-Language")
            applyCookieHeader(to: &request)
            if let csrfToken = csrfToken() {
                request.setValue(csrfToken, forHTTPHeaderField: "X-CSRFToken")
            }
            if let referer {
                request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
            }
        }

        func applyModuleRequestHeaders(to request: inout URLRequest, referer: URL) {
            applyAuthenticatedHeaders(to: &request, referer: referer)
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        }

        func storeCookies(from response: HTTPURLResponse) {
            if let responseURL = response.url,
               let headerFields = response.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: responseURL)
                for cookie in cookies {
                    cookieJar[cookie.name] = cookie.value
                }
            }
            syncTrackedCookies()
        }
    }

    private static let browserUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36"

    private static let romanianAcceptLanguage = "ro-RO,ro;q=0.9,en-US;q=0.8,en;q=0.7"

    /// Login + pregătire modul Rapoarte Z. Refolosește sesiunea returnată la descărcare.
    static func authenticateAndPrepare(
        loginURL: URL,
        username: String,
        password: String
    ) async throws -> (web: WebSession, base: URL) {
        let base = binaBaseURL(from: loginURL)
        let web = WebSession()
        web.rememberBase(base)
        _ = try await authenticate(
            web: web,
            base: base,
            username: username,
            password: password
        )
        guard web.hasSessionCookie() else {
            throw CashRegisterExtractError.authenticationFailed
        }
        await prepareZReportsModule(web: web, base: base)
        return (web, base)
    }

    static func listAvailableReports(
        loginURL: URL,
        username: String,
        password: String,
        from: Date,
        to: Date,
        binaLocationFilter: String? = nil
    ) async throws -> [BinaPosZReportRow] {
        let base = binaBaseURL(from: loginURL)
        let web = WebSession()
        web.rememberBase(base)

        _ = try await authenticate(
            web: web,
            base: base,
            username: username,
            password: password
        )

        guard web.hasSessionCookie() else {
            throw CashRegisterExtractError.authenticationFailed
        }

        await prepareZReportsModule(web: web, base: base)
        return try await BinaPosZReportService.listReports(
            web: web,
            base: base,
            from: from,
            to: to,
            locationFilter: binaLocationFilter,
            customerCompanyID: nil
        )
    }

    static func downloadReports(
        loginURL: URL,
        username: String,
        password: String,
        rows: [BinaPosZReportRow],
        from: Date,
        to: Date,
        binaLocationFilter: String? = nil
    ) async throws -> [ExtractedCashRegisterZReport] {
        let base = binaBaseURL(from: loginURL)
        let web = WebSession()
        web.rememberBase(base)

        _ = try await authenticate(
            web: web,
            base: base,
            username: username,
            password: password
        )

        guard web.hasSessionCookie() else {
            throw CashRegisterExtractError.authenticationFailed
        }

        await prepareZReportsModule(web: web, base: base)
        return try await BinaPosZReportService.downloadReports(
            web: web,
            base: base,
            rows: rows,
            from: from,
            to: to,
            locationFilter: binaLocationFilter
        )
    }

    static func extractReports(
        loginURL: URL,
        username: String,
        password: String,
        from: Date,
        to: Date,
        binaLocationFilter: String? = nil
    ) async throws -> [ExtractedCashRegisterZReport] {
        let base = binaBaseURL(from: loginURL)
        let web = WebSession()
        web.rememberBase(base)

        _ = try await authenticate(
            web: web,
            base: base,
            username: username,
            password: password
        )

        guard web.hasSessionCookie() else {
            throw CashRegisterExtractError.authenticationFailed
        }

        await prepareZReportsModule(web: web, base: base)
        return try await BinaPosZReportService.extractReports(
            web: web,
            base: base,
            from: from,
            to: to,
            locationFilter: binaLocationFilter,
            customerCompanyID: nil
        )
    }

    private static func authenticate(
        web: WebSession,
        base: URL,
        username: String,
        password: String
    ) async throws -> LoginResult {
        web.rememberBase(base)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        #if os(macOS)
        if await BinaPosZReportCurlDownloader.login(
            web: web,
            base: base,
            email: username,
            password: trimmedPassword
        ), web.hasSessionCookie() {
            web.setRomanianLanguageCookies()
            await activateRomanianLanguageSession(web: web, base: base)
            return LoginResult(companies: [], requiresCompanyLogin: false, loginComplete: true)
        }
        #endif

        try await BinaRawHTTPClient.login(
            web: web,
            base: base,
            email: username,
            password: trimmedPassword
        )
        web.ensureSessionCookies(base: base, email: username)
        await activateRomanianLanguageSession(web: web, base: base)
        return LoginResult(companies: [], requiresCompanyLogin: false, loginComplete: true)
    }

    static func activateRomanianLanguageSession(web: WebSession, base: URL) async {
        web.ensureRomanianLanguageCookie(base: base)
        let referer = binaRootReferer(base)

        _ = try? await fetchNavigationPage(web: web, url: url(base, path: "/"), referer: referer)
        // /pos/zreports/ răspunde 404 fără X-Requested-With — folosim XHR ca în browser.
        _ = try? await fetchModulePage(web: web, url: url(base, path: "/pos/zreports/"), referer: referer)
        web.ensureRomanianLanguageCookie(base: base)
    }

    static func prepareZReportsModule(web: WebSession, base: URL) async {
        let referer = binaRootReferer(base)
        web.ensureRomanianLanguageCookie(base: base)
        _ = try? await fetchNavigationPage(web: web, url: url(base, path: "/"), referer: referer)
        _ = try? await fetchModulePage(web: web, url: url(base, path: "/pos/zreports/"), referer: referer)
    }

    /// Pregătește sesiunea exact ca browserul înainte de PDF: view XHR cu Referer root.
    static func primeZReportPDFSession(
        web: WebSession,
        base: URL,
        remoteID: String
    ) async {
        web.ensureRomanianLanguageCookie(base: base)
        let referer = binaRootReferer(base)
        let root = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        _ = try? await fetchModulePage(web: web, url: url(base, path: "/pos/zreports/"), referer: referer)
        if let viewURL = URL(string: "\(root)/pos/zreports/view/\(remoteID)/") {
            _ = try? await fetchModulePage(web: web, url: viewURL, referer: referer)
        }
        web.ensureRomanianLanguageCookie(base: base)
    }

    /// GET ca în browser (fără X-Requested-With) — necesar ca BINA să servească PDF în română.
    @discardableResult
    static func fetchNavigationPage(web: WebSession, url: URL, referer: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        web.applyAuthenticatedHeaders(to: &request, referer: referer)
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        let (data, response) = try await web.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CashRegisterExtractError.unsupportedResponse
        }
        web.storeCookies(from: http)
        guard (200...399).contains(http.statusCode) else {
            throw CashRegisterExtractError.network("HTTP \(http.statusCode)")
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw CashRegisterExtractError.unsupportedResponse
        }
        if html.contains("password_unhash") && html.contains("isLogin") {
            throw CashRegisterExtractError.authenticationFailed
        }
        return html
    }

    static func downloadNavigationPDF(web: WebSession, url: URL, referer: URL) async throws -> Data? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        web.applyRomanianPDFRequestHeaders(to: &request, referer: referer)
        let (data, response) = try await web.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        web.storeCookies(from: http)
        guard data.starts(with: [0x25, 0x50, 0x44, 0x46]) else { return nil }
        return data
    }

    /// GET cu X-Requested-With — același tip de request ca view/list în browser.
    static func downloadModulePDF(web: WebSession, url: URL, referer: URL) async throws -> Data? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        web.applyModuleRequestHeaders(to: &request, referer: referer)
        request.setValue("application/pdf,*/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await web.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        web.storeCookies(from: http)
        guard data.starts(with: [0x25, 0x50, 0x44, 0x46]) else { return nil }
        return data
    }

    static func fetchModulePage(web: WebSession, url: URL, referer: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        web.applyModuleRequestHeaders(to: &request, referer: referer)
        let (data, response) = try await web.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CashRegisterExtractError.unsupportedResponse
        }
        web.storeCookies(from: http)
        guard (200...299).contains(http.statusCode) else {
            throw CashRegisterExtractError.network("HTTP \(http.statusCode)")
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw CashRegisterExtractError.unsupportedResponse
        }
        if html.contains("password_unhash") && html.contains("isLogin") {
            throw CashRegisterExtractError.authenticationFailed
        }
        return html
    }

    static func binaZReportsReferer(_ base: URL) -> URL {
        let root = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: root + "/pos/zreports/?lang=ro")
            ?? binaRootReferer(base)
    }

    static func binaRootReferer(_ base: URL) -> URL {
        var trimmed = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !trimmed.lowercased().hasPrefix("http") {
            trimmed = "https://" + trimmed
        }
        return URL(string: trimmed + "/") ?? base
    }

    static func fetchDashboardHTML(web: WebSession, base: URL) async throws -> String {
        try await fetchText(web: web, url: url(base, path: "/"))
    }

    static func fetchRaw(web: WebSession, url: URL) async throws -> String {
        try await fetchText(web: web, url: url)
    }

    private static func legacyExtractReports(
        web: WebSession,
        base: URL,
        from: Date,
        to: Date
    ) async throws -> [ExtractedCashRegisterZReport] {
        let dashboardHTML = try await fetchText(web: web, url: url(base, path: "/"))
        if isLoginPageHTML(dashboardHTML) {
            throw CashRegisterExtractError.authenticationFailed
        }

        var discoveredPaths = discoverReportPaths(in: dashboardHTML)
        discoveredPaths.append(contentsOf: await discoverReportPathsFromScripts(in: dashboardHTML, web: web, base: base))
        let endpointCandidates = reportEndpointCandidates(base: base, discovered: discoveredPaths, from: from, to: to)

        for endpoint in endpointCandidates {
            if let reports = await fetchReports(from: endpoint, web: web, base: base, from: from, to: to), !reports.isEmpty {
                return reports
            }
        }

        if let htmlReports = await parseReportsFromHTML(dashboardHTML, web: web, base: base, from: from, to: to), !htmlReports.isEmpty {
            return htmlReports
        }

        throw CashRegisterExtractError.apiNotAvailable
    }

    private static func isLoginPageHTML(_ html: String) -> Bool {
        html.contains("password_unhash") && html.contains("isLogin")
    }

    private static func url(_ base: URL, path: String) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        if let questionMark = path.firstIndex(of: "?") {
            components?.path = String(path[..<questionMark])
            components?.percentEncodedQuery = String(path[path.index(after: questionMark)...])
        } else {
            components?.path = path.hasPrefix("/") ? path : "/\(path)"
        }
        return components?.url ?? base.appendingPathComponent(path)
    }

    private static func loginPageURL(_ base: URL) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.path = "/login"
        components?.queryItems = [URLQueryItem(name: "lang", value: "ro")]
        return components?.url ?? url(base, path: "/login")
    }

    private static func loginPostURL(_ base: URL) -> URL {
        url(base, path: "/login")
    }

    private static func discoverReportPathsFromScripts(in html: String, web: WebSession, base: URL) async -> [String] {
        let scriptPattern = #"src="([^"]+\.js[^"]*)""#
        var paths = Set<String>()
        for src in allMatches(in: html, pattern: scriptPattern) {
            guard src.hasPrefix("/") || src.hasPrefix("http") else { continue }
            guard let scriptURL = URL(string: src, relativeTo: base)?.absoluteURL else { continue }
            guard let scriptHTML = try? await fetchText(web: web, url: scriptURL) else { continue }
            paths.formUnion(discoverReportPaths(in: scriptHTML))
        }
        return Array(paths)
    }

    private static func binaBaseURL(from url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let host = components?.host?.lowercased(), host.contains("binasmartbusiness.com") {
            components?.scheme = "https"
            components?.host = host
            components?.path = ""
            components?.query = nil
            components?.fragment = nil
            if let normalized = components?.url { return normalized }
        }
        return FiscalRegisterZReportClient.normalizeBaseURL(url)
    }

    private static func fetchCSRFToken(web: WebSession, base: URL) async throws -> String {
        let loginPage = loginPageURL(base)
        var request = URLRequest(url: loginPage)
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(romanianAcceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(loginPage.absoluteString, forHTTPHeaderField: "Referer")

        let (data, response) = try await web.urlSession.data(for: request)
        if let http = response as? HTTPURLResponse {
            web.storeCookies(from: http)
            guard (200...399).contains(http.statusCode) else {
                throw CashRegisterExtractError.network("HTTP \(http.statusCode)")
            }
        }

        web.syncTrackedCookies()
        if let token = web.csrfToken() {
            web.rememberCSRF(token, base: base)
            return token
        }

        guard let html = String(data: data, encoding: .utf8), let token = extractCSRF(from: html) else {
            throw CashRegisterExtractError.unsupportedResponse
        }
        web.rememberCSRF(token, base: base)
        return token
    }

    private static func extractCSRF(from html: String) -> String? {
        let patterns = [
            #"name=['\"]csrfmiddlewaretoken['\"][^>]*value=['\"]([^'\"]+)['\"]"#,
            #"value=['\"]([^'\"]+)['\"][^>]*name=['\"]csrfmiddlewaretoken['\"]"#,
            #"name='csrfmiddlewaretoken'\s+value='([^']+)'"#,
        ]
        for pattern in patterns {
            if let token = firstMatch(in: html, pattern: pattern) {
                return token
            }
        }
        return nil
    }

    private static func performLogin(
        web: WebSession,
        base: URL,
        csrf: String,
        email: String,
        password: String,
        companyId: Int?
    ) async throws -> LoginResult {
        web.syncTrackedCookies()
        let csrfToken = web.csrfToken() ?? csrf
        web.rememberCSRF(csrfToken, base: base)

        let loginPage = loginPageURL(base)
        let loginPost = loginPostURL(base)
        var request = URLRequest(url: loginPost)
        request.httpMethod = "POST"
        request.setValue(BinaSmartBusinessSessionClient.browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(BinaSmartBusinessSessionClient.romanianAcceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(binaRootReferer(base).absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")), forHTTPHeaderField: "Origin")
        request.setValue(loginPage.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue(csrfToken, forHTTPHeaderField: "X-CSRFToken")

        var body: [String: String] = [
            "csrfmiddlewaretoken": csrfToken,
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password_unhash": password,
            "language": "ro",
            "lang": "ro",
        ]
        if let companyId {
            body["company"] = String(companyId)
        }
        request.httpBody = formEncoded(body)

        let (data, response) = try await web.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CashRegisterExtractError.unsupportedResponse
        }
        web.storeCookies(from: http)
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 403 {
                throw CashRegisterExtractError.network("HTTP 403")
            }
            throw CashRegisterExtractError.network("HTTP \(http.statusCode)")
        }

        let decoded: LoginResponse
        do {
            decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
        } catch {
            let preview = String(data: data, encoding: .utf8)?.prefix(180) ?? ""
            if preview.localizedCaseInsensitiveContains("403 forbidden") {
                throw CashRegisterExtractError.network("HTTP 403")
            }
            throw CashRegisterExtractError.network("BINA login: \(preview)")
        }

        switch decoded.code {
        case 200, 204:
            web.syncTrackedCookies()
            return LoginResult(
                companies: decoded.companies,
                requiresCompanyLogin: decoded.requiresCompanyLogin,
                loginComplete: decoded.loginComplete
            )
        case 401, 402, 403, 404, 405, 406, 407, 409:
            if let message = decoded.message, !message.isEmpty {
                throw CashRegisterExtractError.network(message)
            }
            throw CashRegisterExtractError.authenticationFailed
        default:
            if let message = decoded.message, !message.isEmpty {
                throw CashRegisterExtractError.network(message)
            }
            throw CashRegisterExtractError.authenticationFailed
        }
    }

    private static func discoverReportPaths(in html: String) -> [String] {
        let patterns = [
            #"/cors-request/[a-zA-Z0-9_/-]+"#,
        ]
        var paths = Set<String>()
        for pattern in patterns {
            for match in allMatches(in: html, pattern: pattern) {
                let cleaned = match.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                if cleaned.contains("cors-request"),
                   !cleaned.contains("registration"),
                   !cleaned.contains("forgot") {
                    paths.insert(cleaned.split(separator: "?").first.map(String.init) ?? cleaned)
                }
            }
        }
        return Array(paths)
    }

    private static func reportEndpointCandidates(base: URL, discovered: [String], from: Date, to: Date) -> [URL] {
        let fromStr = apiDate(from)
        let toStr = apiDate(to)
        var paths = discovered
        paths.append(contentsOf: [
            "/cors-request/fiscal_reports/",
            "/cors-request/fiscal_reports/list/",
            "/cors-request/reports/z/",
            "/cors-request/reports/z/list/",
            "/cors-request/zreports/",
            "/cors-request/zreports/list/",
            "/cors-request/pos/zreports/",
            "/cors-request/pos/fiscal_reports/",
            "/cors-request/export/zreports/",
            "/cors-request/reports/fiscal/",
            "/cors-request/reports/fiscal_z/",
        ])

        var urls: [URL] = []
        let root = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        for path in Set(paths) {
            let normalized = path.hasPrefix("/") ? path : "/\(path)"
            let variants = [
                normalized,
                normalized + "?from=\(fromStr)&to=\(toStr)",
                normalized + "?startDate=\(fromStr)&endDate=\(toStr)",
                normalized + "?date_from=\(fromStr)&date_to=\(toStr)",
            ]
            for variant in variants {
                if let endpoint = URL(string: root + variant) {
                    urls.append(endpoint)
                }
            }
        }
        return urls
    }

    private static func fetchReports(
        from endpoint: URL,
        web: WebSession,
        base: URL,
        from: Date,
        to: Date
    ) async -> [ExtractedCashRegisterZReport]? {
        var getRequest = URLRequest(url: endpoint)
        getRequest.httpMethod = "GET"
        web.applyAuthenticatedHeaders(to: &getRequest, referer: base)
        getRequest.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        if let reports = await parseHTTPResponse(web: web, request: getRequest, from: from, to: to) {
            return reports
        }

        var formRequest = URLRequest(url: endpoint)
        formRequest.httpMethod = "POST"
        web.applyAuthenticatedHeaders(to: &formRequest, referer: base)
        formRequest.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        formRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        formRequest.httpBody = formEncoded([
            "from": apiDate(from),
            "to": apiDate(to),
            "startDate": apiDate(from),
            "endDate": apiDate(to),
            "date_from": apiDate(from),
            "date_to": apiDate(to),
        ])
        if let reports = await parseHTTPResponse(web: web, request: formRequest, from: from, to: to) {
            return reports
        }

        var jsonRequest = URLRequest(url: endpoint)
        jsonRequest.httpMethod = "POST"
        web.applyAuthenticatedHeaders(to: &jsonRequest, referer: base)
        jsonRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        jsonRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        let payload: [String: String] = [
            "from": apiDate(from),
            "to": apiDate(to),
            "startDate": apiDate(from),
            "endDate": apiDate(to),
            "date_from": apiDate(from),
            "date_to": apiDate(to),
        ]
        jsonRequest.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        return await parseHTTPResponse(web: web, request: jsonRequest, from: from, to: to)
    }

    private static func parseHTTPResponse(
        web: WebSession,
        request: URLRequest,
        from: Date,
        to: Date
    ) async -> [ExtractedCashRegisterZReport]? {
        guard let (data, response) = try? await web.urlSession.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return nil
        }
        web.storeCookies(from: http)

        if data.starts(with: [0x25, 0x50, 0x44, 0x46]) {
            return try? FiscalRegisterZReportClient.parseUploadedFiles(
                urls: [writeTempPDF(data)],
                from: from,
                to: to
            )
        }

        if let json = try? JSONSerialization.jsonObject(with: data),
           let reports = parseJSONReports(json, from: from, to: to),
           !reports.isEmpty {
            return reports
        }

        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            if text.contains("RAPORT FISCAL") || text.contains("RAPORT Z") {
                return try? FiscalRegisterZReportClient.parseUploadedFiles(
                    urls: [writeTempText(text)],
                    from: from,
                    to: to
                )
            }
            if let htmlReports = await parseReportsFromHTML(
                text,
                web: web,
                base: request.url ?? URL(string: "https://app.binasmartbusiness.com")!,
                from: from,
                to: to
            ), !htmlReports.isEmpty {
                return htmlReports
            }
        }
        return nil
    }

    private static func parseJSONReports(_ json: Any, from: Date, to: Date) -> [ExtractedCashRegisterZReport]? {
        if let array = json as? [[String: Any]] {
            return mapJSONArray(array)
        }
        if let dict = json as? [String: Any] {
            if let code = dict["code"] as? Int, code != 200 {
                return nil
            }
            for key in ["data", "reports", "zreports", "items", "results"] {
                if let array = dict[key] as? [[String: Any]], let mapped = mapJSONArray(array), !mapped.isEmpty {
                    return mapped
                }
            }
        }
        return nil
    }

    private static func mapJSONArray(_ array: [[String: Any]]) -> [ExtractedCashRegisterZReport]? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        let mapped: [ExtractedCashRegisterZReport] = array.compactMap { item in
            let dateString = (item["date"] ?? item["reportDate"] ?? item["data"] ?? item["day"]) as? String
            let parsedDate = dateString.flatMap { formatter.date(from: $0) ?? flexibleDate($0) } ?? Date()
            let number = (item["number"] ?? item["zNumber"] ?? item["nrZ"]) as? String
            if let pdfBase64 = item["pdfBase64"] as? String, let pdfData = Data(base64Encoded: pdfBase64) {
                let text = extractPDFText(pdfData) ?? ""
                return ExtractedCashRegisterZReport(reportDate: parsedDate, reportNumber: number, textContent: text, pdfData: pdfData)
            }
            if let content = (item["content"] ?? item["text"] ?? item["body"]) as? String, !content.isEmpty {
                return ExtractedCashRegisterZReport(reportDate: parsedDate, reportNumber: number, textContent: content)
            }
            if let urlString = (item["url"] ?? item["pdfUrl"] ?? item["downloadUrl"]) as? String {
                return ExtractedCashRegisterZReport(reportDate: parsedDate, reportNumber: number, textContent: urlString)
            }
            return nil
        }
        return mapped.isEmpty ? nil : mapped
    }

    private static func parseReportsFromHTML(
        _ html: String,
        web: WebSession,
        base: URL,
        from: Date,
        to: Date
    ) async -> [ExtractedCashRegisterZReport]? {
        guard html.localizedCaseInsensitiveContains("raport") || html.localizedCaseInsensitiveContains("fiscal") else {
            return nil
        }

        var reports: [ExtractedCashRegisterZReport] = []
        let linkPattern = #"href="([^"]*(?:zreport|z_report|raport[^"]*|fiscal[^"]*))"#
        for href in allMatches(in: html, pattern: linkPattern) {
            guard href.hasSuffix(".pdf") else { continue }
            let absolute = URL(string: href, relativeTo: base)?.absoluteURL ?? URL(string: href)
            guard let downloadURL = absolute else { continue }
            guard let (data, response) = try? await web.urlSession.data(from: downloadURL),
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { continue }
            if let parsed = try? FiscalRegisterZReportClient.parseUploadedFiles(urls: [writeTempPDF(data)], from: from, to: to) {
                reports.append(contentsOf: parsed)
            }
        }

        if html.uppercased().contains("RAPORT FISCAL ZILNIC") {
            let textReports = html.components(separatedBy: "RAPORT FISCAL ZILNIC")
                .dropFirst()
                .map { "RAPORT FISCAL ZILNIC\n" + $0 }
            for text in textReports {
                if let parsed = try? FiscalRegisterZReportClient.parseUploadedFiles(urls: [writeTempText(text)], from: from, to: to) {
                    reports.append(contentsOf: parsed)
                }
            }
        }

        return reports.isEmpty ? nil : reports
    }

    private static func fetchText(web: WebSession, url: URL) async throws -> String {
        var request = URLRequest(url: url)
        web.applyAuthenticatedHeaders(to: &request, referer: url)
        let (data, response) = try await web.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) else {
            throw CashRegisterExtractError.network("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        web.storeCookies(from: http)
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
    }

    private static func formEncoded(_ values: [String: String]) -> Data {
        values
            .map { key, value in
                "\(formEncodeComponent(key))=\(formEncodeComponent(value))"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private static func formEncodeComponent(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func writeTempPDF(_ data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bina-z-\(UUID().uuidString).pdf")
        try? data.write(to: url, options: .atomic)
        return url
    }

    private static func writeTempText(_ text: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bina-z-\(UUID().uuidString).txt")
        try? text.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private static func extractPDFText(_ data: Data) -> String? {
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: data) else { return nil }
        return (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
        #else
        return nil
        #endif
    }

    private static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func flexibleDate(_ raw: String) -> Date? {
        let formats = ["yyyy-MM-dd", "dd.MM.yyyy", "dd/MM/yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return date
            }
        }
        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        allMatches(in: text, pattern: pattern).first
    }

    private static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let swiftRange = Range(match.range(at: 1), in: text) else {
                if let swiftRange = Range(match.range, in: text) {
                    return String(text[swiftRange])
                }
                return nil
            }
            return String(text[swiftRange])
        }
    }
}
