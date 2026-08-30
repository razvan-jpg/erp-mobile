import Foundation

enum StockSheetXLSBuilder {
    static func writeTemporaryXLS(from snapshot: StockSheetSnapshot) throws -> URL {
        try write(content: makeDetailSpreadsheet(from: snapshot), fileName: "Fisa-stoc-\(sanitized(snapshot.product.denumire))")
    }

    static func writeTemporaryListingXLS(from snapshot: StockSheetListingSnapshot) throws -> URL {
        try write(content: makeListingSpreadsheet(from: snapshot), fileName: "Fisa-stoc-lista")
    }

    private static func write(content: String, fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName)-\(UUID().uuidString.prefix(8)).xls")
        guard let data = content.data(using: .utf8) else { throw ServiceError.invalidResponse }
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func makeListingSpreadsheet(from snapshot: StockSheetListingSnapshot) -> String {
        var rows: [String] = []
        rows.append(dataRow([stringCell(snapshot.company?.denumire ?? L10n.tr("common.unknown_company"))], style: "Title"))
        rows.append(dataRow([
            stringCell(L10n.tr("stock_sheet.title")),
            stringCell(L10n.tr("account.listing_date")),
            stringCell(SupplierFormatting.date(snapshot.generatedAt))
        ], style: "Title"))
        rows.append(emptyRow())
        rows.append(dataRow([
            stringCell(L10n.tr("stock_sheet.col_no")),
            stringCell(L10n.tr("stock_sheet.col_name")),
            stringCell(L10n.tr("stock_sheet.col_unit")),
            stringCell(L10n.tr("stock_sheet.col_quantity")),
            stringCell(L10n.tr("stock_sheet.col_avg_cost")),
            stringCell(L10n.tr("stock_sheet.col_value"))
        ], style: "Header"))

        if snapshot.rows.isEmpty {
            rows.append(dataRow([stringCell(L10n.tr("stock_sheet.empty"))]))
        } else {
            for (index, row) in snapshot.rows.enumerated() {
                rows.append(dataRow([
                    numberCell(Decimal(index + 1)),
                    stringCell(row.product.denumire),
                    stringCell(row.unit),
                    numberCell(row.cantitate),
                    row.pretMediu.map { numberCell($0, currency: "RON") } ?? stringCell("—"),
                    numberCell(row.valoare, currency: "RON")
                ]))
            }
        }
        rows.append(dataRow([
            stringCell(""),
            stringCell(L10n.tr("stock_sheet.total")),
            stringCell(""),
            stringCell(""),
            stringCell(""),
            numberCell(snapshot.totalValue, currency: "RON")
        ], style: "Header"))
        return workbook(sheetName: L10n.tr("stock_sheet.title"), rows: rows)
    }

    private static func makeDetailSpreadsheet(from snapshot: StockSheetSnapshot) -> String {
        var rows: [String] = []
        rows.append(dataRow([stringCell(snapshot.company?.denumire ?? L10n.tr("common.unknown_company"))], style: "Title"))
        rows.append(dataRow([stringCell(L10n.tr("stock_sheet.detail_title"))], style: "Title"))
        rows.append(dataRow([stringCell(snapshot.product.denumire)], style: "Title"))
        rows.append(dataRow([
            stringCell(L10n.tr("inventory.field_quantity")),
            numberCell(snapshot.cantitate)
        ]))
        rows.append(dataRow([
            stringCell(L10n.tr("inventory.weighted_average_cost")),
            snapshot.pretMediu.map { numberCell($0, currency: "RON") } ?? stringCell("—")
        ]))
        rows.append(dataRow([
            stringCell(L10n.tr("stock_sheet.col_value")),
            numberCell(snapshot.valoare, currency: "RON")
        ]))
        rows.append(emptyRow())
        rows.append(dataRow([
            stringCell(L10n.tr("stock_sheet.col_date")),
            stringCell(L10n.tr("stock_sheet.col_document")),
            stringCell(L10n.tr("stock_sheet.col_in_qty")),
            stringCell(L10n.tr("stock_sheet.col_in_value")),
            stringCell(L10n.tr("stock_sheet.col_out_qty")),
            stringCell(L10n.tr("stock_sheet.col_out_value")),
            stringCell(L10n.tr("stock_sheet.col_stock_qty")),
            stringCell(L10n.tr("stock_sheet.col_stock_value"))
        ], style: "Header"))

        if snapshot.entries.isEmpty {
            rows.append(dataRow([stringCell(L10n.tr("stock_sheet.ledger_empty"))]))
        } else {
            for entry in snapshot.entries {
                rows.append(dataRow([
                    stringCell(SupplierFormatting.compactDate(entry.dataTranzactie)),
                    stringCell(entry.numarDocument),
                    numberCell(entry.cantitateIntrare),
                    numberCell(entry.valoareIntrare, currency: "RON"),
                    numberCell(entry.cantitateIesire),
                    numberCell(entry.valoareIesire, currency: "RON"),
                    numberCell(entry.stocCantitate),
                    numberCell(entry.stocValoare, currency: "RON")
                ]))
            }
        }
        return workbook(sheetName: L10n.tr("stock_sheet.detail_title"), rows: rows)
    }

    private static func workbook(sheetName: String, rows: [String]) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
         xmlns:o="urn:schemas-microsoft-com:office:office"
         xmlns:x="urn:schemas-microsoft-com:office:excel"
         xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
         <Styles>
          <Style ss:ID="Default" ss:Name="Normal">
           <Alignment ss:Vertical="Top" ss:WrapText="1"/>
           <Font ss:FontName="Calibri" ss:Size="11"/>
          </Style>
          <Style ss:ID="Title">
           <Font ss:FontName="Calibri" ss:Size="14" ss:Bold="1"/>
          </Style>
          <Style ss:ID="Header">
           <Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/>
           <Interior ss:Color="#E8E8E8" ss:Pattern="Solid"/>
          </Style>
          <Style ss:ID="Amount">
           <NumberFormat ss:Format="#,##0.00"/>
           <Alignment ss:Horizontal="Right"/>
          </Style>
         </Styles>
         <Worksheet ss:Name="\(escapeXML(sheetName))">
          <Table>
           \(rows.joined(separator: "\n"))
          </Table>
         </Worksheet>
        </Workbook>
        """
    }

    private static func dataRow(_ cells: [String], style: String? = nil) -> String {
        let styleAttr = style.map { " ss:StyleID=\"\($0)\"" } ?? ""
        return "<Row\(styleAttr)>\(cells.joined())</Row>"
    }

    private static func emptyRow() -> String {
        "<Row><Cell ss:Index=\"1\"><Data ss:Type=\"String\"></Data></Cell></Row>"
    }

    private static func stringCell(_ value: String) -> String {
        "<Cell><Data ss:Type=\"String\">\(escapeXML(value))</Data></Cell>"
    }

    private static func numberCell(_ value: Decimal, currency: String? = nil) -> String {
        let style = currency == nil ? "" : " ss:StyleID=\"Amount\""
        return "<Cell\(style)><Data ss:Type=\"Number\">\(NSDecimalNumber(decimal: value).stringValue)</Data></Cell>"
    }

    private static func sanitized(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
    }

    private static func escapeXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
