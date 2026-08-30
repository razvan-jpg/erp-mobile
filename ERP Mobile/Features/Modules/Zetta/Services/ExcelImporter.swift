import Foundation

enum ExcelImporter {
    struct ImportResult {
        var reports: [ZReportData]
        var rows: [NotaContabilaRow]
        var firmGroupingKey: String
        var displayName: String
    }

    static func importFile(from url: URL) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let sheetXML = try extractSheetXML(from: data)
        try validateExportStructure(in: sheetXML)
        let rows = parseRows(from: sheetXML)
        guard !rows.isEmpty else {
            throw ImportError.incompatibleFile
        }
        let reports = reconstructReports(from: rows)
        guard let first = reports.first else {
            throw ImportError.incompatibleFile
        }
        return ImportResult(
            reports: reports,
            rows: rows,
            firmGroupingKey: FirmaRegistry.groupingKey(for: first),
            displayName: FirmaRegistry.displayName(for: first)
        )
    }

    /// Completează CUI/firmă din denumirea fișierului — necesar pentru deduplicare după reîncărcare Excel.
    static func enrichReportsFromFileName(_ reports: [ZReportData], fileName: String) -> [ZReportData] {
        guard let parsed = ExcelExporter.parseNCFileName(fileName) else { return reports }
        return reports.map { enrich($0, parsed: parsed) }
    }

    private static func enrich(_ report: ZReportData, parsed: ExcelExporter.NCFileNameInfo) -> ZReportData {
        var z = report
        if z.cui.isEmpty {
            z.cui = parsed.cui
        }
        if let profile = FirmaRegistry.profile(forCUI: z.cui)
            ?? FirmaRegistry.profile(matchingName: parsed.firmName) {
            z.firma = profile.displayName
            z.cui = profile.cui
            z.isNectarieFirma = profile.isNectarie
        } else if z.firma.isEmpty || z.firma == Conturi.partenerNume {
            z.firma = parsed.firmName
        }
        return z
    }

    /// Verifică dacă foaia are antetul și coloanele generate la export de Zetta.
    static func validateExportStructure(in sheetXML: String) throws {
        guard sheetXML.contains("<sheetData>") else {
            throw ImportError.incompatibleFile
        }

        let found = headerRowValues(from: sheetXML)
        guard found.count >= ExcelExporter.headers.count else {
            throw ImportError.incompatibleFile
        }

        for (index, expected) in ExcelExporter.headers.enumerated() {
            let actual = found[index]
            let matches = actual == expected
                || actual.trimmingCharacters(in: .whitespacesAndNewlines)
                    == expected.trimmingCharacters(in: .whitespacesAndNewlines)
            guard matches else {
                throw ImportError.incompatibleFile
            }
        }

        let rows = parseRows(from: sheetXML)
        guard !rows.isEmpty else {
            throw ImportError.incompatibleFile
        }

        let validJournals = Set(["JV", "RC", "OD"])
        guard rows.contains(where: { validJournals.contains($0.jurnal.uppercased()) }) else {
            throw ImportError.incompatibleFile
        }
    }

    /// Antetul primei rânduri, indexat pe coloană (păstrează spațiile din export).
    private static func headerRowValues(from xml: String) -> [String] {
        guard let headerChunk = xml.components(separatedBy: "<row r=\"").dropFirst().first,
              let end = headerChunk.firstIndex(of: ">") else { return [] }
        let rowBody = String(headerChunk[headerChunk.index(after: end)...])
        guard let close = rowBody.range(of: "</row>") else { return [] }
        let cells = parseCells(from: String(rowBody[..<close.lowerBound]))
        guard let maxCol = cells.keys.max() else { return [] }
        return (0...maxCol).map { cells[$0] ?? "" }
    }

    private static func extractSheetXML(from xlsxData: Data) throws -> String {
        guard ZipReader.findEOCD(in: xlsxData) != nil else {
            throw ImportError.incompatibleFile
        }
        let candidates = ["xl/worksheets/sheet1.xml", "xl/worksheets/sheet2.xml"]
        for path in candidates {
            if let sheetData = try? ZipReader.extract(entryPath: path, from: xlsxData),
               let xml = String(data: sheetData, encoding: .utf8), xml.contains("<sheetData>") {
                return xml
            }
        }
        throw ImportError.incompatibleFile
    }

    // MARK: - Parse XML

    private static func parseRows(from xml: String) -> [NotaContabilaRow] {
        let headerMap = columnIndexMap(from: xml)
        guard !headerMap.isEmpty else { return [] }

        var rows: [NotaContabilaRow] = []
        let rowChunks = xml.components(separatedBy: "<row r=\"")
        for chunk in rowChunks.dropFirst() {
            guard let end = chunk.firstIndex(of: ">") else { continue }
            let rowBody = String(chunk[chunk.index(after: end)...])
            guard let close = rowBody.range(of: "</row>") else { continue }
            let cellsXML = String(rowBody[..<close.lowerBound])
            if cellsXML.contains("Nr. inreg.") { continue }

            let cells = parseCells(from: cellsXML)
            guard let nr = intCell(cells, headerMap, "Nr. inreg.") else { continue }
            guard let valoare = decimalCell(cells, headerMap, "Valoare") else { continue }

            var row = NotaContabilaRow(
                nrInreg: nr,
                jurnal: textCell(cells, headerMap, "Jurnal") ?? "",
                dataYYYYMMDD: intCell(cells, headerMap, "Data") ?? 0,
                numarDocument: textCell(cells, headerMap, "Numar document") ?? "",
                contDebit: textCell(cells, headerMap, "Cont debit simbol") ?? "",
                titluDebit: textCell(cells, headerMap, "Cont debit titlu") ?? "",
                contCredit: textCell(cells, headerMap, "Cont credit simbol") ?? "",
                titluCredit: textCell(cells, headerMap, "Cont credit titlu") ?? "",
                valoare: valoare
            )
            row.explicatie = textCell(cells, headerMap, "Explicatie") ?? ""
            row.codPartener = textCell(cells, headerMap, "Cod Partener") ?? ""
            row.partenerCIF = textCell(cells, headerMap, "Partener CIF") ?? ""
            row.partenerNume = textCell(cells, headerMap, "Partener Nume") ?? ""
            row.firmCUI = textCellAt(cells, column: ExcelExporter.firmCUIColumnIndex) ?? ""
            row.optiuneTva = textCell(cells, headerMap, "Optiune TVA") ?? ""
            row.cotaTva = decimalCell(cells, headerMap, "Cota TVA")
            row.codTvaSaft = textCell(cells, headerMap, "Cod TVA SAF-T") ?? ""
            row.moneda = textCell(cells, headerMap, "Moneda") ?? "RON"
            rows.append(row)
        }
        return rows
    }

    private typealias CellMap = [Int: String]

    private static func columnIndexMap(from xml: String) -> [String: Int] {
        let headers = headerRowValues(from: xml)
        guard !headers.isEmpty else { return [:] }
        var map: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // Prima apariție câștigă — suficient pentru coloanele folosite la import.
            if map[trimmed] == nil {
                map[trimmed] = index
            }
        }
        return map
    }

    private static func parseCells(from rowXML: String) -> CellMap {
        var cells: CellMap = [:]
        let parts = rowXML.components(separatedBy: "<c r=\"")
        for part in parts.dropFirst() {
            guard let quote = part.firstIndex(of: "\"") else { continue }
            let ref = String(part[..<quote])
            guard let col = columnNumber(from: ref) else { continue }
            let body = String(part[part.index(after: quote)...])
            if let value = inlineString(in: body) ?? numericValue(in: body) {
                cells[col] = value
            }
        }
        return cells
    }

    private static func inlineString(in cellXML: String) -> String? {
        guard let start = cellXML.range(of: "<t>"),
              let end = cellXML.range(of: "</t>", range: start.upperBound..<cellXML.endIndex) else {
            return nil
        }
        return unescapeXML(String(cellXML[start.upperBound..<end.lowerBound]))
    }

    private static func numericValue(in cellXML: String) -> String? {
        guard let start = cellXML.range(of: "<v>"),
              let end = cellXML.range(of: "</v>", range: start.upperBound..<cellXML.endIndex) else {
            return nil
        }
        return String(cellXML[start.upperBound..<end.lowerBound])
    }

    private static func textCell(_ cells: CellMap, _ map: [String: Int], _ header: String) -> String? {
        guard let col = map[header], let raw = cells[col] else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func textCellAt(_ cells: CellMap, column: Int) -> String? {
        guard let raw = cells[column] else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func intCell(_ cells: CellMap, _ map: [String: Int], _ header: String) -> Int? {
        guard let text = textCell(cells, map, header) else { return nil }
        if let i = Int(text) { return i }
        if let d = Decimal(string: text.replacingOccurrences(of: ",", with: ".")) {
            return NSDecimalNumber(decimal: d).intValue
        }
        return nil
    }

    private static func decimalCell(_ cells: CellMap, _ map: [String: Int], _ header: String) -> Decimal? {
        guard let text = textCell(cells, map, header) else { return nil }
        return Decimal(string: text.replacingOccurrences(of: ",", with: "."))
    }

    private static func columnNumber(from cellRef: String) -> Int? {
        let letters = cellRef.prefix { $0.isLetter }
        guard !letters.isEmpty else { return nil }
        var n = 0
        for ch in letters.uppercased() {
            guard let scalar = ch.unicodeScalars.first else { continue }
            n = n * 26 + Int(scalar.value - 65) + 1
        }
        return n - 1
    }

    private static func unescapeXML(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }

    // MARK: - Reconstruct Z

    static func reconstructReports(from rows: [NotaContabilaRow]) -> [ZReportData] {
        let grouped = Dictionary(grouping: rows, by: \.nrInreg)
        return grouped.keys.sorted().compactMap { nr in
            guard let group = grouped[nr] else { return nil }
            return reconstructReport(from: group)
        }
    }

    private static func reconstructReport(from rows: [NotaContabilaRow]) -> ZReportData? {
        guard let head = rows.first else { return nil }
        var z = ZReportData()
        z.sourceFileName = "Excel · NC \(head.nrInreg)"
        z.zNumber = parseZNumber(from: head.numarDocument)
        z.date = dateFromYYYYMMDD(head.dataYYYYMMDD)
        z.firma = head.partenerNume.trimmingCharacters(in: .whitespacesAndNewlines)
        if !head.firmCUI.isEmpty {
            z.cui = normalizeCIF(head.firmCUI)
        } else {
            z.cui = normalizeCIF(head.partenerCIF)
        }
        if let profile = FirmaRegistry.profile(forCUI: z.cui) ?? FirmaRegistry.profile(matchingName: z.firma) {
            z.firma = profile.displayName
            z.cui = profile.cui
            z.isNectarieFirma = profile.isNectarie
        } else {
            z.isNectarieFirma = Conturi.isNectarieFirma(z.firma)
        }
        if z.isNectarieFirma {
            z.punctLucru = inferPunct(from: head.numarDocument, rows: rows)
        }

        var tva11Seen = 0

        for row in rows {
            let cota = row.cotaTva.map { NSDecimalNumber(decimal: $0).intValue } ?? -1
            switch row.jurnal.uppercased() {
            case "JV":
                if row.contCredit == Conturi.tvaColectata || row.contCredit == "4427" {
                    if cota == 21 { z.tva21 = row.valoare }
                    else if cota == 11 {
                        if tva11Seen == 0 { z.tva11 = row.valoare }
                        else { z.tva11C = row.valoare }
                        tva11Seen += 1
                    }
                } else if row.contCredit == Conturi.venituri11 || row.contCredit == "701" {
                    if z.usesBacsisSchema {
                        z.vanzari11C = row.valoare + z.tva11C
                    } else {
                        z.vanzari11 = row.valoare + z.tva11
                    }
                } else if row.contCredit == Conturi.venituri21 || row.contCredit == "707" {
                    if cota == 21 {
                        z.vanzari21 = row.valoare + z.tva21
                    } else if cota == 11 {
                        z.vanzari11 = row.valoare + z.tva11
                    } else if cota == 0 {
                        z.vanzari0 = row.valoare
                    }
                } else if row.contCredit == Conturi.venituriServicii || row.contCredit == "704"
                    || row.contCredit == Conturi.garantie || row.contCredit == Conturi.bacsisVenit
                    || row.contCredit == "267.1" || row.contCredit == "462.1" || row.contCredit == "462" {
                    z.vanzari0 = row.valoare
                }
            case "RC":
                if row.contDebit.hasPrefix("5311"), row.contCredit.hasPrefix("4111") {
                    z.numerar = row.valoare
                } else if row.contDebit == Conturi.card || row.contDebit == "5125" {
                    z.card = row.valoare
                } else if row.contDebit == Conturi.plataModerna || row.contDebit == "5113" {
                    z.altePlati = row.valoare
                }
            case "OD":
                if row.contDebit == Conturi.card || row.contDebit == "5125" {
                    if z.card == 0 { z.card = row.valoare }
                } else if row.contDebit == Conturi.plataModerna || row.contDebit == "5113" {
                    if z.altePlati == 0 { z.altePlati = row.valoare }
                    else { z.plataModerna = row.valoare }
                }
            default:
                break
            }
        }

        let sumCategories = z.vanzari21 + z.vanzari11 + z.vanzari11C + z.vanzari0
        z.totalVanzari = sumCategories > 0 ? sumCategories : z.numerar + z.card + z.altePlati + z.plataModerna
        return z.zNumber > 0 ? z : nil
    }

    private static func parseZNumber(from doc: String) -> Int {
        let trimmed = doc.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digits = trimmed.filter { $0.isNumber }
        return Int(digits) ?? 0
    }

    private static func dateFromYYYYMMDD(_ value: Int) -> Date {
        let y = value / 10000
        let m = (value / 100) % 100
        let d = value % 100
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    private static func normalizeCIF(_ raw: String) -> String {
        raw.uppercased()
            .replacingOccurrences(of: "RO", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isNumber }
    }

    private static func inferPunct(from doc: String, rows: [NotaContabilaRow]) -> PunctLucru {
        if doc.lowercased().hasPrefix("z") { return .ploiesti }
        if rows.contains(where: { $0.contDebit == "5311.2" || $0.titluDebit.contains("Ploiesti") }) {
            return .ploiesti
        }
        return .agro
    }

    enum ImportError: LocalizedError, Equatable {
        case incompatibleFile

        var errorDescription: String? {
            switch self {
            case .incompatibleFile: return "Fisier excel incompatibil!!!"
            }
        }
    }
}

struct SavedExcelSession: Identifiable, Equatable {
    let id: String
    let firmGroupingKey: String
    let displayName: String
    var fileURL: URL
    var fileName: String

    init(firmGroupingKey: String, displayName: String, fileURL: URL) {
        self.id = firmGroupingKey
        self.firmGroupingKey = firmGroupingKey
        self.displayName = displayName
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
    }
}

enum SavedExcelWarning {
    static let text = """
    Aplicația nu stochează niciun fel de date. Fișierele xlsx salvate conțin în denumirea lor numele societății și perioada Z-urilor încărcate.

    Încărcarea unui fișier și continuarea lucrului pe el se face strict pe răspunderea utilizatorului: trebuie importate în continuare Z-uri ale aceleiași societăți, altfel importul în softul de contabilitate va produce erori fiscale — date denaturate.
    """
}
