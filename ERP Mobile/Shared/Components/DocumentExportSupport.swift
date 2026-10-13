import MessageUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MailAttachment: Sendable {
    let fileURL: URL
    let mimeType: String

    init(fileURL: URL, mimeType: String = "application/pdf") {
        self.fileURL = fileURL
        self.mimeType = mimeType
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipients: [String]
    let attachments: [MailAttachment]
    let onFinish: (MFMailComposeResult) -> Void

    init(
        subject: String,
        body: String,
        recipients: [String],
        attachmentURL: URL?,
        onFinish: @escaping () -> Void
    ) {
        self.subject = subject
        self.body = body
        self.recipients = recipients
        self.attachments = attachmentURL.map { [MailAttachment(fileURL: $0)] } ?? []
        self.onFinish = { _ in onFinish() }
    }

    init(
        subject: String,
        body: String,
        recipients: [String],
        attachments: [MailAttachment],
        onFinish: @escaping (MFMailComposeResult) -> Void
    ) {
        self.subject = subject
        self.body = body
        self.recipients = recipients
        self.attachments = attachments
        self.onFinish = onFinish
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void
        init(onFinish: @escaping (MFMailComposeResult) -> Void) { self.onFinish = onFinish }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
            onFinish(result)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        if !recipients.isEmpty {
            controller.setToRecipients(recipients)
        }
        for attachment in attachments {
            if let data = try? Data(contentsOf: attachment.fileURL) {
                controller.addAttachmentData(
                    data,
                    mimeType: attachment.mimeType,
                    fileName: attachment.fileURL.lastPathComponent
                )
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

struct PrintDocumentView: UIViewControllerRepresentable {
    let pdfData: Data
    let jobName: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        DispatchQueue.main.async {
#if targetEnvironment(macCatalyst)
            // Sheet-ul gol blochează panoul de print pe Mac până la Esc — tipărim direct și închidem sheet-ul.
            onFinish()
            DispatchQueue.main.async {
                DocumentExportSupport.printPDF(data: pdfData, jobName: jobName)
            }
#else
            let printInfo = UIPrintInfo(dictionary: nil)
            printInfo.jobName = jobName
            printInfo.outputType = .general
            let printController = UIPrintInteractionController.shared
            printController.printInfo = printInfo
            printController.printingItem = pdfData
            printController.present(animated: true) { _, _, _ in
                onFinish()
            }
#endif
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct LocalSaveDocumentPicker: UIViewControllerRepresentable {
    let sourceURLs: [URL]
    let onFinish: () -> Void

    init(sourceURL: URL, onFinish: @escaping () -> Void) {
        self.sourceURLs = [sourceURL]
        self.onFinish = onFinish
    }

    init(sourceURLs: [URL], onFinish: @escaping () -> Void) {
        self.sourceURLs = sourceURLs
        self.onFinish = onFinish
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFinish()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: sourceURLs, asCopy: true)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

typealias PDFLocalSaveDocumentPicker = LocalSaveDocumentPicker

enum DocumentExportSupport {
    static var prefersLocalPDFSaveOnFinish: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }

    static var canSendMail: Bool {
#if targetEnvironment(macCatalyst)
        false
#else
        MFMailComposeViewController.canSendMail()
#endif
    }

    static func writeTemporaryPDF(data: Data, preferredFileName: String) throws -> URL {
        try writeTemporaryFile(data: data, preferredFileName: preferredFileName, pathExtension: "pdf")
    }

    static func writeTemporaryFile(data: Data, preferredFileName: String, pathExtension: String) throws -> URL {
        let trimmed = preferredFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = pathExtension.lowercased()
        let suffix = ".\(ext)"
        let baseName: String
        if trimmed.lowercased().hasSuffix(suffix) {
            baseName = String(trimmed.dropLast(suffix.count))
        } else if trimmed.isEmpty {
            baseName = "Document"
        } else {
            baseName = trimmed
        }
        let safeName = baseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(8)).\(ext)")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func whatsAppShareURL(for phone: String?) -> URL? {
        guard let phone else { return nil }
        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        let normalized = digits.hasPrefix("40") ? digits : "40\(digits)"
        return URL(string: "https://wa.me/\(normalized)")
    }

#if targetEnvironment(macCatalyst)
    /// Save/share without a nested SwiftUI sheet (blank white screen on Mac Catalyst).
    @discardableResult
    static func saveOnMac(from sourceURL: URL, suggestedName: String) -> Bool {
        _ = suggestedName
        return presentExportPicker(sourceURL: sourceURL)
    }

    static func shareOnMac(url: URL) {
        guard let host = MacExportPresenter.topViewController() else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = host.view
            popover.sourceRect = CGRect(x: host.view.bounds.midX, y: 72, width: 1, height: 1)
        }
        host.present(controller, animated: true)
    }

    /// Print fără sheet intermediar (altfel panoul Mac rămâne blocat până la Esc).
    static func printPDF(data: Data, jobName: String) {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = jobName
        printInfo.outputType = .general
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.printingItem = data
        printController.present(animated: true, completionHandler: nil)
    }

    static func printPDF(url: URL, jobName: String) throws {
        let data = try Data(contentsOf: url)
        printPDF(data: data, jobName: jobName)
    }

    @discardableResult
    private static func presentExportPicker(sourceURL: URL) -> Bool {
        guard let host = MacExportPresenter.topViewController() else { return false }
        let delegate = MacExportPresenter.ExportPickerDelegate()
        MacExportPresenter.documentPickerDelegate = delegate
        let picker = UIDocumentPickerViewController(forExporting: [sourceURL], asCopy: true)
        picker.delegate = delegate
        picker.shouldShowFileExtensions = true
        if let popover = picker.popoverPresentationController {
            popover.sourceView = host.view
            popover.sourceRect = CGRect(x: host.view.bounds.midX, y: 72, width: 1, height: 1)
        }
        host.present(picker, animated: true)
        return true
    }
#else
    static func printPDF(data: Data, jobName: String) {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = jobName
        printInfo.outputType = .general
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.printingItem = data
        printController.present(animated: true, completionHandler: nil)
    }

    static func printPDF(url: URL, jobName: String) throws {
        let data = try Data(contentsOf: url)
        printPDF(data: data, jobName: jobName)
    }
#endif
}

#if targetEnvironment(macCatalyst)
private enum MacExportPresenter {
    static var documentPickerDelegate: ExportPickerDelegate?

    final class ExportPickerDelegate: NSObject, UIDocumentPickerDelegate {
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            MacExportPresenter.documentPickerDelegate = nil
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            MacExportPresenter.documentPickerDelegate = nil
        }
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif
