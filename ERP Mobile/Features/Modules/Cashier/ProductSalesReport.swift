import SwiftUI

struct ProductSalesReport: View {
    let locationId: UUID
    let companyId: UUID
    let onClose: () -> Void

    @State private var sheets: [SalesSavedZSheet] = []
    @State private var products: [PosSoldProduct] = []
    @State private var showingProducts = false
    @State private var heading = ""
    @State private var status = ""
    @State private var failed = false
    @State private var printing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                barButton(L10n.tr("module.cashier.product_report_back"), filled: false) {
                    if showingProducts {
                        showingProducts = false
                        heading = L10n.tr("module.cashier.product_report")
                        status = ""
                        failed = false
                    } else {
                        onClose()
                    }
                }
                Text(showingProducts ? heading : L10n.tr("module.cashier.product_report"))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(PosChrome.navy)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showingProducts, !products.isEmpty {
                    barButton(L10n.tr("module.cashier.product_report_print"), filled: false) {
                        Task { await printProducts() }
                    }
                    .disabled(printing)
                }
                barButton(L10n.tr("module.cashier.product_report_close"), filled: true, action: onClose)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(PosChrome.paper)

            if showingProducts {
                ScrollView([.vertical, .horizontal]) {
                    VStack(spacing: 0) {
                        productHeader
                        ForEach(bands) { band in
                            Text(band.name)
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(PosChrome.navy)
                            ForEach(band.rows) { product in
                                productLine(product)
                            }
                            summaryLine("Subtotal", amount: band.subtotal, grand: false)
                        }
                        if !products.isEmpty {
                            summaryLine("Total general", amount: grandTotal, grand: true)
                        }
                    }
                    .frame(minWidth: 860)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        zButton(L10n.tr("module.cashier.product_report_open"), open: true) {
                            Task { await showProducts(sheetId: nil, label: L10n.tr("module.cashier.product_report_open")) }
                        }
                        ForEach(sheets) { sheet in
                            let label = Self.label(sheet)
                            zButton(label, open: false) {
                                Task { await showProducts(sheetId: sheet.id, label: label) }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text(status)
                .font(.body)
                .foregroundColor(failed ? .red : AppColors.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PosChrome.field.ignoresSafeArea())
        .task { await loadSheets() }
    }

    private struct ReportBand: Identifiable {
        let name: String
        let rows: [PosSoldProduct]
        var id: String { name }
        var subtotal: Decimal { rows.reduce(0) { $0 + $1.value } }
    }

    private var bands: [ReportBand] {
        var order: [String] = []
        var rows: [String: [PosSoldProduct]] = [:]
        for product in products {
            if rows[product.group] == nil {
                order.append(product.group)
                rows[product.group] = []
            }
            rows[product.group, default: []].append(product)
        }
        return order.map { ReportBand(name: $0, rows: rows[$0] ?? []) }
    }

    private var grandTotal: Decimal {
        products.reduce(0) { $0 + $1.value }
    }

    private var productHeader: some View {
        HStack(spacing: 12) {
            Text("Cod").frame(width: 100, alignment: .leading)
            Text("Produs").frame(maxWidth: .infinity, alignment: .leading)
            Text("UM").frame(width: 48, alignment: .leading)
            Text("Cantitate").frame(width: 90, alignment: .trailing)
            Text("Preț").frame(width: 100, alignment: .trailing)
            Text("Total").frame(width: 120, alignment: .trailing)
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(PosChrome.navy)
    }

    private func productLine(_ product: PosSoldProduct) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(product.code)
                .frame(width: 100, alignment: .leading)
            Text(product.name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(product.unit)
                .frame(width: 48, alignment: .leading)
            Text(SupplierFormatting.stockQuantityString(product.quantity))
                .frame(width: 90, alignment: .trailing)
            Text(SupplierFormatting.amountString(product.price))
                .frame(width: 100, alignment: .trailing)
            Text(SupplierFormatting.amountString(product.value))
                .frame(width: 120, alignment: .trailing)
        }
        .font(.title3)
        .foregroundColor(PosChrome.navy)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PosChrome.paper)
    }

    private func summaryLine(_ title: String, amount: Decimal, grand: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(SupplierFormatting.amountString(amount))
                .frame(width: 120, alignment: .trailing)
        }
        .font(grand ? .title3.weight(.bold) : .title3.weight(.semibold))
        .foregroundColor(grand ? .white : PosChrome.navy)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(grand ? PosChrome.navy : PosChrome.field)
    }

    private func barButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(filled ? .white : PosChrome.navy)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(filled ? PosChrome.navy : PosChrome.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(PosChrome.navy, lineWidth: filled ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func zButton(_ title: String, open: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(open ? .white : PosChrome.navy)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(open ? PosChrome.navy : PosChrome.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PosChrome.navy, lineWidth: open ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func loadSheets() async {
        status = L10n.tr("module.cashier.product_report_loading")
        failed = false
        do {
            sheets = try await FiscalSaleReceiptService.fetchSavedZSheets(companyId: companyId, locationId: locationId)
            status = ""
        } catch {
            failed = true
            status = error.localizedDescription
        }
    }

    private func showProducts(sheetId: UUID?, label: String) async {
        showingProducts = true
        heading = label
        products = []
        status = L10n.tr("module.cashier.product_report_loading")
        failed = false
        do {
            products = try await FiscalSaleReceiptService.fetchSoldProducts(locationId: locationId, sheetId: sheetId)
            status = products.isEmpty
                ? L10n.tr("module.cashier.product_report_empty")
                : L10n.tr("module.cashier.product_report_count", products.count)
        } catch {
            failed = true
            status = error.localizedDescription
        }
    }

    private func printProducts() async {
        guard !printing, !products.isEmpty else { return }
        guard FiscalNetStation.isReady else {
            failed = true
            status = L10n.tr("module.cashier.product_report_print_pending")
            return
        }
        printing = true
        defer { printing = false }
        var lines = ["Raport produse", heading]
        for band in bands {
            lines.append(band.name)
            for product in band.rows {
                let qty = SupplierFormatting.stockQuantityString(product.quantity)
                lines.append("\(qty) \(product.unit)  \(product.code)")
                if !product.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lines.append(product.name)
                }
                lines.append("Pret \(SupplierFormatting.amountString(product.price))  Total \(SupplierFormatting.amountString(product.value))")
            }
            lines.append("Subtotal \(SupplierFormatting.amountString(band.subtotal))")
        }
        lines.append("TOTAL \(SupplierFormatting.amountString(grandTotal))")
        let reply = await FiscalNetStation.send(
            fileName: FiscalNet.fileName(prefix: "rp", nonFiscal: true),
            commands: FiscalNet.nonFiscal(lines, documentUrl: ""),
            timeout: 90
        )
        if reply.bonOk != 1 {
            failed = true
            status = FiscalNet.failure(reply, fallback: L10n.tr("module.cashier.product_report_print_failed"))
        } else {
            failed = false
            status = L10n.tr("module.cashier.product_report_printed")
        }
    }

    private static func label(_ sheet: SalesSavedZSheet) -> String {
        let parts = sheet.sheetDate.split(separator: "-")
        var shown = sheet.sheetDate
        if parts.count == 3,
           let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
           let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) {
            let adjusted = sheet.shiftNo == 2 ? Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: date) ?? date : date
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "ro_RO")
            formatter.dateFormat = "dd.MM.yyyy"
            shown = formatter.string(from: adjusted)
        }
        let number = sheet.zNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let z = number.isEmpty ? "—" : number
        return L10n.tr("module.cashier.product_report_z", z, shown, sheet.shiftNo)
    }
}
