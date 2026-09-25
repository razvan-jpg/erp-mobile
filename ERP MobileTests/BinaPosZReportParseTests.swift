import XCTest
@testable import ERPMobile

final class BinaPosZReportParseTests: XCTestCase {
    private let binaEnglishSample = """
    COMPLEX MAGNOLIA
    MUNICIPIUL BUCUREŞTI, SECTOR 1, BLD MAREŞAL ALEXANDRU AVERESCU, NR.7A, BL.C, SC.A, ET.3, AP.114
    Z report No.

    266
    Location
    AGRONOMIEI
    POS number
    1
    User
    CASIER AGRONOMIEI
    From
    16/08/2026 18:31:14
    To
    17/08/2026 06:22:32
    Documents
    41
    Total
    1.953,90
    RON
    Payment types
    Cash
    344,50
    RON
    Credit cards
    990,50
    RON
    Credit
    Meal ticket
    Jeton
    Meal card
    Plata moderna
    618,90
    RON
    Voucher
    Total
    1.953,90
    RON
    VAT group breakdown
    BRUT A
    VAT 21%
    149,50
    BRUT B
    VAT 11%
    1.791,90
    BRUT D
    VAT 0%
    12,50
    VAT A 21%
    25,95
    VAT B 11%
    177,58
    VAT D 0%
    0,00
    Total VAT
    203,53
    Total Sold
    1.953,90
    """

    func testNormalizerDetectsEnglishBinaFormat() {
        XCTAssertTrue(BinaPosZReportTextNormalizer.looksLikeEnglishBinaPOS(binaEnglishSample))
    }

    func testParseEnglishBinaPDFLikeStandaloneZetta() {
        let parsed = ZParser.parse(ocrText: binaEnglishSample)

        XCTAssertEqual(parsed.parseSource, .digitalPDF)
        XCTAssertTrue(parsed.isNectarieFirma)
        XCTAssertEqual(parsed.firma, "NECTARIE 20XXV S.R.L.")
        XCTAssertEqual(parsed.punctLucru, .agro)
        XCTAssertEqual(parsed.locatieLabel, "AGRONOMIEI")
        XCTAssertEqual(parsed.zNumber, 266)
        XCTAssertEqual(parsed.vanzari21, 149.50)
        XCTAssertEqual(parsed.vanzari11, 1791.90)
        XCTAssertEqual(parsed.vanzari0, 12.50)
        XCTAssertEqual(parsed.tva21, 25.95)
        XCTAssertEqual(parsed.tva11, 177.58)
        XCTAssertEqual(parsed.totalVanzari, 1953.90)
        XCTAssertEqual(parsed.numerar, 344.50)
        XCTAssertEqual(parsed.card, 990.50)
        XCTAssertEqual(parsed.plataModerna, 618.90)
        XCTAssertTrue(parsed.isBalanced)
        XCTAssertEqual(parsed.dateFormatted, "16/08/2026")
        XCTAssertTrue(parsed.isNightShift)
    }

    func testRomanianExportLayoutWithoutDiacriticsFromEnglish() {
        let layout = BinaPosZReportTextNormalizer.romanianExportLayoutWithoutDiacritics(from: binaEnglishSample)
        XCTAssertTrue(layout.contains("Locatia"))
        XCTAssertTrue(layout.contains("Pana la"))
        XCTAssertTrue(layout.contains("Metode de Plata"))
        XCTAssertFalse(layout.contains("â"))
        XCTAssertFalse(layout.contains("ă"))
        XCTAssertFalse(layout.contains("ț"))
        XCTAssertFalse(layout.contains("ș"))
    }

    func testVisualModelMatchesBinaLayoutFields() {
        let model = CashRegisterZReportBinaLayout.build(from: binaEnglishSample, fallbackZNumber: "266")
        XCTAssertEqual(model.zNumber, "266")
        XCTAssertEqual(model.location, "AGRONOMIEI")
        XCTAssertEqual(model.totalSales, "1.953,90 RON")
        XCTAssertEqual(model.payments.first(where: { $0.label == "Numerar" })?.amount, "344,50 RON")
        let pdf = CashRegisterZReportBinaLayout.makePDF(from: model)
        XCTAssertTrue(pdf.starts(with: [0x25, 0x50, 0x44, 0x46]))
    }
}
