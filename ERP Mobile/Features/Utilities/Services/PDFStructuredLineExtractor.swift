#if canImport(PDFKit)
import Foundation
import PDFKit

/// Reconstruiește linii din PDF pe baza poziției caracterelor (extrase bancare cu coloane).
enum PDFStructuredLineExtractor {
    static func extractLines(from document: PDFDocument) -> [String] {
        var lines: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            lines.append(contentsOf: extractLines(from: page))
        }
        return lines
    }

    static func extractLines(from page: PDFPage) -> [String] {
        let count = page.numberOfCharacters
        guard count > 0, count <= 50_000 else {
            return []
        }

        struct Glyph {
            let x: CGFloat
            let y: CGFloat
            let char: Character
        }

        var glyphs: [Glyph] = []
        glyphs.reserveCapacity(min(count, 20_000))

        for index in 0..<count {
            let bounds = page.characterBounds(at: index)
            guard bounds.width.isFinite, bounds.height.isFinite,
                  bounds.origin.x.isFinite, bounds.origin.y.isFinite,
                  bounds.width > 0 || bounds.height > 0 else { continue }
            guard let piece = page.selection(for: bounds)?.string,
                  let char = piece.first,
                  !char.isNewline else { continue }
            glyphs.append(Glyph(x: bounds.midX, y: bounds.midY, char: char))
        }

        guard !glyphs.isEmpty else { return [] }

        let tolerance: CGFloat = 3.5
        var rows: [CGFloat: [(CGFloat, Character)]] = [:]
        for glyph in glyphs {
            let bucket = (glyph.y / tolerance).rounded() * tolerance
            rows[bucket, default: []].append((glyph.x, glyph.char))
        }

        return rows.keys.sorted(by: >).compactMap { y in
            let line = rows[y]!
                .sorted { $0.0 < $1.0 }
                .map(\.1)
            let text = String(line)
                .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }
}
#endif
