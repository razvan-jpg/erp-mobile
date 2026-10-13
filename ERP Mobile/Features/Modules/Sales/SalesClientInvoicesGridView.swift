import MessageUI
import SwiftUI
import UIKit

struct SalesClientInvoicesGridView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var invoices: [ClientInvoiceRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedInvoice: ClientInvoiceRow?
    @State private var pdfPreview: SalesInvoicePDFItem?
    @State private var mailPayload: SalesInvoiceMailItem?
    @State private var showMailUnavailable = false
    @State private var showEFacturaAuth = false
    @State private var efacturaSettings: CompanyEFacturaSettings?
    @State private var pendingEFacturaInvoiceId: UUID?
    @State private var showEFacturaBlocked = false
    @State private var showMacEFacturaSentConfirm = false
    @State private var macPendingInvoiceId: UUID?

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: 12)]

    var body: some View {
        Group {
            if isLoading && invoices.isEmpty {
                ProgressView(L10n.tr("module.sales.cash_sale.invoices_loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if invoices.isEmpty {
                AppEmptyStateView(
                    L10n.tr("module.sales.cash_sale.invoices_empty"),
                    systemImage: "doc.text",
                    description: Text(L10n.tr("module.sales.cash_sale.invoices_empty_hint"))
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(invoices) { invoice in
                            invoiceCard(invoice)
                        }
                    }
                    .padding()
                    .appScrollBottomPadding()
                }
            }
        }
        .safeAreaInset(edge: .top) {
            efacturaBanner
        }
        .appTask {
            await reload()
            await reloadEFacturaSettings()
        }
        .appRefreshable {
            await reload()
            await reloadEFacturaSettings()
        }
        .onChange(of: companyManager.currentCompany?.id) { _, _ in
            Task {
                await reload()
                await reloadEFacturaSettings()
            }
        }
        .sheet(item: $selectedInvoice) { invoice in
            ClientInvoiceFormView(mode: .edit(invoice), access: access) {
                await reload()
                selectedInvoice = nil
            }
        }
        .sheet(item: $pdfPreview) { item in
            PDFDocumentPreviewSheet(title: item.title, pdfData: item.data) {
                pdfPreview = nil
            }
        }
        .sheet(item: $mailPayload) { payload in
            MailComposeView(
                subject: payload.subject,
                body: payload.body,
                recipients: payload.recipients,
                attachments: payload.attachments,
                onFinish: { result in
                    let invoiceId = pendingEFacturaInvoiceId
                    mailPayload = nil
                    if payload.marksEFacturaOnSend, result == .sent, let invoiceId {
                        Task { await markEFacturaSent(invoiceId) }
                    }
                    pendingEFacturaInvoiceId = nil
                }
            )
        }
        .sheet(isPresented: $showEFacturaAuth) {
            SalesEFacturaAuthSheet()
                .environmentObject(companyManager)
                .onDisappear {
                    Task { await reloadEFacturaSettings() }
                }
        }
        .alert(L10n.tr("module.sales.cash_sale.mail_unavailable_title"), isPresented: $showMailUnavailable) {
            Button(L10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(L10n.tr("module.sales.cash_sale.mail_unavailable_body"))
        }
        .alert(L10n.tr("efactura.blocked_title"), isPresented: $showEFacturaBlocked) {
            Button(L10n.tr("efactura.open_auth")) { showEFacturaAuth = true }
            Button(L10n.tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("efactura.blocked_body"))
        }
        .alert(L10n.tr("efactura.mac_sent_confirm_title"), isPresented: $showMacEFacturaSentConfirm) {
            Button(L10n.tr("efactura.mark_sent")) {
                if let id = macPendingInvoiceId {
                    Task { await markEFacturaSent(id) }
                }
                macPendingInvoiceId = nil
            }
            Button(L10n.tr("common.cancel"), role: .cancel) {
                macPendingInvoiceId = nil
            }
        } message: {
            Text(L10n.tr("efactura.mac_sent_confirm_body", efacturaSettings?.trimmedAccountantEmail ?? ""))
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

    private var efacturaBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "building.columns")
                .foregroundColor(AppColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("efactura.banner_title"))
                    .font(.caption.weight(.semibold))
                Text(efacturaStatusText)
                    .font(.caption2)
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button(L10n.tr("efactura.setup")) {
                showEFacturaAuth = true
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private var efacturaStatusText: String {
        guard let settings = efacturaSettings else {
            return L10n.tr("efactura.banner_not_configured")
        }
        switch settings.authStatus {
        case .none:
            return L10n.tr("efactura.banner_not_configured")
        case .requested:
            return L10n.tr("efactura.banner_requested")
        case .authorized:
            if settings.isExpired {
                return L10n.tr("efactura.banner_expired", settings.validUntilText ?? "")
            }
            if let until = settings.validUntilText {
                return L10n.tr("efactura.banner_authorized_until", until)
            }
            return L10n.tr("efactura.banner_authorized")
        }
    }

    private func invoiceCard(_ invoice: ClientInvoiceRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(statusColor(invoice.status))
                    .frame(width: 8, height: 8)
                Spacer()
                Menu {
                    Button {
                        presentPDF(invoice)
                    } label: {
                        Label("PDF", systemImage: "doc.richtext")
                    }
                    Button {
                        emailPDF(invoice)
                    } label: {
                        Label(L10n.tr("module.sales.cash_sale.action_email"), systemImage: "envelope").appHoverTip(L10n.tr("module.sales.cash_sale.action_email"))
                    }
                    Button {
                        sendToEFactura(invoice)
                    } label: {
                        Label(L10n.tr("efactura.send_invoice"), systemImage: "paperplane").appHoverTip(L10n.tr("efactura.send_invoice"))
                    }
                    Button {
                        selectedInvoice = invoice
                    } label: {
                        Label(L10n.tr("module.sales.cash_sale.action_details"), systemImage: "info.circle").appHoverTip(L10n.tr("module.sales.cash_sale.action_details"))
                    }
                } label: {
                    Text(L10n.tr("module.sales.cash_sale.actions_menu"))
                        .font(.caption.weight(.semibold))
                }
            }

            Text(invoice.numarFactura)
                .font(.headline)
            Text(SupplierFormatting.date(invoice.dataFactura))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            Text(invoice.clientName)
                .font(.subheadline)
                .lineLimit(2)
            Text(SupplierFormatting.currency(invoice.sumaTotala, code: invoice.moneda))
                .font(.subheadline.weight(.semibold).monospacedDigit())
            HStack {
                Text(invoice.status.label)
                    .font(.caption2)
                    .foregroundColor(statusColor(invoice.status))
                if invoice.efacturaStatus != .none {
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(AppColors.secondary)
                    Text(invoice.efacturaStatus.label)
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .platita: return .green
        case .partial: return .orange
        case .anulata: return .red
        case .neplatita: return AppColors.accent
        }
    }

    private func reload() async {
        guard companyManager.currentCompany?.id != nil else {
            invoices = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            invoices = try await ClientService.fetchInvoices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadEFacturaSettings() async {
        guard let companyId = companyManager.currentCompany?.id else {
            efacturaSettings = nil
            return
        }
        do {
            efacturaSettings = try await CompanyEFacturaSettingsService.fetch(companyId: companyId)
        } catch {
            // Banner stays on “not configured”; do not block invoice list.
        }
    }

    private func pdfData(for invoice: ClientInvoiceRow) -> Data {
        SalesClientInvoicePDFBuilder.makePDF(invoice: invoice)
    }

    private func presentPDF(_ invoice: ClientInvoiceRow) {
        pdfPreview = SalesInvoicePDFItem(
            title: invoice.numarFactura,
            data: pdfData(for: invoice)
        )
    }

    private func emailPDF(_ invoice: ClientInvoiceRow) {
        guard DocumentExportSupport.canSendMail else {
            showMailUnavailable = true
            presentPDF(invoice)
            return
        }
        do {
            let url = try DocumentExportSupport.writeTemporaryPDF(
                data: pdfData(for: invoice),
                preferredFileName: "\(invoice.numarFactura).pdf"
            )
            pendingEFacturaInvoiceId = nil
            mailPayload = SalesInvoiceMailItem(
                subject: L10n.tr("module.sales.cash_sale.invoice_mail_subject", invoice.numarFactura),
                body: L10n.tr("module.sales.cash_sale.invoice_mail_body"),
                recipients: [],
                attachments: [MailAttachment(fileURL: url)],
                marksEFacturaOnSend: false
            )
        } catch {
            errorMessage = error.localizedDescription
            presentPDF(invoice)
        }
    }

    private func sendToEFactura(_ invoice: ClientInvoiceRow) {
        guard let company = companyManager.currentCompany else { return }
        guard let settings = efacturaSettings, settings.canSendInvoices,
              let accountant = settings.trimmedAccountantEmail else {
            showEFacturaBlocked = true
            return
        }
        guard invoice.status != .anulata else {
            errorMessage = L10n.tr("efactura.error_cancelled")
            return
        }

        let xml = ClientEFacturaUBLBuilder.makeXML(
            company: company,
            invoice: invoice,
            buyerCUI: invoice.client?.cui,
            buyerAddress: invoice.client?.adresa
        )
        let pdf = pdfData(for: invoice)
        let safeName = invoice.numarFactura
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        do {
            let xmlURL = try DocumentExportSupport.writeTemporaryFile(
                data: xml,
                preferredFileName: "eFactura_\(safeName)",
                pathExtension: "xml"
            )
            let pdfURL = try DocumentExportSupport.writeTemporaryPDF(
                data: pdf,
                preferredFileName: "\(safeName).pdf"
            )

            if DocumentExportSupport.canSendMail {
                pendingEFacturaInvoiceId = invoice.id
                mailPayload = SalesInvoiceMailItem(
                    subject: L10n.tr("efactura.invoice_mail_subject", company.denumire, invoice.numarFactura),
                    body: L10n.tr("efactura.invoice_mail_body", invoice.numarFactura, invoice.clientName),
                    recipients: [accountant],
                    attachments: [
                        MailAttachment(fileURL: xmlURL, mimeType: "application/xml"),
                        MailAttachment(fileURL: pdfURL)
                    ],
                    marksEFacturaOnSend: true
                )
            } else {
#if targetEnvironment(macCatalyst)
                DocumentExportSupport.shareOnMac(url: xmlURL)
                macPendingInvoiceId = invoice.id
                showMacEFacturaSentConfirm = true
#else
                showMailUnavailable = true
                presentPDF(invoice)
#endif
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markEFacturaSent(_ invoiceId: UUID) async {
        do {
            try await ClientService.markInvoiceEFacturaSent(id: invoiceId)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SalesInvoicePDFItem: Identifiable {
    let id = UUID()
    let title: String
    let data: Data
}

private struct SalesInvoiceMailItem: Identifiable {
    let id = UUID()
    let subject: String
    let body: String
    let recipients: [String]
    let attachments: [MailAttachment]
    let marksEFacturaOnSend: Bool
}

enum SalesClientInvoicePDFBuilder {
    static func makePDF(invoice: ClientInvoiceRow) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40
            let margin: CGFloat = 40
            let width = page.width - margin * 2
            let titleFont = UIFont.boldSystemFont(ofSize: 16)
            let body = UIFont.systemFont(ofSize: 12)

            func line(_ text: String, font: UIFont = body) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                let rect = CGRect(x: margin, y: y, width: width, height: 40)
                (text as NSString).draw(in: rect, withAttributes: attrs)
                y += 22
            }

            line(L10n.tr("module.sales.cash_sale.invoice_pdf_title"), font: titleFont)
            y += 8
            line("\(L10n.tr("invoices.field_invoice_number")): \(invoice.numarFactura)")
            line("\(L10n.tr("invoices.field_invoice_date")): \(SupplierFormatting.date(invoice.dataFactura))")
            line("\(L10n.tr("clients.field_client_required")): \(invoice.clientName)")
            line("\(L10n.tr("invoices.field_total_amount")): \(SupplierFormatting.currency(invoice.sumaTotala, code: invoice.moneda))")
            line("\(L10n.tr("invoices.field_status")): \(invoice.status.label)")
            if invoice.efacturaStatus != .none {
                line("\(L10n.tr("efactura.send_status")): \(invoice.efacturaStatus.label)")
            }
            if let notes = invoice.observatii, !notes.isEmpty {
                y += 8
                line(notes)
            }
        }
    }
}
