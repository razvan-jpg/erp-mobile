import Foundation
import Testing
@testable import ERPMobile

struct CashRegisterJournalBuilderTests {

    private var calendar: Calendar {
        Calendar(identifier: .gregorian)
    }

    @Test func explicitOpeningAppearsOnFirstDayOfPeriod() throws {
        let august5 = day(2026, 8, 5)
        let context = try makeContext(
            manuals: [
                CashRegisterManualEntry(
                    date: august5,
                    casaTarget: .headquarters,
                    kind: .incasareDiverse,
                    documentNumber: "1",
                    explanation: "Test",
                    amount: 50
                )
            ],
            explicitOpening: ["hq": 1234.56]
        )

        let pages = CashRegisterJournalBuilder.build(
            context: context,
            from: day(2026, 8, 1),
            to: day(2026, 8, 31)
        )

        #expect(pages.count == 1)
        let page = try #require(pages.first)
        #expect(calendar.component(.day, from: page.date) == 5)
        #expect(page.openingBalance == Decimal(string: "1234.56"))
        #expect(page.closingBalance == Decimal(string: "1284.56"))
    }

    @Test func priorMonthOperationsCarryIntoFirstPage() throws {
        let context = try makeContext(
            manuals: [
                CashRegisterManualEntry(
                    date: day(2026, 7, 31),
                    casaTarget: .headquarters,
                    kind: .incasareDiverse,
                    documentNumber: "10",
                    explanation: "Iulie",
                    amount: 200
                ),
                CashRegisterManualEntry(
                    date: day(2026, 8, 5),
                    casaTarget: .headquarters,
                    kind: .incasareDiverse,
                    documentNumber: "11",
                    explanation: "August",
                    amount: 50
                )
            ]
        )

        let pages = CashRegisterJournalBuilder.build(
            context: context,
            from: day(2026, 8, 1),
            to: day(2026, 8, 31)
        )

        #expect(pages.count == 1)
        let page = try #require(pages.first)
        #expect(page.openingBalance == 200)
        #expect(page.closingBalance == 250)
    }

    @Test func explicitOpeningOverridesComputedHistory() throws {
        let context = try makeContext(
            manuals: [
                CashRegisterManualEntry(
                    date: day(2026, 7, 31),
                    casaTarget: .headquarters,
                    kind: .incasareDiverse,
                    documentNumber: "10",
                    explanation: "Iulie",
                    amount: 200
                ),
                CashRegisterManualEntry(
                    date: day(2026, 8, 5),
                    casaTarget: .headquarters,
                    kind: .incasareDiverse,
                    documentNumber: "11",
                    explanation: "August",
                    amount: 50
                )
            ],
            explicitOpening: ["hq": 80]
        )

        let pages = CashRegisterJournalBuilder.build(
            context: context,
            from: day(2026, 8, 1),
            to: day(2026, 8, 31)
        )

        let page = try #require(pages.first)
        #expect(page.openingBalance == 80)
        #expect(page.closingBalance == 130)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeContext(
        manuals: [CashRegisterManualEntry],
        explicitOpening: [String: Decimal] = [:]
    ) throws -> CashRegisterJournalBuilder.Context {
        CashRegisterJournalBuilder.Context(
            company: try sampleCompany(),
            settings: .defaults(),
            workLocations: [],
            zReports: [],
            manualEntries: manuals,
            supplierCashPayments: [],
            clientCashPayments: [],
            explicitOpeningBalances: explicitOpening
        )
    }

    private func sampleCompany() throws -> Company {
        let json = Data(#"{"id":"00000000-0000-0000-0000-000000000001","denumire":"Test SRL"}"#.utf8)
        return try JSONDecoder().decode(Company.self, from: json)
    }
}
