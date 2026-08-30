import Foundation

/// Legătură Zetta ↔ societatea selectată în ERP Mobile.
struct ZettaERPContext: Equatable {
    private static let utilityStandaloneCompanyId = UUID(uuidString: "E1E1E1E1-E1E1-4E1E-A1E1-E1E1E1E1E1E2")!

    /// Utilitar: fără societate ERP activă — acceptă orice Z scanat.
    static let utilityStandalone = ZettaERPContext(
        companyId: utilityStandaloneCompanyId,
        companyName: "",
        expectedCUI: nil
    )

    let companyId: UUID
    let companyName: String
    /// Cifre CUI normalizate (fără prefix RO), dacă există în nomenclator.
    let expectedCUI: String?

    init(company: Company) {
        self.init(
            companyId: company.id,
            companyName: company.denumire.trimmingCharacters(in: .whitespacesAndNewlines),
            expectedCUI: company.cui
                .flatMap { FirmaRegistry.normalizeCUI($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    private init(companyId: UUID, companyName: String, expectedCUI: String?) {
        self.companyId = companyId
        self.companyName = companyName
        self.expectedCUI = expectedCUI
    }

    var isUtilityStandalone: Bool {
        companyId == Self.utilityStandaloneCompanyId
    }

    var hasExpectedCUI: Bool {
        guard let expectedCUI else { return false }
        return !expectedCUI.isEmpty
    }

    var cifLabel: String {
        guard let expectedCUI else { return "—" }
        return "RO\(expectedCUI)"
    }

    /// CUI efectiv al raportului Z (profil cunoscut sau parser).
    func resolvedReportCUI(for report: ZReportData) -> String? {
        FirmaRegistry.profile(for: report)?.cui
            ?? FirmaRegistry.normalizeCUI(report.cui)
            ?? FirmaRegistry.normalizeCUI(report.ocrText)
    }

    func matches(report: ZReportData) -> Bool {
        guard hasExpectedCUI, let expected = expectedCUI else { return true }

        if let reportCUI = resolvedReportCUI(for: report) {
            if reportCUI == expected { return true }
            if FirmaRegistry.profile(forCUI: reportCUI)?.cui == FirmaRegistry.profile(forCUI: expected)?.cui {
                return true
            }
            if FirmaRegistry.profile(fuzzyCUI: reportCUI)?.cui == expected {
                return true
            }
        }

        return nameMatchesCompany(report.firma)
    }

    func mismatchMessage(for report: ZReportData) -> String {
        let detected = resolvedReportCUI(for: report).map { "RO\($0)" } ?? report.firma.trimmingCharacters(in: .whitespacesAndNewlines)
        let detectedLabel = detected.isEmpty ? "firmă necunoscută" : detected
        return L10n.tr(
            "module.clients.zetta_company_mismatch",
            companyName,
            cifLabel,
            detectedLabel
        )
    }

    private func nameMatchesCompany(_ reportName: String) -> Bool {
        let companyKey = Conturi.compactFirmaKey(companyName)
        let reportKey = Conturi.compactFirmaKey(reportName)
        guard !companyKey.isEmpty, !reportKey.isEmpty else { return false }
        if companyKey == reportKey { return true }
        if companyKey.count >= 6, reportKey.contains(companyKey) { return true }
        if reportKey.count >= 6, companyKey.contains(reportKey) { return true }
        return false
    }
}
