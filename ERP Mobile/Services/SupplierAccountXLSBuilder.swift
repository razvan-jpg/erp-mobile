import Foundation

enum SupplierAccountXLSBuilder {
    static func writeTemporaryXLS(from snapshot: SupplierAccountSnapshot) throws -> URL {
        let content = makeSpreadsheetML(from: snapshot)
        let safeName = sanitizedFileName(snapshot.supplier.denumire)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Fisa-\(safeName)-\(UUID().uuidString.prefix(8)).xls")
        guard let data = content.data(using: .utf8) else {
            throw ServiceError.invalidResponse
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func makeSpreadsheetML(from snapshot: SupplierAccountSnapshot) -> String {
        let supplier = snapshot.supplier
        var rows: [String] = []

        let listingDate = SupplierFormatting.date(snapshot.generatedAt)
        if let company = snapshot.company {
            rows.append(dataRow([
                stringCell(company.denumire),
                stringCell(L10n.tr("account.listing_date")),
                stringCell(listingDate)
            ], style: "Title"))
            for line in [
                labeledLine(L10n.tr("common.cui"), company.cui),
                labeledLine(L10n.tr("common.field_nr_reg_com"), company.nrRegCom),
                labeledLine(L10n.tr("common.field_address"), company.adresa),
                labeledLine(L10n.tr("common.field_iban"), company.iban),
                labeledLine(L10n.tr("common.field_email"), company.email),
                labeledLine(L10n.tr("common.field_phone"), company.telefon)
            ].compactMap(\.self) {
                rows.append(dataRow([stringCell(line), stringCell(""), stringCell("")]))
            }
        } else {
            rows.append(dataRow([
                stringCell(L10n.tr("common.unknown_company")),
                stringCell(L10n.tr("account.listing_date")),
                stringCell(listingDate)
            ], style: "Title"))
        }
        rows.append(emptyRow())

        rows.append(dataRow([stringCell(L10n.tr("account.supplier_sheet"))], style: "Title"))
        rows.append(dataRow([stringCell(supplier.denumire)], style: "Title"))
        rows.append(dataRow([
            stringCell(L10n.tr("account.outstanding_balance")),
            numberCell(snapshot.soldRestant, currency: snapshot.moneda)
        ]))
        rows.append(dataRow([
            stringCell(L10n.tr("account.first_due_date")),
            stringCell(SupplierFormatting.date(snapshot.primaScadenta))
        ]))
        rows.append(emptyRow())

        rows.append(dataRow([stringCell(L10n.tr("account.supplier_data"))], style: "Section"))
        rows.append(dataRow([
            stringCell(L10n.tr("account.partner_role_label")),
            stringCell(snapshot.partnerRole.displayLabel)
        ]))
        rows.append(dataRow([stringCell(L10n.tr("common.cui")), stringCell(value(supplier.cui))]))
        rows.append(dataRow([stringCell(L10n.tr("common.field_nr_reg_com")), stringCell(value(supplier.nrRegCom))]))
        rows.append(dataRow([stringCell(L10n.tr("common.field_address")), stringCell(value(supplier.adresa))]))
        rows.append(dataRow([stringCell(L10n.tr("common.field_iban")), stringCell(value(supplier.iban))]))
        rows.append(dataRow([stringCell(L10n.tr("common.field_email")), stringCell(value(supplier.email))]))
        rows.append(dataRow([stringCell(L10n.tr("common.field_phone")), stringCell(value(supplier.telefon))]))
        rows.append(dataRow([
            stringCell(L10n.tr("suppliers.field_payment_term_days")),
            stringCell(supplier.nrZileScadenta > 0 ? String(supplier.nrZileScadenta) : "0")
        ]))
        rows.append(dataRow([
            stringCell(L10n.tr("common.field_status")),
            stringCell(supplier.isActive ? L10n.tr("common.active") : L10n.tr("common.inactive"))
        ]))
        rows.append(emptyRow())

        rows.append(dataRow([
            stringCell(L10n.tr("account.table_no")),
            stringCell(L10n.tr("account.table_doc_type")),
            stringCell(L10n.tr("account.table_doc_number")),
            stringCell(L10n.tr("account.table_doc_date")),
            stringCell(L10n.tr("account.table_due_date")),
            stringCell(L10n.tr("account.table_amount")),
            stringCell(L10n.tr("account.table_invoice_balance")),
            stringCell(L10n.tr("account.table_final_balance")),
            stringCell(L10n.tr("account.table_overdue_days")),
            stringCell(L10n.tr("account.table_invoice_status"))
        ], style: "Header"))

        if snapshot.ledgerEntries.isEmpty {
            rows.append(dataRow([stringCell(L10n.tr("common.no_records"))]))
        } else {
            for entry in snapshot.ledgerEntries {
                rows.append(dataRow([
                    numberCell(Decimal(entry.nrCrt)),
                    stringCell(entry.tipDocument),
                    stringCell(entry.nrDocument),
                    stringCell(SupplierFormatting.date(entry.dataDocument)),
                    stringCell(entry.dataScadenta.map { SupplierFormatting.date($0) } ?? ""),
                    numberCell(entry.isInvoice ? entry.suma : -entry.suma, currency: snapshot.moneda),
                    entry.soldFactura.map { numberCell($0, currency: snapshot.moneda) } ?? stringCell(""),
                    entry.soldFinal.map { numberCell($0, currency: snapshot.moneda) } ?? stringCell(""),
                    stringCell(entry.zileIntarziereDisplay),
                    stringCell(entry.statusDisplay)
                ]))
            }
        }

        return """
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
          <Style ss:ID="Section">
           <Font ss:FontName="Calibri" ss:Size="12" ss:Bold="1"/>
          </Style>
          <Style ss:ID="Header">
           <Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/>
           <Interior ss:Color="#E8E8E8" ss:Pattern="Solid"/>
           <Borders>
            <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
            <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
            <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
            <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
           </Borders>
          </Style>
          <Style ss:ID="Amount">
           <NumberFormat ss:Format="#,##0.00"/>
           <Alignment ss:Horizontal="Right"/>
          </Style>
         </Styles>
         <Worksheet ss:Name="\(escapeXML(L10n.tr("account.title")))">
          <Table>
           <Column ss:Width="72"/>
           <Column ss:Width="72"/>
           <Column ss:Width="72"/>
           <Column ss:Width="72"/>
           <Column ss:Width="72"/>
           <Column ss:Width="72"/>
           <Column ss:Width="72"/>
           <Column ss:Width="72"/>
           <Column ss:Width="60"/>
           <Column ss:Width="160"/>
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
        return "<Cell\(style)><Data ss:Type=\"Number\">\(decimalString(value))</Data></Cell>"
    }

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func labeledLine(_ label: String, _ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : L10n.tr("common.detail_line", label, text)
    }

    private static func value(_ text: String?) -> String {
        text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func sanitizedFileName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "/", with: "-")
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
