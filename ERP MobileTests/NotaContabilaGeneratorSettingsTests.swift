import Foundation
import Testing
@testable import ERPMobile

struct NotaContabilaGeneratorSettingsTests {

    private func sampleZReport() -> ZReportData {
        var z = ZReportData()
        z.zNumber = 218
        z.firma = "SOCIETATE TEST S.R.L."
        z.cui = "12345678"
        z.vanzari21 = 1210
        z.tva21 = 210
        z.vanzari11 = 555
        z.tva11 = 55
        z.vanzari0 = 100
        z.numerar = 500
        z.card = 800
        z.plataModerna = 465
        z.totalVanzari = 1765
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        z.date = f.date(from: "2026-07-23") ?? Date()
        return z
    }

    private func sampleConfig(multipleLocations: Bool) -> ZettaNCConfig {
        let companyId = UUID()
        var settings = ZettaSettingsPayload.defaults()
        settings.headquartersCasaAccount = "5311.0"
        settings.cardPaymentAccount = "5125"
        settings.modernPaymentAccount = "5113"

        var slotA = settings.vatSettings(for: .a)
        slotA.isEnabled = true
        slotA.rate = .twentyOne
        slotA.salesMappings = slotA.salesMappings.map {
            var m = $0
            m.isEnabled = $0.category == .marfa
            return m
        }
        settings.setVatSettings(slotA, for: .a)

        var slotB = settings.vatSettings(for: .b)
        slotB.isEnabled = true
        slotB.rate = .eleven
        slotB.salesMappings = slotB.salesMappings.map {
            var m = $0
            m.isEnabled = $0.category == .marfa
            m.account = "707"
            return m
        }
        settings.setVatSettings(slotB, for: .b)

        var slotD = settings.vatSettings(for: .d)
        slotD.isEnabled = true
        slotD.rate = .zero
        slotD.salesMappings = slotD.salesMappings.map {
            var m = $0
            m.isEnabled = $0.category == .sgr
            return m
        }
        settings.setVatSettings(slotD, for: .d)

        let loc1 = CompanyWorkLocation(
            id: UUID(), companyId: companyId, denumire: "Agro", country: nil, county: nil,
            city: "Bucuresti", street: nil, streetNumber: nil, block: nil, stair: nil,
            floor: nil, apartment: nil, postalCode: nil, telefon: nil, telefonMobil: nil,
            gln: nil, isActive: true, isDefault: true, operatesAtHeadquarters: false,
            isFiscalDomicile: false, useInDeclarations: true, createdAt: nil, updatedAt: nil
        )
        let loc2 = CompanyWorkLocation(
            id: UUID(), companyId: companyId, denumire: "Ploiesti", country: nil, county: nil,
            city: "Ploiesti", street: nil, streetNumber: nil, block: nil, stair: nil,
            floor: nil, apartment: nil, postalCode: nil, telefon: nil, telefonMobil: nil,
            gln: nil, isActive: true, isDefault: false, operatesAtHeadquarters: false,
            isFiscalDomicile: false, useInDeclarations: true, createdAt: nil, updatedAt: nil
        )
        settings.syncLocationAccounts(with: multipleLocations ? [loc1, loc2] : [loc1])

        return ZettaNCConfig(
            settings: settings,
            workLocations: multipleLocations ? [loc1, loc2] : [loc1]
        )
    }

    @Test func taxedSlotsProduceTVAAndRevenueLines() {
        let rows = NotaContabilaGenerator.generate(from: sampleZReport(), nrInreg: 1, config: sampleConfig(multipleLocations: false))
        let tvaLines = rows.filter { $0.contCredit == Conturi.tvaColectata }
        let revenue707 = rows.filter { $0.contCredit == "707" }
        #expect(tvaLines.count == 2)
        #expect(revenue707.count >= 1)
        #expect(rows.allSatisfy { $0.valoare != 0 })
    }

    @Test func zeroRateSGREUses267() {
        let rows = NotaContabilaGenerator.generate(from: sampleZReport(), nrInreg: 1, config: sampleConfig(multipleLocations: false))
        let sgr = rows.first { $0.contCredit == "267" }
        #expect(sgr != nil)
        #expect(sgr?.valoare == 100)
    }

    @Test func singleLocationUsesOneCashLine() {
        let rows = NotaContabilaGenerator.generate(from: sampleZReport(), nrInreg: 1, config: sampleConfig(multipleLocations: false))
        let cashRC = rows.filter { $0.jurnal == "RC" && $0.contDebit == "5311" }
        #expect(cashRC.count == 1)
        #expect(cashRC.first?.valoare == 500)
    }

    @Test func multipleLocationsUsesViramenteLines() {
        let rows = NotaContabilaGenerator.generate(from: sampleZReport(), nrInreg: 1, config: sampleConfig(multipleLocations: true))
        let viramente = rows.filter { $0.contDebit == Conturi.viramente || $0.contCredit == Conturi.viramente }
        #expect(viramente.count == 2)
        let sediu = rows.first { $0.contDebit == "5311.0" }
        #expect(sediu != nil)
    }

    @Test func cardAndModernUseSettingsAccounts() {
        let rows = NotaContabilaGenerator.generate(from: sampleZReport(), nrInreg: 1, config: sampleConfig(multipleLocations: false))
        #expect(rows.contains { $0.contDebit == "5125" && $0.valoare == 800 })
        #expect(rows.contains { $0.contDebit == "5113" && $0.valoare == 465 })
    }

    @Test func omitsZeroValueRows() {
        var z = sampleZReport()
        z.card = 0
        z.plataModerna = 0
        let rows = NotaContabilaGenerator.generate(from: z, nrInreg: 1, config: sampleConfig(multipleLocations: false))
        #expect(!rows.contains { $0.contDebit == "5125" })
        #expect(!rows.contains { $0.contDebit == "5113" })
    }
}
