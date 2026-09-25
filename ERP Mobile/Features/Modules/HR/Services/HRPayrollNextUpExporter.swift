import Foundation

enum HRPayrollNextUpExporter {
    static let headers: [String] = [
        "Numar inregistrare",
        "Jurnal",
        "Data",
        "Data Scadenta",
        "Numar Document",
        "Cont",
        "Explicatie",
        "Valoare",
        "Debit/credit",
        "Marca",
        "Cod Buget",
        "Titlu Cont",
        "Deviza-Cod deviza",
        "Deviza-valoare debit in deviza",
        "Deviza-valoare credti in deviza",
        "Deviza - valoare in deviza",
        "Partener- Cod fiscal",
        "Partener - Partener",
        "Denumire buget",
        "Optiune Tva",
        "Cod Auxiliar"
    ]

    static func fileName(company: Company, period: HRMonthPeriod) -> String {
        let firm = sanitize(company.denumire)
        return "Salarii_\(firm)_\(period.year)-\(String(format: "%02d", period.month)).xlsx"
    }

    static func export(entries: [HRJournalEntry], to url: URL) throws {
        let files: [String: Data] = [
            "[Content_Types].xml": Data(contentTypesXML.utf8),
            "_rels/.rels": Data(relsXML.utf8),
            "xl/workbook.xml": Data(workbookXML.utf8),
            "xl/_rels/workbook.xml.rels": Data(workbookRelsXML.utf8),
            "xl/styles.xml": Data(stylesXML.utf8),
            "xl/worksheets/sheet1.xml": Data(sheetXML(entries: entries).utf8)
        ]
        try ZipWriter.create(files: files).write(to: url, options: .atomic)
    }

    static func writeTemporary(entries: [HRJournalEntry], company: Company, period: HRMonthPeriod) throws -> URL {
        try writeTemporary(entries: entries, fileName: fileName(company: company, period: period))
    }

    static func writeTemporary(entries: [HRJournalEntry], fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try export(entries: entries, to: url)
        return url
    }

    private static func sheetXML(entries: [HRJournalEntry]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>
        """
        xml += rowXML(index: 1, values: headers.map { .text($0) }, bold: true)
        for (index, entry) in entries.enumerated() {
            xml += rowXML(index: index + 2, values: cells(for: entry), bold: false)
        }
        xml += "</sheetData></worksheet>"
        return xml
    }

    private static func cells(for entry: HRJournalEntry) -> [CellValue] {
        [
            .number(Decimal(entry.number)),
            .text(entry.journal),
            .number(Decimal(entry.dateYYYYMMDD)),
            .number(Decimal(entry.dateYYYYMMDD)),
            .text(entry.documentNumber),
            .text(entry.account),
            .text(entry.explanation),
            .number(entry.amount),
            .text(entry.debitCredit),
            .text(entry.employeeCode),
            .empty,
            .text(entry.accountTitle),
            .empty, .empty, .empty, .empty,
            .empty,
            .empty,
            .empty, .empty, .empty
        ]
    }

    private enum CellValue {
        case empty
        case text(String)
        case number(Decimal)
    }

    private static func rowXML(index: Int, values: [CellValue], bold: Bool) -> String {
        var cells = ""
        for (column, value) in values.enumerated() {
            let ref = cellRef(col: column, row: index)
            let style = bold ? #" s="1""# : ""
            switch value {
            case .empty:
                cells += #"<c r="\#(ref)" t="inlineStr"\#(style)><is><t></t></is></c>"#
            case .text(let text):
                cells += #"<c r="\#(ref)" t="inlineStr"\#(style)><is><t>\#(xmlEscape(text))</t></is></c>"#
            case .number(let number):
                cells += #"<c r="\#(ref)"\#(style)><v>\#(NSDecimalNumber(decimal: number).stringValue)</v></c>"#
            }
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

    private static func xmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func sanitize(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:.\n\t")
        let cleaned = raw.components(separatedBy: invalid).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        return cleaned.isEmpty ? "Firma" : cleaned
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
        <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
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
