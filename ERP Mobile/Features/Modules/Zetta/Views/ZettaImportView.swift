import SwiftUI
#if canImport(UIKit)
import UIKit
import AVFoundation
#endif

private enum ZettaScrollAnchor {
    static let top = "zetta.scroll.top"
    static let bottom = "zetta.scroll.bottom"
}

struct ZettaImportView: View {
    @ObservedObject var model: ZettaAppViewModel
    let erpContext: ZettaERPContext
    var showsSavedExcelTools = true
    var exportButtonTitle: String?
    var onExportAndSaveCompleted: (() -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appBottomBarClearance) private var bottomBarClearance
    @State private var showHelp = false

    private var showScrollNavigation: Bool {
        !model.isProcessing && !model.scopedReports.isEmpty
    }
    #if os(iOS)
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showMediaPicker = false
    #endif

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 1100 : 720
    }

    private var contentPadding: CGFloat {
        horizontalSizeClass == .regular ? 32 : 16
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.canvasTop, .canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            header
                                .id(ZettaScrollAnchor.top)

                            if showScrollNavigation {
                                scrollNavigationButton(
                                    title: L10n.tr("module.clients.zetta_scroll_down"),
                                    systemImage: "arrow.down.circle.fill"
                                ) {
                                    scrollTo(ZettaScrollAnchor.bottom, using: scrollProxy)
                                }
                            }

                            controls
                            DropZoneView(
                                onImport: { model.importImages($0) },
                                onImportFailure: { model.reportImportReadFailure() }
                            )

                            if model.isProcessing {
                                ProgressView(model.statusMessage ?? "Se procesează…")
                                    .padding()
                            }

                            ForEach(model.scopedReports) { report in
                                ReportEditorCard(model: model, reportID: report.id)
                            }

                            if !model.scopedReports.isEmpty {
                                RowsPreview(rows: model.previewRows)
                                exportBar
                            }

                            if let status = model.statusMessage, !model.isProcessing {
                                Text(status)
                                    .font(.custom("Avenir Next", size: 13).weight(.medium))
                                    .foregroundStyle(Color.accentInk)
                            }
                            if let err = model.errorMessage {
                                Text(err)
                                    .font(.custom("Avenir Next", size: 13))
                                    .foregroundStyle(Color.dangerSoft)
                            }

                            if showScrollNavigation {
                                scrollNavigationButton(
                                    title: L10n.tr("module.clients.zetta_scroll_up"),
                                    systemImage: "arrow.up.circle.fill"
                                ) {
                                    scrollTo(ZettaScrollAnchor.top, using: scrollProxy)
                                }
                                .id(ZettaScrollAnchor.bottom)
                            }

                            if usesExportAndSave {
                                Color.clear.frame(height: 72)
                            }
                        }
                        .padding(contentPadding)
                        .frame(maxWidth: contentMaxWidth)
                        .frame(maxWidth: .infinity)
                    }
                }

                Text(AppInfo.displayVersion)
                    .font(.custom("Avenir Next", size: 13).weight(.bold))
                    .foregroundStyle(Color.labelMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .overlay(alignment: .bottomLeading) {
                if usesExportAndSave {
                    clientsBottomExportButton
                        .padding(.leading, contentPadding)
                        .padding(.bottom, 12 + bottomBarClearance)
                }
            }
        }
        .onAppear {
            model.bindERPContext(erpContext)
            if !erpContext.isUtilityStandalone {
                Task { await model.reloadZettaNCConfig() }
            }
        }
        .onChange(of: erpContext.companyId) { _ in
            model.bindERPContext(erpContext)
        }
        #if os(iOS)
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showHelp) {
            HelpView(onBack: { showHelp = false })
        }
        .overlay {
            if model.showSavedExcelWarning {
                SavedExcelWarningOverlay {
                    model.dismissSavedExcelWarningAndPickFile()
                }
            }
            if let prompt = model.savedExcelContinuePrompt {
                SavedExcelContinueOverlay(
                    firmName: prompt.firmName,
                    cui: prompt.cui
                ) {
                    model.dismissSavedExcelContinue()
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            IOSImagePicker(sourceType: .camera) { model.importImages([$0]) }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            IOSPhotoLibraryPicker(
                onPick: { model.importImages($0) },
                onFailure: { model.reportImportReadFailure() }
            )
        }
        .sheet(isPresented: $showMediaPicker) {
            IOSMediaDocumentPicker(
                onPick: { model.importImages($0) },
                onFailure: { model.reportImportReadFailure() }
            )
        }
        .sheet(isPresented: $model.showXlsxPicker) {
            IOSXlsxDocumentPicker { url in
                model.loadSavedExcel(from: url)
            }
        }
        .sheet(item: $model.pendingShare) { item in
            ZettaShareSheet(urls: item.urls) {
                model.completePendingExportUserAction()
            }
        }
        #if targetEnvironment(macCatalyst)
        .sheet(item: $model.pendingLocalSave) { item in
            LocalSaveDocumentPicker(sourceURLs: item.urls) {
                model.completePendingExportUserAction()
            }
            .ignoresSafeArea()
        }
        #endif
        #else
        .sheet(isPresented: $showHelp) {
            HelpView(onBack: { showHelp = false })
                .frame(minWidth: 560, minHeight: 720)
        }
        .overlay {
            if model.showSavedExcelWarning {
                SavedExcelWarningOverlay {
                    model.dismissSavedExcelWarningAndPickFile()
                }
            }
            if let prompt = model.savedExcelContinuePrompt {
                SavedExcelContinueOverlay(
                    firmName: prompt.firmName,
                    cui: prompt.cui
                ) {
                    model.dismissSavedExcelContinue()
                }
            }
        }
        #endif
    }

    private var usesExportAndSave: Bool {
        !erpContext.isUtilityStandalone
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        erpContext.isUtilityStandalone
                            ? L10n.tr("utilities.zetta_import.title")
                            : L10n.tr("module.clients.tile_zetta")
                    )
                        .font(.custom("Avenir Next", size: 28).weight(.bold))
                        .foregroundStyle(Color.accentInk)
                    if erpContext.isUtilityStandalone {
                        Text(L10n.tr("utilities.zetta_import.subtitle"))
                            .font(.custom("Avenir Next", size: 14).weight(.semibold))
                            .foregroundStyle(Color.accentInk.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(
                            L10n.tr(
                                "module.clients.zetta_company_context",
                                erpContext.companyName,
                                erpContext.cifLabel
                            )
                        )
                        .font(.custom("Avenir Next", size: 14).weight(.semibold))
                        .foregroundStyle(Color.accentInk.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Button("Ajutor") { showHelp = true }
                    .buttonStyle(SecondaryButtonStyle())
            }

            if !erpContext.isUtilityStandalone {
                Text(L10n.tr("module.clients.zetta_subtitle"))
                    .font(.custom("Avenir Next", size: 15).weight(.medium))
                    .foregroundStyle(Color.labelMuted)
            }

            firstAccountingNoteField

            if !erpContext.hasExpectedCUI, !erpContext.isUtilityStandalone {
                Text(L10n.tr("module.clients.zetta_no_cui_warning"))
                    .font(.custom("Avenir Next", size: 13).weight(.semibold))
                    .foregroundStyle(Color.accentWarm)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentWarm.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var firstAccountingNoteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("utilities.zetta_import.first_nc_number"))
                .font(.custom("Avenir Next", size: 13).weight(.semibold))
                .foregroundStyle(Color.accentInk)
            TextField(
                L10n.tr("utilities.zetta_import.first_nc_number_placeholder"),
                value: $model.firstAccountingNoteNumber,
                format: IntegerFormatStyle<Int>().grouping(.never)
            )
            .textFieldStyle(.roundedBorder)
            .font(.custom("Avenir Next", size: 18).weight(.bold))
            .foregroundStyle(Color.accentInk)
            .frame(maxWidth: 220)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .onChange(of: model.firstAccountingNoteNumber) { value in
                model.applyFirstAccountingNoteNumber(value)
            }
            Text(L10n.tr("utilities.zetta_import.first_nc_number_hint"))
                .font(.custom("Avenir Next", size: 12).weight(.medium))
                .foregroundStyle(Color.labelMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.fieldStroke, lineWidth: 1)
        )
    }

    private var controls: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(spacing: 12) {
                    controlItems
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    controlItems
                }
            }
        }
    }

    @ViewBuilder
    private var controlItems: some View {
        #if os(macOS) && !targetEnvironment(macCatalyst)
        MacFileImporterButton(title: "Încarcă JPG/PDF", systemImage: "photo.on.rectangle") {
            model.importImages($0)
        } onImportFailure: {
            model.reportImportReadFailure()
        }
        if showsSavedExcelTools {
            Button {
                model.beginLoadSavedExcel()
            } label: {
                Label("Încarcă xlsx salvat", systemImage: "tablecells.badge.ellipsis")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        #else
        Button {
            showMediaPicker = true
        } label: {
            Label("Încarcă JPG/PDF", systemImage: "doc.on.doc")
        }
        .buttonStyle(PrimaryButtonStyle())
        Button {
            showLibrary = true
        } label: {
            Label("Galerie", systemImage: "photo.on.rectangle")
        }
        .buttonStyle(SecondaryButtonStyle())
        .accessibilityHint("Poți selecta mai multe poze odată")

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            Button {
                Task { await openCamera() }
            } label: {
                Label("Cameră", systemImage: "camera")
            }
            .buttonStyle(SecondaryButtonStyle())
        }

        if showsSavedExcelTools {
            Button {
                model.beginLoadSavedExcel()
            } label: {
                Label("Încarcă xlsx salvat", systemImage: "tablecells.badge.ellipsis")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        #endif

        if !model.scopedReports.isEmpty {
            Button("Golește") { model.clearAll() }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    #if os(iOS)
    /// Cere permisiunea înainte, ca UIImagePickerController să nu blocheze UI-ul la primul tap.
    private func openCamera() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showCamera = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { showCamera = true }
        case .denied, .restricted:
            model.errorMessage = "Accesul la cameră este dezactivat. Activează-l din Setări → \(ZettaAppInfo.appName)."
        @unknown default:
            showCamera = true
        }
    }
    #endif

    private var exportBar: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(alignment: .center, spacing: 16) {
                    exportLabels
                    Spacer(minLength: 8)
                    if !usesExportAndSave {
                        exportButton
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    exportLabels
                    if !usesExportAndSave {
                        exportButton
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentWarm.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.accentWarm.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var exportLabels: some View {
        let groups = ExcelExporter.groupsByFirma(
            from: model.scopedReports,
            config: model.zettaNCConfig,
            namingStyle: model.exportNamingStyle,
            companyDisplayName: model.utilityCompanyDisplayName,
            startingNrInreg: model.resolvedFirstAccountingNoteNumber
        )
        let fileCount = max(groups.count, 1)
        let fileNames = groups.map(\.fileName).joined(separator: ", ")
        let detailLine = exportDetailLine(groups: groups)
        let fallbackName = ExcelExporter.suggestedFileName(
            for: model.scopedReports,
            style: model.exportNamingStyle,
            companyDisplayName: model.utilityCompanyDisplayName
        )
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(model.scopedReports.count) Z-uri → \(fileCount) Excel · \(detailLine)")
                .font(.custom("Avenir Next", size: 14).weight(.semibold))
            Text(fileNames.isEmpty ? fallbackName : fileNames)
                .font(.custom("Avenir Next", size: 12).weight(.medium))
                .foregroundStyle(Color.accentInk.opacity(0.85))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
            #if os(iOS) && !targetEnvironment(macCatalyst)
            Text(fileCount > 1
                 ? "Câte un Excel pe firmă — compatibil NextUp (fiecare fișier se importă în firma corectă)."
                 : "Un Excel pentru firma detectată. Trimite prin WhatsApp, AirDrop, e-mail sau Fișiere.")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color.labelMuted)
                .fixedSize(horizontal: false, vertical: true)
            #elseif targetEnvironment(macCatalyst)
            Text(fileCount > 1
                 ? "Câte un Excel pe firmă — compatibil NextUp. La salvare alegi folderul de destinație."
                 : "Un Excel — alege direct locația de salvare pe Mac (Desktop, Documents etc.).")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color.labelMuted)
                .fixedSize(horizontal: false, vertical: true)
            #else
            Text(fileCount > 1
                 ? "Câte un Excel pe firmă — compatibil NextUp. La export alegi folderul de destinație."
                 : "Un Excel — câte 10 rânduri (Nectarie) sau 8 rânduri (altă firmă) per Z, Nr. înreg. consecutiv de la numărul setat sus.")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color.labelMuted)
                .fixedSize(horizontal: false, vertical: true)
            #endif
        }
    }

    private func exportDetailLine(groups: [ExcelExporter.FirmExportGroup]) -> String {
        if groups.count == 1, let only = groups.first {
            let rowCount = only.rows.count
            let ncNumbers = Set(only.rows.map(\.nrInreg)).sorted()
            if ncNumbers.count <= 1 {
                return "\(rowCount) rânduri · \(only.reports.count) note contabile"
            }
            let ncRange = "\(ncNumbers.first!)–\(ncNumbers.last!)"
            return "\(rowCount) rânduri · NC \(ncRange) (\(only.reports.count) Z-uri)"
        }
        return groups.map { group in
            let ncCount = Set(group.rows.map(\.nrInreg)).count
            return "\(group.displayName): \(group.rows.count) rând. / \(ncCount) NC"
        }.joined(separator: " · ")
    }

    private var exportButton: some View {
        Button {
            model.exportExcel()
        } label: {
            exportButtonLabel(defaultTitle: utilityExportTitle)
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var clientsBottomExportButton: some View {
        Button {
            model.exportExcelAndSave(onCompleted: onExportAndSaveCompleted)
        } label: {
            exportButtonLabel(defaultTitle: L10n.tr("module.clients.zetta_export_and_save"))
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!model.isReadyForExportAndSave)
        .opacity(model.isReadyForExportAndSave ? 1 : 0.45)
    }

    private var utilityExportTitle: String {
        exportButtonTitle ?? defaultExportTitle
    }

    private var defaultExportTitle: String {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        "Exportă & trimite"
        #elseif targetEnvironment(macCatalyst)
        "Salvează Excel"
        #else
        "Exportă Excel"
        #endif
    }

    private func exportButtonLabel(defaultTitle: String) -> some View {
        Group {
            #if os(iOS) && !targetEnvironment(macCatalyst)
            Label(defaultTitle, systemImage: "square.and.arrow.up")
            #elseif targetEnvironment(macCatalyst)
            Label(defaultTitle, systemImage: "square.and.arrow.down")
            #else
            Label(defaultTitle, systemImage: "square.and.arrow.up")
            #endif
        }
    }

    private func scrollNavigationButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .labelStyle(.titleAndIcon)
                    .imageScale(.small)
            }
            .buttonStyle(CompactSecondaryButtonStyle())
        }
    }

    private func scrollTo(_ anchor: String, using scrollProxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.35)) {
            scrollProxy.scrollTo(anchor, anchor: .top)
        }
    }
}

#if os(iOS)
/// Share sheet sistem: WhatsApp, AirDrop, Mail, Fișiere etc. (unul sau mai multe Excel pe firmă).
struct ZettaShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    var onComplete: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any] = urls.map { ExcelFileActivityItem(url: $0, totalCount: urls.count) }
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .markupAsPDF
        ]
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                context.coordinator.onComplete?()
            }
        }
        configurePopover(for: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        configurePopover(for: uiViewController)
    }

    private func configurePopover(for controller: UIActivityViewController) {
        guard let popover = controller.popoverPresentationController else { return }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController?.view
            ?? scene.windows.first?.rootViewController?.view {
            popover.sourceView = root
            popover.sourceRect = CGRect(
                x: root.bounds.midX,
                y: root.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
    }

    final class Coordinator {
        var onComplete: (() -> Void)?
        init(onComplete: (() -> Void)?) {
            self.onComplete = onComplete
        }
    }
}

/// Expune tipul .xlsx + subiect e-mail pentru WhatsApp, AirDrop și Mail.
final class ExcelFileActivityItem: NSObject, UIActivityItemSource {
    let url: URL
    let totalCount: Int

    init(url: URL, totalCount: Int = 1) {
        self.url = url
        self.totalCount = totalCount
        super.init()
    }

    private var mailSubject: String {
        if totalCount > 1 {
            return "Note contabile — \(totalCount) fișiere Excel"
        }
        let base = url.deletingPathExtension().lastPathComponent
        return "Note contabile — \(base)"
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        mailSubject
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "org.openxmlformats.spreadsheetml.sheet"
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        thumbnailImageForActivityType activityType: UIActivity.ActivityType?,
        suggestedSize size: CGSize
    ) -> UIImage? {
        UIImage(systemName: "tablecells")
    }
}
#endif

/// Card stabil pentru editare + ștergere (binding pe id, ștergere amânată).
private struct ReportEditorCard: View {
    @ObservedObject var model: ZettaAppViewModel
    let reportID: UUID

    private var isPresent: Bool {
        model.reports.contains { $0.id == reportID }
    }

    var body: some View {
        if isPresent {
            VStack(alignment: .trailing, spacing: 8) {
                ZReportEditor(report: model.binding(for: reportID))
                Button("Șterge", role: .destructive) {
                    model.scheduleRemoveReport(id: reportID)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}
