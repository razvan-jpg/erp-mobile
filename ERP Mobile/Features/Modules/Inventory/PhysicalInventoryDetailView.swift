import SwiftUI

struct PhysicalInventoryDetailView: View {
    let context: PhysicalInventoryContext
    let onChanged: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var inventory: PhysicalInventory
    @State private var lines: [PhysicalInventoryLine] = []
    @State private var countedDrafts: [UUID: String] = [:]
    @State private var isLoading = false
    @State private var savingLineIds: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var exportErrorMessage: String?
    @State private var searchText = ""
    @State private var lineFilter: PhysicalInventoryLineFilter = .all
    @State private var sortColumn: PhysicalInventorySortColumn = .category
    @State private var sortAscending = true
    @State private var showProductPicker = false
    @State private var showFinalizeConfirm = false
    @State private var showReopenConfirm = false
    @State private var showScanner = false
    @State private var showExportShare = false
    @State private var showPrintSheet = false
    @State private var showGroupedList = false
    @State private var exportShareItems: [Any] = []
    @State private var pdfAttachmentURL: URL?
    @State private var focusedLineId: UUID?
    @FocusState private var focusedCountedField: UUID?

    private let borderColor = Color(.separator)
    private let categoryWidth: CGFloat = 120
    private let nameWidth: CGFloat = 220
    private let codeWidth: CGFloat = 88
    private let qtyWidth: CGFloat = 88
    private let diffWidth: CGFloat = 80
    private let unitWidth: CGFloat = 44
    private let deleteWidth: CGFloat = 36

    init(context: PhysicalInventoryContext, onChanged: @escaping () async -> Void) {
        self.context = context
        self.onChanged = onChanged
        _inventory = State(initialValue: context.inventory)
    }

    private var summary: PhysicalInventorySummary {
        PhysicalInventorySummary.build(from: lines)
    }

    private var tableWidth: CGFloat {
        categoryWidth + nameWidth + codeWidth + qtyWidth + qtyWidth + diffWidth + unitWidth + (canEdit ? deleteWidth : 0)
    }

    private var filteredLines: [PhysicalInventoryLine] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = lines.filter { line in
            guard lineFilter.matches(line) else { return false }
            guard !query.isEmpty else { return true }
            let cod = line.product?.cod ?? ""
            let barcode = line.product?.codBare ?? ""
            return line.productName.localizedCaseInsensitiveContains(query)
                || BarcodeMatching.matchesField(cod, query: query)
                || BarcodeMatching.matchesField(barcode, query: query)
        }
        return filtered.sorted(by: compareLines)
    }

    private var canEdit: Bool {
        context.access.canEdit && inventory.status.isEditable
    }

    private var canReopen: Bool {
        context.access.canEdit && inventory.status == .finalized
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
                    VStack(spacing: 0) {
                        summaryBar
                        filterBar
                        ScrollView(.horizontal, showsIndicators: true) {
                            VStack(spacing: 0) {
                                tableHeaderRow
                                ScrollView {
                                    LazyVStack(spacing: 0) {
                                        ForEach(Array(filteredLines.enumerated()), id: \.element.id) { index, line in
                                            tableRow(line: line, index: index)
                                        }
                                    }
                                    .appScrollBottomPadding()
                                }
                            }
                            .frame(width: tableWidth, alignment: .leading)
                        }
                    }
                    .searchableWithBarcodeScanner(
                        text: $searchText,
                        prompt: L10n.tr("inventory.search_prompt"),
                        isScannerPresented: $showScanner,
                        showsScanButton: false,
                        onScanned: handleBarcodeScan
                    )
                    .onChangeCompat(of: focusedCountedField) { oldValue, _ in
                        guard let oldValue,
                              let line = lines.first(where: { $0.id == oldValue }) else { return }
                        Task { await commitCounted(for: line) }
                    }
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
                        .appControlHint(L10n.tr("inventory.scan_barcode"))

                        Menu {
                            Button(L10n.tr("inventory.physical_list_by_category"), systemImage: "list.bullet.rectangle") {
                                showGroupedList = true
                            }
                            .appHoverTip(L10n.tr("inventory.physical_list_by_category"))
                            Button(L10n.tr("account.export_pdf"), systemImage: "doc.fill") {
                                Task { await exportPDF(groupByCategory: false) }
                            }
                            .appHoverTip(L10n.tr("account.export_pdf"))
                            Button(L10n.tr("inventory.physical_export_pdf_by_category"), systemImage: "doc.text.fill") {
                                Task { await exportPDF(groupByCategory: true) }
                            }
                            .appHoverTip(L10n.tr("inventory.physical_export_pdf_by_category"))
                            Button(L10n.tr("account.print"), systemImage: "printer.fill") {
                                Task { await printPDF(groupByCategory: false) }
                            }
                            .appHoverTip(L10n.tr("account.print"))
                            Button(L10n.tr("inventory.physical_print_by_category"), systemImage: "printer") {
                                Task { await printPDF(groupByCategory: true) }
                            }
                            .appHoverTip(L10n.tr("inventory.physical_print_by_category"))
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .appControlHint(L10n.tr("account.export_pdf"))

                        if canEdit || canReopen {
                            Menu {
                                if canEdit {
                                    Button {
                                        showProductPicker = true
                                    } label: {
                                        Label(L10n.tr("inventory.physical_add_product"), systemImage: "plus").appHoverTip(L10n.tr("inventory.physical_add_product"))
                                    }
                                    Button {
                                        Task { await populateFromStock() }
                                    } label: {
                                        Label(L10n.tr("inventory.physical_refresh_products"), systemImage: "arrow.clockwise").appHoverTip(L10n.tr("inventory.physical_refresh_products"))
                                    }
                                    if summary.countedLines > 0 {
                                        Button {
                                            showFinalizeConfirm = true
                                        } label: {
                                            Label(L10n.tr("inventory.physical_finalize"), systemImage: "checkmark.seal").appHoverTip(L10n.tr("inventory.physical_finalize"))
                                        }
                                    }
                                }
                                if canReopen {
                                    Button {
                                        showReopenConfirm = true
                                    } label: {
                                        Label(L10n.tr("inventory.physical_reopen"), systemImage: "pencil").appHoverTip(L10n.tr("inventory.physical_reopen"))
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .appControlHint(L10n.tr("common.more_actions"))
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
            .appTask { await reload(populateIfOpen: true) }
            .appRefreshable { await reload(populateIfOpen: true) }
            .sheet(isPresented: $showProductPicker) {
                PhysicalInventoryProductPickerView(
                    inventoryId: inventory.id,
                    existingProductIds: Set(lines.map(\.productId))
                ) {
                    await reload(populateIfOpen: false)
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
            .alert(isPresented: $showReopenConfirm) {
                Alert(
                    title: Text(L10n.tr("inventory.physical_reopen_title")),
                    message: Text(L10n.tr("inventory.physical_reopen_confirm")),
                    primaryButton: .default(Text(L10n.tr("inventory.physical_reopen"))) {
                        Task { await reopenInventory() }
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showGroupedList) {
                PhysicalInventoryGroupedListView(
                    snapshot: makeSnapshot(groupByCategory: true),
                    onExportPDF: { await exportPDF(groupByCategory: true) },
                    onPrintPDF: { await printPDF(groupByCategory: true) }
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

    private var summaryBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(inventory.status.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(inventory.status == .open ? Color.orange.opacity(0.18) : Color.green.opacity(0.18))
                    .clipShape(Capsule())
                Text(SupplierFormatting.date(inventory.dataInventar))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                Spacer()
                Text("\(summary.countedLines)/\(summary.totalLines)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(AppColors.secondary)
            }
            HStack(spacing: 12) {
                summaryChip(L10n.tr("inventory.physical_summary_differences"), "\(summary.differenceLines)")
                if summary.plusDifference > 0 {
                    summaryChip(L10n.tr("inventory.physical_summary_plus"), "+\(SupplierFormatting.stockQuantityString(summary.plusDifference))", color: .green)
                }
                if summary.minusDifference > 0 {
                    summaryChip(L10n.tr("inventory.physical_summary_minus"), "−\(SupplierFormatting.stockQuantityString(summary.minusDifference))", color: .red)
                }
            }
            if canEdit {
                Text(L10n.tr("inventory.physical_table_hint"))
                    .font(.caption2)
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08))
    }

    private func summaryChip(_ title: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundColor(AppColors.tertiary)
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }

    private var filterBar: some View {
        Picker(L10n.tr("inventory.physical_filter_picker"), selection: $lineFilter) {
            ForEach(PhysicalInventoryLineFilter.allCases) { filter in
                Text(filter.label).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var tableHeaderRow: some View {
        HStack(spacing: 0) {
            sortHeader(.category, width: categoryWidth)
            sortHeader(.name, width: nameWidth)
            sortHeader(.code, width: codeWidth)
            sortHeader(.bookStock, width: qtyWidth)
            sortHeader(.counted, width: qtyWidth)
            sortHeader(.difference, width: diffWidth)
            headerCell(L10n.tr("inventory.physical_field_unit_short"), width: unitWidth)
            if canEdit {
                Color.clear.frame(width: deleteWidth)
            }
        }
        .frame(width: tableWidth, alignment: .leading)
        .background(Color.secondary.opacity(0.14))
        .appOverlay(alignment: .bottom) {
            Rectangle().frame(height: 0.5).foregroundColor(borderColor)
        }
    }

    private func sortHeader(_ column: PhysicalInventorySortColumn, width: CGFloat) -> some View {
        Button {
            if sortColumn == column {
                sortAscending.toggle()
            } else {
                sortColumn = column
                sortAscending = true
            }
        } label: {
            HStack(spacing: 2) {
                Text(column.label)
                    .font(.caption2.bold())
                    .lineLimit(1)
                if sortColumn == column {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundColor(.primary)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appOverlay(alignment: .trailing) {
            Rectangle().frame(width: 0.5).foregroundColor(borderColor)
        }
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.caption2.bold())
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .appOverlay(alignment: .trailing) {
                Rectangle().frame(width: 0.5).foregroundColor(borderColor)
            }
    }

    private func tableRow(line: PhysicalInventoryLine, index: Int) -> some View {
        let draft = countedDrafts[line.id] ?? countedDisplay(for: line)
        let parsed = SupplierFormatting.parseAmount(
            draft,
            maxFractionDigits: SupplierFormatting.stockQuantityMaxFractionDigits
        )
        let liveDiff: Decimal? = {
            if let parsed { return parsed - line.stocScriptic }
            return line.diferenta
        }()
        let isFocused = focusedLineId == line.id || focusedCountedField == line.id

        return HStack(spacing: 0) {
            Text(line.categoryLabel)
                .font(.caption)
                .foregroundColor(AppColors.secondary)
                .lineLimit(2)
                .frame(width: categoryWidth, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)

            Text(line.productName)
                .font(.subheadline)
                .lineLimit(2)
                .frame(width: nameWidth, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)

            Text(line.product?.cod ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundColor(AppColors.secondary)
                .frame(width: codeWidth, alignment: .leading)
                .padding(.horizontal, 6)

            Text(SupplierFormatting.stockQuantityString(line.stocScriptic))
                .font(.subheadline.monospacedDigit())
                .frame(width: qtyWidth, alignment: .trailing)
                .padding(.horizontal, 6)

            Group {
                if canEdit {
                    TextField("—", text: binding(for: line))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.monospacedDigit().bold())
                        .focused($focusedCountedField, equals: line.id)
                        .onSubmit { Task { await commitCounted(for: line) } }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.secondarySystemBackground))
                        )
                } else {
                    Text(line.isCounted ? SupplierFormatting.stockQuantityString(line.cantitateNumarata ?? 0) : "—")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundColor(line.isCounted ? .primary : .secondary)
                }
            }
            .frame(width: qtyWidth, alignment: .trailing)
            .padding(.horizontal, 4)

            Text(differenceText(liveDiff))
                .font(.caption.bold().monospacedDigit())
                .foregroundColor(differenceColor(liveDiff))
                .frame(width: diffWidth, alignment: .trailing)
                .padding(.horizontal, 6)

            Text(line.unitateMasura)
                .font(.caption2)
                .foregroundColor(AppColors.secondary)
                .frame(width: unitWidth, alignment: .leading)
                .padding(.horizontal, 4)

            if canEdit {
                Button {
                    Task { await deleteLine(line) }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(width: deleteWidth, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(savingLineIds.contains(line.id))
                .appControlHint(L10n.tr("common.delete"))
            }
        }
        .frame(width: tableWidth, alignment: .leading)
        .background(isFocused ? Color.accentColor.opacity(0.10) : rowBackground(for: index))
        .opacity(savingLineIds.contains(line.id) ? 0.55 : 1)
        .appOverlay(alignment: .bottom) {
            Rectangle().frame(height: 0.5).foregroundColor(borderColor.opacity(0.7))
        }
        .id(line.id)
    }

    private func binding(for line: PhysicalInventoryLine) -> Binding<String> {
        Binding(
            get: { countedDrafts[line.id] ?? countedDisplay(for: line) },
            set: { countedDrafts[line.id] = $0 }
        )
    }

    private func countedDisplay(for line: PhysicalInventoryLine) -> String {
        guard let counted = line.cantitateNumarata else { return "" }
        return SupplierFormatting.stockQuantityString(counted)
    }

    private func rowBackground(for index: Int) -> Color {
        index.isMultiple(of: 2) ? Color(.systemBackground) : Color.secondary.opacity(0.08)
    }

    private func differenceText(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        if value == 0 { return "0" }
        let sign = value > 0 ? "+" : "−"
        return "\(sign)\(SupplierFormatting.stockQuantityString(abs(value)))"
    }

    private func differenceColor(_ value: Decimal?) -> Color {
        guard let value, value != 0 else { return AppColors.secondary }
        return value > 0 ? .green : .red
    }

    private func compareLines(_ lhs: PhysicalInventoryLine, _ rhs: PhysicalInventoryLine) -> Bool {
        let ascending = sortAscending
        let result: ComparisonResult
        switch sortColumn {
        case .category:
            if lhs.categorySortIndex != rhs.categorySortIndex {
                result = lhs.categorySortIndex < rhs.categorySortIndex ? .orderedAscending : .orderedDescending
            } else {
                result = lhs.categoryLabel.localizedStandardCompare(rhs.categoryLabel)
            }
        case .name:
            result = lhs.productName.localizedStandardCompare(rhs.productName)
        case .code:
            result = (lhs.product?.cod ?? "").localizedStandardCompare(rhs.product?.cod ?? "")
        case .bookStock:
            result = compareDecimal(lhs.stocScriptic, rhs.stocScriptic)
        case .counted:
            result = compareOptionalDecimal(lhs.cantitateNumarata, rhs.cantitateNumarata)
        case .difference:
            result = compareOptionalDecimal(lhs.diferenta, rhs.diferenta)
        }
        switch result {
        case .orderedAscending: return ascending
        case .orderedDescending: return !ascending
        case .orderedSame:
            if sortColumn != .name {
                let byName = lhs.productName.localizedStandardCompare(rhs.productName)
                if byName != .orderedSame { return byName == .orderedAscending }
            }
            return (lhs.product?.cod ?? "").localizedStandardCompare(rhs.product?.cod ?? "") == .orderedAscending
        }
    }

    private func compareDecimal(_ lhs: Decimal, _ rhs: Decimal) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    private func compareOptionalDecimal(_ lhs: Decimal?, _ rhs: Decimal?) -> ComparisonResult {
        switch (lhs, rhs) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedAscending
        case (_, nil): return .orderedDescending
        case let (l?, r?): return compareDecimal(l, r)
        }
    }

    private func handleBarcodeScan(_ code: String) {
        guard let line = lines.first(where: {
            BarcodeMatching.exactMatch(productBarcode: $0.product?.codBare, scanned: code)
        }) else { return }
        searchText = ""
        focusedLineId = line.id
        focusedCountedField = line.id
    }

    private func makeSnapshot(groupByCategory: Bool = false) -> PhysicalInventorySnapshot {
        PhysicalInventorySnapshot(
            company: companyManager.currentCompany,
            inventory: inventory,
            lines: lines,
            summary: summary,
            generatedAt: Date(),
            groupByCategory: groupByCategory
        )
    }

    private func exportPDF(groupByCategory: Bool) async {
        exportErrorMessage = nil
        do {
            let url = try PhysicalInventoryPDFBuilder.writeTemporaryPDF(from: makeSnapshot(groupByCategory: groupByCategory))
#if targetEnvironment(macCatalyst)
            let suggested = url.deletingPathExtension().lastPathComponent + ".pdf"
            if !DocumentExportSupport.saveOnMac(from: url, suggestedName: suggested) {
                exportErrorMessage = L10n.tr("inventory.stock_control_save_failed")
            }
#else
            exportShareItems = [url]
            showExportShare = true
#endif
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func printPDF(groupByCategory: Bool) async {
        exportErrorMessage = nil
        do {
            let url = try PhysicalInventoryPDFBuilder.writeTemporaryPDF(from: makeSnapshot(groupByCategory: groupByCategory))
#if targetEnvironment(macCatalyst)
            try DocumentExportSupport.printPDF(
                url: url,
                jobName: L10n.tr(
                    groupByCategory
                        ? "inventory.physical_print_job_by_category"
                        : "inventory.physical_print_job",
                    inventory.numarInventar
                )
            )
#else
            pdfAttachmentURL = url
            showPrintSheet = true
#endif
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private var finalizeMessage: String {
        L10n.tr(
            "inventory.physical_finalize_confirm",
            summary.countedLines,
            summary.differenceLines,
            SupplierFormatting.stockQuantityString(summary.plusDifference),
            SupplierFormatting.stockQuantityString(summary.minusDifference)
        )
    }

    private func reload(populateIfOpen: Bool) async {
        isLoading = true
        errorMessage = nil
        do {
            inventory = try await PhysicalInventoryService.fetchInventory(id: context.inventory.id)
            if populateIfOpen, inventory.status == .open {
                _ = try await PhysicalInventoryService.loadProductsFromStock(inventoryId: inventory.id)
            }
            lines = try await PhysicalInventoryService.fetchLines(inventoryId: inventory.id)
            syncDrafts(preservingEdits: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func syncDrafts(preservingEdits: Bool) {
        var next = preservingEdits ? countedDrafts : [:]
        let ids = Set(lines.map(\.id))
        next = next.filter { ids.contains($0.key) }
        for line in lines {
            if next[line.id] == nil {
                next[line.id] = countedDisplay(for: line)
            }
        }
        countedDrafts = next
    }

    private func populateFromStock() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await PhysicalInventoryService.loadProductsFromStock(inventoryId: inventory.id)
            await reload(populateIfOpen: false)
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func finalizeInventory() async {
        isLoading = true
        errorMessage = nil
        do {
            for line in lines where canEdit {
                await commitCounted(for: line)
            }
            try await PhysicalInventoryService.finalize(inventoryId: inventory.id)
            await reload(populateIfOpen: false)
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func reopenInventory() async {
        isLoading = true
        errorMessage = nil
        do {
            try await PhysicalInventoryService.reopen(inventoryId: inventory.id)
            await reload(populateIfOpen: true)
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func commitCounted(for line: PhysicalInventoryLine) async {
        guard canEdit else { return }
        let raw = (countedDrafts[line.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            // Gol = nenumărat → la finalizare stocul rămâne intact. Doar „0” explicit face stoc 0.
            guard line.cantitateNumarata != nil else {
                countedDrafts[line.id] = ""
                return
            }
            savingLineIds.insert(line.id)
            errorMessage = nil
            do {
                try await PhysicalInventoryService.clearCountedQuantity(lineId: line.id)
                if let idx = lines.firstIndex(where: { $0.id == line.id }) {
                    lines[idx] = line.withCounted(nil)
                }
                countedDrafts[line.id] = ""
            } catch {
                errorMessage = error.localizedDescription
                countedDrafts[line.id] = countedDisplay(for: line)
            }
            savingLineIds.remove(line.id)
            return
        }
        guard let amount = SupplierFormatting.parseAmount(
            raw,
            maxFractionDigits: SupplierFormatting.stockQuantityMaxFractionDigits
        ), amount >= 0 else {
            errorMessage = L10n.tr("inventory.physical_error_invalid_quantity")
            countedDrafts[line.id] = countedDisplay(for: line)
            return
        }
        if let existing = line.cantitateNumarata, existing == amount {
            countedDrafts[line.id] = SupplierFormatting.stockQuantityString(amount)
            return
        }

        savingLineIds.insert(line.id)
        errorMessage = nil
        do {
            let updated = try await PhysicalInventoryService.upsertLine(
                inventoryId: inventory.id,
                productId: line.productId,
                cantitateNumarata: amount,
                observatii: line.observatii
            )
            if let idx = lines.firstIndex(where: { $0.id == line.id }) {
                lines[idx] = line.withCounted(updated.cantitateNumarata, stocScriptic: updated.stocScriptic)
            }
            countedDrafts[line.id] = SupplierFormatting.stockQuantityString(amount)
        } catch {
            errorMessage = error.localizedDescription
            countedDrafts[line.id] = countedDisplay(for: line)
        }
        savingLineIds.remove(line.id)
    }

    private func deleteLine(_ line: PhysicalInventoryLine) async {
        guard canEdit else { return }
        savingLineIds.insert(line.id)
        errorMessage = nil
        do {
            try await PhysicalInventoryService.deleteLine(id: line.id)
            lines.removeAll { $0.id == line.id }
            countedDrafts[line.id] = nil
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        savingLineIds.remove(line.id)
    }
}
