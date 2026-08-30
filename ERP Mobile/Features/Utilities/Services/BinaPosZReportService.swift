import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

struct BinaPosZReportRow: Sendable {
    let remoteID: String
    let number: String?
    let date: Date
    let location: String?
    let posNumber: String?
    let pdfPath: String?
    let hasReliableDate: Bool

    nonisolated init(
        remoteID: String,
        number: String?,
        date: Date,
        location: String?,
        posNumber: String?,
        pdfPath: String?,
        hasReliableDate: Bool
    ) {
        self.remoteID = remoteID
        self.number = number
        self.date = date
        self.location = location
        self.posNumber = posNumber
        self.pdfPath = pdfPath
        self.hasReliableDate = hasReliableDate
    }
}

enum BinaPosZReportService {
    struct LocationOption: Identifiable, Sendable, Equatable {
        let id: String
        let label: String
    }

    typealias Row = BinaPosZReportRow

    private static let modulePath = "/pos/zreports/"

    private static let listPaths = [
        "/pos/zreports/",
        "/cors-request/pos/zreports/list/",
        "/cors-request/pos/zreports/get_list/",
        "/cors-request/pos/zreports/filter/",
        "/cors-request/pos/z_report/list/",
        "/cors-request/pos/z_report/filter/",
        "/cors-request/pos/z_report/search/",
        "/cors-request/pos/zreport/get_list/",
        "/cors-request/pos/zreport/list/",
        "/cors-request/pos/zreports/list/",
        "/cors-request/pos/fiscal_z/get_list/",
        "/cors-request/pos/fiscal_z/list/",
        "/cors-request/pos/fiscal_z_report/list/",
        "/cors-request/pos/ecr/z_report/list/",
        "/cors-request/pos/cashier/z_report/list/",
        "/cors-request/z_report/get_list/",
        "/cors-request/z_report/list/",
        "/cors-request/reports/z_report/list/",
    ]

    static func discoverLocations(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        from: Date,
        to: Date,
        customerCompanyID: Int? = nil
    ) async -> [LocationOption] {
        guard let rows = try? await fetchRows(
            web: web,
            base: base,
            from: from,
            to: to,
            locationFilter: nil,
            customerCompanyID: customerCompanyID
        ) else {
            return []
        }
        let labels = Set(rows.compactMap(\.location).filter { !$0.isEmpty })
        return labels.sorted().map { LocationOption(id: $0, label: $0) }
    }

    static func listReports(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        from: Date,
        to: Date,
        locationFilter: String?,
        customerCompanyID: Int? = nil
    ) async throws -> [Row] {
        let rows = try await fetchRows(
            web: web,
            base: base,
            from: from,
            to: to,
            locationFilter: locationFilter,
            customerCompanyID: customerCompanyID
        )
        let filtered = filterRowsForPeriod(rows, from: from, to: to, locationFilter: locationFilter)
        guard !filtered.isEmpty else {
            throw CashRegisterExtractError.noReportsFound
        }
        return filtered.sorted { $0.date > $1.date }
    }

    static func downloadReports(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        rows: [Row],
        from: Date,
        to: Date,
        locationFilter: String?
    ) async throws -> [ExtractedCashRegisterZReport] {
        guard !rows.isEmpty else {
            throw CashRegisterExtractError.noReportsFound
        }

        var reports: [ExtractedCashRegisterZReport] = []
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)

        for row in rows {
            web.refreshRomanianCookies(base: base)
            let pdfData = try await downloadBinaPDF(web: web, base: base, row: row)
            let text = extractPDFText(pdfData) ?? ""
            let reportDate = inferDate(from: text) ?? (row.hasReliableDate ? row.date : nil)
            guard let reportDate else { continue }
            let day = calendar.startOfDay(for: reportDate)
            guard day >= start && day <= end else { continue }
            if let locationFilter = locationFilter?.trimmingCharacters(in: .whitespacesAndNewlines),
               !locationFilter.isEmpty,
               let location = row.location?.uppercased(),
               !location.contains(locationFilter.uppercased()) {
                continue
            }
            reports.append(
                ExtractedCashRegisterZReport(
                    reportDate: reportDate,
                    reportNumber: row.number ?? inferZNumber(from: text),
                    textContent: text,
                    pdfData: pdfData
                )
            )
        }

        guard !reports.isEmpty else {
            throw CashRegisterExtractError.noReportsFound
        }
        return reports
    }

    static func extractReports(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        from: Date,
        to: Date,
        locationFilter: String?,
        customerCompanyID: Int? = nil
    ) async throws -> [ExtractedCashRegisterZReport] {
        let rows = try await listReports(
            web: web,
            base: base,
            from: from,
            to: to,
            locationFilter: locationFilter,
            customerCompanyID: customerCompanyID
        )
        return try await downloadReports(
            web: web,
            base: base,
            rows: rows,
            from: from,
            to: to,
            locationFilter: locationFilter
        )
    }

    private static func filterRowsForPeriod(
        _ rows: [Row],
        from: Date,
        to: Date,
        locationFilter: String?
    ) -> [Row] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return rows.filter { row in
            let day = calendar.startOfDay(for: row.date)
            guard day >= start && day <= end else { return false }
            guard let locationFilter = locationFilter?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !locationFilter.isEmpty else { return true }
            guard let location = row.location?.uppercased() else { return true }
            return location.contains(locationFilter.uppercased())
        }
    }

    private static func fetchRows(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        from: Date,
        to: Date,
        locationFilter: String?,
        customerCompanyID: Int?
    ) async throws -> [Row] {
        if let apiRows = try await fetchRowsFromListAPI(
            web: web,
            base: base,
            from: from,
            to: to,
            locationFilter: locationFilter,
            customerCompanyID: customerCompanyID
        ), !apiRows.isEmpty {
            return apiRows
        }

        if let moduleRows = try await fetchRowsFromModulePage(
            web: web,
            base: base,
            from: from,
            to: to,
            locationFilter: locationFilter
        ), !moduleRows.isEmpty {
            return moduleRows
        }

        throw CashRegisterExtractError.noReportsFound
    }

    private static func fetchRowsFromListAPI(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        from: Date,
        to: Date,
        locationFilter: String?,
        customerCompanyID: Int?,
        allowRetryWithoutCompany: Bool = true
    ) async throws -> [Row]? {
        var allRows: [Row] = []
        var start = 0
        let pageSize = 100
        var lastHTTPStatus: Int?
        var sawHTMLLoginPage = false
        var companyID = customerCompanyID
        var retriedWithoutCompany = false

        while start < 5000 {
            let path = listAPIPath(
                from: from,
                to: to,
                customerCompanyID: companyID,
                start: start,
                length: pageSize
            )
            let referer = moduleURL(base: base).absoluteString

            do {
                let response = try await BinaRawHTTPClient.get(
                    web: web,
                    base: base,
                    path: path,
                    extraHeaders: ["Referer": referer]
                )
                web.mergeResponseCookies(response.cookies)
                lastHTTPStatus = response.statusCode

                if response.statusCode == 403, companyID != nil, allowRetryWithoutCompany, !retriedWithoutCompany {
                    companyID = nil
                    retriedWithoutCompany = true
                    start = 0
                    allRows = []
                    continue
                }

                guard (200...299).contains(response.statusCode) else {
                    if response.statusCode == 403 { break }
                    break
                }

                let data = response.body
                if response.bodyText.contains("<!DOCTYPE") || response.bodyText.contains("password_unhash") {
                    sawHTMLLoginPage = true
                    break
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let code = json["code"] as? Int,
                   code == 403 {
                    sawHTMLLoginPage = true
                    break
                }

                let batch = binaParseListResponse(data)
                if batch.isEmpty { break }
                allRows.append(contentsOf: batch)
                if batch.count < pageSize { break }
                start += pageSize
            } catch {
                break
            }
        }

        if sawHTMLLoginPage {
            throw CashRegisterExtractError.authenticationFailed
        }

        guard !allRows.isEmpty else {
            if lastHTTPStatus == 403 {
                return nil
            }
            return nil
        }
        return filterRows(allRows, from: from, to: to, locationFilter: locationFilter, requireReliableDate: false)
    }

    /// BINA necesită slash final: `/pos/zreports/?...` (fără slash → 301 + body gol).
    private static func listAPIPath(
        from: Date,
        to: Date,
        customerCompanyID: Int?,
        start: Int,
        length: Int
    ) -> String {
        var parts = [
            "order=1",
            "sorting=date_close",
            "date[from]=\(apiDate(from))",
            "date[to]=\(apiDate(to))",
            "start=\(start)",
            "length=\(length)",
            "lang=ro",
            "language=ro",
        ]
        if let customerCompanyID {
            parts.append("customer_company=\(customerCompanyID)")
        }
        return "/pos/zreports/?" + parts.joined(separator: "&")
    }

    private static func listAPIURL(
        base: URL,
        from: Date,
        to: Date,
        customerCompanyID: Int?,
        start: Int,
        length: Int
    ) -> URL? {
        var components = URLComponents()
        components.scheme = base.scheme ?? "https"
        components.host = base.host
        components.path = "/pos/zreports/"
        var queryItems = [
            URLQueryItem(name: "order", value: "1"),
            URLQueryItem(name: "sorting", value: "date_close"),
            URLQueryItem(name: "date[from]", value: apiDate(from)),
            URLQueryItem(name: "date[to]", value: apiDate(to)),
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "length", value: String(length)),
            URLQueryItem(name: "lang", value: "ro"),
            URLQueryItem(name: "language", value: "ro"),
        ]
        if let customerCompanyID {
            queryItems.append(URLQueryItem(name: "customer_company", value: String(customerCompanyID)))
        }
        components.queryItems = queryItems
        return components.url
    }

    private static func moduleURL(base: URL) -> URL {
        URL(string: base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + modulePath)
            ?? base.appendingPathComponent("pos/zreports/")
    }

    private static func fetchRowsFromModulePage(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        from: Date,
        to: Date,
        locationFilter: String?
    ) async throws -> [Row]? {
        let referer = BinaSmartBusinessSessionClient.binaRootReferer(base)
        for pageURL in modulePageCandidates(base: base, from: from, to: to) {
            guard let html = try? await BinaSmartBusinessSessionClient.fetchModulePage(
                web: web,
                url: pageURL,
                referer: referer
            ) else { continue }

            let linkRows = binaParseReportLinksFromHTML(html)
            if let rows = linkRows, !rows.isEmpty {
                return filterRows(rows, from: from, to: to, locationFilter: locationFilter, requireReliableDate: false)
            }
            let tableRows = binaParseHTMLTableRows(html)
            if let rows = tableRows, !rows.isEmpty {
                return filterRows(rows, from: from, to: to, locationFilter: locationFilter, requireReliableDate: true)
            }
        }
        return nil
    }

    private static func modulePageCandidates(base: URL, from: Date, to: Date) -> [URL] {
        let root = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let roFrom = roDate(from)
        let roTo = roDate(to)
        let paths = [
            "/pos/zreports/?lang=ro",
            "/pos/zreports/?lang=ro&date_from=\(roFrom)&date_to=\(roTo)",
            "/pos/zreports/?language=ro&date_from=\(roFrom)&date_to=\(roTo)",
            "/pos/zreports/?date_from=\(roFrom)&date_to=\(roTo)",
            "/pos/zreports/?from=\(apiDate(from))&to=\(apiDate(to))",
            "/pos/zreports/",
        ]
        return paths.compactMap { URL(string: root + $0) }
    }

    private static func discoverListEndpoint(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        from: Date,
        to: Date
    ) async -> URL? {
        var htmlSources: [String] = []
        if let dashboard = try? await BinaSmartBusinessSessionClient.fetchDashboardHTML(web: web, base: base) {
            htmlSources.append(dashboard)
        }
        if let moduleHTML = try? await BinaSmartBusinessSessionClient.fetchModulePage(
            web: web,
            url: moduleURL(base: base),
            referer: BinaSmartBusinessSessionClient.binaRootReferer(base)
        ) {
            htmlSources.append(moduleHTML)
        }
        guard !htmlSources.isEmpty else { return nil }

        let patterns = [
            #"/cors-request/[a-zA-Z0-9_/-]*z[_-]?report[a-zA-Z0-9_/-]*"#,
            #"/cors-request/pos/[a-zA-Z0-9_/-]*z[a-zA-Z0-9_/-]*"#,
            #"'(/cors-request/[^']*z[^']*)'"#,
        ]
        var paths = Set<String>()
        for html in htmlSources {
            for pattern in patterns {
                for match in allMatches(in: html, pattern: pattern) {
                    let cleaned = match.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                    if cleaned.contains("cors-request") {
                        paths.insert(cleaned.split(separator: "?").first.map(String.init) ?? cleaned)
                    }
                }
            }

            for src in allMatches(in: html, pattern: #"src="(/static/js/[^"]+\.js)""#) {
                guard let scriptURL = URL(string: src, relativeTo: base)?.absoluteURL,
                      src.contains("third-party") == false else { continue }
                guard let script = try? await BinaSmartBusinessSessionClient.fetchRaw(web: web, url: scriptURL) else { continue }
                for pattern in patterns {
                    for match in allMatches(in: script, pattern: pattern) {
                        paths.insert(match.trimmingCharacters(in: CharacterSet(charactersIn: "'\"")))
                    }
                }
            }
        }

        for path in paths {
            guard let endpoint = URL(string: base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path) else {
                continue
            }
            if let rows = try? await requestRows(
                web: web,
                base: base,
                endpoint: endpoint,
                from: from,
                to: to,
                locationFilter: nil
            ), !rows.isEmpty {
                return endpoint
            }
        }
        return nil
    }

    private static func requestRows(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        endpoint: URL,
        from: Date,
        to: Date,
        locationFilter: String?,
        referer: URL? = nil
    ) async throws -> [Row]? {
        let refererURL = referer ?? moduleURL(base: base)
        let payloads = buildPayloads(from: from, to: to, locationFilter: locationFilter)
        for payload in payloads {
            if let rows = await postJSON(web: web, referer: refererURL, endpoint: endpoint, payload: payload), !rows.isEmpty {
                return filterRows(rows, from: from, to: to, locationFilter: locationFilter, requireReliableDate: true)
            }
            if let rows = await postForm(web: web, referer: refererURL, endpoint: endpoint, payload: payload), !rows.isEmpty {
                return filterRows(rows, from: from, to: to, locationFilter: locationFilter, requireReliableDate: true)
            }
        }

        for query in buildQueryItems(from: from, to: to, locationFilter: locationFilter) {
            var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
            components?.queryItems = query
            guard let url = components?.url else { continue }
            if let rows = await getJSON(web: web, referer: refererURL, endpoint: url), !rows.isEmpty {
                return filterRows(rows, from: from, to: to, locationFilter: locationFilter, requireReliableDate: true)
            }
        }

        if let rows = await getJSON(web: web, referer: refererURL, endpoint: endpoint), !rows.isEmpty {
            return filterRows(rows, from: from, to: to, locationFilter: locationFilter, requireReliableDate: true)
        }
        return nil
    }

    private static func buildPayloads(from: Date, to: Date, locationFilter: String?) -> [[String: Any]] {
        let isoFrom = apiDate(from)
        let isoTo = apiDate(to)
        let roFrom = roDate(from)
        let roTo = roDate(to)
        var payloads: [[String: Any]] = [
            ["date_from": roFrom, "date_to": roTo],
            ["start_date": roFrom, "end_date": roTo],
            ["from": isoFrom, "to": isoTo],
            ["from_date": isoFrom, "to_date": isoTo],
            ["dateFrom": isoFrom, "dateTo": isoTo],
            ["filter": ["date_from": roFrom, "date_to": roTo]],
            ["data": ["date_from": roFrom, "date_to": roTo]],
            [
                "draw": 1,
                "start": 0,
                "length": 1000,
                "date_from": roFrom,
                "date_to": roTo,
            ],
        ]
        if let locationFilter, !locationFilter.isEmpty {
            payloads.append(["date_from": roFrom, "date_to": roTo, "location": locationFilter, "locatie": locationFilter])
        }
        return payloads
    }

    private static func buildQueryItems(from: Date, to: Date, locationFilter: String?) -> [[URLQueryItem]] {
        let isoFrom = apiDate(from)
        let isoTo = apiDate(to)
        let roFrom = roDate(from)
        let roTo = roDate(to)
        var variants: [[URLQueryItem]] = [
            [URLQueryItem(name: "date_from", value: roFrom), URLQueryItem(name: "date_to", value: roTo)],
            [URLQueryItem(name: "from", value: isoFrom), URLQueryItem(name: "to", value: isoTo)],
        ]
        if let locationFilter, !locationFilter.isEmpty {
            variants.append([
                URLQueryItem(name: "date_from", value: roFrom),
                URLQueryItem(name: "date_to", value: roTo),
                URLQueryItem(name: "location", value: locationFilter),
            ])
        }
        return variants
    }

    private static func postJSON(
        web: BinaSmartBusinessSessionClient.WebSession,
        referer: URL,
        endpoint: URL,
        payload: [String: Any]
    ) async -> [Row]? {
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        web.applyAuthenticatedHeaders(to: &request, referer: referer)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.httpBody = body
        return await parseRowsResponse(web: web, request: request, base: referer)
    }

    private static func postForm(
        web: BinaSmartBusinessSessionClient.WebSession,
        referer: URL,
        endpoint: URL,
        payload: [String: Any]
    ) async -> [Row]? {
        let flat = flatten(payload)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        web.applyAuthenticatedHeaders(to: &request, referer: referer)
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.httpBody = formEncoded(flat)
        return await parseRowsResponse(web: web, request: request, base: referer)
    }

    private static func getJSON(
        web: BinaSmartBusinessSessionClient.WebSession,
        referer: URL,
        endpoint: URL
    ) async -> [Row]? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        web.applyAuthenticatedHeaders(to: &request, referer: referer)
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        return await parseRowsResponse(web: web, request: request, base: referer)
    }

    private static func parseRowsResponse(
        web: BinaSmartBusinessSessionClient.WebSession,
        request: URLRequest,
        base: URL
    ) async -> [Row]? {
        guard let (data, response) = try? await web.urlSession.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return nil
        }

        if let json = try? JSONSerialization.jsonObject(with: data) {
            if let dict = json as? [String: Any], let code = dict["code"] as? Int, code != 200 && code != 204 {
                return nil
            }
            if let rows = binaParseRowsFromJSON(json), !rows.isEmpty {
                return rows
            }
        }

        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
           let rows = binaParseRowsFromHTML(text), !rows.isEmpty {
            return rows
        }
        return nil
    }

    private static func filterRows(
        _ rows: [Row],
        from: Date,
        to: Date,
        locationFilter: String?,
        requireReliableDate: Bool = true
    ) -> [Row] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return rows.filter { row in
            if requireReliableDate || row.hasReliableDate {
                let day = calendar.startOfDay(for: row.date)
                guard day >= start && day <= end else { return false }
            }
            guard let locationFilter, !locationFilter.isEmpty else { return true }
            guard let location = row.location?.uppercased() else { return true }
            return location.contains(locationFilter.uppercased())
        }
    }

    /// Descarcă PDF original BINA în română (wkhtmltopdf) — ca eu.pdf.
    private static func downloadBinaPDF(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        row: Row
    ) async throws -> Data {
        web.refreshRomanianCookies(base: base)

        if let data = try await fetchRomanianNavigationPDF(web: web, base: base, row: row),
           isRomanianBinaPDF(data) {
            return data
        }

        // Sesiune expirată sau cookie lipsă — re-activează română și reîncearcă o dată.
        await BinaSmartBusinessSessionClient.activateRomanianLanguageSession(web: web, base: base)
        if let data = try await fetchRomanianNavigationPDF(web: web, base: base, row: row),
           isRomanianBinaPDF(data) {
            return data
        }

        throw CashRegisterExtractError.romanianPDFUnavailable
    }

    private static func fetchRomanianNavigationPDF(
        web: BinaSmartBusinessSessionClient.WebSession,
        base: URL,
        row: Row
    ) async throws -> Data? {
        let root = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let rootReferer = BinaSmartBusinessSessionClient.binaRootReferer(base)
        let viewReferer = URL(string: "\(root)/pos/zreports/view/\(row.remoteID)/")!
        let pdfURL = URL(string: "\(root)/pos/zreports/pdf/\(row.remoteID)/")!

        web.refreshRomanianCookies(base: base)
        await BinaSmartBusinessSessionClient.primeZReportPDFSession(web: web, base: base, remoteID: row.remoteID)

        var bestEnglish: Data?
        let attempts: [(URL, URL, Bool)] = [
            (pdfURL, viewReferer, true),
            (pdfURL, viewReferer, false),
            (pdfURL, rootReferer, true),
            (URL(string: "\(root)/pos/zreports/pdf/\(row.remoteID)/?lang=ro")!, viewReferer, true),
        ]

        for (url, referer, useModuleHeaders) in attempts {
            web.refreshRomanianCookies(base: base)
            let data: Data?
            if let curlData = await BinaPosZReportCurlDownloader.downloadPDF(
                web: web, base: base, url: url, referer: referer, useXHR: useModuleHeaders
            ), isValidBinaPDF(curlData), isBinaZReportPDF(curlData) {
                data = curlData
            } else if useModuleHeaders {
                data = try await BinaSmartBusinessSessionClient.downloadModulePDF(web: web, url: url, referer: referer)
            } else {
                data = try await BinaSmartBusinessSessionClient.downloadNavigationPDF(web: web, url: url, referer: referer)
            }
            guard let data, isValidBinaPDF(data), isBinaZReportPDF(data) else { continue }
            if isRomanianBinaPDF(data) { return data }
            if bestEnglish == nil, CashRegisterZReportPDFSource.isBinaOriginalPDF(data) {
                bestEnglish = data
            }
        }
        return bestEnglish
    }

    /// Respinge PDF-ul de login BINA (24 pagini „Welcome back”) — nu e raport Z.
    private static func isBinaZReportPDF(_ data: Data) -> Bool {
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: data) else { return false }
        if document.pageCount > 2 { return false }
        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
            .folding(options: .caseInsensitive, locale: .current)
        if text.contains("welcome back") || text.contains("forgot password") { return false }
        return text.contains("z report")
        #else
        return true
        #endif
    }

    private static func isValidBinaPDF(_ data: Data) -> Bool {
        guard CashRegisterZReportPDFSource.isValidPDF(data),
              !CashRegisterZReportPDFSource.isAppGeneratedPDF(data) else { return false }
        if CashRegisterZReportPDFSource.isBinaOriginalPDF(data) { return true }
        let text = extractPDFText(data) ?? ""
        return BinaPosZReportTextNormalizer.looksLikeEnglishBinaPOS(text)
            || BinaPosZReportTextNormalizer.isRomanianBinaPDFText(text)
    }

    private static func isRomanianBinaPDF(_ data: Data) -> Bool {
        guard isValidBinaPDF(data) else { return false }
        if CashRegisterZReportPDFSource.pdfDataLooksEnglish(data) { return false }
        if CashRegisterZReportPDFSource.pdfDataLooksRomanian(data) { return true }
        let text = extractPDFText(data) ?? ""
        if BinaPosZReportTextNormalizer.looksLikeEnglishBinaPOS(text) { return false }
        if BinaPosZReportTextNormalizer.isRomanianBinaPDFText(text) { return true }
        return CashRegisterZReportPDFSource.isBinaOriginalPDF(data)
    }

    private static func isAcceptableBinaPDF(_ data: Data) -> Bool {
        isValidBinaPDF(data)
    }

    private static func inferDate(from text: String) -> Date? {
        let normalized = BinaPosZReportTextNormalizer.normalizeIfNeeded(text)
        if let closing = inferClosingDate(from: normalized) ?? inferClosingDate(from: text) {
            return closing
        }

        let patterns = [
            #"(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})"#,
            #"(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2})"#,
            #"(\d{4}-\d{2}-\d{2})"#,
            #"(\d{2}\.\d{2}\.\d{4})"#,
            #"DATA[:\s]+(\d{2}\.\d{2}\.\d{4})"#,
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let raw = String(text[match]).replacingOccurrences(of: "DATA:", with: "").trimmingCharacters(in: .whitespaces)
                if let date = binaParseDate(raw) { return date }
            }
        }
        return nil
    }

    private static func inferClosingDate(from text: String) -> Date? {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
            .uppercased()
        let patterns = [
            #"PANA LA\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}(?::\d{2})?)"#,
            #"TO\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}(?::\d{2})?)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: folded, range: NSRange(folded.startIndex..., in: folded)),
                  match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: folded) else { continue }
            if let date = binaParseDate(String(folded[range])) { return date }
        }
        return nil
    }

    private static func inferZNumber(from text: String) -> String? {
        let patterns = [
            #"Z\s*report\s*No\.?\s*(\d{1,4})"#,
            #"Z\s*report\s*Num[aă]r\s*(\d{1,4})"#,
            #"Z\s*NR[:\s]+(\d+)"#,
            #"Raport\s*Z[:\s#]+(\d+)"#,
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   match.numberOfRanges >= 2,
                   let numRange = Range(match.range(at: 1), in: text) {
                    return String(text[numRange])
                }
                let chunk = String(text[range])
                let digits = chunk.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if !digits.isEmpty { return digits }
            }
        }
        return nil
    }

    private static func extractPDFText(_ data: Data) -> String? {
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: data) else { return nil }
        return (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
        #else
        return nil
        #endif
    }

    private static func stringValue(_ value: Any?) -> String? {
        binaStringValue(value)
    }

    private static func flatten(_ payload: [String: Any], prefix: String = "") -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in payload {
            let fullKey = prefix.isEmpty ? key : "\(prefix)[\(key)]"
            if let nested = value as? [String: Any] {
                result.merge(flatten(nested, prefix: fullKey)) { $1 }
            } else if let string = stringValue(value) {
                result[fullKey] = string
            }
        }
        return result
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

    private static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func roDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
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

// MARK: - Row parsing (file-level nonisolated helpers)

nonisolated private func binaParseListResponse(_ data: Data) -> [BinaPosZReportRow] {
    let payload = binaExtractJSONPayload(from: data) ?? data
    if let json = try? JSONSerialization.jsonObject(with: payload) {
        let rows = binaParseRowsFromJSON(json) ?? []
        if !rows.isEmpty { return rows }
    }

    if let text = String(data: payload, encoding: .utf8) ?? String(data: data, encoding: .utf8) {
        if text.contains("<!DOCTYPE") || text.contains("password_unhash") {
            return []
        }
        if let rows = binaParseHTMLTableRows(text), !rows.isEmpty { return rows }
        if let rows = binaParseReportLinksFromHTML(text), !rows.isEmpty { return rows }
    }
    return []
}

nonisolated private func binaExtractJSONPayload(from data: Data) -> Data? {
    if (try? JSONSerialization.jsonObject(with: data)) != nil { return data }
    guard let text = String(data: data, encoding: .utf8) else { return nil }
    if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]") {
        return Data(text[start...end].utf8)
    }
    if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
        return Data(text[start...end].utf8)
    }
    return nil
}

nonisolated private func binaParseRowsFromJSON(_ json: Any) -> [BinaPosZReportRow]? {
    let arrays = binaExtractArrays(from: json)
    var rows: [BinaPosZReportRow] = []
    rows.reserveCapacity(arrays.count)
    for item in arrays {
        if let row = binaMapRow(item) {
            rows.append(row)
        }
    }
    return rows.isEmpty ? nil : rows
}

nonisolated private func binaParseRowsFromHTML(_ text: String) -> [BinaPosZReportRow]? {
    if let rows = binaParseHTMLTableRows(text), !rows.isEmpty { return rows }
    if let rows = binaParseReportLinksFromHTML(text), !rows.isEmpty { return rows }
    return nil
}

nonisolated private func binaParseDate(_ raw: String?) -> Date? {
    guard let raw, !raw.isEmpty else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let date = binaParseISO8601(trimmed) { return date }

    let patterns: [(String, Bool)] = [
        (#"^(\d{2})/(\d{2})/(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?$"#, true),
        (#"^(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?$"#, true),
        (#"^(\d{2})\.(\d{2})\.(\d{4})$"#, false),
        (#"^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})$"#, true),
        (#"^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$"#, true),
        (#"^(\d{4})-(\d{2})-(\d{2})$"#, false),
    ]

    for (pattern, hasTime) in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)),
              match.numberOfRanges >= 4 else { continue }

        func int(at index: Int) -> Int? {
            guard index < match.numberOfRanges,
                  let range = Range(match.range(at: index), in: trimmed) else { return nil }
            return Int(trimmed[range])
        }

        if pattern.hasPrefix(#"^(\d{4})"#) {
            guard let year = int(at: 1), let month = int(at: 2), let day = int(at: 3) else { continue }
            return binaMakeDate(
                year: year, month: month, day: day,
                hour: hasTime ? (int(at: 4) ?? 0) : 0,
                minute: hasTime ? (int(at: 5) ?? 0) : 0,
                second: hasTime ? (int(at: 6) ?? 0) : 0,
                offsetSeconds: 0
            )
        } else {
            guard let day = int(at: 1), let month = int(at: 2), let year = int(at: 3) else { continue }
            return binaMakeDate(
                year: year, month: month, day: day,
                hour: hasTime ? (int(at: 4) ?? 0) : 0,
                minute: hasTime ? (int(at: 5) ?? 0) : 0,
                second: hasTime ? (int(at: 6) ?? 0) : 0,
                offsetSeconds: binaLocalTimeZoneOffsetSeconds()
            )
        }
    }
    return nil
}

nonisolated private func binaStringValue(_ value: Any?) -> String? {
    switch value {
    case let string as String:
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    case let number as Int:
        return String(number)
    case let number as Double:
        return String(Int(number))
    default:
        return nil
    }
}

nonisolated private func binaParseReportLinksFromHTML(_ html: String) -> [BinaPosZReportRow]? {
    let patterns = [#"/pos/zreports/pdf/(\d+)/?"#, #"/pos/zreports/view/(\d+)/?"#]
    var rows: [BinaPosZReportRow] = []
    var seen = Set<String>()

    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for match in regex.matches(in: html, range: range) {
            guard match.numberOfRanges > 1, let idRange = Range(match.range(at: 1), in: html) else { continue }
            let reportID = String(html[idRange])
            guard seen.insert(reportID).inserted else { continue }

            let fullRange = Range(match.range, in: html)!
            let lower = html.index(fullRange.lowerBound, offsetBy: -500, limitedBy: html.startIndex) ?? html.startIndex
            let upper = html.index(fullRange.upperBound, offsetBy: 500, limitedBy: html.endIndex) ?? html.endIndex
            let context = String(html[lower..<upper])
            let dateText = binaFirstMatch(in: context, pattern: #"(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})"#)
                ?? binaFirstMatch(in: context, pattern: #"(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2})"#)
            let number = binaFirstMatch(in: context, pattern: #">(\d{1,6})</td>"#)
            let location = binaFirstMatch(in: context, pattern: #">\s*(\d+\s*-\s*[A-ZĂÂÎȘȚA-Z0-9\s]+)\s*</td>"#)
            rows.append(
                BinaPosZReportRow(
                    remoteID: reportID,
                    number: number,
                    date: binaParsedDate(from: dateText),
                    location: location?.trimmingCharacters(in: .whitespacesAndNewlines),
                    posNumber: nil,
                    pdfPath: "/pos/zreports/pdf/\(reportID)/",
                    hasReliableDate: dateText != nil
                )
            )
        }
    }
    return rows.isEmpty ? nil : rows
}

nonisolated private func binaParseHTMLTableRows(_ html: String) -> [BinaPosZReportRow]? {
    guard html.localizedCaseInsensitiveContains("raport") || html.localizedCaseInsensitiveContains("pdf") else {
        return nil
    }
    var rows: [BinaPosZReportRow] = []
    let rowPattern = #"<tr[^>]*>([\s\S]*?)</tr>"#
    guard let regex = try? NSRegularExpression(pattern: rowPattern, options: .caseInsensitive) else { return nil }
    let range = NSRange(html.startIndex..<html.endIndex, in: html)
    for match in regex.matches(in: html, range: range) {
        guard let swiftRange = Range(match.range(at: 1), in: html) else { continue }
        let chunk = String(html[swiftRange])
        guard chunk.localizedCaseInsensitiveContains("pdf") else { continue }

        let pdfHref = binaFirstMatch(in: chunk, pattern: #"href="([^"]+)""#)
            ?? binaFirstMatch(in: chunk, pattern: #"href='([^']+)'"#)
        let reportID = pdfHref.flatMap { binaExtractPdfReportID(from: $0) }
        let number = binaFirstMatch(in: chunk, pattern: #">(\d{1,6})</td>"#)
        let dateText = binaFirstMatch(in: chunk, pattern: #"(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})"#)
            ?? binaFirstMatch(in: chunk, pattern: #"(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2})"#)
        let location = binaFirstMatch(in: chunk, pattern: #">\s*(\d+\s*-\s*[A-ZĂÂÎȘȚA-Z0-9\s]+)\s*</td>"#)
        rows.append(
            BinaPosZReportRow(
                remoteID: reportID ?? number ?? pdfHref ?? UUID().uuidString,
                number: number,
                date: binaParsedDate(from: dateText),
                location: location?.trimmingCharacters(in: .whitespacesAndNewlines),
                posNumber: nil,
                pdfPath: pdfHref ?? reportID.map { "/pos/zreports/pdf/\($0)/" },
                hasReliableDate: dateText != nil
            )
        )
    }
    return rows.isEmpty ? nil : rows
}

nonisolated private func binaExtractArrays(from json: Any) -> [[String: Any]] {
    if let array = json as? [[String: Any]] { return array }
    guard let dict = json as? [String: Any] else { return [] }
    for key in ["data", "rows", "items", "results", "list", "zreports", "reports", "aaData"] {
        if let array = dict[key] as? [[String: Any]] { return array }
        if let nested = dict[key] as? [String: Any],
           let array = nested["rows"] as? [[String: Any]] ?? nested["data"] as? [[String: Any]] {
            return array
        }
    }
    return []
}

nonisolated private func binaMapRow(_ item: [String: Any]) -> BinaPosZReportRow? {
    let remoteID = binaStringValue(item["id"] ?? item["pk"] ?? item["z_id"] ?? item["report_id"])
    let number = binaStringValue(
        item["code"] ?? item["number"] ?? item["numar"] ?? item["nr"] ?? item["z_number"] ?? item["zNumber"] ?? item["no"]
    )
    let location = binaStringValue(
        item["location_nm"] ?? item["location"] ?? item["locatie"] ?? item["loc"] ?? item["location_name"] ?? item["nm"]
    )
        let posNumber = binaStringValue(
            item["pos_nr"] ?? item["pos_number"] ?? item["posNumber"] ?? item["pos"] ?? item["posnumber"]
        )
    let pdfPath = binaStringValue(item["pdf"] ?? item["pdf_url"] ?? item["pdfUrl"] ?? item["download_url"] ?? item["url"])
    let dateRaw = binaStringValue(
        item["date_close"] ?? item["date"] ?? item["data"] ?? item["report_date"] ?? item["created"] ?? item["datetime"]
    )
    let rowDate = binaParsedDate(from: dateRaw)

    let resolvedID: String
    if let remoteID {
        resolvedID = remoteID
    } else if let pdfPath, let extracted = binaExtractPdfReportID(from: pdfPath) {
        resolvedID = extracted
    } else if let number {
        resolvedID = number
    } else {
        resolvedID = UUID().uuidString
    }

    return BinaPosZReportRow(
        remoteID: resolvedID,
        number: number,
        date: rowDate,
        location: location,
        posNumber: posNumber,
        pdfPath: pdfPath ?? "/pos/zreports/pdf/\(resolvedID)/",
        hasReliableDate: dateRaw != nil && binaParseDate(dateRaw) != nil
    )
}

nonisolated private func binaExtractPdfReportID(from path: String) -> String? {
    binaFirstMatch(in: path, pattern: #"/zreports/pdf/(\d+)/?"#)
        ?? binaFirstMatch(in: path, pattern: #"pdf/(\d+)/?"#)
}

nonisolated private func binaFirstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          match.numberOfRanges > 1,
          let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
    return String(text[swiftRange])
}

nonisolated private func binaParsedDate(from raw: String?) -> Date {
    guard let raw, let date = binaParseDate(raw) else { return Date() }
    return date
}

nonisolated private func binaParseISO8601(_ raw: String) -> Date? {
    let pattern = #"^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|([+-])(\d{2}):?(\d{2}))?$"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..<raw.endIndex, in: raw)) else {
        return nil
    }

    func int(at index: Int) -> Int? {
        guard index < match.numberOfRanges,
              match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: raw) else { return nil }
        return Int(raw[range])
    }

    guard let year = int(at: 1), let month = int(at: 2), let day = int(at: 3),
          let hour = int(at: 4), let minute = int(at: 5), let second = int(at: 6) else {
        return nil
    }

    var offsetSeconds = 0
    if match.range(at: 7).location != NSNotFound,
       let signRange = Range(match.range(at: 7), in: raw) {
        let sign = raw[signRange] == "-" ? -1 : 1
        offsetSeconds = sign * (((int(at: 8) ?? 0) * 3600) + ((int(at: 9) ?? 0) * 60))
    }

    return binaMakeDate(
        year: year, month: month, day: day, hour: hour, minute: minute, second: second,
        offsetSeconds: offsetSeconds
    )
}

nonisolated private func binaMakeDate(
    year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, offsetSeconds: Int
) -> Date? {
    guard (1...12).contains(month), (1...31).contains(day) else { return nil }
    let a = (14 - month) / 12
    let y = year + 4_800 - a
    let m = month + 12 * a - 3
    let julianDay = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32_045
    let days = julianDay - 2_440_588
    let totalSeconds = days * 86_400 + hour * 3_600 + minute * 60 + second - offsetSeconds
    return Date(timeIntervalSince1970: TimeInterval(totalSeconds))
}

nonisolated private func binaLocalTimeZoneOffsetSeconds() -> Int { 7_200 }
