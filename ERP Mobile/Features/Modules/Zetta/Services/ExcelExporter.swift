import Foundation
import Compression

enum ExcelExportNamingStyle: Sendable {
    case accountingNote
    case zettaUtility
}

enum ExcelExporter {
    /// Coloana BZ — CUI firmă (deduplicare Zetta; nu se completează Partener CIF pentru NextUp).
    static let firmCUIColumnIndex = 77

    /// Antet identic cu NC.xls (aceeași ordine, aceleași denumiri).
    static let headers: [String] = [
        "Nr. inreg.",
        "Tip inregistrare",
        "Jurnal",
        "Data",
        "Data scadenta",
        "Numar document",
        "Cod tip factura",
        "Cont debit simbol",
        "Cont debit titlu",
        "Metoda de plata SAF-T",
        "Mecanism de plata SAF-T",
        "Tip Taxa SAF-T",
        "Cod Taxa SAF-T",
        "Cont credit simbol",
        "Cont credit titlu",
        "Metoda de plata SAF-T    ",
        "Mecanism de plata SAFT-T",
        "Tip Taxa SAF_T",
        "Cod TAXA SAF_T",
        "Explicatie",
        "Valoare",
        "Cod Partener",
        "Partener CIF",
        "Partener Nume",
        "Partener Rezidenta",
        "Partener Judet",
        "Partener Cont",
        "Angajat CNP",
        "Angajat Nume",
        "Angajat Cont",
        "Optiune TVA",
        "Cota TVA",
        "Cod TVA SAF-T",
        "Moneda",
        "Curs",
        "Valoare deviza",
        "Stornare - Nr. inreg.",
        "Incasari/plati",
        "Diferente curs",
        "TVA la incasare",
        "Colectare/Deducere TVA",
        "Efect de incasat/platit",
        "Banca efect",
        "Centre de cost",
        "Informatii export",
        "Punct de lucru",
        "Deductibilitate",
        "Reevaluare",
        "Factura simplificata",
        "Borderou de achizitie",
        "Carnet prod. Agricole",
        "Contract",
        "Document stornat"
    ]

    static func export(rows: [NotaContabilaRow], to url: URL) throws {
        let sheetXML = buildSheetXML(rows: rows)
        let files: [String: Data] = [
            "[Content_Types].xml": Data(contentTypesXML.utf8),
            "_rels/.rels": Data(relsXML.utf8),
            "xl/workbook.xml": Data(workbookXML.utf8),
            "xl/_rels/workbook.xml.rels": Data(workbookRelsXML.utf8),
            "xl/styles.xml": Data(stylesXML.utf8),
            "xl/worksheets/sheet1.xml": Data(sheetXML.utf8)
        ]
        let zipData = try ZipWriter.create(files: files)
        try zipData.write(to: url)
    }

    /// Grup de Z-uri pentru o singură firmă → un fișier Excel dedicat.
    struct FirmExportGroup: Identifiable {
        let id: String
        let displayName: String
        let reports: [ZReportData]
        let config: ZettaNCConfig?
        let namingStyle: ExcelExportNamingStyle
        let companyDisplayName: String?
        let startingNrInreg: Int

        var fileName: String {
            ExcelExporter.suggestedFileName(
                for: reports,
                style: namingStyle,
                companyDisplayName: companyDisplayName
            )
        }
        var rows: [NotaContabilaRow] {
            NotaContabilaGenerator.generate(
                from: reports,
                config: config,
                startingNrInreg: startingNrInreg
            )
        }
    }

    /// Împarte rapoartele pe firmă (fără diacritice / case). Fiecare grup = un Excel separat.
    static func groupsByFirma(
        from reports: [ZReportData],
        config: ZettaNCConfig? = nil,
        namingStyle: ExcelExportNamingStyle = .accountingNote,
        companyDisplayName: String? = nil,
        startingNrInreg: Int = 1
    ) -> [FirmExportGroup] {
        var order: [String] = []
        var buckets: [String: (display: String, reports: [ZReportData])] = [:]

        for report in reports.sortedForExport() {
            let display = FirmaRegistry.displayName(for: report)
            let key = FirmaRegistry.groupingKey(for: report)
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = (display, [])
            }
            buckets[key]?.reports.append(report)
        }

        return order.compactMap { key in
            guard let bucket = buckets[key] else { return nil }
            return FirmExportGroup(
                id: key,
                displayName: bucket.display,
                reports: bucket.reports,
                config: config,
                namingStyle: namingStyle,
                companyDisplayName: companyDisplayName,
                startingNrInreg: startingNrInreg
            )
        }
    }

    /// `NC_<Firma>_<CUI>_<yyyy-MM-dd>.xlsx` sau interval; utilitar → `ZETTA - <Firma> - <perioadă>.xlsx`.
    static func suggestedFileName(
        for reports: [ZReportData],
        style: ExcelExportNamingStyle = .accountingNote,
        companyDisplayName: String? = nil
    ) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let sorted = reports.sortedForExport()
        let datePart = dateRangePart(from: sorted, formatter: f)
        let explicitFirm = companyDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !explicitFirm.isEmpty {
            let firmPart = sanitizeFileNameComponent(explicitFirm)
            switch style {
            case .accountingNote:
                let cuiPart = sanitizeCUIComponent(companyCUI(for: sorted))
                return "NC_\(firmPart)_\(cuiPart)_\(datePart).xlsx"
            case .zettaUtility:
                return "ZETTA - \(firmPart) - \(datePart).xlsx"
            }
        }

        let groups = groupsByFirma(from: sorted, namingStyle: style, companyDisplayName: companyDisplayName)

        if groups.count == 1, let only = groups.first {
            let firmPart = sanitizeFileNameComponent(companyDisplayName ?? companyName(for: only.reports))
            switch style {
            case .accountingNote:
                let cuiPart = sanitizeCUIComponent(companyCUI(for: only.reports))
                return "NC_\(firmPart)_\(cuiPart)_\(datePart).xlsx"
            case .zettaUtility:
                return "ZETTA - \(firmPart) - \(datePart).xlsx"
            }
        }

        switch style {
        case .accountingNote:
            return "NC_Export_\(datePart).xlsx"
        case .zettaUtility:
            return "ZETTA - Export - \(datePart).xlsx"
        }
    }

    struct NCFileNameInfo: Equatable {
        let firmName: String
        let cui: String
    }

    /// Extrage numele firmei și CUI-ul din denumirea `NC_<Firma>_<CUI>_<dată>.xlsx`.
    static func parseNCFileName(_ fileName: String) -> NCFileNameInfo? {
        let base = fileName.lowercased().hasSuffix(".xlsx")
            ? String(fileName.dropLast(5))
            : fileName
        guard base.hasPrefix("NC_") else { return nil }
        let body = String(base.dropFirst(3))
        guard let beforeDate = stripDateSuffix(from: body), !beforeDate.isEmpty else { return nil }
        guard let lastUnderscore = beforeDate.lastIndex(of: "_") else { return nil }

        let cuiCandidate = String(beforeDate[beforeDate.index(after: lastUnderscore)...])
        guard cuiCandidate.allSatisfy(\.isNumber),
              (6...10).contains(cuiCandidate.count) else { return nil }

        let firmPart = String(beforeDate[..<lastUnderscore])
        guard !firmPart.isEmpty, firmPart != "Export" else { return nil }

        let firmName = firmPart
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return NCFileNameInfo(firmName: firmName, cui: cuiCandidate)
    }

    private static func dateRangePart(from reports: [ZReportData], formatter: DateFormatter) -> String {
        let days = Set(reports.map { Calendar.current.startOfDay(for: $0.date) }).sorted()
        if days.count == 1, let only = days.first {
            return formatter.string(from: only)
        }
        if let first = days.first, let last = days.last, days.count > 1 {
            return "\(formatter.string(from: first))_\(formatter.string(from: last))"
        }
        return formatter.string(from: Date())
    }

    private static func stripDateSuffix(from body: String) -> String? {
        if let range = body.range(
            of: #"_\d{4}-\d{2}-\d{2}_\d{4}-\d{2}-\d{2}$"#,
            options: .regularExpression
        ) {
            return String(body[..<range.lowerBound])
        }
        if let range = body.range(
            of: #"_\d{4}-\d{2}-\d{2}$"#,
            options: .regularExpression
        ) {
            return String(body[..<range.lowerBound])
        }
        return nil
    }

    private static func companyCUI(for reports: [ZReportData]) -> String {
        for report in reports {
            if let profile = FirmaRegistry.profile(for: report) {
                return profile.cui
            }
            if let normalized = FirmaRegistry.normalizeCUI(report.cui) {
                return normalized
            }
        }
        return "00000000"
    }

    private static func sanitizeCUIComponent(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        if (6...10).contains(digits.count) { return digits }
        return "00000000"
    }

    private static func companyName(for reports: [ZReportData]) -> String {
        for report in reports {
            let name = report.firma.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        return "Firma"
    }

    private static func normalizedFirmaDisplay(_ raw: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Firma" : name
    }

    private static func firmaGroupingKey(_ displayName: String) -> String {
        displayName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private static func sanitizeFileNameComponent(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:.\n\t")
        var cleaned = raw
            .components(separatedBy: invalid)
            .joined(separator: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        while cleaned.contains("__") {
            cleaned = cleaned.replacingOccurrences(of: "__", with: "_")
        }
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "_+"))
        if cleaned.isEmpty { return "Firma" }
        if cleaned.count > 80 {
            return String(cleaned.prefix(80))
        }
        return cleaned
    }

    // MARK: - Sheet

    private static func buildSheetXML(rows: [NotaContabilaRow]) -> String {
        let lastRow = max(rows.count + 1, 1)
        let usesFirmCUI = rows.contains { !$0.firmCUI.isEmpty }
        let lastColIndex = usesFirmCUI
            ? max(headers.count - 1, firmCUIColumnIndex)
            : headers.count - 1
        let lastCol = cellRef(col: lastColIndex, row: 1)
            .filter { $0.isLetter }
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <dimension ref="A1:\(lastCol)\(lastRow)"/>
        <sheetData>
        """
        xml += rowXML(index: 1, values: headers.map { .text($0) }, bold: true)

        for (i, row) in rows.enumerated() {
            let cui = row.firmCUI.trimmingCharacters(in: .whitespacesAndNewlines)
            xml += rowXML(
                index: i + 2,
                values: cells(for: row),
                bold: false,
                firmCUI: cui.isEmpty ? nil : cui
            )
        }

        xml += "</sheetData></worksheet>"
        return xml
    }

    /// Completează doar coloanele din modelul de notă contabilă; restul rămân goale.
    private static func cells(for row: NotaContabilaRow) -> [CellValue] {
        var values = Array(repeating: CellValue.empty, count: headers.count)

        func set(_ index: Int, _ value: CellValue) {
            values[index] = value
        }

        set(0, .number(Decimal(row.nrInreg)))               // Nr. inreg. (același pe cele 10 linii)
        set(1, .text("Bon fiscal vanzare"))                 // Tip inregistrare
        set(2, .text(row.jurnal))                           // Jurnal
        set(3, .number(Decimal(row.dataYYYYMMDD)))          // Data
        set(4, .number(Decimal(row.dataYYYYMMDD)))          // Data scadenta
        set(5, .text(row.numarDocument))                    // Numar document
        set(7, .text(row.contDebit))                        // Cont debit simbol
        set(8, .text(row.titluDebit))                       // Cont debit titlu
        set(13, .text(row.contCredit))                      // Cont credit simbol
        set(14, .text(row.titluCredit))                     // Cont credit titlu
        if !row.explicatie.isEmpty { set(19, .text(row.explicatie)) }
        set(20, .number(row.valoare))                       // Valoare
        if !row.codPartener.isEmpty { set(21, .text(row.codPartener)) }
        if !row.partenerNume.isEmpty { set(23, .text(row.partenerNume)) }

        // Partener Cont: D dacă 4111 e la debit, C dacă e la credit, altfel gol
        if isClientiAccount(row.contDebit) {
            set(26, .text("D"))
        } else if isClientiAccount(row.contCredit) {
            set(26, .text("C"))
        }

        if !row.angajatCNP.isEmpty { set(27, .text(row.angajatCNP)) }
        if !row.angajatNume.isEmpty { set(28, .text(row.angajatNume)) }
        if !row.optiuneTva.isEmpty { set(30, .text(row.optiuneTva)) }
        if let cota = row.cotaTva { set(31, .number(cota)) }
        if !row.codTvaSaft.isEmpty { set(32, .text(row.codTvaSaft)) }
        if !row.moneda.isEmpty { set(33, .text(row.moneda)) }

        set(39, .number(0))                                 // TVA la incasare
        set(44, .text("20230601-20230630-CielStd_CodSoc"))  // Informatii export
        set(48, .number(0))                                 // Factura simplificata
        set(49, .number(0))                                 // Borderou de achizitie
        set(50, .number(0))                                 // Carnet prod. Agricole
        set(51, .number(0))                                 // Contract
        set(52, .number(0))                                 // Document stornat

        return values
    }

    private static func isClientiAccount(_ simbol: String) -> Bool {
        let s = simbol.trimmingCharacters(in: .whitespaces)
        return s == "4111" || s.hasPrefix("4111.")
    }

    private enum CellValue {
        case empty
        case text(String)
        case number(Decimal)
    }

    private static func rowXML(index: Int, values: [CellValue], bold: Bool, firmCUI: String? = nil) -> String {
        var cells = ""
        for (c, value) in values.enumerated() {
            let ref = cellRef(col: c, row: index)
            let style = bold ? #" s="1""# : ""
            switch value {
            case .empty:
                // Celulă goală — păstrează structura coloanei
                cells += #"<c r="\#(ref)" t="inlineStr"\#(style)><is><t></t></is></c>"#
            case .text(let s):
                let escaped = xmlEscape(s)
                cells += #"<c r="\#(ref)" t="inlineStr"\#(style)><is><t>\#(escaped)</t></is></c>"#
            case .number(let n):
                let num = NSDecimalNumber(decimal: n).stringValue
                cells += #"<c r="\#(ref)"\#(style)><v>\#(num)</v></c>"#
            }
        }
        if let cui = firmCUI, !cui.isEmpty {
            let ref = cellRef(col: firmCUIColumnIndex, row: index)
            let style = bold ? #" s="1""# : ""
            let escaped = xmlEscape(cui)
            cells += #"<c r="\#(ref)" t="inlineStr"\#(style)><is><t>\#(escaped)</t></is></c>"#
        }
        return "<row r=\"\(index)\">\(cells)</row>"
    }

    private static func cellRef(col: Int, row: Int) -> String {
        var name = ""
        var n = col + 1
        while n > 0 {
            let rem = (n - 1) % 26
            name = String(UnicodeScalar(65 + rem)!) + name
            n = (n - 1) / 26
        }
        return "\(name)\(row)"
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    </Types>
    """

    private static let relsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """

    private static let workbookXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets>
        <sheet name="NoteContabile.xls" sheetId="1" r:id="rId1"/>
      </sheets>
    </workbook>
    """

    private static let workbookRelsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <fonts count="2">
        <font><sz val="11"/><name val="Calibri"/></font>
        <font><b/><sz val="11"/><name val="Calibri"/></font>
      </fonts>
      <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
      <borders count="1"><border/></borders>
      <cellStyleXfs count="1"><xf/></cellStyleXfs>
      <cellXfs count="2">
        <xf fontId="0" fillId="0" borderId="0"/>
        <xf fontId="1" fillId="0" borderId="0" applyFont="1"/>
      </cellXfs>
    </styleSheet>
    """
}

// MARK: - Minimal ZIP writer (store + deflate)

enum ZipWriter {
    static func create(files: [String: Data]) throws -> Data {
        var central = Data()
        var local = Data()
        var offset: UInt32 = 0

        for (name, content) in files.sorted(by: { $0.key < $1.key }) {
            let nameData = Data(name.utf8)
            let crc = crc32(content)
            let compressed = deflate(content) ?? content
            let useDeflate = compressed.count < content.count
            let payload = useDeflate ? compressed : content
            let method: UInt16 = useDeflate ? 8 : 0

            var localHeader = Data()
            localHeader.append(contentsOf: UInt32(0x04034b50).leBytes)
            localHeader.append(contentsOf: UInt16(20).leBytes)
            localHeader.append(contentsOf: UInt16(0).leBytes)
            localHeader.append(contentsOf: method.leBytes)
            localHeader.append(contentsOf: UInt16(0).leBytes)
            localHeader.append(contentsOf: UInt16(0).leBytes)
            localHeader.append(contentsOf: crc.leBytes)
            localHeader.append(contentsOf: UInt32(payload.count).leBytes)
            localHeader.append(contentsOf: UInt32(content.count).leBytes)
            localHeader.append(contentsOf: UInt16(nameData.count).leBytes)
            localHeader.append(contentsOf: UInt16(0).leBytes)
            localHeader.append(nameData)
            localHeader.append(payload)

            var centralHeader = Data()
            centralHeader.append(contentsOf: UInt32(0x02014b50).leBytes)
            centralHeader.append(contentsOf: UInt16(20).leBytes)
            centralHeader.append(contentsOf: UInt16(20).leBytes)
            centralHeader.append(contentsOf: UInt16(0).leBytes)
            centralHeader.append(contentsOf: method.leBytes)
            centralHeader.append(contentsOf: UInt16(0).leBytes)
            centralHeader.append(contentsOf: UInt16(0).leBytes)
            centralHeader.append(contentsOf: crc.leBytes)
            centralHeader.append(contentsOf: UInt32(payload.count).leBytes)
            centralHeader.append(contentsOf: UInt32(content.count).leBytes)
            centralHeader.append(contentsOf: UInt16(nameData.count).leBytes)
            centralHeader.append(contentsOf: UInt16(0).leBytes)
            centralHeader.append(contentsOf: UInt16(0).leBytes)
            centralHeader.append(contentsOf: UInt16(0).leBytes)
            centralHeader.append(contentsOf: UInt16(0).leBytes)
            centralHeader.append(contentsOf: UInt32(0).leBytes)
            centralHeader.append(contentsOf: offset.leBytes)
            centralHeader.append(nameData)

            offset += UInt32(localHeader.count)
            local.append(localHeader)
            central.append(centralHeader)
        }

        let centralOffset = UInt32(local.count)
        let centralSize = UInt32(central.count)
        var end = Data()
        end.append(contentsOf: UInt32(0x06054b50).leBytes)
        end.append(contentsOf: UInt16(0).leBytes)
        end.append(contentsOf: UInt16(0).leBytes)
        end.append(contentsOf: UInt16(files.count).leBytes)
        end.append(contentsOf: UInt16(files.count).leBytes)
        end.append(contentsOf: centralSize.leBytes)
        end.append(contentsOf: centralOffset.leBytes)
        end.append(contentsOf: UInt16(0).leBytes)

        var result = Data()
        result.append(local)
        result.append(central)
        result.append(end)
        return result
    }

    private static func deflate(_ data: Data) -> Data? {
        data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Data? in
            guard let base = src.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let destSize = data.count + data.count / 10 + 64
            var dest = Data(count: destSize)
            let written = dest.withUnsafeMutableBytes { destBuf -> Int in
                guard let destBase = destBuf.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_encode_buffer(
                    destBase, destSize,
                    base, data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
            // ZIP needs raw deflate (no zlib wrapper). compression_encode_buffer with ZLIB
            // adds zlib header — use STORE if we can't strip reliably.
            // Prefer STORE for simplicity/reliability.
            _ = written
            return nil
        }
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ crcTable[idx]
        }
        return crc ^ 0xffffffff
    }

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xedb88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()
}

private extension FixedWidthInteger {
    var leBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian, Array.init)
    }
}
