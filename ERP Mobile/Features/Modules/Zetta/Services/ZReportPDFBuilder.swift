import Foundation
import UIKit

@MainActor
enum ZReportPDFBuilder {
    static func makePDF(from report: ZReportData) -> Data? {
        let text = report.ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return CashRegisterZReportPDFBuilder.makeA4PDF(text: text)
    }

    static func previewFileName(for report: ZReportData) -> String {
        let base = report.sourceFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.isEmpty, base.lowercased().hasSuffix(".pdf") {
            return base
        }
        if !base.isEmpty {
            return "\(base).pdf"
        }
        return "Raport_Z_\(report.zNumber)_\(SupplierFormatting.inputDateString(report.date)).pdf"
    }
}
