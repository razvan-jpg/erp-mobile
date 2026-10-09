import SwiftUI

struct DocumentSeriesListView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var series: [DocumentSeries] = []
    @State private var locations: [CompanyWorkLocation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editor: DocumentSeries?
    @State private var showCreate = false
    @State private var pendingDelete: DocumentSeries?
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if series.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.nomenclatoare.document_series.empty"),
                    systemImage: "number",
                    description: Text(access.canCreate
                        ? L10n.tr("module.nomenclatoare.document_series.empty_create")
                        : L10n.tr("module.nomenclatoare.document_series.empty_readonly"))
                )
            } else {
                List {
                    ForEach(series) { item in
                        Button {
                            editor = item
                        } label: {
                            DocumentSeriesRow(item: item, locationName: locationName(item.workLocationId))
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                }
                .appScrollBottomPadding()
            }
        }
        .floatingBottomTrailing {
            if access.canCreate {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .appSymbolRenderingMode(.hierarchical)
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
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask(id: companyManager.currentCompany?.id) { await load() }
        .appRefreshable { await load() }
        .fullScreenCover(isPresented: $showCreate) {
            DocumentSeriesFormView(existing: nil, locations: locations, access: access) {
                await load()
            }
        }
        .fullScreenCover(item: $editor) { item in
            DocumentSeriesFormView(existing: item, locations: locations, access: access) {
                await load()
            }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text(L10n.tr("module.nomenclatoare.document_series.delete_title")),
                message: Text(pendingDelete.map { L10n.tr("module.nomenclatoare.document_series.delete_confirm", $0.serie) } ?? ""),
                primaryButton: .destructive(Text(L10n.tr("common.delete"))) {
                    if let pendingDelete {
                        Task { await delete(pendingDelete) }
                    }
                },
                secondaryButton: .cancel { pendingDelete = nil }
            )
        }
    }

    private func locationName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return locations.first { $0.id == id }?.denumire
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else {
            series = []
            locations = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let loadedSeries = DocumentSeriesService.fetch(companyId: companyId)
            async let loadedLocations = WorkLocationService.fetchWorkLocations(companyId: companyId)
            series = try await loadedSeries
            locations = try await loadedLocations
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        pendingDelete = series[index]
        showDeleteConfirm = true
    }

    private func delete(_ item: DocumentSeries) async {
        isLoading = true
        errorMessage = nil
        do {
            try await DocumentSeriesService.delete(id: item.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct DocumentSeriesRow: View {
    let item: DocumentSeries
    let locationName: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.serie)
                    .font(.headline)
                Text(item.seriesKind.title)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                if let locationName {
                    Text(locationName)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text(L10n.tr("module.nomenclatoare.document_series.next_short", String(item.nextNumber)))
                    .font(.caption.weight(.semibold))
                if !item.isActive {
                    Text(L10n.tr("module.nomenclatoare.document_series.inactive"))
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DocumentSeriesFormView: View {
    let existing: DocumentSeries?
    let locations: [CompanyWorkLocation]
    let access: ModuleAccessRights
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var kind: DocumentSeriesKind
    @State private var serie: String
    @State private var nextNumber: String
    @State private var locationId: UUID?
    @State private var isActive: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(existing: DocumentSeries?, locations: [CompanyWorkLocation], access: ModuleAccessRights, onSaved: @escaping () async -> Void) {
        self.existing = existing
        self.locations = locations
        self.access = access
        self.onSaved = onSaved
        _kind = State(initialValue: existing?.seriesKind ?? .fiscalCash)
        _serie = State(initialValue: existing?.serie ?? "")
        _nextNumber = State(initialValue: String(existing?.nextNumber ?? 1))
        _locationId = State(initialValue: existing?.workLocationId ?? locations.first?.id)
        _isActive = State(initialValue: existing?.isActive ?? true)
    }

    private var canEdit: Bool {
        existing == nil ? access.canCreate : access.canEdit
    }

    var body: some View {
        NavigationView {
            Form {
                Picker(L10n.tr("module.nomenclatoare.document_series.kind"), selection: $kind) {
                    ForEach(DocumentSeriesKind.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                TextField(L10n.tr("module.nomenclatoare.document_series.serie"), text: $serie)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField(L10n.tr("module.nomenclatoare.document_series.next"), text: $nextNumber)
                    .keyboardType(.numberPad)
                if kind == .fiscalCash {
                    Picker(L10n.tr("module.nomenclatoare.document_series.location"), selection: $locationId) {
                        Text(L10n.tr("module.nomenclatoare.document_series.location_none")).tag(UUID?.none)
                        ForEach(locations) { location in
                            Text(location.denumire).tag(Optional(location.id))
                        }
                    }
                    Text(L10n.tr("module.nomenclatoare.document_series.fiscal_hint"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                Toggle(L10n.tr("module.nomenclatoare.document_series.active"), isOn: $isActive)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle(existing == nil
                ? L10n.tr("module.nomenclatoare.document_series.new")
                : L10n.tr("module.nomenclatoare.document_series.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) { Task { await save() } }
                        .disabled(!canEdit || isLoading)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func save() async {
        let code = serie.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            errorMessage = L10n.tr("module.nomenclatoare.document_series.serie_required")
            return
        }
        guard let number = Int(nextNumber), number >= 1 else {
            errorMessage = L10n.tr("module.nomenclatoare.document_series.number_required")
            return
        }
        if kind == .fiscalCash && locationId == nil {
            errorMessage = L10n.tr("module.nomenclatoare.document_series.location_required")
            return
        }
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            if kind == .fiscalCash, let locationId {
                let current = try await DocumentSeriesService.fetch(companyId: companyId)
                let clash = current.contains {
                    $0.seriesKind == .fiscalCash && $0.workLocationId == locationId && $0.id != existing?.id
                }
                if clash {
                    errorMessage = L10n.tr("module.nomenclatoare.document_series.duplicate_location")
                    isLoading = false
                    return
                }
            }
            try await DocumentSeriesService.save(
                id: existing?.id,
                companyId: companyId,
                kind: kind,
                serie: code,
                nextNumber: number,
                workLocationId: locationId,
                isActive: isActive
            )
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
