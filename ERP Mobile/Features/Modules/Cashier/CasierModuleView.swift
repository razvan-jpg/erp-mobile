import Combine
import SwiftUI

@MainActor
final class CasierPosLaunch: ObservableObject {
    @Published var location: CompanyWorkLocation?
}

struct CasierModuleView: View {
    let module: AppModule

    var body: some View {
        CasierHubView(title: module.name)
            .navigationTitle(module.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CasierHubView: View {
    let title: String

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 16)],
                spacing: 16
            ) {
                NavigationLink {
                    CasierProductionView()
                } label: {
                    CasierChoiceCard(
                        title: L10n.tr("module.cashier.production"),
                        hint: L10n.tr("module.cashier.production_hint"),
                        systemImage: "gearshape.2.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CasierLocationView()
                } label: {
                    CasierChoiceCard(
                        title: L10n.tr("module.cashier.pos"),
                        hint: L10n.tr("module.cashier.pos_hint"),
                        systemImage: "barcode.viewfinder"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CasierProductionView: View {
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var localeManager: LocaleManager
    @State private var showTransfer = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button {
                    showTransfer = true
                } label: {
                    CasierActionLabel(title: L10n.tr("module.cashier.transfer_note"))
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CasierProductionNoteView()
                } label: {
                    CasierActionLabel(title: L10n.tr("module.cashier.production_note"))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(L10n.tr("module.cashier.production"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTransfer) {
            StockTransferListView()
                .environmentObject(companyManager)
                .environmentObject(session)
                .environmentObject(localeManager)
        }
    }
}

private struct CasierProductionNoteView: View {
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if products.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.cashier.production_empty"),
                    systemImage: "gearshape.2",
                    description: Text(errorMessage ?? L10n.tr("module.cashier.production_empty_hint"))
                )
            } else {
                List(products) { product in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.denumire)
                            .font(.headline)
                        if let cod = product.cod, !cod.isEmpty {
                            Text(cod)
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("module.cashier.production_note"))
        .navigationBarTitleDisplayMode(.inline)
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
    }

    private func reload() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            products = try await ProductService.fetchProducts(companyId: companyId, hasRecipe: true)
        } catch {
            products = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct CasierLocationView: View {
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var casierPos: CasierPosLaunch
    @State private var locations: [CompanyWorkLocation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            if locations.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.cashier.no_locations"),
                    systemImage: "mappin.and.ellipse",
                    description: Text(errorMessage ?? L10n.tr("module.cashier.no_locations_hint"))
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(locations) { location in
                        Button {
                            casierPos.location = location
                        } label: {
                            Text(location.denumire)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.primary)
                                .frame(maxWidth: .infinity, minHeight: 120)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(L10n.tr("module.cashier.pos"))
        .navigationBarTitleDisplayMode(.inline)
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
    }

    private func reload() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            locations = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
                .filter(\.isActive)
        } catch {
            locations = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct CasierChoiceCard: View {
    let title: String
    let hint: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(AppColors.accent)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.primary)
                Text(hint)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct CasierActionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(AppColors.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}
