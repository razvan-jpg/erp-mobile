import Foundation
import Supabase

enum FiscalSaleReceiptService {
    private static let client = SupabaseManager.client

    static func fetchReceipts(companyId: UUID) async throws -> [FiscalSaleReceipt] {
        try await client
            .from("company_fiscal_sale_receipts")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("issued_at", ascending: true)
            .execute()
            .value
    }

    static func fetchLines(receiptId: UUID) async throws -> [FiscalSaleReceiptLine] {
        try await client
            .from("company_fiscal_sale_receipt_lines")
            .select()
            .eq("receipt_id", value: receiptId.uuidString)
            .order("sort_order", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func fetchLines(receiptIds: [UUID]) async throws -> [UUID: [FiscalSaleReceiptLine]] {
        let unique = Array(Set(receiptIds))
        guard !unique.isEmpty else { return [:] }
        var all: [FiscalSaleReceiptLine] = []
        for chunk in unique.chunked(into: 100) {
            let rows: [FiscalSaleReceiptLine] = try await client
                .from("company_fiscal_sale_receipt_lines")
                .select()
                .in("receipt_id", values: chunk.map(\.uuidString))
                .order("sort_order", ascending: true)
                .execute()
                .value
            all.append(contentsOf: rows)
        }
        return Dictionary(grouping: all, by: \.receiptId)
    }

    static func upsertReceipt(_ receipt: FiscalSaleReceiptInsert) async throws -> FiscalSaleReceipt {
        let rows: [FiscalSaleReceipt] = try await client
            .from("company_fiscal_sale_receipts")
            .upsert(receipt)
            .select()
            .execute()
            .value
        guard let row = rows.first else { throw ServiceError.invalidResponse }
        return row
    }

    static func replaceLines(
        companyId: UUID,
        receiptId: UUID,
        lines: [FiscalSaleReceiptLineInsert]
    ) async throws {
        try await client
            .from("company_fiscal_sale_receipt_lines")
            .delete()
            .eq("receipt_id", value: receiptId.uuidString)
            .execute()
        guard !lines.isEmpty else { return }
        let payload = lines.enumerated().map { index, line in
            FiscalSaleReceiptLineInsert(
                companyId: companyId,
                receiptId: receiptId,
                productId: line.productId,
                denumire: line.denumire,
                cantitate: Decimal(string: line.cantitate) ?? 0,
                pretUnitar: Decimal(string: line.pretUnitar) ?? 0,
                cotaTva: Decimal(string: line.cotaTva) ?? 0,
                discountAmount: Decimal(string: line.discountAmount) ?? 0,
                sortOrder: index
            )
        }
        try await client
            .from("company_fiscal_sale_receipt_lines")
            .insert(payload)
            .execute()
    }

    /// Builds location → date → shift (Z-closed) → receipts.
    /// Shifts are delimited by Z reports matched to each work location.
    static func buildLocationBuckets(
        locations: [CompanyWorkLocation],
        zReports: [CompanyZReportRecord],
        receipts: [FiscalSaleReceipt],
        calendar: Calendar = .current
    ) -> [FiscalSaleLocationBucket] {
        let activeLocations = locations
            .filter(\.isActive)
            .sorted {
                $0.denumire.localizedCaseInsensitiveCompare($1.denumire) == .orderedAscending
            }

        return activeLocations.map { location in
            let locationReports = zReports.filter { report in
                resolvedLocationId(for: report, locations: activeLocations) == location.id
            }
            let locationReceipts = receipts.filter { $0.workLocationId == location.id }
            let days = buildDayBuckets(
                locationId: location.id,
                zReports: locationReports,
                receipts: locationReceipts,
                calendar: calendar
            )
            return FiscalSaleLocationBucket(id: location.id, location: location, days: days)
        }
    }

    static func resolvedLocationId(
        for report: CompanyZReportRecord,
        locations: [CompanyWorkLocation]
    ) -> UUID? {
        switch CashRegisterWorkLocationMatcher.match(report: report, locations: locations) {
        case .workLocation(let id):
            return id
        case .headquarters:
            return locations.first(where: \.operatesAtHeadquarters)?.id
                ?? locations.first(where: \.isDefault)?.id
                ?? locations.first?.id
        }
    }

    private static func buildDayBuckets(
        locationId: UUID,
        zReports: [CompanyZReportRecord],
        receipts: [FiscalSaleReceipt],
        calendar: Calendar
    ) -> [FiscalSaleDayBucket] {
        let sortedReports = zReports.sorted(by: reportSort)
        var dayKeys = Set(sortedReports.map { calendar.startOfDay(for: $0.accountingDate) })
        for receipt in receipts {
            dayKeys.insert(calendar.startOfDay(for: receipt.saleDate))
        }
        if dayKeys.isEmpty, calendar.isDateInToday(Date()) {
            dayKeys.insert(calendar.startOfDay(for: Date()))
        }

        return dayKeys.sorted(by: >).compactMap { day in
            let dayReports = sortedReports.filter {
                calendar.isDate($0.accountingDate, inSameDayAs: day)
            }
            let dayReceipts = receipts.filter {
                calendar.isDate($0.saleDate, inSameDayAs: day)
            }
            let shifts = buildShifts(
                locationId: locationId,
                saleDate: day,
                dayReports: dayReports,
                previousReports: sortedReports.filter {
                    calendar.startOfDay(for: $0.accountingDate) < day
                },
                dayReceipts: dayReceipts,
                calendar: calendar
            )
            guard !shifts.isEmpty else { return nil }
            return FiscalSaleDayBucket(saleDate: day, shifts: shifts)
        }
    }

    private static func buildShifts(
        locationId: UUID,
        saleDate: Date,
        dayReports: [CompanyZReportRecord],
        previousReports: [CompanyZReportRecord],
        dayReceipts: [FiscalSaleReceipt],
        calendar: Calendar
    ) -> [FiscalSaleShiftBucket] {
        let ordered = dayReports.sorted(by: reportSort)
        var shifts: [FiscalSaleShiftBucket] = []
        var previousEnd = previousReports.last.map(shiftEnd)
            ?? calendar.startOfDay(for: saleDate)
        var claimed = Set<UUID>()

        for report in ordered {
            let end = shiftEnd(report)
            let windowReceipts = dayReceipts.filter { receipt in
                guard !claimed.contains(receipt.id) else { return false }
                if let closing = receipt.closingZReportId {
                    return closing == report.id
                }
                return receipt.issuedAt > previousEnd && receipt.issuedAt <= end
            }
            .sorted { $0.issuedAt < $1.issuedAt }

            claimed.formUnion(windowReceipts.map(\.id))
            shifts.append(
                FiscalSaleShiftBucket(
                    id: report.id,
                    workLocationId: locationId,
                    saleDate: saleDate,
                    zNumber: report.zNumber,
                    closingZReportId: report.id,
                    endsAt: end,
                    isNightShift: report.reportData.isNightShift,
                    isOpen: false,
                    receipts: windowReceipts,
                    zReport: report
                )
            )
            previousEnd = end
        }

        let remaining = dayReceipts
            .filter { !claimed.contains($0.id) }
            .sorted { $0.issuedAt < $1.issuedAt }

        let showOpen = !remaining.isEmpty || calendar.isDateInToday(saleDate)
        if showOpen {
            shifts.append(
                FiscalSaleShiftBucket(
                    id: openShiftId(locationId: locationId, saleDate: saleDate, calendar: calendar),
                    workLocationId: locationId,
                    saleDate: saleDate,
                    zNumber: nil,
                    closingZReportId: nil,
                    endsAt: nil,
                    isNightShift: false,
                    isOpen: true,
                    receipts: remaining,
                    zReport: nil
                )
            )
        }

        return shifts
    }

    private static func openShiftId(locationId: UUID, saleDate: Date, calendar: Calendar) -> UUID {
        let day = Int(calendar.startOfDay(for: saleDate).timeIntervalSince1970)
        let loc = locationId.uuid
        return UUID(uuid: (
            loc.0, loc.1, loc.2, loc.3, loc.4, loc.5, loc.6, loc.7,
            UInt8((day >> 24) & 0xff),
            UInt8((day >> 16) & 0xff),
            UInt8((day >> 8) & 0xff),
            UInt8(day & 0xff),
            0x0F, 0x15, 0xCA, 0x1E
        ))
    }

    nonisolated private static func reportSort(_ lhs: CompanyZReportRecord, _ rhs: CompanyZReportRecord) -> Bool {
        let leftEnd = shiftEnd(lhs)
        let rightEnd = shiftEnd(rhs)
        if leftEnd != rightEnd { return leftEnd < rightEnd }
        if lhs.zNumber != rhs.zNumber { return lhs.zNumber < rhs.zNumber }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func fetchSoldProducts(locationId: UUID, sheetId: UUID?) async throws -> [PosSoldProduct] {
        if let sheetId {
            return try await client
                .rpc("pos_sold_products", params: PosSoldProductsSheetParams(workLocationId: locationId, sheetId: sheetId))
                .execute()
                .value
        }
        return try await client
            .rpc("pos_sold_products", params: PosSoldProductsOpenParams(workLocationId: locationId))
            .execute()
            .value
    }

    static func fetchSavedZSheets(companyId: UUID, locationId: UUID) async throws -> [SalesSavedZSheet] {
        try await client
            .from("z_stock_sheets")
            .select("id,sheet_date,shift_no,z_number")
            .eq("company_id", value: companyId.uuidString)
            .eq("work_location_id", value: locationId.uuidString)
            .order("created_at", ascending: false)
            .limit(200)
            .execute()
            .value
    }

    static func fetchIssuedReceipts(locationId: UUID, sheetId: UUID?) async throws -> [SalesIssuedReceipt] {
        try await client
            .rpc(
                "sales_fiscal_receipts",
                params: SalesFiscalReceiptsParams(workLocationId: locationId, sheetId: sheetId)
            )
            .execute()
            .value
    }

    nonisolated private static func shiftEnd(_ report: CompanyZReportRecord) -> Date {
        if let print = report.payload.printDateTime {
            return print
        }
        let day = Calendar.current.startOfDay(for: report.payload.date)
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: day)
            ?? report.reportDate
    }
}
