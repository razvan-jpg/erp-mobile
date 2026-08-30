import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import os

private final class ImportedImageBatchCollector {
    private var batches: [[ImportedImage]] = []
    private let lock = NSLock()

    func append(_ images: [ImportedImage]) {
        lock.lock()
        batches.append(images)
        lock.unlock()
    }

    var flattened: [ImportedImage] {
        lock.lock()
        defer { lock.unlock() }
        return batches.flatMap { $0 }
    }
}

private final class ImportedImageListCollector {
    private var items: [ImportedImage] = []
    private let lock = NSLock()

    func append(_ image: ImportedImage) {
        lock.lock()
        items.append(image)
        lock.unlock()
    }

    var all: [ImportedImage] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct ImportedImage: Identifiable, Equatable {
    let id = UUID()
    let image: PlatformImage
    let fileName: String
    /// Text încorporat din PDF (fără OCR) — când există, parserul îl folosește direct.
    let embeddedText: String?

    init(image: PlatformImage, fileName: String, embeddedText: String? = nil) {
        self.image = image
        self.fileName = fileName
        self.embeddedText = embeddedText
    }
}

enum ImageLoader {
    static let acceptedFileTypes: [UTType] = [.jpeg, .png, .heic, .heif, .pdf, .image, .tiff]

    static let acceptedDropTypes: [UTType] = [
        .fileURL, .image, .pdf, .jpeg, .png, .heic, .heif, .tiff, .content
    ]

    /// Una sau mai multe imagini din fișier (PDF → câte o pagină).
    static func loadAll(from url: URL) -> [ImportedImage] {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return loadAllWithoutSecurityScope(from: url)
    }

    private static func loadAllWithoutSecurityScope(from url: URL) -> [ImportedImage] {
        if isPDF(url) {
            return loadPDFPages(from: url)
        }
        if let image = loadImageFile(from: url) {
            return [image]
        }
        return []
    }

    static func load(from url: URL) -> ImportedImage? {
        loadAll(from: url).first
    }

    private static func loadImageFile(from url: URL) -> ImportedImage? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard !isPDF(url), let image = NSImage(contentsOf: url) else { return nil }
        return ImportedImage(image: image, fileName: url.lastPathComponent)
        #elseif canImport(UIKit)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        return ImportedImage(image: normalizedUIImage(image), fileName: url.lastPathComponent)
        #else
        return nil
        #endif
    }

    private static func isPDF(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "pdf"
            || (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .pdf)) == true
    }

    /// Renderează fiecare pagină PDF la rezoluție potrivită OCR (~3200px pe latura lungă).
    private static func loadPDFPages(from url: URL) -> [ImportedImage] {
        guard let document = PDFDocument(url: url) else { return [] }
        let baseName = url.deletingPathExtension().lastPathComponent
        let pageCount = document.pageCount
        guard pageCount > 0 else { return [] }

        var results: [ImportedImage] = []
        for index in 0..<pageCount {
            guard let page = document.page(at: index),
                  let image = renderPDFPage(page) else { continue }
            let fileName = pageCount > 1
                ? "\(baseName) · p\(index + 1).pdf"
                : url.lastPathComponent
            let embeddedText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = (embeddedText?.isEmpty == false) ? embeddedText : nil
            results.append(ImportedImage(image: image, fileName: fileName, embeddedText: text))
        }
        return results
    }

    private static func renderPDFPage(_ page: PDFPage) -> PlatformImage? {
        let bounds = page.bounds(for: .mediaBox)
        let longest = max(bounds.width, bounds.height)
        guard longest > 0 else { return nil }

        let targetLongest: CGFloat = 3200
        let scale = max(2, min(4, targetLongest / longest))
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let thumbnail = page.thumbnail(of: size, for: .mediaBox)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard thumbnail.size.width > 0, thumbnail.size.height > 0 else { return nil }
        return thumbnail
        #elseif canImport(UIKit)
        guard thumbnail.size.width > 0, thumbnail.size.height > 0 else { return nil }
        return normalizedUIImage(thumbnail)
        #else
        return nil
        #endif
    }

    static func loadFromDropProvider(
        _ provider: NSItemProvider,
        completion: @escaping @Sendable ([ImportedImage]) -> Void
    ) {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let fileURL = item as? URL {
                    url = fileURL
                } else {
                    url = nil
                }
                guard let url else {
                    completion([])
                    return
                }
                completion(loadAll(from: url))
            }
            return
        }

        let fileTypes: [UTType] = [.pdf, .jpeg, .png, .heic, .heif, .tiff, .image]
        if let type = fileTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) {
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                guard let url else {
                    completion([])
                    return
                }
                completion(loadAllWithoutSecurityScope(from: url))
            }
            return
        }

        #if canImport(UIKit)
        let dataTypes = [UTType.image.identifier, UTType.jpeg.identifier, UTType.png.identifier, UTType.heic.identifier]
        if let type = dataTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) {
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                guard let data,
                      let imported = load(from: data, fileName: "Z_drop_\(Int(Date().timeIntervalSince1970)).jpg") else {
                    completion([])
                    return
                }
                completion([imported])
            }
            return
        }
        #endif

        completion([])
    }

    #if canImport(UIKit)
    /// Re-dimensionează la pixeli reali + orientare corectă (EXIF din galerie / WhatsApp).
    static func normalizedUIImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up, image.scale == 1 {
            return image
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func load(from data: Data, fileName: String) -> ImportedImage? {
        guard let image = UIImage(data: data) else { return nil }
        return ImportedImage(image: normalizedUIImage(image), fileName: fileName)
    }
    #endif
}

struct DropZoneView: View {
    var onImport: ([ImportedImage]) -> Void
    var onImportFailure: (() -> Void)? = nil
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.accentInk.opacity(0.85))
            Text("Trage pozele cu Raport Z aici")
                .font(.custom("Avenir Next", size: 20).weight(.semibold))
                .foregroundStyle(Color.accentInk)
            #if os(macOS) && !targetEnvironment(macCatalyst)
            Text("JPG, PNG, HEIC sau PDF — trage fișierele aici sau folosește butonul de import.\nPDF: fiecare pagină = un bon Z.\nSe ignoră automat Raport X.")
                .font(.custom("Avenir Next", size: 13).weight(.medium))
                .foregroundStyle(Color.labelMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            #else
            Text("sau folosește butoanele de mai jos — fotografiază bonul Z tipărit (hârtie), nu ecranul telefonului.\n2× zoom · tot bonul vizibil (header + DATA/ORA jos).\nSe ignoră automat Raport X.")
                .font(.custom("Avenir Next", size: 13).weight(.medium))
                .foregroundStyle(Color.labelMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            #endif
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.panelFill.opacity(isTargeted ? 0.95 : 0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            Color.accentInk.opacity(isTargeted ? 0.7 : 0.25),
                            style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                        )
                )
        )
        .onDrop(of: ImageLoader.acceptedDropTypes, isTargeted: $isTargeted) { providers in
            guard !providers.isEmpty else { return false }
            handleDrop(providers)
            return true
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        let collector = ImportedImageBatchCollector()

        for provider in providers {
            group.enter()
            ImageLoader.loadFromDropProvider(provider) { images in
                collector.append(images)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let loaded = collector.flattened
            if loaded.isEmpty {
                onImportFailure?()
            } else {
                onImport(loaded)
            }
        }
    }
}

#if os(macOS) && !targetEnvironment(macCatalyst)
struct MacFileImporterButton: View {
    var title: String
    var systemImage: String
    var onImport: ([ImportedImage]) -> Void
    var onImportFailure: (() -> Void)? = nil

    var body: some View {
        Button {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = ImageLoader.acceptedFileTypes
            panel.message = "Selectează poze sau PDF cu Raport Z"
            if panel.runModal() == .OK {
                let images = panel.urls.flatMap { ImageLoader.loadAll(from: $0) }
                if images.isEmpty {
                    onImportFailure?()
                } else {
                    onImport(images)
                }
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}
#endif

#if os(iOS)
import UniformTypeIdentifiers

struct IOSMediaDocumentPicker: UIViewControllerRepresentable {
    var onPick: ([ImportedImage]) -> Void
    var onFailure: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onFailure: onFailure, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: ImageLoader.acceptedFileTypes,
            asCopy: true
        )
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([ImportedImage]) -> Void
        let onFailure: (() -> Void)?
        let dismiss: DismissAction

        init(
            onPick: @escaping ([ImportedImage]) -> Void,
            onFailure: (() -> Void)?,
            dismiss: DismissAction
        ) {
            self.onPick = onPick
            self.onFailure = onFailure
            self.dismiss = dismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            let images = urls.flatMap { ImageLoader.loadAll(from: $0) }
            dismiss()
            Task { @MainActor in
                if images.isEmpty {
                    onFailure?()
                } else {
                    onPick(images)
                }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            dismiss()
        }
    }
}

@preconcurrency import PhotosUI

/// Galerie iOS — selecție multiplă (mai multe poze Z dintr-o dată).
struct IOSPhotoLibraryPicker: UIViewControllerRepresentable {
    var onPick: ([ImportedImage]) -> Void
    var onFailure: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 0
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: IOSPhotoLibraryPicker
        init(parent: IOSPhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard !results.isEmpty else { return }

            let group = DispatchGroup()
            let collector = ImportedImageListCollector()

            for (index, result) in results.enumerated() {
                group.enter()
                loadFullResolutionImage(from: result, index: index) { imported in
                    defer { group.leave() }
                    if let imported {
                        collector.append(imported)
                    }
                }
            }

            group.notify(queue: .main) {
                let loaded = collector.all
                if loaded.isEmpty {
                    self.parent.onFailure?()
                } else {
                    self.parent.onPick(loaded)
                }
            }
        }

        /// Încarcă bytes originali din galerie (nu thumbnail comprimat de loadObject).
        private func loadFullResolutionImage(
            from result: PHPickerResult,
            index: Int,
            completion: @escaping @Sendable (ImportedImage?) -> Void
        ) {
            let provider = result.itemProvider
            let assetID = result.assetIdentifier
            let typeOrder = [UTType.image.identifier, UTType.jpeg.identifier, UTType.png.identifier, UTType.heic.identifier]
            guard let type = typeOrder.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                completion(nil)
                return
            }
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                let name: String
                if let suggested = assetID {
                    name = "Z_\(suggested.prefix(8)).jpg"
                } else {
                    name = "Z_\(index + 1)_\(Int(Date().timeIntervalSince1970)).jpg"
                }
                let imported: ImportedImage?
                if let data {
                    imported = ImageLoader.load(from: data, fileName: name)
                } else {
                    imported = nil
                }
                completion(imported)
            }
        }
    }
}

struct IOSImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var onPick: (ImportedImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
            picker.showsCameraControls = true
            // Full-screen e mai rapid / mai stabil decât sheet pe iPhone.
            picker.modalPresentationStyle = .fullScreen
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: IOSImagePicker
        init(parent: IOSImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Închide camera imediat, OCR rulează după pe background.
            parent.dismiss()
            if let image = info[.originalImage] as? UIImage {
                let name = "Z_\(Int(Date().timeIntervalSince1970)).jpg"
                parent.onPick(ImportedImage(image: ImageLoader.normalizedUIImage(image), fileName: name))
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
