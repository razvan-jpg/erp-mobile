import SwiftUI
import MessageUI

struct SalesFiscalReceiptsListView: View {
    let shift: FiscalSaleShiftBucket
    let locationName: String
    let locations: [CompanyWorkLocation]
    let clientAccess: ModuleAccessRights

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var linesByReceipt: [UUID: [FiscalSaleReceiptLine]] = [:]
    @State private var isLoadingLines = false
    @State private var pdfPreview: SalesReceiptPDFItem?
    @State private var mailPayload: SalesMailPayload?
    @State private var showMailUnavailable = false
    @State private var invoiceDraft: ClientInvoiceCreateDraft?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if shift.receipts.isEmpty {
                AppEmptyStateView(
                    L10n.tr("module.sales.cash_sale.no_receipts_in_shift"),
                    systemImage: "doc.text",
                    description: Text(L10n.tr("module.sales.cash_sale.receipts_empty_hint"))
                )
            } else {
                List {
                    ForEach(Array(shift.receipts.enumerated()), id: \.element.id) { index, receipt in
                        receiptRow(receipt, sequence: index + 1)
                    }
                }
                .listStyle(.plain)
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.tr("common.close")) { presentationMode.wrappedValue.dismiss() }
            }
        }
        .appTask { await loadLines() }
        .appFullOverlay { LoadingOverlay(isLoading: isLoadingLines) }
        .sheet(item: $pdfPreview) { item in
            PDFDocumentPreviewSheet(title: item.title, pdfData: item.data) {
                pdfPreview = nil
            }
        }
        .sheet(item: $mailPayload) { payload in
            MailComposeView(
                subject: payload.subject,
                body: payload.body,
                recipients: [],
                attachmentURL: payload.fileURL,
                onFinish: { mailPayload = nil }
            )
        }
        .sheet(item: $invoiceDraft) { draft in
            ClientInvoiceFormView(
                mode: .create,
                access: clientAccess,
                createDraft: draft
            ) {
                invoiceDraft = nil
            }
        }
        .alert(L10n.tr("module.sales.cash_sale.mail_unavailable_title"), isPresented: $showMailUnavailable) {
            Button(L10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(L10n.tr("module.sales.cash_sale.mail_unavailable_body"))
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
            }
        }
    }

    private var title: String {
        if let z = shift.zNumber {
            return L10n.tr("module.sales.cash_sale.receipts_for_z_title", z)
        }
        return L10n.tr("module.sales.cash_sale.receipts_section")
    }

    private func receiptRow(_ receipt: FiscalSaleReceipt, sequence: Int) -> some View {
        let lines = linesByReceipt[receipt.id] ?? []
        let qty = lines.reduce(Decimal.zero) { $0 + abs($1.cantitate) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Button {
                        presentPDF(receipt)
                    } label: {
                        Label("PDF", systemImage: "doc.richtext")
                    }
                    Button {
                        emailPDF(receipt)
                    } label: {
                        Label(L10n.tr("module.sales.cash_sale.action_email"), systemImage: "envelope")
                    }
                    if clientAccess.canCreate {
                        Button {
                            invoiceDraft = ClientInvoiceCreateDraft(
                                sumaTotala: receipt.totalAmount,
                                dataFactura: receipt.saleDate,
                                observatii: L10n.tr(
                                    "module.sales.cash_sale.invoice_from_receipt_note",
                                    receipt.receiptNumber.isEmpty ? "\(sequence)" : receipt.receiptNumber
                                ),
                                sourceFiscalReceiptId: receipt.id
                            )
                        } label: {
                            Label(L10n.tr("module.sales.cash_sale.action_create_invoice"), systemImage: "doc.badge.plus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(numberLabel(receipt, sequence: sequence))
                        .font(.subheadline.weight(.semibold))
                    Text(SupplierFormatting.dateTime(receipt.issuedAt))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                Spacer()
                Text(SupplierFormatting.currency(receipt.totalAmount))
                    .font(.subheadline.monospacedDigit())
            }

            HStack(spacing: 12) {
                Text(receipt.displayClient)
                Text(locationName)
                if qty > 0 {
                    Text(SupplierFormatting.amountString(qty))
                } else {
                    Text("—")
                }
            }
            .font(.caption)
            .foregroundColor(AppColors.secondary)
        }
        .padding(.vertical, 4)
    }

    private func numberLabel(_ receipt: FiscalSaleReceipt, sequence: Int) -> String {
        let base = receipt.receiptNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty {
            return L10n.tr("module.sales.cash_sale.receipt_seq", sequence)
        }
        return "\(base) (\(sequence))"
    }

    private func loadLines() async {
        guard !shift.receipts.isEmpty else { return }
        isLoadingLines = true
        defer { isLoadingLines = false }
        do {
            linesByReceipt = try await FiscalSaleReceiptService.fetchLines(
                receiptIds: shift.receipts.map(\.id)
            )
        } catch {
            // Lines table may be empty / new — keep UI usable.
            linesByReceipt = [:]
        }
    }

    private func makePDFData(_ receipt: FiscalSaleReceipt) -> Data {
        let company = companyManager.currentCompany
        return FiscalSaleReceiptPDFBuilder.makePDF(
            receipt: receipt,
            lines: linesByReceipt[receipt.id] ?? [],
            companyName: company?.denumire ?? "",
            companyAddress: company?.adresa ?? "",
            companyCUI: company?.cui,
            locationName: locationName,
            cashierLabel: nil
        )
    }

    private func presentPDF(_ receipt: FiscalSaleReceipt) {
        let data = makePDFData(receipt)
        let title = receipt.receiptNumber.isEmpty
            ? L10n.tr("module.sales.cash_sale.receipt_untitled")
            : receipt.receiptNumber
        pdfPreview = SalesReceiptPDFItem(title: title, data: data)
    }

    private func emailPDF(_ receipt: FiscalSaleReceipt) {
        guard DocumentExportSupport.canSendMail else {
            showMailUnavailable = true
            presentPDF(receipt)
            return
        }
        let data = makePDFData(receipt)
        let name = (receipt.receiptNumber.isEmpty ? "bon" : receipt.receiptNumber)
            .replacingOccurrences(of: "/", with: "-")
        do {
            let url = try DocumentExportSupport.writeTemporaryPDF(data: data, preferredFileName: "\(name).pdf")
            mailPayload = SalesMailPayload(
                subject: L10n.tr("module.sales.cash_sale.mail_subject", name),
                body: L10n.tr("module.sales.cash_sale.mail_body"),
                fileURL: url
            )
        } catch {
            errorMessage = error.localizedDescription
            presentPDF(receipt)
        }
    }
}

private struct SalesReceiptPDFItem: Identifiable {
    let id = UUID()
    let title: String
    let data: Data
}

private struct SalesMailPayload: Identifiable {
    let id = UUID()
    let subject: String
    let body: String
    let fileURL: URL
}

// Make draft Identifiable for sheet(item:)
extension ClientInvoiceCreateDraft: Identifiable {
    var id: String {
        sourceFiscalReceiptId?.uuidString
            ?? "\(dataFactura.timeIntervalSince1970)-\(sumaTotala)"
    }
}
