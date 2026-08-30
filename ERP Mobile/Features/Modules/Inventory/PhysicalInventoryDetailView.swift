import SwiftUI

struct PhysicalInventoryDetailView: View {
    let context: PhysicalInventoryContext
    let onChanged: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var inventory: PhysicalInventory
    @State private var lines: [PhysicalInventoryLine] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var exportErrorMessage: String?
    @State private var searchText = ""
    @State private var lineFilter: PhysicalInventoryLineFilter = .all
    @State private var lineToEdit: PhysicalInventoryLine?
    @State private var showProductPicker = false
    @State private var showFinalizeConfirm = false
    @State private var showScanner = false
    @State private var showExportShare = false
    @State private var showPrintSheet = false
    @State private var exportShareItems: [Any] = []
    @State private var pdfAttachmentURL: URL?

    init(context: PhysicalInventoryContext, onChanged: @escaping () async -> Void) {
        self.context = context
        self.onChanged = onChanged
        _inventory = State(initialValue: context.inventory)
    }

    private var summary: PhysicalInventorySummary {
        PhysicalInventorySummary.build(from: lines)
    }

    private var filteredLines: [PhysicalInventoryLine] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return lines.filter { line in
            guard lineFilter.matches(line) else { return false }
            guard !query.isEmpty else { return true }
            let cod = line.product?.cod ?? ""
            let barcode = line.product?.codBare ?? ""
            return line.productName.localizedCaseInsensitiveContains(query)
                || BarcodeMatching.matchesField(cod, query: query)
                || BarcodeMatching.matchesField(barcode, query: query)
        }
    }

    private var canEdit: Bool {
        context.access.canEdit && inventory.status.isEditable
    }

    var body: some View {
        NavigationView {
            Group {
                if lines.isEmpty && !isLoading {
                    AppEmptyStateView(
                        L10n.tr("inventory.physical_lines_empty"),
                        systemImage: "tray",
                        description: Text(canEdit
                            ? L10n.tr("inventory.physical_lines_empty_hint")
                            : L10n.tr("inventory.physical_lines_empty_readonly"))
                    )
                } else {
                    List {
                        summarySection
                        filterSection
                        linesSection
                    }
                    .searchableWithBarcodeScanner(
                        text: $searchText,
                        prompt: L10n.tr("inventory.search_prompt"),
                        isScannerPresented: $showScanner,
                        showsScanButton: false,
                        onScanned: handleBarcodeScan
                    )
                    .appScrollBottomPadding()
                }
            }
            .navigationTitle(L10n.tr("inventory.physical_number", inventory.numarInventar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.back")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                        }
                        .accessibilityLabel(L10n.tr("inventory.scan_barcode"))

                        Menu {
                            Button(L10n.tr("account.export_pdf"), systemImage: "doc.fill") {
                                Task { await exportPDF() }
                            }
                            Button(L10n.tr("account.print"), systemImage: "printer.fill") {
                                Task { await printPDF() }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(L10n.tr("account.export_pdf"))

                        if canEdit {
                            Menu {
                                Button {
                                    showProductPicker = true
                                } label: {
                                    Label(L10n.tr("inventory.physical_add_product"), systemImage: "plus")
                                }
                                Button {
                                    Task { await populateFromStock() }
                                } label: {
                                    Label(L10n.tr("inventory.physical_populate_from_stock"), systemImage: "shippingbox")
                                }
                                if summary.countedLines > 0 {
                                    Button {
                                        showFinalizeConfirm = true
                                    } label: {
                                        Label(L10n.tr("inventory.physical_finalize"), systemImage: "checkmark.seal")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
            .appSafeAreaInsetBottom {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .appBarBackground()
                } else if let exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .appBarBackground()
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .appTask { await reload() }
            .appRefreshable { await reload() }
            .sheet(item: $lineToEdit) { line in
                PhysicalInventoryLineEditView(
                    inventoryId: inventory.id,
                    line: line,
                    canEdit: canEdit
                ) {
                    await reload()
                    await onChanged()
                }
            }
            .sheet(isPresented: $showProductPicker) {
                PhysicalInventoryProductPickerView(
                    inventoryId: inventory.id,
                    existingProductIds: Set(lines.map(\.productId))
                ) {
                    await reload()
                    await onChanged()
                }
            }
            .alert(isPresented: $showFinalizeConfirm) {
                Alert(
                    title: Text(L10n.tr("inventory.physical_finalize_title")),
                    message: Text(finalizeMessage),
                    primaryButton: .default(Text(L10n.tr("inventory.physical_finalize"))) {
                        Task { await finalizeInventory() }
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showExportShare) {
                ActivityShareSheet(
                    items: exportShareItems,
                    excludedActivityTypes: nil,
                    onFinish: { showExportShare = false }
                )
            }
            .sheet(isPresented: $showPrintSheet) {
                if let pdfAttachmentURL,
                   let data = try? Data(contentsOf: pdfAttachmentURL) {
                    PrintDocumentView(
                        pdfData: data,
                        jobName: L10n.tr("inventory.physical_print_job", inventory.numarInventar),
                        onFinish: { showPrintSheet = false }
                    )
                }
            }
        }
    }

    private func handleBarcodeScan(_ code: String) {
        if let line = lines.first(where: { BarcodeMatching.exactMatch(productBarcode: $0.product?.codBare, scanned: code) }) {
            lineToEdit = line
        }
    }

    private func makeSnapshot() -> PhysicalInventorySnapshot {
        PhysicalInventorySnapshot(
            company: companyManager.currentCompany,
            inventory: inventory,
            lines: lines,
            summary: summary,
            generatedAt: Date()
        )
    }

    private func exportPDF() async {
        exportErrorMessage = nil
        do {
            let url = try PhysicalInventoryPDFBuilder.writeTemporaryPDF(from: makeSnapshot())
            exportShareItems = [url]
            showExportShare = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func printPDF() async {
        exportErrorMessage = nil
        do {
            pdfAttachmentURL = try PhysicalInventoryPDFBuilder.writeTemporaryPDF(from: makeSnapshot())
            showPrintSheet = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private var finalizeMessage: String {
        L10n.tr(
            "inventory.physical_finalize_confirm",
            summary.countedLines,
            summary.differenceLines,
            SupplierFormatting.amountString(summary.plusDifference),
            SupplierFormatting.amountString(summary.minusDifference)
        )
    }

    @ViewBuilder
    private var summarySection: some View {
        Section {
            AppLabeledContent(L10n.tr("inventory.physical_field_date"), value: SupplierFormatting.date(inventory.dataInventar))
            AppLabeledContent(L10n.tr("inventory.physical_status"), value: inventory.status.label)
            AppLabeledContent(L10n.tr("inventory.physical_summary_lines"), value: "\(summary.totalLines)")
            AppLabeledContent(L10n.tr("inventory.physical_summary_counted"), value: "\(summary.countedLines)")
            AppLabeledContent(L10n.tr("inventory.physical_summary_differences"), value: "\(summary.differenceLines)")
            if summary.plusDifference > 0 {
                AppLabeledContent(L10n.tr("inventory.physical_summary_plus")) {
                    Text("+\(SupplierFormatting.amountString(summary.plusDifference))")
                        .foregroundColor(.green)
                }
            }
            if summary.minusDifference > 0 {
                AppLabeledContent(L10n.tr("inventory.physical_summary_minus")) {
                    Text("−\(SupplierFormatting.amountString(summary.minusDifference))")
                        .foregroundColor(.red)
                }
            }
            if let observatii = inventory.observatii, !observatii.isEmpty {
                AppLabeledContent(L10n.tr("inventory.physical_field_notes"), value: observatii)
            }
        }
    }

    @ViewBuilder
    private var filterSection: some View {
        Section {
            Picker(L10n.tr("inventory.physical_filter_picker"), selection: $lineFilter) {
                ForEach(PhysicalInventoryLineFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    @ViewBuilder
    private var linesSection: some View {
        Section(header: Text(L10n.tr("inventory.physical_lines_section"))) {
            ForEach(filteredLines) { line in
                Button {
                    lineToEdit = line
                } label: {
                    PhysicalInventoryLineRowView(line: line)
                }
                .buttonStyle(.plain)
                .disabled(!canEdit && !line.isCounted)
            }
            .onDelete(perform: canEdit ? deleteLines : { _ in })
        }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            inventory = try await PhysicalInventoryService.fetchInventory(id: context.inventory.id)
            lines = try await PhysicalInventoryService.fetchLines(inventoryId: inventory.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func populateFromStock() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await PhysicalInventoryService.loadProductsFromStock(inventoryId: inventory.id)
            await reload()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func finalizeInventory() async {
        isLoading = true
        errorMessage = nil
        do {
            try await PhysicalInventoryService.finalize(inventoryId: inventory.id)
            await reload()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteLines(at offsets: IndexSet) {
        guard canEdit else { return }
        let items = offsets.map { filteredLines[$0] }
        Task {
            isLoading = true
            errorMessage = nil
            do {
                for line in items {
                    try await PhysicalInventoryService.deleteLine(id: line.id)
                }
                await reload()
                await onChanged()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

private struct PhysicalInventoryLineRowView: View {
    let line: PhysicalInventoryLine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(line.productName)
                .font(.headline)
            HStack(spacing: 12) {
                if let cod = line.product?.cod, !cod.isEmpty {
                    Text(cod)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                if let barcode = line.product?.codBare, !barcode.isEmpty {
                    Label(barcode, systemImage: "barcode")
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("inventory.physical_book_stock"))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    Text(quantityLabel(line.stocScriptic))
                        .font(.subheadline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.tr("inventory.physical_counted_stock"))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    Text(line.isCounted ? quantityLabel(line.cantitateNumarata ?? 0) : "—")
                        .font(.subheadline.bold())
                        .foregroundColor(line.isCounted ? .primary : .secondary)
                }
            }
            if let diferenta = line.diferenta, diferenta != 0 {
                Text(differenceLabel(diferenta))
                    .font(.caption.bold())
                    .foregroundColor(diferenta > 0 ? .green : .red)
            } else if !line.isCounted {
                Text(L10n.tr("inventory.physical_not_counted"))
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func quantityLabel(_ value: Decimal) -> String {
        "\(SupplierFormatting.amountString(value)) \(line.unitateMasura)"
    }

    private func differenceLabel(_ value: Decimal) -> String {
        let sign = value > 0 ? "+" : "−"
        return L10n.tr("inventory.physical_difference", "\(sign)\(SupplierFormatting.amountString(abs(value))) \(line.unitateMasura)")
    }
}
