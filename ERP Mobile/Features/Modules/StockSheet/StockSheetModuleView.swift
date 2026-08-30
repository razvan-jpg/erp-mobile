import SwiftUI

enum StockSheetModuleSection: String, CaseIterable, Identifiable {
    case initialStock
    case generate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .initialStock:
            return L10n.tr("module.stock_sheet.tile_initial")
        case .generate:
            return L10n.tr("module.stock_sheet.tile_generate")
        }
    }

    var description: String {
        switch self {
        case .initialStock:
            return L10n.tr("module.stock_sheet.tile_initial_hint")
        case .generate:
            return L10n.tr("module.stock_sheet.tile_generate_hint")
        }
    }

    var systemImage: String {
        switch self {
        case .initialStock:
            return "arrow.down.to.line.circle.fill"
        case .generate:
            return "list.bullet.rectangle.fill"
        }
    }
}

struct StockSheetModuleView: View {
    let module: AppModule

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(StockSheetModuleSection.allCases) { section in
                            NavigationLink {
                                StockSheetDestinationView(module: module, section: section)
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
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .appScrollBottomPadding()
            } else {
                List(StockSheetModuleSection.allCases) { section in
                    NavigationLink {
                        StockSheetDestinationView(module: module, section: section)
                    } label: {
                        StockSheetModuleRowView(section: section)
                    }
                }
                .appScrollBottomPadding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(module.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StockSheetDestinationView: View {
    let module: AppModule
    let section: StockSheetModuleSection

    var body: some View {
        switch section {
        case .initialStock:
            StockSheetInitialStockView(module: module)
        case .generate:
            StockSheetGenerateView(module: module)
        }
    }
}

private struct StockSheetModuleRowView: View {
    let section: StockSheetModuleSection

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
