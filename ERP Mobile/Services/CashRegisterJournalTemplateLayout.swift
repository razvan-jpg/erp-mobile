import CoreGraphics

/// Poziții calibrate pe modelul PDF `Registru_Casa_model.pdf` (792×612, origine jos-stânga PDF).
enum CashRegisterJournalTemplateLayout {
    /// Model sursă (Letter landscape).
    static let templateContentSize = CGSize(width: 792, height: 612)
    /// Pagină generată pentru listare: A4 landscape.
    static let pageSize = CGSize(width: 841.89, height: 595.28)
    static let bodyFontSize: CGFloat = 8.5
    static let headerFontSize: CGFloat = 9.5

    static let companyName = CGPoint(x: 120, y: 518)
    static let registration = CGPoint(x: 120, y: 499)
    static let address = CGPoint(x: 120, y: 482)

    /// Casetele goale de sub etichetele ZI / LUNA / AN (pdf coords: origine jos-stânga).
    static let dateDayBox = CGRect(x: 508.3, y: 464, width: 48.6, height: 28)
    static let dateMonthBox = CGRect(x: 558.8, y: 464, width: 48.6, height: 28)
    static let dateYearBox = CGRect(x: 609.3, y: 464, width: 48.6, height: 28)

    /// Caseta de sub „CASA” — cont centrat, aliniat la stânga față de marginea dreaptă.
    static let contCasaBox = CGRect(x: 661.8, y: 464, width: 46.6, height: 28)

    static let amountRightPadding: CGFloat = 5

    static let columns = ColumnLayout(
        actCasa: 118,
        anexa: 168,
        explicatie: 248,
        incasariLeft: 407.2,
        incasariRight: 506.4,
        platiLeft: 508.3,
        platiRight: 607.4,
        simbolLeft: 609.3,
        simbolRight: 708.5
    )

    struct ColumnLayout {
        let actCasa: CGFloat
        let anexa: CGFloat
        let explicatie: CGFloat
        let incasariLeft: CGFloat
        let incasariRight: CGFloat
        let platiLeft: CGFloat
        let platiRight: CGFloat
        let simbolLeft: CGFloat
        let simbolRight: CGFloat
    }

    /// Baseline Y (PDF) pentru rândurile 0…15 și RAPORT.
    static let rowBaselines: [Int: CGFloat] = [
        0: 421.31,
        1: 402.68,
        2: 385.28,
        3: 367.81,
        4: 350.48,
        5: 332.94,
        6: 315.61,
        7: 298.19,
        8: 280.79,
        9: 263.39,
        10: 246.06,
        11: 228.66,
        12: 211.26,
        13: 193.86,
        14: 176.43,
        15: 159.27,
        16: 144.01
    ]

    static let strikeLineStartX: CGFloat = 112
    static let strikeLineEndX: CGFloat = 708.5
    static let rowHeight: CGFloat = 17.4

    static func rowCellBottomPdfY(_ row: Int) -> CGFloat {
        guard let baseline = rowBaselines[row] else { return 0 }
        return baseline - rowHeight * 0.82
    }

    static func rowCellTopPdfY(_ row: Int) -> CGFloat {
        guard let baseline = rowBaselines[row] else { return 0 }
        return baseline + rowHeight * 0.35
    }
}
