import Foundation

enum HRPayrollNCNoteStyle: String, CaseIterable, Identifiable, Sendable {
    case simple
    case collectedUniqueAccount

    var id: String { rawValue }

    var label: String {
        switch self {
        case .simple:
            return L10n.tr("utilities.payroll_nc.style_simple")
        case .collectedUniqueAccount:
            return L10n.tr("utilities.payroll_nc.style_collected")
        }
    }
}

enum HRPayrollNCUniqueAccountCollector {
    static let collectedAccounts: Set<String> = ["444", "4315", "4316", "436"]
    static let uniqueAccount = "4311"

    static func exportEntries(_ entries: [HRJournalEntry], style: HRPayrollNCNoteStyle) -> [HRJournalEntry] {
        guard style == .collectedUniqueAccount else { return entries }
        var result: [HRJournalEntry] = []
        result.reserveCapacity(entries.count * 2)
        for entry in entries {
            result.append(entry)
            guard entry.debitCredit.uppercased() == "C",
                  collectedAccounts.contains(accountDigits(entry.account))
            else { continue }
            result.append(copy(entry, account: entry.account, title: entry.accountTitle, debitCredit: "D"))
            result.append(
                copy(
                    entry,
                    account: uniqueAccount,
                    title: L10n.tr("utilities.payroll_nc.account_4311_title"),
                    debitCredit: "C"
                )
            )
        }
        return result
    }

    static func accountDigits(_ raw: String) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(while: \.isNumber))
    }

    private static func copy(
        _ entry: HRJournalEntry,
        account: String,
        title: String,
        debitCredit: String
    ) -> HRJournalEntry {
        HRJournalEntry(
            number: entry.number,
            journal: entry.journal,
            dateYYYYMMDD: entry.dateYYYYMMDD,
            documentNumber: entry.documentNumber,
            account: account,
            accountTitle: title,
            explanation: entry.explanation,
            amount: entry.amount,
            debitCredit: debitCredit,
            employeeCode: entry.employeeCode
        )
    }
}
