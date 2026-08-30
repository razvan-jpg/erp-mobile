import Foundation
import ImageIO
import SwiftUI
import UIKit

enum CompanyLogoStorage {
    private static let maxEdge: CGFloat = 512
    private static let jpegQuality: CGFloat = 0.82
    private static let maxStoredBytes = 900_000

    static func dataURL(from imageData: Data, contentType: String) -> String? {
        guard let prepared = prepare(imageData: imageData, contentType: contentType) else { return nil }
        let encoded = prepared.data.base64EncodedString()
        return "data:\(prepared.contentType);base64,\(encoded)"
    }

    static func uiImage(from storedValue: String?) -> UIImage? {
        guard let storedValue, !storedValue.isEmpty else { return nil }

        if storedValue.hasPrefix("data:"),
           let commaIndex = storedValue.firstIndex(of: ",") {
            let base64 = String(storedValue[storedValue.index(after: commaIndex)...])
            guard let data = Data(base64Encoded: base64) else { return nil }
            return UIImage(data: data)
        }

        if let url = URL(string: storedValue),
           url.scheme?.hasPrefix("http") == true,
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }

        return nil
    }

    static func dataURL(fromFile url: URL) -> String? {
        guard let loaded = loadFileData(from: url) else { return nil }
        return dataURL(from: loaded.data, contentType: loaded.contentType)
    }

    static func previewImage(from data: Data) -> Image? {
        guard let uiImage = uiImage(from: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    static func previewImage(fromStoredValue storedValue: String?) -> Image? {
        guard let uiImage = uiImage(from: storedValue) else { return nil }
        return Image(uiImage: uiImage)
    }

    private static func loadFileData(from url: URL) -> (data: Data, contentType: String)? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        let contentType = mimeType(for: url.pathExtension)
        return (data, contentType)
    }

    private static func uiImage(from data: Data) -> UIImage? {
        if let image = UIImage(data: data) {
            return image
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    static func suggestedLogo(from companyName: String) -> String? {
        let initials = initials(from: companyName)
        guard !initials.isEmpty else { return nil }
        let image = renderSuggestedLogo(initials: initials, seed: companyName)
        guard let data = image.jpegData(compressionQuality: jpegQuality) else { return nil }
        return dataURL(from: data, contentType: "image/jpeg")
    }

    static func swiftUIImage(from storedValue: String?) -> Image? {
        previewImage(fromStoredValue: storedValue)
    }

    private static func prepare(imageData: Data, contentType: String) -> (data: Data, contentType: String)? {
        guard let image = uiImage(from: imageData) else { return nil }
        let resized = resize(image, maxEdge: maxEdge)
        guard var jpegData = resized.jpegData(compressionQuality: jpegQuality) else { return nil }

        var quality = jpegQuality
        while jpegData.count > maxStoredBytes, quality > 0.35 {
            quality -= 0.08
            guard let smaller = resized.jpegData(compressionQuality: quality) else { break }
            jpegData = smaller
        }

        guard jpegData.count <= maxStoredBytes else { return nil }
        return (jpegData, "image/jpeg")
    }

    private static let legalSuffixes: Set<String> = [
        "SRL", "SA", "SCS", "SCA", "SNC", "PFA", "II", "IF", "SRL-D", "SRLD"
    ]

    private static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "tif", "tiff": return "image/tiff"
        default: return "image/jpeg"
        }
    }

    private static func initials(from companyName: String) -> String {
        let cleaned = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        let words = cleaned
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "&" || $0 == "/" })
            .map { String($0).trimmingCharacters(in: .punctuationCharacters) }
            .filter { word in
                guard !word.isEmpty else { return false }
                return !legalSuffixes.contains(word.uppercased())
            }

        if words.isEmpty {
            return String(cleaned.prefix(2)).uppercased()
        }
        if words.count == 1 {
            return String(words[0].prefix(2)).uppercased()
        }

        let first = words[0].prefix(1)
        let second = words[1].prefix(1)
        return (first + second).uppercased()
    }

    private static func color(from seed: String) -> UIColor {
        var hash: UInt64 = 5381
        for byte in seed.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }

        let hue = CGFloat(hash % 360) / 360.0
        return UIColor(hue: hue, saturation: 0.58, brightness: 0.72, alpha: 1)
    }

    private static func renderSuggestedLogo(initials: String, seed: String) -> UIImage {
        let edge: CGFloat = 512
        let size = CGSize(width: edge, height: edge)
        let backgroundColor = color(from: seed)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: edge * 0.18)
            backgroundColor.setFill()
            path.fill()

            let fontSize = initials.count > 1 ? edge * 0.34 : edge * 0.42
            let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            let text = initials as NSString
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2 - edge * 0.015,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }

    private static func resize(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxEdge / size.width, maxEdge / size.height, 1)
        guard scale < 1 else { return image }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
