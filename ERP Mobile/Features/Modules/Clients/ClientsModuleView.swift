import SwiftUI

enum ClientsModuleSection: String, CaseIterable, Identifiable {
    case clientSituation
    case zetta

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clientSituation:
            return L10n.tr("module.clients.tile_situation")
        case .zetta:
            return L10n.tr("module.clients.tile_zetta")
        }
    }

    var description: String {
        switch self {
        case .clientSituation:
            return L10n.tr("module.clients.tile_situation_hint")
        case .zetta:
            return L10n.tr("module.clients.tile_zetta_hint")
        }
    }

    var systemImage: String {
        switch self {
        case .clientSituation:
            return "person.2.fill"
        case .zetta:
            return "doc.text.viewfinder"
        }
    }
}

struct ClientsModuleView: View {
    let module: AppModule

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var openSituationZReports = false

    var body: some View {
        Group {
            if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(ClientsModuleSection.allCases) { section in
                            NavigationLink {
                                ClientsModuleDestinationView(module: module, section: section)
                            } label: {
                                ModuleTileCardView(
                                    title: section.title,
                                    description: section.description,
                                    systemImage: section.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .frame(maxWidth: DeviceLayout.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }
                .appScrollBottomPadding()
            } else {
                List(ClientsModuleSection.allCases) { section in
                    NavigationLink {
                        ClientsModuleDestinationView(module: module, section: section)
                    } label: {
                        ClientsModuleRowView(section: section)
                    }
                }
                .appScrollBottomPadding()
            }
        }
        .background(
            NavigationLink(
                destination: ClientInvoicesPaymentsView(module: module, initialSection: ClientInvoicesPaymentsView.Section.zReports),
                isActive: $openSituationZReports
            ) {
                EmptyView()
            }
            .hidden()
        )
        .navigationTitle(module.name)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .clientZettaOpenSituationZReports)) { _ in
            openSituationZReports = true
        }
    }
}

struct ClientsModuleDestinationView: View {
    let module: AppModule
    let section: ClientsModuleSection

    var body: some View {
        switch section {
        case .clientSituation:
            ClientInvoicesPaymentsView(module: module)
        case .zetta:
            ZettaModuleView(module: module)
        }
    }
}

private struct ClientsModuleRowView: View {
    let section: ClientsModuleSection

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: section.systemImage)
                .font(.title3)
                .foregroundColor(AppColors.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.headline)
                Text(section.description)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
