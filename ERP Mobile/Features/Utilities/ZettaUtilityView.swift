import SwiftUI

struct ZettaUtilityView: View {
    @StateObject private var model = ZettaAppViewModel()

    var body: some View {
        ZettaImportView(
            model: model,
            erpContext: .utilityStandalone,
            showsSavedExcelTools: false,
            exportButtonTitle: L10n.tr("utilities.zetta_import.export")
        )
        .preferredColorScheme(.light)
        .navigationTitle(L10n.tr("utilities.zetta_import.title"))
        .navigationBarTitleDisplayMode(.inline)
        .appTask {
            _ = try? await UtilityTemplateService.fetchTemplate(.zReportModel)
        }
    }
}
