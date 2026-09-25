import Foundation

enum HRPayrollJournalBuilder {
    static func build(
        run: HRPayrollRun,
        drafts: [HRPayrollLineDraft],
        settings: HRSettings,
        calendar: Calendar = .current
    ) -> [HRJournalEntry] {
        let dateYYYYMMDD = yyyymmdd(run.period.dateInterval(calendar: calendar).end, calendar: calendar)
        var number = max(settings.firstNoteNumber, 1)
        var entries: [HRJournalEntry] = []

        for draft in drafts.sorted(by: { $0.employeeCode.localizedStandardCompare($1.employeeCode) == .orderedAscending }) {
            let noteNumber = settings.oneNotePerEmployee ? number : max(settings.firstNoteNumber, 1)
            let document = "\(noteNumber)"
            let name = draft.employeeName
            let contributions = HRPayrollStatutoryRates.amounts(for: draft.line)

            appendPair(
                into: &entries,
                number: noteNumber,
                journal: settings.journal,
                dateYYYYMMDD: dateYYYYMMDD,
                document: document,
                debit: settings.expenseAccount,
                debitTitle: L10n.tr("module.hr.account_641_title"),
                credit: settings.payableAccount,
                creditTitle: L10n.tr("module.hr.account_421_title"),
                explanation: L10n.tr("module.hr.journal_salary", name),
                amount: draft.line.grossAmount,
                employeeCode: draft.employeeCode
            )
            appendPair(
                into: &entries,
                number: noteNumber,
                journal: settings.journal,
                dateYYYYMMDD: dateYYYYMMDD,
                document: document,
                debit: settings.payableAccount,
                debitTitle: L10n.tr("module.hr.account_421_title"),
                credit: settings.taxAccount,
                creditTitle: L10n.tr("module.hr.account_444_title"),
                explanation: L10n.tr("module.hr.journal_tax", name),
                amount: contributions.tax,
                employeeCode: draft.employeeCode
            )
            appendPair(
                into: &entries,
                number: noteNumber,
                journal: settings.journal,
                dateYYYYMMDD: dateYYYYMMDD,
                document: document,
                debit: settings.payableAccount,
                debitTitle: L10n.tr("module.hr.account_421_title"),
                credit: settings.casAccount,
                creditTitle: L10n.tr("module.hr.account_4315_title"),
                explanation: L10n.tr("module.hr.journal_cas", name),
                amount: contributions.cas,
                employeeCode: draft.employeeCode
            )
            appendPair(
                into: &entries,
                number: noteNumber,
                journal: settings.journal,
                dateYYYYMMDD: dateYYYYMMDD,
                document: document,
                debit: settings.payableAccount,
                debitTitle: L10n.tr("module.hr.account_421_title"),
                credit: settings.cassAccount,
                creditTitle: L10n.tr("module.hr.account_4316_title"),
                explanation: L10n.tr("module.hr.journal_cass", name),
                amount: contributions.cass,
                employeeCode: draft.employeeCode
            )
            appendPair(
                into: &entries,
                number: noteNumber,
                journal: settings.journal,
                dateYYYYMMDD: dateYYYYMMDD,
                document: document,
                debit: settings.camExpenseAccount,
                debitTitle: L10n.tr("module.hr.account_6461_title"),
                credit: settings.camAccount,
                creditTitle: L10n.tr("module.hr.account_436_title"),
                explanation: L10n.tr("module.hr.journal_cam", name),
                amount: contributions.cam,
                employeeCode: draft.employeeCode
            )
            if settings.oneNotePerEmployee {
                number += 1
            }
        }
        return entries
    }

    private static func appendPair(
        into entries: inout [HRJournalEntry],
        number: Int,
        journal: String,
        dateYYYYMMDD: Int,
        document: String,
        debit: String,
        debitTitle: String,
        credit: String,
        creditTitle: String,
        explanation: String,
        amount: Decimal,
        employeeCode: String
    ) {
        guard amount > 0 else { return }
        entries.append(
            HRJournalEntry(
                number: number,
                journal: journal,
                dateYYYYMMDD: dateYYYYMMDD,
                documentNumber: document,
                account: debit,
                accountTitle: debitTitle,
                explanation: explanation,
                amount: amount,
                debitCredit: "D",
                employeeCode: employeeCode
            )
        )
        entries.append(
            HRJournalEntry(
                number: number,
                journal: journal,
                dateYYYYMMDD: dateYYYYMMDD,
                documentNumber: document,
                account: credit,
                accountTitle: creditTitle,
                explanation: explanation,
                amount: amount,
                debitCredit: "C",
                employeeCode: employeeCode
            )
        )
    }

    static func yyyymmdd(_ date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }
}
