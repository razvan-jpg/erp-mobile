import MessageUI
import SwiftUI
import UIKit

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipients: [String]
    let attachmentURL: URL?
    let onFinish: () -> Void

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
            onFinish()
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
        if let attachmentURL,
           let data = try? Data(contentsOf: attachmentURL) {
            controller.addAttachmentData(data, mimeType: "application/pdf", fileName: attachmentURL.lastPathComponent)
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
            let printInfo = UIPrintInfo(dictionary: nil)
            printInfo.jobName = jobName
            printInfo.outputType = .general
            let printController = UIPrintInteractionController.shared
            printController.printInfo = printInfo
            printController.printingItem = pdfData
            printController.present(animated: true) { _, _, _ in
                onFinish()
            }
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

#if targetEnvironment(macCatalyst)
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
#endif

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
        let trimmed = preferredFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName: String
        if trimmed.lowercased().hasSuffix(".pdf") {
            baseName = String(trimmed.dropLast(4))
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
            .appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(8)).pdf")
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
}
