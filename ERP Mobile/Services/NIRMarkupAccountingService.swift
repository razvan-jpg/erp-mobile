import Foundation

enum NIRMarkupAccountingService {
    static func buildReport(companyId: UUID, month: Date) async throws -> NIRMarkupAccountingReport {
        let monthStart = SupplierFormatting.startOfMonth(for: month)
        let allRows = try await SupplierNIRService.fetchNIRRows(companyId: companyId)
        let rows = allRows
            .filter { SupplierFormatting.isInMonth($0.dataNir, month: monthStart) }
            .sorted { lhs, rhs in
                if lhs.dataNir != rhs.dataNir {
                    return lhs.dataNir < rhs.dataNir
                }
                return lhs.numarNir.localizedStandardCompare(rhs.numarNir) == .orderedAscending
            }

        let products = try await ProductService.fetchProducts(companyId: companyId)
        let productsById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        var entries: [NIRMarkupAccountingEntry] = []
        entries.reserveCapacity(rows.count)

        for row in rows {
            let nirLines = try await SupplierNIRService.fetchNIRLines(nirId: row.id)
            let totals = SupplierNIRService.computeMarkupTotals(
                nirLines: nirLines,
                productsById: productsById,
                allProducts: products
            )
            entries.append(
                NIRMarkupAccountingEntry(
                    id: row.id,
                    numarNir: row.numarNir,
                    dataNir: row.dataNir,
                    invoiceNumber: row.invoiceNumber,
                    supplierName: row.supplierName,
                    adaosSuma: totals.adaosSuma,
                    tvaAfAdeaos: totals.tvaAfAdeaos
                )
            )
        }

        let adaosSuma = entries.reduce(Decimal.zero) { $0 + $1.adaosSuma }
        let tvaAfAdeaos = entries.reduce(Decimal.zero) { $0 + $1.tvaAfAdeaos }

        return NIRMarkupAccountingReport(
            month: monthStart,
            entries: entries,
            adaosSuma: SupplierFormatting.roundAmount(adaosSuma),
            tvaAfAdeaos: SupplierFormatting.roundAmount(tvaAfAdeaos)
        )
    }

    static func formattedNote(_ report: NIRMarkupAccountingReport) -> String {
        var lines = [
            L10n.tr("nir.markup_accounting_note_title"),
            L10n.tr("nir.markup_accounting_month_label", SupplierFormatting.monthYear(report.month)),
            "",
            accountingLine(debit: "371", credit: "378", amount: report.adaosSuma),
            accountingLine(debit: "371", credit: "4428", amount: report.tvaAfAdeaos)
        ]

        if !report.entries.isEmpty {
            lines.append("")
            lines.append(L10n.tr("nir.markup_accounting_included_nirs", report.entries.count))
            for entry in report.entries {
                lines.append(
                    L10n.tr(
                        "nir.markup_accounting_entry_line",
                        entry.numarNir,
                        SupplierFormatting.date(entry.dataNir),
                        entry.invoiceNumber,
                        SupplierFormatting.amountString(entry.adaosSuma),
                        SupplierFormatting.amountString(entry.tvaAfAdeaos)
                    )
                )
            }
        }

        return lines.joined(separator: "\n")
    }

    static func writeTemporaryListing(from report: NIRMarkupAccountingReport) throws -> URL {
        let fileName = exportListingFileName(for: report.month)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try formattedNote(report).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func exportListingFileName(for month: Date) -> String {
        let monthLabel = SupplierFormatting.monthYear(month)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "Nota-Adaos-\(monthLabel).txt"
    }

    private static func accountingLine(debit: String, credit: String, amount: Decimal) -> String {
        L10n.tr(
            "nir.markup_accounting_line",
            debit,
            credit,
            SupplierFormatting.amountString(amount)
        )
    }
}
