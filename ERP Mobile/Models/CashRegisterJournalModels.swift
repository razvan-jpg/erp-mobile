import Foundation

/// Ținta registrului: casă sediu sau casă punct de lucru.
enum CashRegisterCasaTarget: Hashable, Identifiable, Sendable {
    case headquarters
    case workLocation(UUID)

    var id: String {
        switch self {
        case .headquarters:
            return "hq"
        case .workLocation(let uuid):
            return uuid.uuidString
        }
    }

    var isHeadquarters: Bool {
        if case .headquarters = self { return true }
        return false
    }

    func workLocationId() -> UUID? {
        if case .workLocation(let id) = self { return id }
        return nil
    }
}

enum CashRegisterManualEntryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case incasareClient
    case plataFurnizor
    case ridicareNumerarBanca
    case incasareDiverse
    case plataDiverse

    var id: String { rawValue }

    var isIncasare: Bool {
        switch self {
        case .incasareClient, .ridicareNumerarBanca, .incasareDiverse:
            return true
        case .plataFurnizor, .plataDiverse:
            return false
        }
    }
}

/// Operațiune manuală (chitanță încasare/plată) — completată separat de Z.
struct CashRegisterManualEntry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var date: Date
    var casaTarget: String
    var kind: CashRegisterManualEntryKind
    var documentNumber: String
    var explanation: String
    @SupabaseDecimal var amount: Decimal

    init(
        id: UUID = UUID(),
        date: Date,
        casaTarget: CashRegisterCasaTarget,
        kind: CashRegisterManualEntryKind,
        documentNumber: String,
        explanation: String,
        amount: Decimal
    ) {
        self.id = id
        self.date = date
        self.casaTarget = casaTarget.id
        self.kind = kind
        self.documentNumber = documentNumber
        self.explanation = explanation
        self.amount = amount
    }

    func resolvedCasaTarget() -> CashRegisterCasaTarget {
        casaTarget == CashRegisterCasaTarget.headquarters.id
            ? .headquarters
            : .workLocation(UUID(uuidString: casaTarget) ?? UUID())
    }
}

struct CashRegisterJournalLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let rowNumber: Int
    let actCasaNumber: String
    let actAnexaNumber: String
    let explanation: String
    let incasari: Decimal?
    let plati: Decimal?
    let simbolCont: Decimal?

    init(
        id: UUID = UUID(),
        rowNumber: Int,
        actCasaNumber: String = "",
        actAnexaNumber: String = "",
        explanation: String,
        incasari: Decimal? = nil,
        plati: Decimal? = nil,
        simbolCont: Decimal? = nil
    ) {
        self.id = id
        self.rowNumber = rowNumber
        self.actCasaNumber = actCasaNumber
        self.actAnexaNumber = actAnexaNumber
        self.explanation = explanation
        self.incasari = incasari
        self.plati = plati
        self.simbolCont = simbolCont
    }
}

struct CashRegisterDailyJournal: Identifiable, Hashable, Sendable {
    let id: String
    let date: Date
    let casaTarget: CashRegisterCasaTarget
    let casaTitle: String
    let casaAccount: String
    let companyName: String
    let companyRegistration: String
    let companyAddress: String
    let openingBalance: Decimal
    let lines: [CashRegisterJournalLine]
    let totalIncasari: Decimal
    let totalPlati: Decimal
    let closingBalance: Decimal
    let pageNumber: Int
    let pageCount: Int

    var fileName: String {
        let day = CashRegisterJournalFormatting.fileDate(date)
        let casaPart = CashRegisterJournalFormatting.fileCasaComponent(casaTitle)
        return "Registru_Casa_\(casaPart)_\(day).pdf"
    }
}

enum CashRegisterJournalFormatting {
    static func fileDate(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func displayDate(_ date: Date) -> (day: String, month: String, year: String) {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        return (String(format: "%02d", day), String(format: "%02d", month), String(year))
    }

    static func amount(_ value: Decimal) -> String {
        var rounded = value
        var output = Decimal()
        NSDecimalRound(&output, &rounded, 2, .plain)
        let number = NSDecimalNumber(decimal: output)
        let formatted = String(format: "%.2f", number.doubleValue)
        return formatted.replacingOccurrences(of: ".", with: ",")
    }

    static func fileCasaComponent(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "  ", with: " ")
    }
}
