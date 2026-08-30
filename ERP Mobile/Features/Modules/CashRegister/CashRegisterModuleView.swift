import SwiftUI

private struct CashRegisterPDFPreviewItem: Identifiable {
    let id = UUID()
    let title: String
    let data: Data
}

struct CashRegisterModuleView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @StateObject private var viewModel = CashRegisterModuleViewModel()
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true
    @State private var showManualEntrySheet = false
    @State private var pdfPreviewItem: CashRegisterPDFPreviewItem?
    @State private var showErrorAlert = false

    var body: some View {
        Group {
            if isLoadingAccess {
                ProgressView(L10n.tr("module.cash_register.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if companyManager.currentCompany == nil {
                AppEmptyStateView(
                    L10n.tr("module.cash_register.no_company_selected"),
                    systemImage: "building.2.crop.circle",
                    description: Text(L10n.tr("module.no_company"))
                )
            } else if !access.canView {
                AppEmptyStateView(
                    L10n.tr("module.cash_register.access_restricted"),
                    systemImage: "lock.fill",
                    description: Text(L10n.tr("module.no_access"))
                )
            } else {
                content
            }
        }
        .navigationTitle(module.name)
        .navigationBarTitleDisplayMode(.inline)
        .appTask {
            await loadAccess()
            await viewModel.load(company: companyManager.currentCompany)
        }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task {
                await loadAccess()
                await viewModel.load(company: companyManager.currentCompany)
            }
        }
        .sheet(isPresented: $showManualEntrySheet) {
            CashRegisterManualEntrySheet(viewModel: viewModel)
        }
        .sheet(item: $pdfPreviewItem) { item in
            PDFDocumentPreviewSheet(
                title: item.title,
                pdfData: item.data,
                onClose: { pdfPreviewItem = nil }
            )
        }
        .alert(L10n.tr("common.error"), isPresented: $showErrorAlert) {
            Button(L10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { message in
            showErrorAlert = message != nil
        }
        .onChange(of: showErrorAlert) { isPresented in
            guard !isPresented else { return }
            Task { @MainActor in
                viewModel.errorMessage = nil
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                periodSection
                actionsSection
                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)
                }
                manualEntriesSection
                casaTilesSection
            }
            .padding()
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("module.cash_register.period_section"))
                .font(.headline)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("module.cash_register.from_date"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    AppDatePicker(selection: $viewModel.fromDate)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("module.cash_register.to_date"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    AppDatePicker(selection: $viewModel.toDate)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionsSection: some View {
        HStack(spacing: 12) {
            Button(L10n.tr("module.cash_register.generate")) {
                Task { await viewModel.generateRegisters() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Button(L10n.tr("module.cash_register.export_pdf")) {
                Task { await exportAllPDF() }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.dailyPages.isEmpty)
        }
    }

    private var manualEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("module.cash_register.manual_entries"))
                    .font(.headline)
                Spacer()
                Button(L10n.tr("module.cash_register.add_manual_entry")) {
                    showManualEntrySheet = true
                }
                .buttonStyle(.bordered)
            }

            if viewModel.manualEntries.isEmpty {
                Text(L10n.tr("module.cash_register.manual_empty"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
            } else {
                ForEach(viewModel.manualEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.explanation)
                                .font(.subheadline.weight(.medium))
                            Text("\(viewModel.kindLabel(entry.kind)) · \(entry.documentNumber)")
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                        Spacer()
                        Text(CashRegisterJournalFormatting.amount(entry.amount))
                            .font(.subheadline.monospacedDigit())
                        Button(role: .destructive) {
                            Task { await viewModel.deleteManualEntry(entry) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var casaTilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(L10n.tr("module.cash_register.daily_list_title"))
                    .font(.headline)
                Spacer()
                if viewModel.registersListToggleVisible {
                    Button(viewModel.registersListExpanded
                        ? L10n.tr("module.cash_register.list_show_month")
                        : L10n.tr("module.cash_register.list_show_all")) {
                        viewModel.registersListExpanded.toggle()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !viewModel.dailyPages.isEmpty && !viewModel.registersListExpanded {
                let hidden = viewModel.availableCasas.reduce(0) { $0 + viewModel.hiddenPagesCount(for: $1) }
                if hidden > 0 {
                    Text(L10n.tr("module.cash_register.list_collapsed_hint", hidden))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
            }

            if viewModel.availableCasas.count <= 1 {
                casaRegisterSection(for: .headquarters)
            } else {
                ForEach(viewModel.availableCasas, id: \.id) { casa in
                    casaRegisterSection(for: casa)
                }
            }
        }
    }

    private func casaRegisterSection(for casa: CashRegisterCasaTarget) -> some View {
        let allPages = viewModel.pages(for: casa)
        let pages = viewModel.visiblePages(for: casa)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(viewModel.casaTitle(casa), systemImage: casa.isHeadquarters ? "building.2" : "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !allPages.isEmpty {
                    Text(viewModel.registersListExpanded
                        ? L10n.tr("module.cash_register.list_days_count", allPages.count)
                        : L10n.tr("module.cash_register.list_days_month_count", pages.count))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Button(L10n.tr("module.cash_register.export_pdf")) {
                        Task { await exportPDF(for: casa) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if pages.isEmpty {
                Text(L10n.tr("module.cash_register.no_pages"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            } else {
                ForEach(pages) { page in
                    HStack {
                        Text(SupplierFormatting.date(page.date))
                        Spacer()
                        Text(CashRegisterJournalFormatting.amount(page.closingBalance))
                            .font(.caption.monospacedDigit())
                        Button(L10n.tr("module.cash_register.preview_pdf")) {
                            Task { await preview(page: page) }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func exportAllPDF() async {
        guard let data = await viewModel.exportAllPDF() else {
            viewModel.errorMessage = L10n.tr("module.cash_register.preview_failed")
            return
        }
        presentPreview(data: data, fileName: "Registru_Casa.pdf")
    }

    private func exportPDF(for casa: CashRegisterCasaTarget) async {
        guard let data = await viewModel.exportPDF(for: casa) else {
            viewModel.errorMessage = L10n.tr("module.cash_register.preview_failed")
            return
        }
        let name = "Registru_Casa_\(CashRegisterJournalFormatting.fileCasaComponent(viewModel.casaTitle(casa))).pdf"
        presentPreview(data: data, fileName: name)
    }

    private func preview(page: CashRegisterDailyJournal) async {
        guard let data = await viewModel.exportPDF(page: page) else {
            viewModel.errorMessage = L10n.tr("module.cash_register.preview_failed")
            return
        }
        presentPreview(data: data, fileName: page.fileName)
    }

    private func presentPreview(data: Data, fileName: String) {
        pdfPreviewItem = CashRegisterPDFPreviewItem(title: fileName, data: data)
    }

    private func loadAccess() async {
        isLoadingAccess = true
        guard let profile = session.currentProfile,
              let companyId = companyManager.currentCompany?.id else {
            access = .none
            isLoadingAccess = false
            return
        }
        do {
            let moduleAccess = try await ModuleAccessRights.load(moduleId: module.id, profile: profile)
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            access = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            access = .none
        }
        isLoadingAccess = false
    }
}
