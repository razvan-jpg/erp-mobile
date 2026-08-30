import SwiftUI

struct SavedExcelContinueOverlay: View {
    let firmName: String
    let cui: String
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            Text("Veți continua introducerea datelor pentru:\n\(firmName), CUI \(cui)")
                .font(.custom("Avenir Next", size: 18).weight(.bold))
                .foregroundStyle(Color.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: 620)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
                .padding(24)
        }
        .task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            onDismiss()
        }
    }
}

struct SavedExcelWarningOverlay: View {
    var onDismiss: () -> Void
    @State private var didDismiss = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissOnce() }

            Text(SavedExcelWarning.text)
                .font(.custom("Avenir Next", size: 17).weight(.bold))
                .foregroundStyle(Color.blue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: 620)
                .background(Color.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
                .padding(24)
        }
        .task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            dismissOnce()
        }
    }

    private func dismissOnce() {
        guard !didDismiss else { return }
        didDismiss = true
        onDismiss()
    }
}

#if os(macOS) && !targetEnvironment(macCatalyst)
struct MacXlsxImporterButton: View {
    var onPick: (URL) -> Void

    var body: some View {
        Button {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            if let xlsx = UTType(filenameExtension: "xlsx") {
                panel.allowedContentTypes = [xlsx]
            }
            panel.message = "Selectează fișierul Excel salvat anterior (NC_…xlsx)"
            if panel.runModal() == .OK, let url = panel.url {
                onPick(url)
            }
        } label: {
            Label("Încarcă xlsx salvat", systemImage: "tablecells.badge.ellipsis")
        }
        .buttonStyle(SecondaryButtonStyle())
    }
}
#endif

#if os(iOS)
import UniformTypeIdentifiers

struct IOSXlsxDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [UTType(filenameExtension: "xlsx")].compactMap { $0 }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types.isEmpty ? [.spreadsheet] : types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let dismiss: DismissAction

        init(onPick: @escaping (URL) -> Void, dismiss: DismissAction) {
            self.onPick = onPick
            self.dismiss = dismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            defer { dismiss() }
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            dismiss()
        }
    }
}
#endif

#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif
