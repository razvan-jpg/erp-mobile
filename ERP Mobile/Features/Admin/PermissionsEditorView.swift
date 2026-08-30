import SwiftUI

struct PermissionsEditorView: View {
    let modules: [AppModule]
    @Binding var moduleAccess: [UUID: ModuleAccessLevel]

    var body: some View {
        if modules.isEmpty {
            Text(L10n.tr("admin.no_modules_defined"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        } else {
            ForEach(modules) { module in
                VStack(alignment: .leading, spacing: 8) {
                    Text(module.name)
                        .font(.subheadline.bold())
                    if let description = module.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    Picker(L10n.tr("admin.module_access_picker"), selection: accessBinding(for: module.id)) {
                        ForEach(ModuleAccessLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func accessBinding(for moduleId: UUID) -> Binding<ModuleAccessLevel> {
        Binding(
            get: { moduleAccess[moduleId] ?? .noAccess },
            set: { moduleAccess[moduleId] = $0 }
        )
    }
}
