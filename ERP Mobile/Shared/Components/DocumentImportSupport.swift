import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum EFacturaImportFileCollector {
    static func collectXMLFiles(in directoryURL: URL, recursive: Bool = true) throws -> [URL] {
        let didAccessDirectory = directoryURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessDirectory {
                directoryURL.stopAccessingSecurityScopedResource()
            }
        }

        var collected: [URL] = []
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .nameKey]

        if recursive {
            guard let enumerator = FileManager.default.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            ) else {
                throw EFacturaImportCollectorError.unreadableDirectory
            }

            for case let itemURL as URL in enumerator {
                guard (try? itemURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                    continue
                }
                if itemURL.pathExtension.lowercased() == "xml" {
                    collected.append(itemURL)
                }
            }
        } else {
            let items = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            collected = items.filter {
                $0.pathExtension.lowercased() == "xml"
                    && ((try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true)
            }
        }

        return collected.sorted {
            if $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedSame {
                return $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
            }
            return $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
    }
}

enum EFacturaImportCollectorError: LocalizedError {
    case unreadableDirectory
    case noXMLFiles

    var errorDescription: String? {
        switch self {
        case .unreadableDirectory:
            return L10n.tr("invoices.import_error_unreadable_directory")
        case .noXMLFiles:
            return L10n.tr("invoices.import_directory_empty")
        }
    }
}

struct DocumentDirectoryPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        @Binding var isPresented: Bool
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(isPresented: Binding<Bool>, onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            _isPresented = isPresented
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            defer { isPresented = false }
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
            isPresented = false
        }
    }
}

struct DocumentImageFilePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (Data, String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let contentTypes: [UTType] = [.image, .png, .jpeg, .gif, .webP, .bmp, .tiff, .heic, .heif]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        @Binding var isPresented: Bool
        let onPick: (Data, String) -> Void
        let onCancel: () -> Void

        init(isPresented: Binding<Bool>, onPick: @escaping (Data, String) -> Void, onCancel: @escaping () -> Void) {
            _isPresented = isPresented
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                isPresented = false
                return
            }

            let didAccess = url.startAccessingSecurityScopedResource()
            let data = try? Data(contentsOf: url)
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }

            guard let data, !data.isEmpty else {
                onCancel()
                isPresented = false
                return
            }

            let contentType = mimeType(for: url.pathExtension)
            isPresented = false
            Task { @MainActor in
                onPick(data, contentType)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
            isPresented = false
        }

        private func mimeType(for pathExtension: String) -> String {
            switch pathExtension.lowercased() {
            case "png": return "image/png"
            case "gif": return "image/gif"
            case "webp": return "image/webp"
            case "bmp": return "image/bmp"
            case "tif", "tiff": return "image/tiff"
            case "heic": return "image/heic"
            case "heif": return "image/heif"
            default: return "image/jpeg"
            }
        }
    }
}

struct DocumentXMLFilePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: ([URL]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.xml], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        @Binding var isPresented: Bool
        let onPick: ([URL]) -> Void
        let onCancel: () -> Void

        init(isPresented: Binding<Bool>, onPick: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
            _isPresented = isPresented
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            defer { isPresented = false }
            guard !urls.isEmpty else {
                onCancel()
                return
            }
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
            isPresented = false
        }
    }
}
