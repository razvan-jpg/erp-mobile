import SwiftUI

struct NomenclatoareView: View {
    let module: AppModule

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(NomenclatoareSection.allCases) { section in
                            NavigationLink {
                                NomenclatoareDestinationView(module: module, section: section)
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
                List(NomenclatoareSection.allCases) { section in
                    NavigationLink {
                        NomenclatoareDestinationView(module: module, section: section)
                    } label: {
                        NomenclatoareRowView(section: section)
                    }
                }
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(module.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NomenclatoareRowView: View {
    let section: NomenclatoareSection

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

#Preview {
    NavigationView {
        NomenclatoareView(
            module: AppModule(
                id: UUID(),
                code: ModuleCode.nomenclatoare,
                name: "Nomenclatoare",
                description: nil,
                sortOrder: 5,
                isActive: true,
                createdAt: nil
            )
        )
    }
}
