import SwiftUI

struct InvoiceReceptionSection: View {
    @Binding var options: InvoiceReceptionOptions
    let requirements: InvoiceReceptionRequirements
    let workLocations: [CompanyWorkLocation]
    let warehouses: [CompanyWarehouse]
    let showCreateNIRToggle: Bool

    private var activeWorkLocations: [CompanyWorkLocation] {
        workLocations.filter(\.isActive)
    }

    private var activeWarehouses: [CompanyWarehouse] {
        warehouses.filter(\.isActive)
    }

    private var filteredWarehouses: [CompanyWarehouse] {
        activeWarehouses.filter { warehouse in
            guard let selectedWorkLocationId = options.workLocationId else { return true }
            guard let warehouseWorkLocationId = warehouse.workLocationId else { return true }
            return warehouseWorkLocationId == selectedWorkLocationId
        }
    }

    var body: some View {
        if requirements.hasAnyReceptionField || showCreateNIRToggle {
            Section(header: Text(L10n.tr("invoices.section_reception"))) {
                if requirements.requiresWorkLocation {
                    Picker(L10n.tr("invoices.field_work_location_required"), selection: workLocationBinding) {
                        Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                        ForEach(activeWorkLocations) { location in
                            Text(location.denumire).tag(Optional(location.id))
                        }
                    }
                }

                if requirements.requiresWarehouse {
                    Picker(L10n.tr("invoices.field_warehouse_required"), selection: warehouseBinding) {
                        Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                        ForEach(filteredWarehouses) { warehouse in
                            Text(warehouse.denumire).tag(Optional(warehouse.id))
                        }
                    }

                    if filteredWarehouses.isEmpty {
                        Text(L10n.tr("invoices.no_warehouses"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }

                if showCreateNIRToggle {
                    Toggle(L10n.tr("invoices.create_nir"), isOn: $options.createNIR)
                    Text(L10n.tr("invoices.create_nir_hint"))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                }
            }
        }
    }

    private var workLocationBinding: Binding<UUID?> {
        Binding(
            get: { options.workLocationId },
            set: { newValue in
                options.workLocationId = newValue
                if let warehouseId = options.warehouseId,
                   let warehouse = warehouses.first(where: { $0.id == warehouseId }),
                   let newValue,
                   let warehouseWorkLocationId = warehouse.workLocationId,
                   warehouseWorkLocationId != newValue {
                    options.warehouseId = nil
                }
            }
        )
    }

    private var warehouseBinding: Binding<UUID?> {
        Binding(
            get: { options.warehouseId },
            set: { options.warehouseId = $0 }
        )
    }
}

struct InvoiceImportReceptionSheet: View {
    @Binding var options: InvoiceReceptionOptions
    let requirements: InvoiceReceptionRequirements
    let workLocations: [CompanyWorkLocation]
    let warehouses: [CompanyWarehouse]
    let fileCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(importMessage)
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)
                }

                InvoiceReceptionSection(
                    options: $options,
                    requirements: requirements,
                    workLocations: workLocations,
                    warehouses: warehouses,
                    showCreateNIRToggle: true
                )
            }
            .navigationTitle(L10n.tr("invoices.import_reception_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("invoices.import_confirm")) {
                        onConfirm()
                    }
                    .disabled(!requirements.isValid(options))
                }
            }
        }
    }

    private var importMessage: String {
        if requirements.hasAnyReceptionField {
            return L10n.tr("invoices.import_reception_message", fileCount)
        }
        return L10n.tr("invoices.import_reception_message_nir_only", fileCount)
    }
}

struct InvoiceImportPreviewSheet: View {
    @Binding var items: [EFacturaImportPreviewItem]
    @Binding var options: InvoiceReceptionOptions
    let requirements: InvoiceReceptionRequirements
    let workLocations: [CompanyWorkLocation]
    let warehouses: [CompanyWarehouse]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var importableCount: Int {
        items.filter(\.canImport).count
    }

    private var canConfirm: Bool {
        SupplierInvoiceEFacturaImport.canImportItems(
            items,
            receptionOptions: options,
            receptionRequirements: requirements
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(L10n.tr("invoices.import_preview_message", items.count, importableCount))
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)
                }

                if requirements.hasAnyReceptionField {
                    InvoiceReceptionSection(
                        options: $options,
                        requirements: requirements,
                        workLocations: workLocations,
                        warehouses: warehouses,
                        showCreateNIRToggle: false
                    )
                }

                Section(header: Text(L10n.tr("invoices.import_preview_section_invoices"))) {
                    if items.isEmpty {
                        Text(L10n.tr("invoices.import_preview_empty"))
                            .foregroundColor(AppColors.secondary)
                    } else {
                        ForEach(items) { item in
                            InvoiceImportPreviewRow(item: itemBinding(for: item.id))
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("invoices.import_preview_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("invoices.import_confirm")) {
                        onConfirm()
                    }
                    .disabled(!canConfirm)
                }
            }
        }
    }

    private func itemBinding(for id: String) -> Binding<EFacturaImportPreviewItem> {
        Binding(
            get: {
                items.first(where: { $0.id == id })
                    ?? EFacturaImportPreviewItem(
                        id: id,
                        fileURL: URL(fileURLWithPath: "/"),
                        fileName: "",
                        invoiceNumber: "",
                        supplierName: "",
                        issueDate: Date(),
                        totalAmount: .zero,
                        currency: "RON",
                        lineCount: 0,
                        isDuplicate: false,
                        duplicateLabel: nil,
                        isCreditNote: false,
                        errorMessage: nil,
                        createNIR: false
                    )
            },
            set: { newValue in
                guard let index = items.firstIndex(where: { $0.id == id }) else { return }
                items[index] = newValue
            }
        )
    }
}

private struct InvoiceImportPreviewRow: View {
    @Binding var item: EFacturaImportPreviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.invoiceNumber)
                        .font(.headline)
                    Text(item.supplierName)
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)
                    HStack(spacing: 8) {
                        Text(SupplierFormatting.date(item.issueDate))
                        Text(SupplierFormatting.currency(item.totalAmount, code: item.currency))
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                    if item.lineCount > 0 {
                        Text(L10n.tr("invoices.import_preview_lines", item.lineCount))
                            .font(.caption2)
                            .foregroundColor(AppColors.tertiary)
                    }
                    Text(item.fileName)
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                }
                Spacer()
                if item.canImport && !item.isCreditNote {
                    Toggle(L10n.tr("invoices.create_nir"), isOn: $item.createNIR)
                        .font(.subheadline)
                }
            }

            if item.isDuplicate {
                Text(L10n.tr("invoices.import_preview_duplicate"))
                    .font(.caption)
                    .foregroundColor(.orange)
                if let duplicateLabel = item.duplicateLabel {
                    Text(duplicateLabel)
                        .font(.caption2)
                        .foregroundColor(AppColors.secondary)
                }
            } else if item.isCreditNote {
                Text(L10n.tr("invoices.import_preview_credit_note"))
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let errorMessage = item.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
        .opacity(item.canImport ? 1 : 0.75)
    }
}

struct NIRExportFlowView: View {
    let exportItem: NIRExportItem
    let defaultEmail: String?
    let onFinish: () -> Void

    var body: some View {
#if targetEnvironment(macCatalyst)
        PDFLocalSaveDocumentPicker(
            sourceURL: exportItem.pdfURL,
            onFinish: onFinish
        )
        .ignoresSafeArea()
#else
        NIRExportSheet(
            exportItem: exportItem,
            defaultEmail: defaultEmail,
            onFinish: onFinish
        )
#endif
    }
}

struct NIRExportSheet: View {
    let exportItem: NIRExportItem
    let defaultEmail: String?
    let onFinish: () -> Void

    @State private var emailAddress: String
    @State private var showShareSheet = false
    @State private var showMailSheet = false
    @State private var errorMessage: String?

    init(exportItem: NIRExportItem, defaultEmail: String?, onFinish: @escaping () -> Void) {
        self.exportItem = exportItem
        self.defaultEmail = defaultEmail
        self.onFinish = onFinish
        _emailAddress = State(initialValue: defaultEmail ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.tr("nir.export_section_document"))) {
                    AppLabeledContent(L10n.tr("nir.export_number"), value: exportItem.snapshot.nir.numarNir)
                    AppLabeledContent(L10n.tr("nir.export_invoice"), value: exportItem.snapshot.invoiceNumber)
                    AppLabeledContent(L10n.tr("nir.export_supplier"), value: exportItem.snapshot.supplier.denumire)
                }

                Section(header: Text(L10n.tr("nir.export_section_actions"))) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label(L10n.tr("nir.export_save_pdf"), systemImage: "square.and.arrow.up")
                    }

                    if DocumentExportSupport.canSendMail {
                        FormTextField(
                            title: L10n.tr("nir.export_email"),
                            text: $emailAddress,
                            keyboardType: .emailAddress,
                            autocapitalization: .never
                        )
                        Button {
                            showMailSheet = true
                        } label: {
                            Label(L10n.tr("nir.export_send_email"), systemImage: "envelope")
                        }
                        .disabled(emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Text(L10n.tr("nir.export_mail_unavailable"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.tr("nir.export_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.close"), action: onFinish)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityShareSheet(
                    items: [exportItem.pdfURL],
                    excludedActivityTypes: nil,
                    onFinish: { showShareSheet = false }
                )
            }
            .sheet(isPresented: $showMailSheet) {
                MailComposeView(
                    subject: L10n.tr(
                        "nir.export_mail_subject",
                        exportItem.snapshot.nir.numarNir,
                        exportItem.snapshot.invoiceNumber
                    ),
                    body: L10n.tr(
                        "nir.export_mail_body",
                        exportItem.snapshot.company.denumire,
                        exportItem.snapshot.invoiceNumber,
                        exportItem.snapshot.supplier.denumire
                    ),
                    recipients: [emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)],
                    attachmentURL: exportItem.pdfURL,
                    onFinish: { showMailSheet = false }
                )
            }
        }
    }
}

struct NIRExportQueueSheet: View {
    let items: [NIRExportItem]
    let defaultEmail: String?
    let onFinish: () -> Void

    @State private var selectedItem: NIRExportItem?

    var body: some View {
        NavigationView {
            List {
                if items.isEmpty {
                    Text(L10n.tr("nir.export_queue_empty"))
                        .foregroundColor(AppColors.secondary)
                } else {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.tr("nir.export_queue_item", item.snapshot.nir.numarNir))
                                    .font(.headline)
                                Text(item.snapshot.invoiceNumber)
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                                Text(item.snapshot.supplier.denumire)
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("nir.export_queue_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.close"), action: onFinish)
                }
            }
            .sheet(item: $selectedItem) { item in
                NIRExportFlowView(
                    exportItem: item,
                    defaultEmail: defaultEmail,
                    onFinish: { selectedItem = nil }
                )
            }
        }
    }
}

enum InvoiceReceptionSupport {
    static func loadOptionsData(companyId: UUID) async throws -> (workLocations: [CompanyWorkLocation], warehouses: [CompanyWarehouse]) {
        async let workLocations = WorkLocationService.fetchWorkLocations(companyId: companyId)
        async let warehouses = WarehouseService.fetchWarehouses(companyId: companyId)
        return try await (workLocations, warehouses)
    }

    static func requirements(
        workLocations: [CompanyWorkLocation],
        warehouses: [CompanyWarehouse]
    ) -> InvoiceReceptionRequirements {
        InvoiceReceptionRequirements(workLocations: workLocations, warehouses: warehouses)
    }

    static func defaultOptions(
        workLocations: [CompanyWorkLocation],
        warehouses: [CompanyWarehouse]
    ) -> InvoiceReceptionOptions {
        let reqs = requirements(workLocations: workLocations, warehouses: warehouses)
        let defaultLocation = reqs.requiresWorkLocation
            ? (workLocations.first(where: { $0.isDefault && $0.isActive }) ?? workLocations.first(where: \.isActive))
            : nil
        let defaultWarehouse = reqs.requiresWarehouse
            ? (warehouses.first { $0.isActive && $0.workLocationId == defaultLocation?.id } ?? warehouses.first(where: \.isActive))
            : nil
        return InvoiceReceptionOptions(
            workLocationId: defaultLocation?.id,
            warehouseId: defaultWarehouse?.id,
            createNIR: false
        )
    }

    static func workLocationName(
        id: UUID?,
        workLocations: [CompanyWorkLocation]
    ) -> String? {
        guard let id,
              let location = workLocations.first(where: { $0.id == id }) else {
            return nil
        }
        return location.denumire
    }

    static func warehouseName(
        id: UUID?,
        warehouses: [CompanyWarehouse]
    ) -> String? {
        guard let id,
              let warehouse = warehouses.first(where: { $0.id == id }) else {
            return nil
        }
        return warehouse.denumire
    }

    static func receptionNames(
        workLocationId: UUID?,
        warehouseId: UUID?,
        workLocations: [CompanyWorkLocation],
        warehouses: [CompanyWarehouse]
    ) -> (workLocationName: String?, warehouseName: String?) {
        (
            workLocationName(id: workLocationId, workLocations: workLocations),
            warehouseName(id: warehouseId, warehouses: warehouses)
        )
    }
}
