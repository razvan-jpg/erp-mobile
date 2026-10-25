import Supabase
import SwiftUI

/// Deschide documentul înscris pe linia fișei de magazie.
struct WarehouseCardDocumentHost: View {
    let link: WarehouseCardLink

    @Environment(\.presentationMode) private var presentationMode
    @State private var phase: Phase = .loading

    private static let readOnly = ModuleAccessRights(canView: true, canCreate: false, canEdit: false, canDelete: false)

    private enum Phase {
        case loading
        case failed(String)
        case production(ProductionVoucher)
        case consumption(ConsumptionVoucher)
        case transfer(StockTransfer, String, String)
        case nir(SupplierNIRRow)
        case inventory(PhysicalInventory)
        case invoice(SupplierInvoice, [SupplierInvoiceLine])
        case fiscal(Data, String)
    }

    var body: some View {
        VStack(spacing: 0) {
            ListingsBackButton()
            Group {
            switch phase {
            case .loading:
                ProgressView(L10n.tr("common.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                wrapped(title: L10n.tr("listings.card_document")) {
                    Text(message)
                        .foregroundColor(.red)
                        .padding()
                }
            case .production(let voucher):
                ProductionVoucherDetailView(voucher: voucher)
            case .consumption(let voucher):
                wrapped(title: voucher.numar) {
                    ConsumptionVoucherDetailView(voucher: voucher) {}
                }
            case .transfer(let transfer, let source, let destination):
                StockTransferDetailView(transfer: transfer, sourceName: source, destinationName: destination)
            case .nir(let row):
                wrapped(title: row.numarNir) {
                    NIRDetailView(row: row, access: Self.readOnly) {}
                }
            case .inventory(let inventory):
                PhysicalInventoryDetailView(
                    context: PhysicalInventoryContext(inventory: inventory, access: Self.readOnly),
                    onChanged: {}
                )
            case .invoice(let invoice, let lines):
                wrapped(title: invoice.numarFactura) {
                    invoiceBody(invoice, lines: lines)
                }
            case .fiscal(let data, let title):
                PDFDocumentPreviewSheet(title: title, pdfData: data) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        }
        .appTask { await load() }
    }

    private func wrapped<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationView {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.tr("common.close")) { presentationMode.wrappedValue.dismiss() }
                    }
                }
        }
    }

    private func invoiceBody(_ invoice: SupplierInvoice, lines: [SupplierInvoiceLine]) -> some View {
        List {
            Section {
                AppLabeledContent(L10n.tr("listings.card_col_document"), value: invoice.numarFactura)
                AppLabeledContent(L10n.tr("listings.card_col_date"), value: SupplierFormatting.date(invoice.dataFactura))
                AppLabeledContent(L10n.tr("listings.card_invoice_total"), value: SupplierFormatting.currency(invoice.sumaTotala))
            }
            Section {
                ForEach(lines) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.denumire)
                        Text("\(SupplierFormatting.stockQuantityString(line.cantitate)) \(line.unitateMasura) · \(SupplierFormatting.currency(line.sumaLinie))")
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func load() async {
        do {
            switch link {
            case .production(let id):
                phase = .production(try await ProductionVoucherService.fetchVoucher(id: id))
            case .consumption(let id):
                phase = .consumption(try await ConsumptionVoucherService.fetchVoucher(id: id))
            case .transfer(let id):
                let transfer = try await StockTransferService.fetchTransfer(id: id)
                let warehouses = try await WarehouseService.fetchWarehouses(companyId: transfer.companyId)
                let source = warehouses.first { $0.id == transfer.sourceWarehouseId }?.denumire ?? "—"
                let destination = warehouses.first { $0.id == transfer.destinationWarehouseId }?.denumire ?? "—"
                phase = .transfer(transfer, source, destination)
            case .nir(let id):
                phase = .nir(try await SupplierNIRService.fetchNIRRow(id: id))
            case .inventory(let id):
                phase = .inventory(try await PhysicalInventoryService.fetchInventory(id: id))
            case .invoice(let id):
                async let invoice = SupplierService.fetchInvoice(id: id)
                async let lines = SupplierService.fetchInvoiceLines(invoiceId: id)
                phase = .invoice(try await invoice, try await lines)
            case .fiscal(let number, let day, let locationId):
                let data = try await Self.fiscalPDF(number: number, day: day, locationId: locationId)
                phase = .fiscal(data, L10n.tr("listings.card_kind_receipt") + " " + number)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private static func fiscalPDF(number: String, day: String, locationId: UUID?) async throws -> Data {
        struct Slip: Decodable {
            let storagePath: String
            enum CodingKeys: String, CodingKey { case storagePath = "storage_path" }
        }
        let rows: [Slip]
        if let locationId {
            rows = try await SupabaseManager.client
                .from("pos_fiscal_slips")
                .select("storage_path")
                .eq("receipt_number", value: number)
                .eq("issued_on", value: day)
                .eq("work_location_id", value: locationId.uuidString)
                .limit(1)
                .execute()
                .value
        } else {
            rows = try await SupabaseManager.client
                .from("pos_fiscal_slips")
                .select("storage_path")
                .eq("receipt_number", value: number)
                .eq("issued_on", value: day)
                .limit(1)
                .execute()
                .value
        }
        guard let path = rows.first?.storagePath, !path.isEmpty else {
            throw WarehouseCardDocumentError.missingSlip
        }
        return try await PosDocumentStore.download(path: path)
    }
}

private enum WarehouseCardDocumentError: LocalizedError {
    case missingSlip
    var errorDescription: String? { L10n.tr("listings.card_slip_missing") }
}
