import SwiftUI

struct SalesZReportDetailSheet: View {
    let shift: FiscalSaleShiftBucket
    let locationName: String
    let onPDF: () -> Void
    let onViewReceipts: () -> Void

    @Environment(\.presentationMode) private var presentationMode

    private var visual: BinaZReportVisualModel? {
        shift.zReport.map { ZettaModelZReportFormatter.visualModel(for: $0.reportData) }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    detailRow(L10n.tr("module.sales.cash_sale.field_location"), locationName)
                    detailRow(L10n.tr("module.sales.cash_sale.field_pos"), visual?.posNumber ?? "—")
                    detailRow(L10n.tr("module.sales.cash_sale.field_user"), visual?.user.isEmpty == false ? visual!.user : "—")
                    detailRow(L10n.tr("module.sales.cash_sale.field_from"), visual?.fromDate ?? "—")
                    detailRow(L10n.tr("module.sales.cash_sale.field_to"), visual?.toDate ?? dateFallback)
                    detailRow(L10n.tr("module.sales.cash_sale.field_documents"), "\(shift.receiptCount)")
                    HStack {
                        Text(L10n.tr("module.sales.cash_sale.field_total"))
                        Spacer()
                        Text(SupplierFormatting.currency(shift.totalAmount))
                            .fontWeight(.semibold)
                    }
                }

                if let visual {
                    Section(header: Text(L10n.tr("module.sales.cash_sale.section_payments"))) {
                        ForEach(Array(visual.payments.enumerated()), id: \.offset) { _, row in
                            HStack {
                                Text(row.label)
                                Spacer()
                                Text(row.amount?.isEmpty == false ? row.amount! : "—")
                                    .foregroundColor(AppColors.secondary)
                            }
                        }
                        HStack {
                            Text(L10n.tr("module.sales.cash_sale.field_total"))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(visual.paymentSectionTotal.isEmpty ? SupplierFormatting.currency(shift.totalAmount) : visual.paymentSectionTotal)
                                .fontWeight(.semibold)
                        }
                    }

                    Section(header: Text(L10n.tr("module.sales.cash_sale.section_vat"))) {
                        ForEach(Array(visual.vatGroups.enumerated()), id: \.offset) { _, row in
                            HStack {
                                Text(row.label)
                                Spacer()
                                Text(row.amount)
                            }
                        }
                        ForEach(Array(visual.vatLines.enumerated()), id: \.offset) { _, row in
                            HStack {
                                Text(row.label)
                                Spacer()
                                Text(row.amount)
                            }
                        }
                        HStack {
                            Text(L10n.tr("module.sales.cash_sale.field_total_vat"))
                            Spacer()
                            Text(visual.totalVAT.isEmpty ? "—" : visual.totalVAT)
                        }
                        HStack {
                            Text(L10n.tr("module.sales.cash_sale.field_total_sales"))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(visual.totalSales.isEmpty ? SupplierFormatting.currency(shift.totalAmount) : visual.totalSales)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.close")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if shift.zReport != nil {
                            Button(L10n.tr("module.sales.cash_sale.menu_sales_report"), action: onPDF)
                            Button(L10n.tr("module.sales.cash_sale.menu_pdf"), action: onPDF)
                        }
                        Button(L10n.tr("module.sales.cash_sale.menu_view_receipts"), action: onViewReceipts)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .appControlHint(L10n.tr("common.more_actions"))
                }
            }
        }
    }

    private var title: String {
        if let z = shift.zNumber {
            return L10n.tr("module.sales.cash_sale.z_detail_title", z)
        }
        return L10n.tr("module.sales.cash_sale.shift_open")
    }

    private var dateFallback: String {
        if let ends = shift.endsAt { return SupplierFormatting.dateTime(ends) }
        return SupplierFormatting.date(shift.saleDate)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .foregroundColor(AppColors.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
