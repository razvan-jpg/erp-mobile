import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

enum UtilityFilePickerSupport {
    static let bankStatementTypes: [UTType] = {
        var types: [UTType] = [.pdf, .plainText, .commaSeparatedText, .text, .data, .content, .item]
        for ext in ["mt940", "940", "sta", "csv", "txt"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        return types
    }()

    static let bankStatementDropTypes: [UTType] = [
        .fileURL, .pdf, .plainText, .commaSeparatedText, .text, .data, .content, .item
    ]

    /// Citește URL-uri din drag & drop (Mac / Mac Catalyst / iPad).
    static func loadURLsFromDropProviders(
        _ providers: [NSItemProvider],
        completion: @escaping @Sendable ([URL]) -> Void
    ) {
        guard !providers.isEmpty else {
            completion([])
            return
        }

        let lock = NSLock()
        var collected: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            loadURLFromDropProvider(provider) { url in
                if let url {
                    lock.lock()
                    collected.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(collected)
        }
    }

    private static func loadURLFromDropProvider(
        _ provider: NSItemProvider,
        completion: @escaping @Sendable (URL?) -> Void
    ) {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    completion(stabilizeDroppedFile(at: url))
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    completion(stabilizeDroppedFile(at: url))
                } else {
                    completion(nil)
                }
            }
            return
        }

        guard let type = bankStatementDropTypes.first(where: {
            provider.hasItemConformingToTypeIdentifier($0.identifier)
        }) else {
            completion(nil)
            return
        }

        provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
            guard let url else {
                completion(nil)
                return
            }
            completion(stabilizeDroppedFile(at: url))
        }
    }

    /// Copiază fișierul într-un temp persistent — URL-urile din drop/picker pot fi efemere.
    private static func stabilizeDroppedFile(at url: URL) -> URL? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("utility_import_\(UUID().uuidString)_\(url.lastPathComponent)")
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
            return tempURL
        } catch {
            if let data = try? Data(contentsOf: url) {
                do {
                    try data.write(to: tempURL, options: .atomic)
                    return tempURL
                } catch {
                    return nil
                }
            }
            return nil
        }
    }

    /// Citește bytes din URL-uri picker/drop, cu acces security-scoped.
    static func readData(from url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        return try Data(contentsOf: url)
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
struct UtilityMultiFileDocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: ([URL]) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        let dismiss: DismissAction

        init(onPick: @escaping ([URL]) -> Void, dismiss: DismissAction) {
            self.onPick = onPick
            self.dismiss = dismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            dismiss()
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            dismiss()
        }
    }
}
#endif

#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit

enum UtilityDirectoryPicker {
    @discardableResult
    static func pickDirectory(prompt: String, message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        panel.message = message
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}

enum UtilityMacFilePicker {
    @discardableResult
    static func pickFiles(contentTypes: [UTType]) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = contentTypes
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }
}
#endif

struct UtilityFileImportButton: View {
    let title: String
    let contentTypes: [UTType]
    let onImportURLs: ([URL]) -> Void

    @State private var showDocumentPicker = false

    var body: some View {
        Button(title) {
            #if os(macOS) && !targetEnvironment(macCatalyst)
            let urls = UtilityMacFilePicker.pickFiles(contentTypes: contentTypes)
            if !urls.isEmpty {
                onImportURLs(urls)
            }
            #else
            showDocumentPicker = true
            #endif
        }
        #if os(iOS) || targetEnvironment(macCatalyst)
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: contentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                onImportURLs(urls)
            case .failure:
                break
            }
        }
        #endif
    }
}

/// Zonă comună încărcare fișiere: buton + drag & drop.
struct UtilityFileDropZoneView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let contentTypes: [UTType]
    let onImportURLs: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 34))
                .foregroundColor(AppColors.accent)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppColors.secondary)
                .multilineTextAlignment(.center)

            UtilityFileImportButton(
                title: buttonTitle,
                contentTypes: contentTypes,
                onImportURLs: onImportURLs
            )
            .buttonStyle(AppButtonStyles.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 2, dash: [8])
                        )
                )
        )
        .onDrop(of: UtilityFilePickerSupport.bankStatementDropTypes, isTargeted: $isTargeted) { providers in
            guard !providers.isEmpty else { return false }
            UtilityFilePickerSupport.loadURLsFromDropProviders(providers) { urls in
                if !urls.isEmpty {
                    onImportURLs(urls)
                }
            }
            return true
        }
    }
}
