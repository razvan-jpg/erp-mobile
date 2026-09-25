import Foundation
import UIKit

enum HRPayrollPDFBuilder {
    private static let portraitSize = CGSize(width: 595, height: 842)
    private static let landscapeSize = CGSize(width: 842, height: 595)
    private static let margin: CGFloat = 32

    static func payrollGeneral(
        company: Company?,
        period: HRMonthPeriod,
        drafts: [HRPayrollLineDraft]
    ) throws -> Data {
        try tablePDF(
            title: L10n.tr("module.hr.listing_payroll_general"),
            subtitle: period.label,
            company: company,
            landscape: true,
            headers: payrollHeaders,
            fractions: [0.06, 0.22, 0.10, 0.10, 0.10, 0.10, 0.10, 0.11, 0.11],
            rows: drafts.map { payrollRow($0) }
        )
    }

    static func payrollByLocation(
        company: Company?,
        period: HRMonthPeriod,
        drafts: [HRPayrollLineDraft]
    ) throws -> Data {
        let groups = Dictionary(grouping: drafts) { $0.workLocationName.isEmpty ? L10n.tr("module.hr.no_location") : $0.workLocationName }
        let pageRect = CGRect(origin: .zero, size: landscapeSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            for name in groups.keys.sorted() {
                let rows = groups[name] ?? []
                context.beginPage()
                var y = drawHeader(company: company, title: L10n.tr("module.hr.listing_payroll_location"), subtitle: "\(period.label) · \(name)", pageWidth: pageRect.width, y: margin)
                y = drawTable(
                    headers: payrollHeaders,
                    fractions: [0.06, 0.22, 0.10, 0.10, 0.10, 0.10, 0.10, 0.11, 0.11],
                    rows: rows.map { payrollRow($0) },
                    context: context,
                    pageRect: pageRect,
                    y: y
                )
                _ = y
            }
            if groups.isEmpty {
                context.beginPage()
                _ = drawHeader(company: company, title: L10n.tr("module.hr.listing_payroll_location"), subtitle: period.label, pageWidth: pageRect.width, y: margin)
            }
        }
    }

    static func payslips(
        company: Company?,
        period: HRMonthPeriod,
        drafts: [HRPayrollLineDraft]
    ) throws -> Data {
        let pageRect = CGRect(origin: .zero, size: portraitSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            if drafts.isEmpty {
                context.beginPage()
                _ = drawHeader(company: company, title: L10n.tr("module.hr.listing_payslips"), subtitle: period.label, pageWidth: pageRect.width, y: margin)
                return
            }
            for draft in drafts {
                context.beginPage()
                var y = drawHeader(company: company, title: L10n.tr("module.hr.listing_payslips"), subtitle: period.label, pageWidth: pageRect.width, y: margin)
                y = drawText(draft.employeeName, at: y + 8, pageWidth: pageRect.width, font: .boldSystemFont(ofSize: 16))
                y = drawText("\(L10n.tr("module.hr.field_code")): \(draft.employeeCode)", at: y, pageWidth: pageRect.width, font: .systemFont(ofSize: 11))
                y = drawText("\(L10n.tr("module.hr.field_job")): \(draft.jobTitle)", at: y, pageWidth: pageRect.width, font: .systemFont(ofSize: 11))
                if !draft.workLocationName.isEmpty {
                    y = drawText("\(L10n.tr("module.hr.field_location")): \(draft.workLocationName)", at: y, pageWidth: pageRect.width, font: .systemFont(ofSize: 11))
                }
                y += 10
                let pairs = [
                    (L10n.tr("module.hr.field_base_hours"), SupplierFormatting.amountString(draft.line.baseHours)),
                    (L10n.tr("module.hr.field_hours_worked"), SupplierFormatting.amountString(draft.line.hoursWorked)),
                    (L10n.tr("module.hr.field_co"), "\(SupplierFormatting.amountString(draft.line.daysCO)) / \(SupplierFormatting.amountString(draft.line.hoursCO))"),
                    (L10n.tr("module.hr.field_cm"), "\(SupplierFormatting.amountString(draft.line.daysCM)) / \(SupplierFormatting.amountString(draft.line.hoursCM))"),
                    (L10n.tr("module.hr.field_bonuses"), SupplierFormatting.currency(draft.line.bonuses)),
                    (L10n.tr("module.hr.field_other"), SupplierFormatting.currency(draft.line.otherAdditions)),
                    (L10n.tr("module.hr.field_deductions"), SupplierFormatting.currency(draft.line.deductions)),
                    (L10n.tr("module.hr.field_gross"), SupplierFormatting.currency(draft.line.grossAmount)),
                    (L10n.tr("module.hr.field_net"), SupplierFormatting.currency(draft.line.netAmount))
                ]
                for pair in pairs {
                    y = drawText("\(pair.0): \(pair.1)", at: y, pageWidth: pageRect.width, font: .systemFont(ofSize: 12))
                }
            }
        }
    }

    static func timesheet(
        company: Company?,
        period: HRMonthPeriod,
        drafts: [HRPayrollLineDraft],
        days: [HRTimesheetDay]
    ) throws -> Data {
        let byEmployee = Dictionary(grouping: days, by: \.employeeId)
        let pageRect = CGRect(origin: .zero, size: landscapeSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            if drafts.isEmpty {
                context.beginPage()
                _ = drawHeader(company: company, title: L10n.tr("module.hr.listing_timesheet"), subtitle: period.label, pageWidth: pageRect.width, y: margin)
                return
            }
            for draft in drafts {
                context.beginPage()
                var y = drawHeader(
                    company: company,
                    title: L10n.tr("module.hr.listing_timesheet"),
                    subtitle: "\(period.label) · \(draft.employeeName)",
                    pageWidth: pageRect.width,
                    y: margin
                )
                let employeeDays = (byEmployee[draft.line.employeeId] ?? []).sorted { $0.workDate < $1.workDate }
                let rows = employeeDays.map { timesheetRow($0) }
                y = drawTable(
                    headers: [
                        L10n.tr("module.hr.col_date"),
                        L10n.tr("module.hr.col_kind"),
                        L10n.tr("module.hr.col_start"),
                        L10n.tr("module.hr.col_end"),
                        L10n.tr("module.hr.col_hours")
                    ],
                    fractions: [0.20, 0.24, 0.18, 0.18, 0.20],
                    rows: rows,
                    context: context,
                    pageRect: pageRect,
                    y: y
                )
                _ = y
            }
        }
    }

    static func journal(
        company: Company?,
        period: HRMonthPeriod,
        entries: [HRJournalEntry]
    ) throws -> Data {
        try tablePDF(
            title: L10n.tr("module.hr.listing_journal"),
            subtitle: period.label,
            company: company,
            landscape: true,
            headers: [
                L10n.tr("module.hr.col_note"),
                L10n.tr("module.hr.col_journal"),
                L10n.tr("module.hr.col_account"),
                L10n.tr("module.hr.col_dc"),
                L10n.tr("module.hr.col_marca"),
                L10n.tr("module.hr.col_explanation"),
                L10n.tr("module.hr.col_amount")
            ],
            fractions: [0.08, 0.08, 0.10, 0.07, 0.10, 0.39, 0.18],
            rows: entries.map {
                [
                    "\($0.number)",
                    $0.journal,
                    $0.account,
                    $0.debitCredit,
                    $0.employeeCode,
                    $0.explanation,
                    SupplierFormatting.currency($0.amount)
                ]
            }
        )
    }

    private static var payrollHeaders: [String] {
        [
            L10n.tr("module.hr.col_marca"),
            L10n.tr("module.hr.col_name"),
            L10n.tr("module.hr.col_hours"),
            L10n.tr("module.hr.col_co"),
            L10n.tr("module.hr.col_cm"),
            L10n.tr("module.hr.col_bonuses"),
            L10n.tr("module.hr.col_deductions"),
            L10n.tr("module.hr.col_gross"),
            L10n.tr("module.hr.col_net")
        ]
    }

    private static func timesheetRow(_ day: HRTimesheetDay) -> [String] {
        [
            SupplierFormatting.date(day.workDate),
            L10n.tr(day.kind.labelKey),
            day.startTime ?? "—",
            day.endTime ?? "—",
            SupplierFormatting.amountString(day.hours)
        ]
    }

    private static func payrollRow(_ draft: HRPayrollLineDraft) -> [String] {
        [
            draft.employeeCode,
            draft.employeeName,
            SupplierFormatting.amountString(draft.line.hoursWorked),
            SupplierFormatting.amountString(draft.line.hoursCO),
            SupplierFormatting.amountString(draft.line.hoursCM),
            SupplierFormatting.currency(draft.line.bonuses),
            SupplierFormatting.currency(draft.line.deductions),
            SupplierFormatting.currency(draft.line.grossAmount),
            SupplierFormatting.currency(draft.line.netAmount)
        ]
    }

    private static func tablePDF(
        title: String,
        subtitle: String,
        company: Company?,
        landscape: Bool,
        headers: [String],
        fractions: [CGFloat],
        rows: [[String]]
    ) throws -> Data {
        let pageRect = CGRect(origin: .zero, size: landscape ? landscapeSize : portraitSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let y = drawHeader(company: company, title: title, subtitle: subtitle, pageWidth: pageRect.width, y: margin)
            _ = drawTable(headers: headers, fractions: fractions, rows: rows, context: context, pageRect: pageRect, y: y)
        }
    }

    @discardableResult
    private static func drawTable(
        headers: [String],
        fractions: [CGFloat],
        rows: [[String]],
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        y startY: CGFloat
    ) -> CGFloat {
        let widths = columnWidths(fractions, total: pageRect.width - margin * 2)
        let headerFont = UIFont.boldSystemFont(ofSize: 9)
        let bodyFont = UIFont.systemFont(ofSize: 9)
        var y = drawTableRow(headers, widths: widths, x: margin, y: startY + 8, font: headerFont, isHeader: true, isAlternate: false)
        if rows.isEmpty {
            y = drawTableRow(
                Array(repeating: "", count: headers.count),
                widths: widths,
                x: margin,
                y: y,
                font: bodyFont,
                isHeader: false,
                isAlternate: false
            )
            return y
        }
        for (index, row) in rows.enumerated() {
            if y > pageRect.height - margin - 24 {
                context.beginPage()
                y = margin
                y = drawTableRow(headers, widths: widths, x: margin, y: y, font: headerFont, isHeader: true, isAlternate: false)
            }
            y = drawTableRow(row, widths: widths, x: margin, y: y, font: bodyFont, isHeader: false, isAlternate: index % 2 == 1)
        }
        return y
    }

    private static func drawHeader(company: Company?, title: String, subtitle: String, pageWidth: CGFloat, y: CGFloat) -> CGFloat {
        var next = y
        if let company {
            next = drawText(company.denumire, at: next, pageWidth: pageWidth, font: .boldSystemFont(ofSize: 12))
            if let cui = company.cui, !cui.isEmpty {
                next = drawText(L10n.tr("common.cui_label", cui), at: next, pageWidth: pageWidth, font: .systemFont(ofSize: 10))
            }
        }
        next = drawText(title, at: next + 4, pageWidth: pageWidth, font: .boldSystemFont(ofSize: 15))
        next = drawText(subtitle, at: next, pageWidth: pageWidth, font: .systemFont(ofSize: 11))
        return next
    }

    @discardableResult
    private static func drawText(_ text: String, at y: CGFloat, pageWidth: CGFloat, font: UIFont) -> CGFloat {
        let maxWidth = pageWidth - margin * 2
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black, .paragraphStyle: paragraph]
        let height = ceil(text.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil).height)
        text.draw(in: CGRect(x: margin, y: y, width: maxWidth, height: height), withAttributes: attributes)
        return y + height + 3
    }

    @discardableResult
    private static func drawTableRow(
        _ values: [String],
        widths: [CGFloat],
        x: CGFloat,
        y: CGFloat,
        font: UIFont,
        isHeader: Bool,
        isAlternate: Bool
    ) -> CGFloat {
        let padding: CGFloat = 3
        let heights = zip(values, widths).map { value, width -> CGFloat in
            ceil(value.boundingRect(with: CGSize(width: max(width - padding * 2, 1), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height)
        }
        let rowHeight = max(heights.max() ?? 14, 14) + padding * 2
        let rowRect = CGRect(x: x, y: y, width: widths.reduce(0, +), height: rowHeight)
        if isHeader {
            UIColor(white: 0.92, alpha: 1).setFill()
        } else if isAlternate {
            UIColor(white: 0.97, alpha: 1).setFill()
        } else {
            UIColor.white.setFill()
        }
        UIBezierPath(rect: rowRect).fill()
        var cellX = x
        for (index, value) in values.enumerated() {
            let width = widths[index]
            let rect = CGRect(x: cellX, y: y, width: width, height: rowHeight)
            let path = UIBezierPath(rect: rect)
            path.lineWidth = 0.4
            UIColor.separator.setStroke()
            path.stroke()
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            paragraph.alignment = index <= 1 ? .left : .right
            value.draw(in: rect.insetBy(dx: padding, dy: padding), withAttributes: [
                .font: font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ])
            cellX += width
        }
        return y + rowHeight
    }

    private static func columnWidths(_ fractions: [CGFloat], total: CGFloat) -> [CGFloat] {
        var widths = fractions.map { floor(total * $0) }
        if !widths.isEmpty {
            widths[widths.count - 1] += total - widths.reduce(0, +)
        }
        return widths
    }
}
