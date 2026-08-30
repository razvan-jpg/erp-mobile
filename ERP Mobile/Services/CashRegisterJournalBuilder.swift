import Foundation

enum CashRegisterJournalBuilder {
    struct Context: Sendable {
        let company: Company
        let settings: ZettaSettingsPayload
        let workLocations: [CompanyWorkLocation]
        let zReports: [CompanyZReportRecord]
        let manualEntries: [CashRegisterManualEntry]
        let supplierCashPayments: [SupplierPaymentRow]
    }

    static func build(
        context: Context,
        from startDate: Date,
        to endDate: Date
    ) -> [CashRegisterDailyJournal] {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else { return [] }

        let buildStart = min(start, earliestOperationDay(in: context, calendar: calendar, fallback: start))
        let casas = activeCasas(settings: context.settings, locations: context.workLocations)
        var pages: [CashRegisterDailyJournal] = []
        var closingByCasaDay: [String: Decimal] = [:]

        var day = buildStart
        while day <= end {
            for casa in casas {
                if let page = buildDailyPage(
                    context: context,
                    date: day,
                    casa: casa,
                    closingByCasaDay: closingByCasaDay
                ) {
                    pages.append(page)
                    closingByCasaDay[balanceKey(casa: casa, date: day)] = page.closingBalance
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return assignPageNumbers(
            pages.filter { calendar.startOfDay(for: $0.date) >= start }
        )
    }

    private static func earliestOperationDay(
        in context: Context,
        calendar: Calendar,
        fallback: Date
    ) -> Date {
        var dates: [Date] = []
        dates.append(contentsOf: context.zReports.map(\.accountingDate))
        dates.append(contentsOf: context.manualEntries.map(\.date))
        dates.append(contentsOf: context.supplierCashPayments.map(\.dataPlata))
        guard let earliest = dates.map({ calendar.startOfDay(for: $0) }).min() else { return fallback }
        return earliest
    }

    private static func activeCasas(
        settings: ZettaSettingsPayload,
        locations: [CompanyWorkLocation]
    ) -> [CashRegisterCasaTarget] {
        let active = locations.filter(\.isActive)
        if !settings.usesRegistersOnMultipleWorkLocations || active.count <= 1 {
            return [.headquarters]
        }
        return [.headquarters] + active.map { .workLocation($0.id) }
    }

    private static func buildDailyPage(
        context: Context,
        date: Date,
        casa: CashRegisterCasaTarget,
        closingByCasaDay: [String: Decimal]
    ) -> CashRegisterDailyJournal? {
        let calendar = Calendar(identifier: .gregorian)
        let opening = openingBalance(
            for: casa,
            date: date,
            closingByCasaDay: closingByCasaDay,
            calendar: calendar
        )

        var operationLines: [CashRegisterJournalLine] = []
        var row = 1

        func appendLine(
            actCasa: String,
            explanation: String,
            incasari: Decimal? = nil,
            plati: Decimal? = nil
        ) {
            guard row <= 15 else { return }
            operationLines.append(
                CashRegisterJournalLine(
                    rowNumber: row,
                    actCasaNumber: actCasa,
                    explanation: explanation,
                    incasari: incasari,
                    plati: plati
                )
            )
            row += 1
        }

        let zReportsToday = context.zReports.filter {
            calendar.isDate($0.accountingDate, inSameDayAs: date)
        }

        if casa.isHeadquarters {
            for report in zReportsToday where report.numerar > 0 {
                let target = CashRegisterWorkLocationMatcher.match(
                    report: report,
                    locations: context.workLocations
                )
                if target.isHeadquarters {
                    appendLine(
                        actCasa: String(report.zNumber),
                        explanation: L10n.tr("module.cash_register.line_z_incasare", report.zNumber),
                        incasari: report.numerar
                    )
                } else if context.settings.usesRegistersOnMultipleWorkLocations {
                    let locationName = CashRegisterWorkLocationMatcher.displayName(
                        for: target,
                        locations: context.workLocations
                    )
                    appendLine(
                        actCasa: String(report.zNumber),
                        explanation: L10n.tr("module.cash_register.line_transfer_in_sediu", locationName),
                        incasari: report.numerar
                    )
                }
            }
        } else if let locationId = casa.workLocationId() {
            for report in zReportsToday where report.numerar > 0 {
                let target = CashRegisterWorkLocationMatcher.match(
                    report: report,
                    locations: context.workLocations
                )
                guard target.workLocationId() == locationId else { continue }
                appendLine(
                    actCasa: String(report.zNumber),
                    explanation: L10n.tr("module.cash_register.line_z_incasare", report.zNumber),
                    incasari: report.numerar
                )
                if context.settings.usesRegistersOnMultipleWorkLocations {
                    appendLine(
                        actCasa: String(report.zNumber),
                        explanation: L10n.tr("module.cash_register.line_transfer_to_sediu"),
                        plati: report.numerar
                    )
                }
            }
        }

        let manualToday = context.manualEntries.filter {
            calendar.isDate($0.date, inSameDayAs: date) && $0.resolvedCasaTarget() == casa
        }.filter { entry in
            !matchesImportedSupplierPayment(
                entry,
                on: date,
                calendar: calendar,
                payments: context.supplierCashPayments
            )
        }
        for entry in manualToday.sorted(by: { $0.documentNumber < $1.documentNumber }) {
            if entry.kind.isIncasare {
                appendLine(
                    actCasa: entry.documentNumber,
                    explanation: entry.explanation,
                    incasari: entry.amount
                )
            } else {
                appendLine(
                    actCasa: entry.documentNumber,
                    explanation: entry.explanation,
                    plati: entry.amount
                )
            }
        }

        if casa.isHeadquarters {
            let paymentsToday = context.supplierCashPayments.filter {
                calendar.isDate($0.dataPlata, inSameDayAs: date)
            }
            for payment in paymentsToday.sorted(by: { lhs, rhs in
                supplierPaymentDocumentNumber(lhs).localizedCaseInsensitiveCompare(
                    supplierPaymentDocumentNumber(rhs)
                ) == .orderedAscending
            }) {
                appendLine(
                    actCasa: supplierPaymentDocumentNumber(payment),
                    explanation: supplierPaymentExplanation(payment),
                    plati: payment.suma
                )
            }
        }

        guard !operationLines.isEmpty else { return nil }

        var totalIncasari = opening
        var totalPlati = Decimal.zero
        for line in operationLines {
            totalIncasari += line.incasari ?? 0
            totalPlati += line.plati ?? 0
        }

        var closing = totalIncasari - totalPlati
        if closing < 0 {
            let topUp = topUpAmount(forDeficit: closing)
            appendLine(
                actCasa: nextAutoDocumentNumber(from: operationLines),
                explanation: L10n.tr("module.cash_register.line_return_avans"),
                incasari: topUp
            )
            totalIncasari += topUp
            closing = totalIncasari - totalPlati
        }

        var lines: [CashRegisterJournalLine] = [
            CashRegisterJournalLine(
                rowNumber: 0,
                explanation: L10n.tr("module.cash_register.opening_balance"),
                incasari: opening > 0 ? opening : nil
            )
        ]
        lines.append(contentsOf: operationLines)
        lines.append(
            CashRegisterJournalLine(
                rowNumber: 16,
                explanation: L10n.tr("module.cash_register.report_row"),
                incasari: totalIncasari,
                plati: totalPlati,
                simbolCont: max(closing, 0)
            )
        )

        let casaTitle = CashRegisterWorkLocationMatcher.displayName(
            for: casa,
            locations: context.workLocations
        )
        let account = account(for: casa, settings: context.settings)

        return CashRegisterDailyJournal(
            id: "\(casa.id)-\(CashRegisterJournalFormatting.fileDate(date))",
            date: date,
            casaTarget: casa,
            casaTitle: casaTitle,
            casaAccount: account,
            companyName: context.company.denumire,
            companyRegistration: registrationLine(for: context.company),
            companyAddress: addressLine(for: context.company, casa: casa, locations: context.workLocations),
            openingBalance: opening,
            lines: lines,
            totalIncasari: totalIncasari,
            totalPlati: totalPlati,
            closingBalance: max(closing, 0),
            pageNumber: 1,
            pageCount: 1
        )
    }

    private static func openingBalance(
        for casa: CashRegisterCasaTarget,
        date: Date,
        closingByCasaDay: [String: Decimal],
        calendar: Calendar
    ) -> Decimal {
        guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { return 0 }
        var cursor = previous
        for _ in 0..<366 {
            let key = balanceKey(casa: casa, date: cursor)
            if let value = closingByCasaDay[key] { return max(value, 0) }
            guard let next = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = next
        }
        return 0
    }

    private static func balanceKey(casa: CashRegisterCasaTarget, date: Date) -> String {
        "\(casa.id)|\(CashRegisterJournalFormatting.fileDate(date))"
    }

    private static func account(for casa: CashRegisterCasaTarget, settings: ZettaSettingsPayload) -> String {
        switch casa {
        case .headquarters:
            return settings.headquartersCasaAccount
        case .workLocation(let id):
            return settings.account(for: id)
        }
    }

    private static func registrationLine(for company: Company) -> String {
        var parts: [String] = []
        if let nr = company.nrRegCom?.trimmingCharacters(in: .whitespacesAndNewlines), !nr.isEmpty {
            parts.append("J \(nr)")
        }
        if let cui = company.cui?.trimmingCharacters(in: .whitespacesAndNewlines), !cui.isEmpty {
            let prefix = company.cifCountryPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
            parts.append(prefix.isEmpty ? "CUI \(cui)" : "\(prefix) \(cui)")
        }
        return parts.joined(separator: "   ")
    }

    private static func addressLine(
        for company: Company,
        casa: CashRegisterCasaTarget,
        locations: [CompanyWorkLocation]
    ) -> String {
        if case .workLocation(let id) = casa,
           let location = locations.first(where: { $0.id == id }),
           let address = location.formattedPostalAddress {
            return address
        }
        if let hq = company.formattedHeadquartersAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hq.isEmpty {
            return hq
        }
        return company.adresa?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func topUpAmount(forDeficit balance: Decimal) -> Decimal {
        let deficit = abs(balance)
        let deficitNumber = NSDecimalNumber(decimal: deficit).doubleValue
        let rounded = ceil(deficitNumber / 100.0) * 100.0
        return Decimal(rounded)
    }

    private static func supplierPaymentDocumentNumber(_ payment: SupplierPaymentRow) -> String {
        if let referinta = payment.referinta?.trimmingCharacters(in: .whitespacesAndNewlines), !referinta.isEmpty {
            return referinta
        }
        return "PL-\(CashRegisterJournalFormatting.fileDate(payment.dataPlata))"
    }

    private static func supplierPaymentExplanation(_ payment: SupplierPaymentRow) -> String {
        if let trimmed = payment.observatii?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        let supplier = payment.supplierName
        if let invoice = payment.invoiceNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !invoice.isEmpty {
            return L10n.tr("module.cash_register.line_plata_furnizor", invoice, supplier)
        }
        return L10n.tr("module.cash_register.line_plata_furnizor_advance", supplier)
    }

    private static func matchesImportedSupplierPayment(
        _ entry: CashRegisterManualEntry,
        on date: Date,
        calendar: Calendar,
        payments: [SupplierPaymentRow]
    ) -> Bool {
        guard entry.kind == .plataFurnizor, entry.resolvedCasaTarget().isHeadquarters else { return false }
        return payments.contains { payment in
            calendar.isDate(payment.dataPlata, inSameDayAs: date)
                && payment.suma == entry.amount
                && supplierPaymentDocumentNumber(payment).caseInsensitiveCompare(entry.documentNumber) == .orderedSame
        }
    }

    private static func nextAutoDocumentNumber(from lines: [CashRegisterJournalLine]) -> String {
        let maxNumber = lines.compactMap { Int($0.actCasaNumber) }.max() ?? 0
        return String(maxNumber + 1)
    }

    private static func assignPageNumbers(_ pages: [CashRegisterDailyJournal]) -> [CashRegisterDailyJournal] {
        let grouped = Dictionary(grouping: pages) { page in
            "\(page.casaTarget.id)|\(CashRegisterJournalFormatting.fileDate(page.date))"
        }
        return pages.map { page in
            let key = "\(page.casaTarget.id)|\(CashRegisterJournalFormatting.fileDate(page.date))"
            let count = grouped[key]?.count ?? 1
            return CashRegisterDailyJournal(
                id: page.id,
                date: page.date,
                casaTarget: page.casaTarget,
                casaTitle: page.casaTitle,
                casaAccount: page.casaAccount,
                companyName: page.companyName,
                companyRegistration: page.companyRegistration,
                companyAddress: page.companyAddress,
                openingBalance: page.openingBalance,
                lines: page.lines,
                totalIncasari: page.totalIncasari,
                totalPlati: page.totalPlati,
                closingBalance: page.closingBalance,
                pageNumber: 1,
                pageCount: count
            )
        }
    }
}

private extension Company {
    var formattedHeadquartersAddress: String? {
        var segments: [String] = []
        if let street = hqStreet?.trimmingCharacters(in: .whitespacesAndNewlines), !street.isEmpty {
            var line = street
            if let number = hqStreetNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty {
                line += " nr. \(number)"
            }
            segments.append(line)
        }
        if let city = hqCity?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
            segments.append(city)
        }
        if let county = hqCounty?.trimmingCharacters(in: .whitespacesAndNewlines), !county.isEmpty {
            segments.append(county)
        }
        let value = segments.joined(separator: ", ")
        return value.isEmpty ? nil : value
    }
}
