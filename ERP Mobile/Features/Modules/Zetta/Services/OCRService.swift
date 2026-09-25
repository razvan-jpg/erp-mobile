import Foundation
import Vision
import CoreGraphics
import CoreImage

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif

enum OCRService {
    /// Țintă „ca la 2x” — textul mic devine suficient de mare pentru Vision.
    nonisolated private static let targetLongestEdge: CGFloat = 3200
    /// Poze foarte mari (12MP) — redimensionăm înainte de primul pass (viteză).
    nonisolated private static let maxDetectLongestEdge: CGFloat = 4200

    nonisolated private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    nonisolated private static let customWords = [
        "NECTARIE", "NUMERAR", "VANZARI", "VANZ", "MODERNA", "MODERNĂ",
        "RAPORT", "FISCAL", "ZILNIC", "TICHETE", "VOUCHER", "SERTAR",
        "TOTAL", "TVA", "PLOIESTI", "PLOIEȘTI", "BUCURESTI", "BUCUREȘTI",
        "COMPLEX", "MAGNOLIA", "DOCUMENTE", "UTILIZATOR", "LOCATIA", "NUMAR",
        "DATA", "ORA", "CATA", "GRA", "AMEF", "0RR", "23:41", "20:41", "00:51",
        "REDUCERI", "RETRAGERI", "SCUTIT", "DMJE",
        "IMPEX", "HOTEL", "VANZARI", "0741", "0830", "0740", "0742", "0758",
        "BACSIS", "BACsis", "SCUTIT", "CREDIT", "LARD", "ERAR", "DIT"
    ]

    struct OCRResult: Sendable {
        var text: String
        var observations: [OCRToken]
    }

    struct OCRToken: Sendable {
        var text: String
        var box: CGRect
    }

    nonisolated static func recognizeText(from image: PlatformImage) async throws -> String {
        let reports = try await recognizeReports(from: image)
        return reports.first ?? ""
    }

    /// Convertește pe MainActor înainte de OCR async (NSImage/UIImage nu sunt Sendable).
    nonisolated static func cgImageForOCR(from image: PlatformImage) -> CGImage? {
        normalizedCGImage(from: image)
    }

    nonisolated static func recognizeReports(from image: PlatformImage) async throws -> [String] {
        guard let cgImage = cgImageForOCR(from: image) else {
            throw OCRError.invalidImage
        }
        return try await recognizeReports(from: cgImage)
    }

    nonisolated static func recognizeText(from cgImage: CGImage) async throws -> String {
        let reports = try await recognizeReports(from: cgImage)
        return reports.first ?? ""
    }

    /// Un Raport Z pe pagină (utilitar scan): OCR pe toată pagina, fără tăiere pe coloane.
    nonisolated static func recognizeFullPageText(from cgImage: CGImage) async throws -> String {
        try await recognizeScanZPage(from: cgImage)
    }

    /// Scan A4 pe modelul Raport Z (etichete stânga, valori dreapta) — un singur Z, nu două coloane-bon.
    nonisolated static func recognizeScanZPage(from cgImage: CGImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try recognizeScanZPageSync(from: cgImage)
        }.value
    }

    /// Fără crop pe document (taie etichetele stânga). Împerechează coloana de etichete cu coloana de valori.
    nonisolated private static func recognizeScanZPageSync(from source: CGImage) throws -> String {
        let prepared = prepareSourceForOCR(source)
        let full = scaleCGImage(prepared, longestEdge: 4000, allowUpscale: true) ?? prepared

        var candidates: [String] = []

        let accurate = try performOCR(on: full, level: .accurate, minimumTextHeight: 0.0025)
        candidates.append(reconstructBinaTwoColumn(from: accurate.observations))
        candidates.append(reconstructLines(from: accurate.observations))

        if let boosted = enhanceForOCR(full, aggressive: true) {
            let boostOCR = try performOCR(on: boosted, level: .accurate, minimumTextHeight: 0.002)
            candidates.append(reconstructBinaTwoColumn(from: boostOCR.observations))
            candidates.append(reconstructLines(from: boostOCR.observations))
        }

        let columns = try ocrEqualColumnCrops(source: full, columnCount: 2)
        if columns.count == 2 {
            candidates.append(mergeColumnTextsByRelativeY(left: columns[0], right: columns[1]))
            candidates.append("\(columns[0])\n\(columns[1])")
        }

        return bestScanPageText(candidates)
    }

    nonisolated private static func bestScanPageText(_ texts: [String]) -> String {
        var best: (text: String, hasZ: Int, score: Int)?
        for raw in texts {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let parsed = ZParser.parse(ocrText: text)
            let score = ZParser.ocrCandidateScore(parsed, ocrText: text).overall
            let hasZ = parsed.zNumber > 0 ? 1 : 0
            if let current = best {
                if hasZ != current.hasZ {
                    if hasZ > current.hasZ { best = (text, hasZ, score) }
                    continue
                }
                if score > current.score { best = (text, hasZ, score) }
            } else {
                best = (text, hasZ, score)
            }
        }
        return best?.text ?? texts.first ?? ""
    }

    /// Etichete stânga + valori dreapta, pe același rând vizual (ca Raport_Z_model.pdf).
    nonisolated private static func reconstructBinaTwoColumn(from tokens: [OCRToken]) -> String {
        guard tokens.count >= 8 else { return reconstructLines(from: tokens) }
        let left = tokens.filter { $0.box.midX < 0.50 }
        let right = tokens.filter { $0.box.midX >= 0.50 }
        guard left.count >= 5, right.count >= 3 else {
            return reconstructLines(from: tokens)
        }

        let leftRows = groupedRows(from: left)
        let rightRows = groupedRows(from: right)
        var usedRight = Set<Int>()
        var lines: [String] = []

        for leftRow in leftRows {
            let leftText = joinedRow(leftRow)
            let leftY = averageMidY(leftRow)
            if let index = nearestRowIndex(in: rightRows, to: leftY, used: usedRight, tolerance: 0.022) {
                usedRight.insert(index)
                let rightText = joinedRow(rightRows[index])
                if rightText.isEmpty {
                    lines.append(leftText)
                } else {
                    lines.append("\(leftText) \t\(rightText)")
                }
            } else {
                lines.append(leftText)
            }
        }

        for (index, rightRow) in rightRows.enumerated() where !usedRight.contains(index) {
            let extra = joinedRow(rightRow)
            if !extra.isEmpty { lines.append(extra) }
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    nonisolated private static func mergeColumnTextsByRelativeY(left: String, right: String) -> String {
        let leftLines = nonEmptyLines(left)
        let rightLines = nonEmptyLines(right)
        guard !leftLines.isEmpty, !rightLines.isEmpty else {
            return [left, right].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n")
        }

        var usedRight = Set<Int>()
        var lines: [String] = []
        for (leftIndex, leftLine) in leftLines.enumerated() {
            let leftY = CGFloat(leftIndex) / CGFloat(max(leftLines.count - 1, 1))
            var bestIndex: Int?
            var bestDistance = CGFloat.greatestFiniteMagnitude
            for (rightIndex, _) in rightLines.enumerated() where !usedRight.contains(rightIndex) {
                let rightY = CGFloat(rightIndex) / CGFloat(max(rightLines.count - 1, 1))
                let distance = abs(leftY - rightY)
                if distance < bestDistance {
                    bestDistance = distance
                    bestIndex = rightIndex
                }
            }
            if let bestIndex, bestDistance <= 0.12 {
                usedRight.insert(bestIndex)
                lines.append("\(leftLine) \t\(rightLines[bestIndex])")
            } else {
                lines.append(leftLine)
            }
        }
        for (index, rightLine) in rightLines.enumerated() where !usedRight.contains(index) {
            lines.append(rightLine)
        }
        return lines.joined(separator: "\n")
    }

    nonisolated private static func groupedRows(from tokens: [OCRToken]) -> [[OCRToken]] {
        let sorted = tokens.sorted { a, b in
            if abs(a.box.midY - b.box.midY) > 0.008 {
                return a.box.midY > b.box.midY
            }
            return a.box.minX < b.box.minX
        }
        var rows: [[OCRToken]] = []
        for token in sorted {
            if var last = rows.last, let ref = last.first {
                let yTol = max(0.010, min(ref.box.height, token.box.height) * 0.85)
                if abs(ref.box.midY - token.box.midY) <= yTol {
                    last.append(token)
                    rows[rows.count - 1] = last
                    continue
                }
            }
            rows.append([token])
        }
        return rows
    }

    nonisolated private static func joinedRow(_ row: [OCRToken]) -> String {
        row.sorted { $0.box.minX < $1.box.minX }
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func averageMidY(_ row: [OCRToken]) -> CGFloat {
        guard !row.isEmpty else { return 0 }
        return row.map(\.box.midY).reduce(0, +) / CGFloat(row.count)
    }

    nonisolated private static func nearestRowIndex(
        in rows: [[OCRToken]],
        to y: CGFloat,
        used: Set<Int>,
        tolerance: CGFloat
    ) -> Int? {
        var best: (Int, CGFloat)?
        for (index, row) in rows.enumerated() where !used.contains(index) {
            let distance = abs(averageMidY(row) - y)
            if distance <= tolerance, best == nil || distance < best!.1 {
                best = (index, distance)
            }
        }
        return best?.0
    }

    nonisolated private static func nonEmptyLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Unul sau mai multe bonuri Z din aceeași poză (bonuri alăturate sau text concatenat).
    nonisolated static func recognizeReports(from cgImage: CGImage) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            try recognizeReportsSync(from: cgImage)
        }.value
    }

    nonisolated private static func recognizeReportsSync(from source: CGImage) throws -> [String] {
        let prepared = prepareSourceForOCR(source)
        struct Attempt {
            let columnCount: Int
            let texts: [String]
            let validZ: Int
            let balanced: Int
            let score: Int
        }

        var attempts: [Attempt] = []

        for columnCount in [2, 3] {
            let texts = try ocrEqualColumnCrops(source: prepared, columnCount: columnCount)
            guard texts.count >= 2 else { continue }

            var validZ = 0
            var balanced = 0
            var score = 0
            for text in texts {
                let parsed = ZParser.parse(ocrText: text)
                if parsed.zNumber > 0 { validZ += 1 }
                if parsed.isBalanced { balanced += 1 }
                score += ZParser.ocrCandidateScore(parsed, ocrText: text).overall
            }
            attempts.append(Attempt(columnCount: columnCount, texts: texts, validZ: validZ, balanced: balanced, score: score))
        }

        if let best = attempts.max(by: { lhs, rhs in
            if lhs.validZ != rhs.validZ { return lhs.validZ < rhs.validZ }
            if lhs.balanced != rhs.balanced { return lhs.balanced < rhs.balanced }
            if lhs.columnCount != rhs.columnCount { return lhs.columnCount > rhs.columnCount }
            return lhs.score < rhs.score
        }), best.validZ >= 2 {
            return dedupeReportTexts(best.texts)
        }

        // Poate un singur Z valid per coloană dar 3 bonuri — preferă coloanele față de OCR amestecat.
        if let colBest = attempts.filter({ $0.texts.count >= 2 && $0.validZ >= 1 })
            .max(by: { $0.validZ != $1.validZ ? $0.validZ < $1.validZ : $0.columnCount < $1.columnCount }),
            colBest.texts.count >= 2,
            colBest.texts.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return dedupeReportTexts(colBest.texts)
        }

        let fullText = try recognizeTextSingleSync(from: prepared)
        let segments = dedupeReportTexts(ZParser.splitOCRTextIntoReports(fullText))
        if segments.count >= 2 {
            return segments
        }
        return [fullText]
    }

    /// Decupează imaginea în N coloane verticale egale și OCR accurate pe fiecare (bonuri alăturate).
    nonisolated private static func ocrEqualColumnCrops(source: CGImage, columnCount: Int) throws -> [String] {
        guard columnCount >= 2 else { return [] }
        var texts: [String] = []
        for index in 0..<columnCount {
            let x0 = CGFloat(index) / CGFloat(columnCount)
            let x1 = CGFloat(index + 1) / CGFloat(columnCount)
            let pad: CGFloat = 0.012
            let rect = CGRect(
                x: max(0, x0 - pad),
                y: 0,
                width: min(1, x1 + pad) - max(0, x0 - pad),
                height: 1
            )
            guard let crop = cropNormalizedRect(rect, in: source) else { continue }
            let scaled = scaleCGImage(crop, longestEdge: targetLongestEdge, allowUpscale: true) ?? crop
            var text = try ocrBestText(on: scaled)
            if let footerText = try ocrFooterText(on: scaled), !footerText.isEmpty {
                text = mergeFooterOCR(into: text, footerText: footerText)
            }
            if !text.isEmpty { texts.append(text) }
        }
        return texts
    }

    /// Elimină duplicate (același nr. Z extras de două ori).
    nonisolated private static func dedupeReportTexts(_ texts: [String]) -> [String] {
        var seenZ = Set<Int>()
        var result: [String] = []
        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let z = ZParser.parse(ocrText: trimmed).zNumber
            if z > 0 {
                if seenZ.contains(z) { continue }
                seenZ.insert(z)
            }
            result.append(trimmed)
        }
        return result.isEmpty ? texts : result
    }

    /// Bonuri Z alăturate pe orizontală — clusterează ancora „RAPORT FISCAL” / „Z NR” pe axa X.
    nonisolated private static func detectReceiptColumnRects(
        from observations: [VNRecognizedTextObservation]
    ) -> [CGRect]? {
        let tokens = observations.compactMap { obs -> OCRToken? in
            guard let text = bestCandidate(from: obs) else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return OCRToken(text: trimmed, box: obs.boundingBox)
        }
        return detectReceiptColumnRects(from: tokens)
    }

    nonisolated private static func detectReceiptColumnRects(from tokens: [OCRToken]) -> [CGRect]? {
        var anchorXs: [CGFloat] = []
        for token in tokens {
            let u = token.text.uppercased()
            if (u.contains("RAPORT") && (u.contains("FISCAL") || u.contains("ZILNIC")))
                || u.contains("FISCAL ZILNIC")
                || u.range(of: #"Z\s*NR"#, options: .regularExpression) != nil {
                anchorXs.append(token.box.midX)
            }
        }

        let sorted = anchorXs.sorted()
        guard sorted.count >= 2 else { return nil }

        var clusterCenters: [CGFloat] = []
        var cluster: [CGFloat] = [sorted[0]]
        let gapThreshold: CGFloat = 0.08

        for x in sorted.dropFirst() {
            if x - (cluster.last ?? x) > gapThreshold {
                clusterCenters.append(cluster.reduce(0, +) / CGFloat(cluster.count))
                cluster = [x]
            } else {
                cluster.append(x)
            }
        }
        clusterCenters.append(cluster.reduce(0, +) / CGFloat(cluster.count))

        guard clusterCenters.count >= 2 else { return nil }

        let centers = clusterCenters.sorted()
        var rects: [CGRect] = []
        for i in 0..<centers.count {
            let left: CGFloat
            let right: CGFloat
            if i == 0 {
                left = 0
                right = centers.count == 1 ? 1 : (centers[0] + centers[1]) / 2
            } else if i == centers.count - 1 {
                left = (centers[i - 1] + centers[i]) / 2
                right = 1
            } else {
                left = (centers[i - 1] + centers[i]) / 2
                right = (centers[i] + centers[i + 1]) / 2
            }
            let pad: CGFloat = 0.01
            let x0 = max(0, left - pad)
            let x1 = min(1, right + pad)
            rects.append(CGRect(x: x0, y: 0, width: x1 - x0, height: 1))
        }
        return rects
    }

    nonisolated private static func recognizeTextSingleSync(from source: CGImage) throws -> String {
        var bestTrusted: (text: String, score: Int)?
        var bestAny: (text: String, score: Int)?

        func consider(_ text: String) {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let parsed = ZParser.parse(ocrText: text)
            let candidate = ZParser.ocrCandidateScore(parsed, ocrText: text)
            if bestAny == nil || candidate.overall > bestAny!.score {
                bestAny = (text, candidate.overall)
            }
            if candidate.trusted {
                if bestTrusted == nil || candidate.overall > bestTrusted!.score {
                    bestTrusted = (text, candidate.overall)
                }
            }
        }

        var working = scaleCGImage(source, longestEdge: min(maxDetectLongestEdge, targetLongestEdge), allowUpscale: false)
            ?? source

        let aspect = CGFloat(working.height) / max(CGFloat(working.width), 1)
        if aspect < 2.2, let docCrop = cropToDocument(in: working) {
            working = docCrop
        }

        // Pass 1 — rapid
        let fast = try performOCR(on: working, level: .fast, minimumTextHeight: 0.004)
        let fastText = reconstructLines(from: fast.observations)
        consider(fastText)
        if ZParser.isConfidentParse(ZParser.parse(ocrText: fastText), ocrText: fastText) {
            return fastText
        }

        // Pass 2 — crop text + upscale + accurate
        var enhanced = working
        if let cropped = cropToTextRegion(fast.observations, in: working) {
            enhanced = cropped
        }
        enhanced = scaleCGImage(enhanced, longestEdge: targetLongestEdge, allowUpscale: true) ?? enhanced

        let accuratePlain = try performOCR(on: enhanced, level: .accurate, minimumTextHeight: 0.003)
        let plainText = reconstructLines(from: accuratePlain.observations)
        consider(plainText)
        if ZParser.isConfidentParse(ZParser.parse(ocrText: plainText), ocrText: plainText) {
            return plainText
        }

        // Pass 3 — contrast + sharpen
        if let boosted = enhanceForOCR(enhanced) {
            let accurateBoost = try performOCR(on: boosted, level: .accurate, minimumTextHeight: 0.003)
            let boostText = reconstructLines(from: accurateBoost.observations)
            consider(boostText)
            if ZParser.isConfidentParse(ZParser.parse(ocrText: boostText), ocrText: boostText) {
                return boostText
            }
        }

        // Pass 4 — întreaga imagine mărită (header + subsol DATA/ORA)
        let full = scaleCGImage(source, longestEdge: targetLongestEdge, allowUpscale: true) ?? source
        let fullAcc = try performOCR(on: full, level: .accurate, minimumTextHeight: 0.003)
        let fullText = reconstructLines(from: fullAcc.observations)
        consider(fullText)
        if ZParser.isConfidentParse(ZParser.parse(ocrText: fullText), ocrText: fullText) {
            return fullText
        }

        // Pass 5 — full + sharpen agresiv (WhatsApp / JPEG comprimat din galerie)
        if let fullBoost = enhanceForOCR(full, aggressive: true) {
            let fullBoostAcc = try performOCR(on: fullBoost, level: .accurate, minimumTextHeight: 0.0025)
            let fullBoostText = reconstructLines(from: fullBoostAcc.observations)
            consider(fullBoostText)
            if ZParser.isConfidentParse(ZParser.parse(ocrText: fullBoostText), ocrText: fullBoostText) {
                return fullBoostText
            }
        }

        // Pass 6 — upscale maxim pe crop document (bonuri foarte mici în cadru)
        if aspect < 2.2, let docCrop = cropToDocument(in: source) {
            let mega = scaleCGImage(docCrop, longestEdge: targetLongestEdge * 1.15, allowUpscale: true) ?? docCrop
            let megaAcc = try performOCR(on: mega, level: .accurate, minimumTextHeight: 0.0025)
            let megaText = reconstructLines(from: megaAcc.observations)
            consider(megaText)
        }

        if let trusted = bestTrusted { return trusted.text }
        return bestAny?.text ?? fastText
    }

    nonisolated private static func performOCR(
        on cgImage: CGImage,
        level: VNRequestTextRecognitionLevel,
        minimumTextHeight: Float
    ) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["ro-RO", "en-US"]
        request.minimumTextHeight = minimumTextHeight
        request.customWords = customWords

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let tokens: [OCRToken] = observations.compactMap { obs in
            guard let text = bestCandidate(from: obs) else { return nil }
            return OCRToken(text: text, box: obs.boundingBox)
        }
        return OCRResult(text: reconstructLines(from: tokens), observations: tokens)
    }

    /// Preferă candidatul cu cifre pentru sume; altfel primul candidat Vision.
    nonisolated private static func bestCandidate(from obs: VNRecognizedTextObservation) -> String? {
        let candidates = obs.topCandidates(3).map(\.string)
        guard !candidates.isEmpty else { return nil }

        if candidates.count == 1 {
            return candidates[0].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let digitPattern = #"\d"#
        if let withDigits = candidates.first(where: {
            $0.range(of: digitPattern, options: .regularExpression) != nil
        }) {
            return withDigits.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return candidates[0].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func reconstructLines(from observations: [VNRecognizedTextObservation]) -> String {
        let tokens = observations.compactMap { obs -> OCRToken? in
            guard let text = bestCandidate(from: obs) else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return OCRToken(text: trimmed, box: obs.boundingBox)
        }
        return reconstructLines(from: tokens)
    }

    nonisolated private static func reconstructLines(from tokens: [OCRToken]) -> String {
        guard !tokens.isEmpty else { return "" }

        let sorted = tokens.sorted { a, b in
            if abs(a.box.midY - b.box.midY) > 0.008 {
                return a.box.midY > b.box.midY
            }
            return a.box.minX < b.box.minX
        }

        var rows: [[OCRToken]] = []
        for token in sorted {
            if var last = rows.last, let ref = last.first {
                let yTol = max(0.010, min(ref.box.height, token.box.height) * 0.85)
                if abs(ref.box.midY - token.box.midY) <= yTol {
                    last.append(token)
                    rows[rows.count - 1] = last
                    continue
                }
            }
            rows.append([token])
        }

        let lines: [String] = rows.map { row in
            let ordered = row.sorted { $0.box.minX < $1.box.minX }
            var parts: [String] = []
            var prevMaxX: CGFloat?
            for token in ordered {
                if let prev = prevMaxX, token.box.minX - prev > 0.04 {
                    parts.append("  ")
                } else if !parts.isEmpty {
                    parts.append(" ")
                }
                parts.append(token.text)
                prevMaxX = token.box.maxX
            }
            return parts.joined()
                .replacingOccurrences(of: #"\s{2,}"#, with: "  ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }

        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Crop automat pe bon (ca un zoom digital) — textul ocupă mai mulți pixeli.
    nonisolated private static func cropToDocument(in cgImage: CGImage) -> CGImage? {
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let obs = request.results?.first else { return nil }

        let xs = [obs.topLeft.x, obs.topRight.x, obs.bottomLeft.x, obs.bottomRight.x]
        let ys = [obs.topLeft.y, obs.topRight.y, obs.bottomLeft.y, obs.bottomRight.y]
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return nil
        }

        let padX = (maxX - minX) * 0.02
        let padY = (maxY - minY) * 0.02
        let rect = CGRect(
            x: max(0, minX - padX),
            y: max(0, minY - padY),
            width: min(1, maxX - minX + 2 * padX),
            height: min(1, maxY - minY + 2 * padY)
        )
        return cropNormalizedRect(rect, in: cgImage)
    }

    nonisolated private static func cropToTextRegion(_ tokens: [OCRToken], in cgImage: CGImage) -> CGImage? {
        guard !tokens.isEmpty else { return nil }

        let minX = tokens.map(\.box.minX).min() ?? 0
        let maxX = tokens.map(\.box.maxX).max() ?? 1
        let minY = tokens.map(\.box.minY).min() ?? 0
        let maxY = tokens.map(\.box.maxY).max() ?? 1

        let padX = (maxX - minX) * 0.03
        let padY = (maxY - minY) * 0.02
        let rect = CGRect(
            x: max(0, minX - padX),
            y: max(0, minY - padY),
            width: min(1 - max(0, minX - padX), maxX - minX + 2 * padX),
            height: min(1 - max(0, minY - padY), maxY - minY + 2 * padY)
        )
        guard rect.width > 0.15, rect.height > 0.15 else { return nil }
        return cropNormalizedRect(rect, in: cgImage)
    }

    nonisolated private static func cropNormalizedRect(_ rect: CGRect, in cgImage: CGImage) -> CGImage? {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        // Vision: origine stânga-jos → CoreGraphics: stânga-sus
        let pixelRect = CGRect(
            x: rect.minX * w,
            y: (1 - rect.maxY) * h,
            width: rect.width * w,
            height: rect.height * h
        ).integral
        guard pixelRect.width >= 32, pixelRect.height >= 32,
              let cropped = cgImage.cropping(to: pixelRect.intersection(CGRect(x: 0, y: 0, width: w, height: h))) else {
            return nil
        }
        return cropped
    }

    nonisolated private static func scaleCGImage(
        _ cgImage: CGImage,
        longestEdge: CGFloat,
        allowUpscale: Bool
    ) -> CGImage? {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let longest = max(w, h)
        let scale = longestEdge / longest

        if !allowUpscale, scale >= 1 { return cgImage }
        if abs(scale - 1) < 0.03 { return cgImage }

        let newW = max(1, Int(floor(w * scale)))
        let newH = max(1, Int(floor(h * scale)))
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: newW,
            height: newH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return cgImage }

        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage()
    }

    /// 2–3 pass-uri rapide pe crop (plain + contrast); alege textul cu scor OCR cel mai bun.
    nonisolated private static func ocrBestText(on cgImage: CGImage) throws -> String {
        func score(_ text: String) -> Int {
            let parsed = ZParser.parse(ocrText: text)
            let candidate = ZParser.ocrCandidateScore(parsed, ocrText: text)
            var s = candidate.overall
            if parsed.isBalanced { s += 50 }
            if candidate.trusted { s += 25 }
            if parsed.numerar + parsed.card + parsed.plataModerna > 0 { s += 10 }
            return s
        }

        var best = ("", 0)
        let variants: [CGImage] = [cgImage, enhanceForOCR(cgImage), enhanceForOCR(cgImage, aggressive: true)].compactMap { $0 }
        for variant in variants {
            let acc = try performOCR(on: variant, level: .accurate, minimumTextHeight: 0.0025)
            let text = reconstructLines(from: acc.observations)
            let s = score(text)
            if s > best.1 { best = (text, s) }
        }
        return best.0
    }

    /// OCR dedicat pe subsolul bonului (DATA/CATA + ORA/GRA) — text mare, contrast ridicat.
    nonisolated private static func ocrFooterText(on columnImage: CGImage) throws -> String? {
        // Vision: y=0 = partea de jos a imaginii
        let footerRect = CGRect(x: 0, y: 0, width: 1, height: 0.24)
        guard let footerCrop = cropNormalizedRect(footerRect, in: columnImage) else { return nil }
        let scaled = scaleCGImage(footerCrop, longestEdge: targetLongestEdge * 1.35, allowUpscale: true) ?? footerCrop

        func scoreFooter(_ text: String) -> Int {
            let u = text.uppercased()
            var s = 0
            if u.contains("CATA") || u.contains("DATA") { s += 40 }
            if u.contains("GRA") || u.contains("ORA") { s += 40 }
            if text.range(of: #"\d{2}[-\./]\d{2}[-\./]\d{4}"#, options: .regularExpression) != nil { s += 30 }
            if text.range(of: #"\d{1,2}:\d{2}:\d{2}"#, options: .regularExpression) != nil { s += 25 }
            if text.range(of: #"2[03]:4[0-9]"#, options: .regularExpression) != nil { s += 15 }
            return s
        }

        var best = ("", 0)
        let variants: [CGImage] = [scaled, enhanceForOCR(scaled), enhanceForOCR(scaled, aggressive: true)].compactMap { $0 }
        for variant in variants {
            let acc = try performOCR(on: variant, level: .accurate, minimumTextHeight: 0.0018)
            let text = reconstructLines(from: acc.observations)
            let s = scoreFooter(text)
            if s > best.1 { best = (text, s) }
        }
        guard best.1 >= 55 else { return nil }
        return best.0
    }

    /// Înlocuiește subsolul OCR (DMJE / CATA…) cu textul citit din crop dedicat.
    nonisolated private static func mergeFooterOCR(into text: String, footerText: String) -> String {
        let footerLines = footerText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !footerLines.isEmpty else { return text }

        var lines = text.components(separatedBy: .newlines)
        if let start = lines.lastIndex(where: { line in
            let u = line.uppercased()
            return u.contains("DMJE") || u.contains("CATA") || u.contains("DATA:")
                || u.contains("DATAR") || u.contains("NUMAR BONURI")
        }) {
            lines.removeSubrange(start...)
        } else if lines.count > 8 {
            lines.removeLast(8)
        }
        lines.append(contentsOf: footerLines)
        return lines.joined(separator: "\n")
    }

    /// Upscale pentru poze mici (WhatsApp / galerie comprimată) înainte de OCR.
    nonisolated private static func prepareSourceForOCR(_ cgImage: CGImage) -> CGImage {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let longest = max(w, h)
        if longest > maxDetectLongestEdge {
            return scaleCGImage(cgImage, longestEdge: maxDetectLongestEdge, allowUpscale: false) ?? cgImage
        }
        // WhatsApp salvează adesea ~1024–1600px — upscale la 3200 ca „2× zoom digital”.
        if longest < 2800 {
            return scaleCGImage(cgImage, longestEdge: targetLongestEdge, allowUpscale: true) ?? cgImage
        }
        return cgImage
    }

    nonisolated private static func enhanceForOCR(_ cgImage: CGImage, aggressive: Bool = false) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        let preprocessed: CIImage = {
            guard aggressive else { return input }
            return input.applyingFilter("CINoiseReduction", parameters: [
                "inputNoiseLevel": 0.02,
                "inputSharpness": 0.45
            ])
        }()
        let gray = preprocessed.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0,
            kCIInputContrastKey: aggressive ? 1.28 : 1.18,
            kCIInputBrightnessKey: aggressive ? 0.05 : 0.03
        ])
        let sharpened = gray.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: aggressive ? 0.45 : 0.35
        ])
        return ciContext.createCGImage(sharpened, from: sharpened.extent)
    }

    nonisolated private static func normalizedCGImage(from image: PlatformImage) -> CGImage? {
        #if canImport(UIKit)
        if image.imageOrientation == .up, let cg = image.cgImage {
            return cg
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
        #elseif canImport(AppKit)
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #endif
    }
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Imaginea nu a putut fi citită."
        }
    }
}
