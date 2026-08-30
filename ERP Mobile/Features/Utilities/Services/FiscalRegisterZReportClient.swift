import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

enum FiscalRegisterZReportClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    static func listAvailableReports(request: CashRegisterExtractRequest) async throws -> [CashRegisterZReportPreviewItem] {
        let baseURL = normalizeBaseURL(request.baseURL)
        if shouldUseBinaWebSession(provider: request.provider, baseURL: baseURL) {
            let rows = try await BinaSmartBusinessSessionClient.listAvailableReports(
                loginURL: binaLoginURL(from: request.baseURL),
                username: request.username,
                password: request.password,
                from: request.fromDate,
                to: request.toDate,
                binaLocationFilter: request.binaLocationFilter
            )
            return rows.map { row in
                CashRegisterZReportPreviewItem(
                    remoteID: row.remoteID,
                    reportNumber: row.number,
                    reportDate: row.date,
                    location: row.location,
                    posNumber: row.posNumber
                )
            }
        }
        throw CashRegisterExtractError.apiNotAvailable
    }

    static func downloadSelectedReports(
        request: CashRegisterExtractRequest,
        selectedRemoteIDs: [String],
        listedRows: [BinaPosZReportRow]
    ) async throws -> [ExtractedCashRegisterZReport] {
        let baseURL = normalizeBaseURL(request.baseURL)
        guard shouldUseBinaWebSession(provider: request.provider, baseURL: baseURL) else {
            throw CashRegisterExtractError.apiNotAvailable
        }
        let selected = listedRows.filter { selectedRemoteIDs.contains($0.remoteID) }
        guard !selected.isEmpty else {
            throw CashRegisterExtractError.noReportsFound
        }
        return try await BinaSmartBusinessSessionClient.downloadReports(
            loginURL: binaLoginURL(from: request.baseURL),
            username: request.username,
            password: request.password,
            rows: selected,
            from: request.fromDate,
            to: request.toDate,
            binaLocationFilter: request.binaLocationFilter
        )
    }

    static func extractReports(request: CashRegisterExtractRequest) async throws -> [ExtractedCashRegisterZReport] {
        let baseURL = normalizeBaseURL(request.baseURL)
        if shouldUseBinaWebSession(provider: request.provider, baseURL: baseURL) {
            return try await BinaSmartBusinessSessionClient.extractReports(
                loginURL: binaLoginURL(from: request.baseURL),
                username: request.username,
                password: request.password,
                from: request.fromDate,
                to: request.toDate,
                binaLocationFilter: request.binaLocationFilter
            )
        }
        if isWebLoginURL(baseURL) {
            throw CashRegisterExtractError.webLoginAddress
        }

        let endpoints = endpointCandidates(for: request.provider, baseURL: baseURL, from: request.fromDate, to: request.toDate)
        var lastStatusCode: Int?
        var lastError: Error?

        for endpoint in endpoints {
            do {
                var urlRequest = URLRequest(url: endpoint)
                urlRequest.httpMethod = "GET"
                applyAuth(to: &urlRequest, username: request.username, password: request.password)

                let (data, response) = try await session.data(for: urlRequest)
                guard let http = response as? HTTPURLResponse else {
                    throw CashRegisterExtractError.unsupportedResponse
                }

                switch http.statusCode {
                case 200...299:
                    if let reports = try parseResponse(data: data, from: request.fromDate, to: request.toDate), !reports.isEmpty {
                        return reports
                    }
                case 401, 403:
                    throw CashRegisterExtractError.authenticationFailed
                default:
                    lastStatusCode = http.statusCode
                    lastError = CashRegisterExtractError.network("HTTP \(http.statusCode)")
                }
            } catch let error as CashRegisterExtractError {
                throw error
            } catch {
                lastError = error
            }
        }

        if let authError = lastError as? CashRegisterExtractError { throw authError }
        if lastStatusCode == 404 || request.provider == .binaSmartBusiness {
            throw CashRegisterExtractError.apiNotAvailable
        }
        if let lastError { throw CashRegisterExtractError.network(lastError.localizedDescription) }
        throw CashRegisterExtractError.noReportsFound
    }

    static func parseUploadedFiles(urls: [URL], from: Date, to: Date) throws -> [ExtractedCashRegisterZReport] {
        var reports: [ExtractedCashRegisterZReport] = []
        let calendar = Calendar.current
        let fromDay = calendar.startOfDay(for: from)
        let toDay = calendar.startOfDay(for: to)

        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            let lower = url.lastPathComponent.lowercased()

            if lower.hasSuffix(".pdf") {
                if let parsed = try parsePDFData(data, from: from, to: to) {
                    reports.append(contentsOf: parsed)
                }
                continue
            }

            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                continue
            }
            if let parsed = try parseResponse(data: Data(text.utf8), from: from, to: to) {
                reports.append(contentsOf: parsed)
            }
        }

        let filtered = reports.filter {
            let day = calendar.startOfDay(for: $0.reportDate)
            return day >= fromDay && day <= toDay
        }
        guard !filtered.isEmpty else { throw CashRegisterExtractError.noReportsFound }
        return filtered
    }

    static func normalizeBaseURL(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.path.lowercased() ?? ""
        let loginSuffixes = ["/login", "/signin", "/auth", "/account/login"]
        for suffix in loginSuffixes where path.hasSuffix(suffix) {
            components?.path = String(path.dropLast(suffix.count))
            break
        }
        if components?.path == "/" { components?.path = "" }
        return components?.url ?? url
    }

    static func isWebLoginURL(_ url: URL) -> Bool {
        if shouldUseBinaWebSession(provider: .binaSmartBusiness, baseURL: url) {
            return false
        }
        let path = url.path.lowercased()
        return path.contains("login") || path.contains("signin")
    }

    static func shouldUseBinaWebSession(provider: CashRegisterProvider, baseURL: URL) -> Bool {
        guard provider == .binaSmartBusiness else { return false }
        let host = (baseURL.host ?? "").lowercased()
        return host.contains("binasmartbusiness.com")
    }

    static func binaLoginURL(from url: URL) -> URL {
        let normalized = normalizeBaseURL(url)
        if url.path.lowercased().contains("login") {
            return url
        }
        return normalized.appendingPathComponent("login")
    }

    private static func endpointCandidates(for provider: CashRegisterProvider, baseURL: URL, from: Date, to: Date) -> [URL] {
        let fromStr = apiDate(from)
        let toStr = apiDate(to)
        let root = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let paths: [String]
        switch provider {
        case .binaSmartBusiness:
            paths = [
                "/api/zreports?from=\(fromStr)&to=\(toStr)",
                "/api/v1/zreports?from=\(fromStr)&to=\(toStr)",
                "/api/reports/z?startDate=\(fromStr)&endDate=\(toStr)",
                "/Export/ZReports?from=\(fromStr)&to=\(toStr)",
            ]
        case .memgest:
            paths = [
                "/api/rapoarte/z?from=\(fromStr)&to=\(toStr)",
                "/Export/RaportZ?from=\(fromStr)&to=\(toStr)",
            ]
        case .bocp:
            paths = [
                "/api/v1/export/rapoarte?from=\(fromStr)&to=\(toStr)",
                "/api/export/zreports?from=\(fromStr)&to=\(toStr)",
            ]
        case .genericHttp:
            paths = [
                "/api/zreports?from=\(fromStr)&to=\(toStr)",
                "/zreports?from=\(fromStr)&to=\(toStr)",
                "/reports/z?from=\(fromStr)&to=\(toStr)",
                "/api/reports/fiscal-z?start=\(fromStr)&end=\(toStr)",
            ]
        }

        return paths.compactMap { URL(string: root + $0) }
    }

    private static func applyAuth(to request: inout URLRequest, username: String, password: String) {
        let token = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private static func parseResponse(data: Data, from: Date, to: Date) throws -> [ExtractedCashRegisterZReport]? {
        if data.starts(with: [0x25, 0x50, 0x44, 0x46]) {
            return try parsePDFData(data, from: from, to: to)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) {
            if let reports = parseJSONArray(json) { return reports }
            if let dict = json as? [String: Any], let reports = parseJSONArray(dict["data"] ?? dict["reports"] ?? dict["zreports"] ?? []) {
                return reports
            }
        }

        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }

        if text.contains("RAPORT FISCAL") || text.contains("RAPORT Z") {
            return splitTextReports(text, from: from, to: to)
        }

        return nil
    }

    private static func parseJSONArray(_ json: Any) -> [ExtractedCashRegisterZReport]? {
        guard let array = json as? [[String: Any]], !array.isEmpty else { return nil }
        let formatter = isoDateFormatter()

        return array.compactMap { item -> ExtractedCashRegisterZReport? in
            let dateString = (item["date"] ?? item["reportDate"] ?? item["data"]) as? String
            let parsedDate = dateString.flatMap { formatter.date(from: $0) ?? flexibleDate($0) } ?? Date()
            let number = (item["number"] ?? item["zNumber"] ?? item["nrZ"]) as? String
            if let pdfBase64 = item["pdfBase64"] as? String, let pdfData = Data(base64Encoded: pdfBase64) {
                let text = extractPDFText(pdfData) ?? ""
                return ExtractedCashRegisterZReport(reportDate: parsedDate, reportNumber: number, textContent: text, pdfData: pdfData)
            }
            if let content = (item["content"] ?? item["text"] ?? item["body"]) as? String, !content.isEmpty {
                return ExtractedCashRegisterZReport(reportDate: parsedDate, reportNumber: number, textContent: content)
            }
            return nil
        }
    }

    private static func parsePDFData(_ data: Data, from: Date, to: Date) throws -> [ExtractedCashRegisterZReport]? {
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: data) else { return nil }
        var reports: [ExtractedCashRegisterZReport] = []
        let calendar = Calendar.current
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let text = page.string, !text.isEmpty else { continue }
            let date = inferDate(from: text) ?? from
            guard date >= calendar.startOfDay(for: from), date <= calendar.startOfDay(for: to) else { continue }
            reports.append(
                ExtractedCashRegisterZReport(
                    reportDate: date,
                    reportNumber: inferZNumber(from: text),
                    textContent: text,
                    pdfData: data
                )
            )
        }
        return reports.isEmpty ? nil : reports
        #else
        throw CashRegisterExtractError.unsupportedResponse
        #endif
    }

    private static func splitTextReports(_ text: String, from: Date, to: Date) -> [ExtractedCashRegisterZReport] {
        let parts = text.components(separatedBy: "RAPORT FISCAL ZILNIC")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let calendar = Calendar.current
        if parts.count <= 1 {
            let date = inferDate(from: text) ?? from
            return [ExtractedCashRegisterZReport(reportDate: date, reportNumber: inferZNumber(from: text), textContent: text)]
        }

        return parts.compactMap { part in
            let body = "RAPORT FISCAL ZILNIC\n" + part
            let date = inferDate(from: body) ?? from
            guard date >= calendar.startOfDay(for: from), date <= calendar.startOfDay(for: to) else { return nil }
            return ExtractedCashRegisterZReport(reportDate: date, reportNumber: inferZNumber(from: body), textContent: body)
        }
    }

    private static func extractPDFText(_ data: Data) -> String? {
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: data) else { return nil }
        return (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
        #else
        return nil
        #endif
    }

    private static func inferDate(from text: String) -> Date? {
        let patterns = [
            #"(\d{4}-\d{2}-\d{2})"#,
            #"(\d{2}\.\d{2}\.\d{4})"#,
            #"DATA[:\s]+(\d{2}\.\d{2}\.\d{4})"#,
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let raw = String(text[match]).replacingOccurrences(of: "DATA:", with: "").trimmingCharacters(in: .whitespaces)
                if let date = flexibleDate(raw) { return date }
            }
        }
        return nil
    }

    private static func inferZNumber(from text: String) -> String? {
        let patterns = [#"Z\s*NR[:\s]+(\d+)"#, #"Raport\s*Z[:\s#]+(\d+)"#]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let chunk = String(text[range])
                let digits = chunk.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if !digits.isEmpty { return digits }
            }
        }
        return nil
    }

    private static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func isoDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return formatter
    }

    private static func flexibleDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = ["yyyy-MM-dd", "dd.MM.yyyy", "dd/MM/yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return isoDateFormatter().date(from: trimmed)
    }
}
