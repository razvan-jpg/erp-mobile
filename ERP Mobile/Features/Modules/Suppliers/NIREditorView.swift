import SwiftUI

struct NIREditorView: View {
    let context: NIREditorContext
    let company: Company
    let createdBy: UUID?
    let onSaved: () async -> Void
    let onFinish: (NIRExportItem?) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var invoiceLines: [SupplierInvoiceLine] = []
    @State private var selectedLineIds: Set<UUID> = []
    @State private var productsById: [UUID: Product] = [:]
    @State private var linePricingByLineId: [UUID: NIRLinePricingState] = [:]
    @State private var conversionDraftByLineId: [UUID: NIRConversionDraft] = [:]
    @State private var receptionOptions = InvoiceReceptionOptions()
    @State private var receptionRequirements = InvoiceReceptionRequirements(workLocations: [], warehouses: [])
    @State private var workLocations: [CompanyWorkLocation] = []
    @State private var warehouses: [CompanyWarehouse] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var exportItem: NIRExportItem?

    private var selectableInvoiceLines: [SupplierInvoiceLine] {
        invoiceLines.filter { NIRLineEligibility.isSelectable($0) }
    }

    private var quantityExcludedLines: [SupplierInvoiceLine] {
        invoiceLines
            .filter { NIRLineEligibility.isQuantityExcluded($0) && !NIRLineEligibility.isGarantieLine($0) }
            .sorted { $0.numarLinie < $1.numarLinie }
    }

    private var selectedLines: [SupplierInvoiceLine] {
        invoiceLines
            .filter { selectedLineIds.contains($0.id) }
            .filter { NIRLineEligibility.isSelectable($0) }
            .sorted { $0.numarLinie < $1.numarLinie }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView(L10n.tr("common.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    editorContent
                }
            }
            .navigationTitle(context.existingNIR == nil ? L10n.tr("nir.editor_create_title") : L10n.tr("nir.editor_edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) {
                        onFinish(nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selectedLines.isEmpty ? L10n.tr("nir.editor_skip_action") : L10n.tr("nir.editor_save")) {
                        Task { await save() }
                    }
                    .disabled(isSaving || isLoading)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isSaving) }
            .appTask { await load() }
            .sheet(item: $exportItem) { item in
                NIRExportFlowView(
                    exportItem: item,
                    defaultEmail: company.email,
                    onFinish: {
                        exportItem = nil
                        onFinish(item)
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        List {
            Section {
                AppLabeledContent(L10n.tr("nir.export_invoice"), value: context.invoice.numarFactura)
                AppLabeledContent(L10n.tr("nir.export_supplier"), value: context.supplier.denumire)
                if let existingNIR = context.existingNIR {
                    AppLabeledContent(L10n.tr("nir.export_number"), value: existingNIR.numarNir)
                }
            }

            InvoiceReceptionSection(
                options: $receptionOptions,
                requirements: receptionRequirements,
                workLocations: workLocations,
                warehouses: warehouses,
                showCreateNIRToggle: false
            )

            if receptionRequirements.hasAnyReceptionField {
                Section {
                    Text(L10n.tr("nir.editor_reception_hint"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
            }

            Section {
                Text(L10n.tr("nir.editor_hint"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                Text(L10n.tr("nir.editor_pricing_hint"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }

            Section(header: Text(L10n.tr("nir.editor_section_lines"))) {
                if invoiceLines.isEmpty {
                    Text(L10n.tr("nir.editor_no_invoice_lines"))
                        .foregroundColor(AppColors.secondary)
                } else if selectedLines.isEmpty {
                    Text(L10n.tr("nir.editor_no_selected_lines"))
                        .foregroundColor(AppColors.secondary)
                } else if ListRowActions.prefersExplicitDeleteButton {
                    ForEach(Array(selectedLines.enumerated()), id: \.element.id) { index, line in
                        selectedLineRow(line, showsSeparator: index < selectedLines.count - 1)
                    }
                } else {
                    ForEach(Array(selectedLines.enumerated()), id: \.element.id) { index, line in
                        selectedLineRow(line, showsSeparator: index < selectedLines.count - 1)
                    }
                    .onDelete(perform: removeLines)
                }
            }

            if !excludedLines.isEmpty {
                Section(
                    header: Text(L10n.tr("nir.editor_excluded_section")),
                    footer: Text(L10n.tr("nir.editor_excluded_hint")).font(.caption)
                ) {
                    ForEach(excludedLines) { line in
                        Button {
                            addLine(line)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(line.denumire)
                                    .foregroundColor(AppColors.primary)
                                Text(excludedLineSummary(line))
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                        }
                    }
                }
            }

            if !quantityExcludedLines.isEmpty {
                Section(
                    header: Text(L10n.tr("nir.editor_non_receivable_section")),
                    footer: Text(L10n.tr("nir.editor_non_receivable_hint")).font(.caption)
                ) {
                    ForEach(quantityExcludedLines) { line in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.denumire)
                            Text(excludedLineSummary(line))
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
        }
    }

    private var excludedLines: [SupplierInvoiceLine] {
        selectableInvoiceLines
            .filter { !selectedLineIds.contains($0.id) }
            .sorted { $0.numarLinie < $1.numarLinie }
    }

    private func selectedLineRow(_ line: SupplierInvoiceLine, showsSeparator: Bool) -> some View {
        let reception = reception(for: line)
        let isRegularWidth = DeviceLayout.isRegularWidth(horizontalSizeClass)
        return VStack(alignment: .leading, spacing: 0) {
            if isRegularWidth {
                HStack(alignment: .bottom, spacing: 8) {
                    Text(line.denumire)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

                    if selectedLineIds.contains(line.id) {
                        NIRLinePricingFields(
                            line: line,
                            product: productsById[line.productId],
                            reception: reception,
                            state: pricingBinding(for: line)
                        )
                    }

                    deleteLineButton(line)
                }
            } else {
                HStack(alignment: .center, spacing: 8) {
                    Text(line.denumire)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    deleteLineButton(line)
                }
                if selectedLineIds.contains(line.id) {
                    NIRLinePricingFields(
                        line: line,
                        product: productsById[line.productId],
                        reception: reception,
                        state: pricingBinding(for: line)
                    )
                    .padding(.top, 6)
                }
            }

            if selectedLineIds.contains(line.id) {
                conversionReviewBlock(for: line, reception: reception)
            }

            if showsSeparator {
                Divider()
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
        .appSwipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                removeLine(line)
            } label: {
                Label(L10n.tr("common.delete"), systemImage: "trash")
            }
        }
    }

    private func conversionReviewBlock(
        for line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if reception.needsConversionReview {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(L10n.tr("nir.editor_conversion_review"))
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            NIRLineQuantityFields(
                reception: reception,
                factorText: conversionFactorBinding(for: line),
                stockQuantityText: conversionQuantityBinding(for: line),
                stockUnit: conversionStockUnitBinding(for: line)
            )
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(reception.needsConversionReview ? Color.red.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, 6)
    }

    @ViewBuilder
    private func deleteLineButton(_ line: SupplierInvoiceLine) -> some View {
        if ListRowActions.prefersExplicitDeleteButton {
            Button {
                removeLine(line)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .compactLineControl()
            .padding(.bottom, 2)
            .accessibilityLabel(L10n.tr("common.delete"))
        }
    }

    private func pricingBinding(for line: SupplierInvoiceLine) -> Binding<NIRLinePricingState> {
        Binding(
            get: {
                linePricingByLineId[line.id]
                    ?? NIRLinePricingState(
                        salePriceText: "",
                        markupPercentText: "",
                        productKind: .materiePrima
                    )
            },
            set: { newValue in
                let previousKind = linePricingByLineId[line.id]?.productKind
                linePricingByLineId[line.id] = newValue
                if previousKind != newValue.productKind {
                    resetConversion(for: line, allowsConversion: newValue.productKind.allowsStockConversion)
                }
            }
        )
    }

    private func allowsConversion(for line: SupplierInvoiceLine) -> Bool {
        if let kind = linePricingByLineId[line.id]?.productKind {
            return kind.allowsStockConversion
        }
        return productsById[line.productId]?.tip.allowsStockConversion ?? true
    }

    private func reception(for line: SupplierInvoiceLine) -> StockUnitConversion.Reception {
        let product = productsById[line.productId]
        let canConvert = allowsConversion(for: line)
        guard let draft = conversionDraftByLineId[line.id] else {
            return StockUnitConversion.reception(
                invoiceLine: line,
                product: product,
                allowsConversion: canConvert
            )
        }
        let stockUnitOverride = draft.stockUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        if let quantity = SupplierFormatting.parseAmount(
            draft.stockQuantityText,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        ), quantity > 0 {
            return StockUnitConversion.reception(
                invoiceLine: line,
                product: product,
                stockQuantityOverride: quantity,
                stockUnitOverride: stockUnitOverride.isEmpty ? nil : stockUnitOverride,
                allowsConversion: canConvert
            )
        }
        if let factor = SupplierFormatting.parseAmount(
            draft.factorText,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        ), factor > 0 {
            return StockUnitConversion.reception(
                invoiceLine: line,
                product: product,
                factorOverride: factor,
                stockUnitOverride: stockUnitOverride.isEmpty ? nil : stockUnitOverride,
                allowsConversion: canConvert
            )
        }
        return StockUnitConversion.reception(
            invoiceLine: line,
            product: product,
            stockUnitOverride: stockUnitOverride.isEmpty ? nil : stockUnitOverride,
            allowsConversion: canConvert
        )
    }

    private func conversionFactorBinding(for line: SupplierInvoiceLine) -> Binding<String> {
        Binding(
            get: {
                conversionDraftByLineId[line.id]?.factorText
                    ?? SupplierFormatting.amountString(reception(for: line).factor)
            },
            set: { setFactor($0, for: line) }
        )
    }

    private func conversionQuantityBinding(for line: SupplierInvoiceLine) -> Binding<String> {
        Binding(
            get: {
                conversionDraftByLineId[line.id]?.stockQuantityText
                    ?? SupplierFormatting.amountString(reception(for: line).stockQuantity)
            },
            set: { setStockQuantity($0, for: line) }
        )
    }

    private func conversionStockUnitBinding(for line: SupplierInvoiceLine) -> Binding<String> {
        Binding(
            get: {
                let draftUnit = conversionDraftByLineId[line.id]?.stockUnit
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return draftUnit.isEmpty ? reception(for: line).stockUnit : draftUnit
            },
            set: { setStockUnit($0, for: line) }
        )
    }

    private func setFactor(_ text: String, for line: SupplierInvoiceLine) {
        let product = productsById[line.productId]
        let current = reception(for: line)
        let parsed = SupplierFormatting.parseAmount(
            text,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        )
        let updated = StockUnitConversion.reception(
            invoiceLine: line,
            product: product,
            factorOverride: parsed,
            stockUnitOverride: current.stockUnit,
            allowsConversion: allowsConversion(for: line)
        )
        conversionDraftByLineId[line.id] = NIRConversionDraft(
            factorText: text,
            stockQuantityText: SupplierFormatting.amountString(updated.stockQuantity),
            stockUnit: updated.stockUnit
        )
        refreshPricingAfterConversion(for: line)
    }

    private func setStockQuantity(_ text: String, for line: SupplierInvoiceLine) {
        let product = productsById[line.productId]
        let current = reception(for: line)
        let parsed = SupplierFormatting.parseAmount(
            text,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        )
        let updated = StockUnitConversion.reception(
            invoiceLine: line,
            product: product,
            stockQuantityOverride: parsed,
            stockUnitOverride: current.stockUnit,
            allowsConversion: allowsConversion(for: line)
        )
        conversionDraftByLineId[line.id] = NIRConversionDraft(
            factorText: SupplierFormatting.amountString(updated.factor),
            stockQuantityText: text,
            stockUnit: updated.stockUnit
        )
        refreshPricingAfterConversion(for: line)
    }

    private func setStockUnit(_ unit: String, for line: SupplierInvoiceLine) {
        let current = reception(for: line)
        conversionDraftByLineId[line.id] = NIRConversionDraft(
            factorText: SupplierFormatting.amountString(current.factor),
            stockQuantityText: SupplierFormatting.amountString(current.stockQuantity),
            stockUnit: unit
        )
        refreshPricingAfterConversion(for: line)
    }

    private func refreshPricingAfterConversion(for line: SupplierInvoiceLine) {
        let product = productsById[line.productId]
        let reception = reception(for: line)
        var state = linePricingByLineId[line.id]
            ?? NIRLinePricingState.make(line: line, product: product, reception: reception)
        if NIRLinePricing.prefersPurchasePriceDefault(product: product)
            || state.productKind.usesPurchasePriceAsDefault {
            let purchase = NIRLinePricing.purchaseUnitWithVAT(line: line, reception: reception)
            state.salePriceText = SupplierFormatting.amountString(purchase)
            state.markupPercentText = SupplierFormatting.amountString(
                NIRLinePricing.markupPercent(salePrice: purchase, line: line, reception: reception)
            )
        } else {
            NIRLinePricing.applySalePriceEdit(
                state.salePriceText,
                line: line,
                reception: reception,
                to: &state
            )
        }
        linePricingByLineId[line.id] = state
    }

    private func resetConversion(for line: SupplierInvoiceLine, allowsConversion: Bool) {
        let reception = StockUnitConversion.reception(
            invoiceLine: line,
            product: productsById[line.productId],
            allowsConversion: allowsConversion
        )
        conversionDraftByLineId[line.id] = NIRConversionDraft(
            factorText: SupplierFormatting.amountString(reception.factor),
            stockQuantityText: SupplierFormatting.amountString(reception.stockQuantity),
            stockUnit: reception.stockUnit
        )
        refreshPricingAfterConversion(for: line)
    }

    private func ensureConversionDraft(for line: SupplierInvoiceLine, existing: SupplierNIRLine? = nil) {
        guard conversionDraftByLineId[line.id] == nil else { return }
        let reception: StockUnitConversion.Reception
        if let existing {
            reception = StockUnitConversion.reception(nirLine: existing)
        } else {
            reception = StockUnitConversion.reception(
                invoiceLine: line,
                product: productsById[line.productId],
                allowsConversion: allowsConversion(for: line)
            )
        }
        conversionDraftByLineId[line.id] = NIRConversionDraft(
            factorText: SupplierFormatting.amountString(reception.factor),
            stockQuantityText: SupplierFormatting.amountString(reception.stockQuantity),
            stockUnit: reception.stockUnit
        )
    }

    private func ensurePricingState(for line: SupplierInvoiceLine) {
        guard linePricingByLineId[line.id] == nil else { return }
        linePricingByLineId[line.id] = NIRLinePricingState.make(
            line: line,
            product: productsById[line.productId],
            reception: reception(for: line)
        )
    }

    private func removeLine(_ line: SupplierInvoiceLine) {
        selectedLineIds.remove(line.id)
    }

    private func addLine(_ line: SupplierInvoiceLine) {
        guard NIRLineEligibility.isSelectable(line) else { return }
        selectedLineIds.insert(line.id)
        ensureConversionDraft(for: line)
        ensurePricingState(for: line)
    }

    private func lineSummary(_ line: SupplierInvoiceLine) -> String {
        L10n.tr(
            "nir.editor_line_summary",
            SupplierFormatting.amountString(line.cantitate),
            line.unitateMasura,
            SupplierFormatting.amountString(line.pretUnitar),
            SupplierFormatting.amountString(line.sumaLinie)
        )
    }

    private func excludedLineSummary(_ line: SupplierInvoiceLine) -> String {
        let quantitySummary = L10n.tr(
            "nir.editor_excluded_line_summary",
            SupplierFormatting.amountString(line.cantitate),
            line.unitateMasura
        )
        if NIRLineEligibility.isAutoExcluded(line) {
            return L10n.tr("nir.editor_excluded_line_auto_summary", quantitySummary)
        }
        return quantitySummary
    }

    private func removeLines(at offsets: IndexSet) {
        let lines = selectedLines
        let idsToRemove = offsets.compactMap { index -> UUID? in
            guard lines.indices.contains(index) else { return nil }
            return lines[index].id
        }
        for id in idsToRemove {
            selectedLineIds.remove(id)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let loadedLinesTask = SupplierService.fetchInvoiceLines(invoiceId: context.invoice.id)
            async let receptionDataTask = InvoiceReceptionSupport.loadOptionsData(companyId: company.id)
            let loadedLines = try await loadedLinesTask
            let receptionData = try await receptionDataTask
            let products = try await ProductService.fetchProducts(ids: loadedLines.map(\.productId))
            let productsMap = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            let requirements = InvoiceReceptionSupport.requirements(
                workLocations: receptionData.workLocations,
                warehouses: receptionData.warehouses
            )
            var initialReception = InvoiceReceptionSupport.defaultOptions(
                workLocations: receptionData.workLocations,
                warehouses: receptionData.warehouses
            )
            initialReception.workLocationId = context.existingNIR?.workLocationId
                ?? context.workLocationId
                ?? context.invoice.workLocationId
                ?? initialReception.workLocationId
            initialReception.warehouseId = context.existingNIR?.warehouseId
                ?? context.warehouseId
                ?? context.invoice.warehouseId
                ?? initialReception.warehouseId
            let receivedElsewhere = try await SupplierNIRService.receivedInvoiceQuantities(
                invoiceId: context.invoice.id,
                excludingNirId: context.existingNIR?.id
            )
            var initialSelection = Set(defaultSelectedLineIds(from: loadedLines))
            var existingByInvoiceLineId: [UUID: SupplierNIRLine] = [:]
            if let existingNIR = context.existingNIR {
                let nirLines = try await SupplierNIRService.fetchNIRLines(nirId: existingNIR.id)
                existingByInvoiceLineId = Dictionary(
                    uniqueKeysWithValues: nirLines.map { ($0.invoiceLineId, $0) }
                )
                initialSelection = Set(nirLines.map(\.invoiceLineId))
                    .intersection(selectableLineIds(from: loadedLines))
            } else {
                initialSelection = initialSelection.filter { lineId in
                    guard let line = loadedLines.first(where: { $0.id == lineId }) else { return false }
                    return NIRQuantityAllocation.remaining(
                        invoiceQuantity: line.cantitate,
                        receivedOnOtherNIRs: receivedElsewhere[lineId] ?? 0
                    ) > 0
                }
            }

            var drafts: [UUID: NIRConversionDraft] = [:]
            var pricing: [UUID: NIRLinePricingState] = [:]
            for line in loadedLines {
                let product = productsMap[line.productId]
                var reception: StockUnitConversion.Reception
                if let existing = existingByInvoiceLineId[line.id] {
                    reception = StockUnitConversion.reception(nirLine: existing)
                } else {
                    reception = StockUnitConversion.reception(
                        invoiceLine: line,
                        product: product,
                        allowsConversion: product?.tip.allowsStockConversion ?? true
                    )
                }
                var state = NIRLinePricingState.make(
                    line: line,
                    product: product,
                    reception: reception
                )
                if existingByInvoiceLineId[line.id] == nil, !state.productKind.allowsStockConversion {
                    reception = StockUnitConversion.reception(
                        invoiceLine: line,
                        product: product,
                        allowsConversion: false
                    )
                    state = NIRLinePricingState.make(
                        line: line,
                        product: product,
                        reception: reception
                    )
                }
                if existingByInvoiceLineId[line.id] == nil {
                    let remaining = NIRQuantityAllocation.remaining(
                        invoiceQuantity: line.cantitate,
                        receivedOnOtherNIRs: receivedElsewhere[line.id] ?? 0
                    )
                    if remaining > 0, remaining < line.cantitate, line.cantitate > 0 {
                        let ratio = remaining / line.cantitate
                        reception.invoiceQuantity = remaining
                        reception.stockQuantity = remaining * reception.factor
                        reception.lineValue = line.sumaLinie * ratio
                        if reception.stockQuantity > 0 {
                            reception.stockUnitPrice = reception.lineValue / reception.stockQuantity
                        }
                        state = NIRLinePricingState.make(
                            line: line,
                            product: product,
                            reception: reception
                        )
                    }
                }
                drafts[line.id] = NIRConversionDraft(
                    factorText: SupplierFormatting.amountString(reception.factor),
                    stockQuantityText: SupplierFormatting.amountString(reception.stockQuantity),
                    stockUnit: reception.stockUnit
                )
                pricing[line.id] = state
            }

            await MainActor.run {
                invoiceLines = loadedLines
                selectedLineIds = initialSelection
                productsById = productsMap
                conversionDraftByLineId = drafts
                linePricingByLineId = pricing
                workLocations = receptionData.workLocations
                warehouses = receptionData.warehouses
                receptionRequirements = requirements
                receptionOptions = initialReception
                isLoading = false
            }
        } catch is CancellationError {
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func save() async {
        guard !selectedLines.isEmpty else {
            await skipWithoutNIR()
            return
        }

        isSaving = true
        errorMessage = nil
        do {
            guard receptionRequirements.isValid(receptionOptions) else {
                throw NIREditorValidationError.missingReception
            }

            let conversions = try conversionsForSelectedLines()
            let salePriceByLineId = try salePricesForSelectedLines()
            await persistNIRProductUpdates(salePriceByLineId)

            let nir = try await SupplierNIRService.saveNIR(
                context: context,
                companyId: company.id,
                selectedInvoiceLineIds: selectedLineIds,
                workLocationId: receptionOptions.workLocationId,
                warehouseId: receptionOptions.warehouseId,
                createdBy: createdBy,
                productsById: productsById,
                conversions: conversions
            )
            await onSaved()
            await MainActor.run {
                isSaving = false
            }

            let receptionNames = InvoiceReceptionSupport.receptionNames(
                workLocationId: nir.workLocationId,
                warehouseId: nir.warehouseId,
                workLocations: workLocations,
                warehouses: warehouses
            )
            do {
                let item = try await SupplierNIRService.prepareExport(
                    company: company,
                    supplier: context.supplier,
                    invoice: context.invoice,
                    nir: nir,
                    workLocationName: receptionNames.workLocationName,
                    warehouseName: receptionNames.warehouseName,
                    salePriceByLineId: salePriceByLineId
                )
                await MainActor.run {
                    exportItem = item
                }
            } catch {
                await MainActor.run {
                    onFinish(nil)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } catch let error as NIRSaveError {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        } catch let error as NIREditorValidationError {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        } catch is CancellationError {
            await MainActor.run {
                isSaving = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func conversionsForSelectedLines() throws -> [UUID: StockUnitConversion.Reception] {
        var conversions: [UUID: StockUnitConversion.Reception] = [:]
        for line in selectedLines {
            let reception = reception(for: line)
            guard reception.stockQuantity > 0, reception.factor > 0 else {
                throw NIREditorValidationError.invalidConversion
            }
            conversions[line.id] = reception
        }
        return conversions
    }

    private func salePricesForSelectedLines() throws -> [UUID: Decimal] {
        var salePriceByLineId: [UUID: Decimal] = [:]
        for line in selectedLines {
            let state = linePricingByLineId[line.id]
                ?? NIRLinePricingState.make(
                    line: line,
                    product: productsById[line.productId],
                    reception: reception(for: line)
                )

            let trimmed = state.salePriceText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard let price = ProductService.parseSalePrice(state.salePriceText) else {
                throw NIREditorValidationError.invalidSalePrice
            }

            let includeForNIR = state.productKind == .marfa
                || NIRLinePricing.hasExplicitSalePriceOverride(
                    salePrice: price,
                    line: line,
                    reception: reception(for: line)
                )
            guard includeForNIR else { continue }

            salePriceByLineId[line.id] = price
        }
        return salePriceByLineId
    }

    private func persistNIRProductUpdates(_ salePriceByLineId: [UUID: Decimal]) async {
        var kindByProductId: [UUID: ProductKind] = [:]
        var priceByProductId: [UUID: Decimal] = [:]
        var conversionByProductId: [UUID: StockUnitConversion.Reception] = [:]
        var catalogProducts = Array(productsById.values)

        for line in selectedLines {
            guard !ProductService.shouldSkipNIRProductKindUpdate(lineName: line.denumire) else { continue }

            var targetProductId = line.productId
            if let linked = productsById[line.productId],
               ProductService.isMislinkedGarantieSGRProduct(linked, lineName: line.denumire) {
                do {
                    let (correctProduct, _) = try await ProductService.findOrCreateProduct(
                        companyId: company.id,
                        cod: nil,
                        codBare: nil,
                        denumire: line.denumire,
                        descriere: nil,
                        unitateMasura: line.unitateMasura,
                        cpv: nil,
                        products: &catalogProducts
                    )
                    targetProductId = correctProduct.id
                } catch {
                    continue
                }
            }

            let productId = targetProductId

            let state = linePricingByLineId[line.id]
                ?? NIRLinePricingState.make(
                    line: line,
                    product: catalogProducts.first(where: { $0.id == productId })
                        ?? productsById[line.productId],
                    reception: reception(for: line)
                )

            if state.productKind == .marfa {
                kindByProductId[productId] = .marfa
            } else if kindByProductId[productId] == nil {
                kindByProductId[productId] = state.productKind
            }

            if let price = salePriceByLineId[line.id] {
                priceByProductId[productId] = price
            }

            if state.productKind.allowsStockConversion {
                conversionByProductId[productId] = reception(for: line)
            }
        }

        var updatedProductsById = productsById
        for product in catalogProducts where updatedProductsById[product.id] == nil {
            updatedProductsById[product.id] = product
        }
        for productId in Set(kindByProductId.keys)
            .union(priceByProductId.keys)
            .union(conversionByProductId.keys) {
            guard let product = updatedProductsById[productId] else { continue }

            if let kind = kindByProductId[productId], product.tip != kind {
                do {
                    let updated = try await ProductService.updateArticleCategory(productId: productId, tip: kind)
                    updatedProductsById[productId] = updated
                } catch {
                    continue
                }
            }

            if let price = priceByProductId[productId] {
                do {
                    let updated = try await ProductService.updatePricing(
                        productId: productId,
                        pretVanzare: price,
                        isVatPayer: company.isVatPayer
                    )
                    updatedProductsById[productId] = updated
                } catch {
                    continue
                }
            }

            if let conversion = conversionByProductId[productId],
               let current = updatedProductsById[productId] {
                let purchaseUnit = conversion.invoiceUnit.trimmingCharacters(in: .whitespacesAndNewlines)
                let needsUpdate =
                    !StockUnitConversion.unitsMatch(current.unitateMasura, conversion.stockUnit)
                    || current.factorConversie != conversion.factor
                    || (current.unitateAchizitie ?? "") != purchaseUnit
                if needsUpdate, conversion.factor > 0 {
                    do {
                        let updated = try await ProductService.updateDetails(
                            productId: productId,
                            companyId: company.id,
                            input: ProductUpdateInput(
                                denumire: current.denumire,
                                cod: current.cod,
                                codBare: current.codBare,
                                unitateMasura: conversion.stockUnit,
                                unitateAchizitie: StockUnitConversion.unitsMatch(
                                    conversion.stockUnit,
                                    purchaseUnit
                                ) ? nil : purchaseUnit,
                                factorConversie: conversion.factor,
                                tip: current.tip
                            )
                        )
                        updatedProductsById[productId] = updated
                    } catch {
                        continue
                    }
                }
            }
        }

        await MainActor.run {
            productsById = updatedProductsById
        }
    }

    private func skipWithoutNIR() async {
        isSaving = true
        errorMessage = nil
        do {
            if let existingNIR = context.existingNIR {
                try await SupplierNIRService.deleteNIR(id: existingNIR.id)
                await onSaved()
            }
            await MainActor.run {
                isSaving = false
                onFinish(nil)
                presentationMode.wrappedValue.dismiss()
            }
        } catch is CancellationError {
            await MainActor.run {
                isSaving = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
    private func defaultSelectedLineIds(from lines: [SupplierInvoiceLine]) -> [UUID] {
        lines.filter { NIRLineEligibility.isReceivable($0) }.map(\.id)
    }

    private func selectableLineIds(from lines: [SupplierInvoiceLine]) -> [UUID] {
        lines.filter { NIRLineEligibility.isSelectable($0) }.map(\.id)
    }
}

private struct NIRConversionDraft: Equatable {
    var factorText: String
    var stockQuantityText: String
    var stockUnit: String
}

private struct NIRLineQuantityFields: View {
    let reception: StockUnitConversion.Reception
    @Binding var factorText: String
    @Binding var stockQuantityText: String
    @Binding var stockUnit: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("nir.editor_field_invoice_qty"))
                    .font(.caption2)
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(1)
                Text(
                    "\(SupplierFormatting.amountString(reception.invoiceQuantity)) \(reception.invoiceUnit)"
                )
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .frame(minWidth: 72, alignment: .leading)

            CompactFormField(
                title: L10n.tr("nir.editor_field_factor", reception.invoiceUnit, stockUnitDisplay),
                text: $factorText,
                width: 78
            )

            CompactFormField(
                title: L10n.tr("nir.editor_field_nir_qty"),
                text: $stockQuantityText,
                width: 72
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("nir.editor_field_stock_unit"))
                    .font(.caption2)
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(1)
                Picker(L10n.tr("nir.editor_field_stock_unit"), selection: $stockUnit) {
                    ForEach(stockUnitOptions, id: \.self) { unit in
                        Text(unit).tag(unit)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .compactLineControl()
                .frame(minWidth: 56, maxWidth: 72, alignment: .leading)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.tr("nir.editor_field_purchase_unit_price"))
                    .font(.caption2)
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(SupplierFormatting.amountString(reception.stockUnitPrice))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(minWidth: 52, alignment: .trailing)
        }
    }

    private var stockUnitDisplay: String {
        let trimmed = stockUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? reception.stockUnit : trimmed
    }

    private var stockUnitOptions: [String] {
        var options = ProductStockUnit.allCases.map(\.rawValue)
        let current = stockUnitDisplay
        if !current.isEmpty, ProductStockUnit.resolve(current) == nil {
            options.append(current)
        }
        return options
    }
}

private enum NIREditorValidationError: LocalizedError {
    case invalidSalePrice
    case missingReception
    case invalidConversion

    var errorDescription: String? {
        switch self {
        case .invalidSalePrice:
            return L10n.tr("nir.editor_invalid_sale_price")
        case .missingReception:
            return L10n.tr("invoices.reception_required")
        case .invalidConversion:
            return L10n.tr("nir.editor_invalid_conversion")
        }
    }
}

struct NIREditorQueueView: View {
    @Binding var contexts: [NIREditorContext]
    let company: Company
    let createdBy: UUID?
    let onSaved: () async -> Void
    let onFinish: () -> Void

    @State private var currentContext: NIREditorContext?

    var body: some View {
        Color.clear
            .onAppear {
                if currentContext == nil {
                    presentNext()
                }
            }
            .fullScreenCover(item: $currentContext) { context in
                NIREditorView(
                    context: context,
                    company: company,
                    createdBy: createdBy,
                    onSaved: onSaved,
                    onFinish: { _ in
                        contexts.removeAll { $0.id == context.id }
                        currentContext = nil
                        if contexts.isEmpty {
                            onFinish()
                        } else {
                            Task { @MainActor in
                                await Task.yield()
                                presentNext()
                            }
                        }
                    }
                )
            }
    }

    private func presentNext() {
        currentContext = contexts.first
    }
}
