import Foundation
import UIKit

/// Comenzi pentru driverul FiscalNet (Datecs FP-700): fișier în folderul Bonuri, răspuns în folderul Răspuns.
enum FiscalNet {
    static let adDateconta = "https://factura.dateconta.ro"
    static let adBeauty = "https://www.beautymanager.net"

    struct SaleLine {
        var name: String
        var unitPrice: Decimal
        var quantity: Decimal
        var vatGroup: Int
        var fullDiscount: Bool
        var discountable: Bool
        var note: String?
    }

    struct BuiltReceipt {
        var commands: [String]
        var payment: Decimal
        var cashTaken: Decimal
        var cardTaken: Decimal
    }

    static func vatGroup(_ rate: Decimal?) -> Int {
        guard let rate else { return 1 }
        if rate >= 19 { return 1 }
        if rate >= 9 { return 2 }
        return 4
    }

    static func payType(_ channel: String) -> Int {
        switch channel {
        case "card": return 2
        case "cash": return 1
        default: return 7
        }
    }

    static func buildReceipt(
        fiscalCode: String?,
        lines: [SaleLine],
        targetTotal: Decimal,
        paymentType: Int,
        tender: Decimal,
        documentUrl: String,
        splitEntered: Decimal? = nil,
        splitEnteredIsCash: Bool = true
    ) -> BuiltReceipt {
        var prepared: [(SaleLine, Int)] = []
        for line in lines where line.unitPrice > 0 && line.quantity > 0 {
            prepared.append((line, lineBani(line.unitPrice, line.quantity)))
        }
        var discountable: [Int] = []
        var discountableIndex: [Int] = []
        var natural = 0
        for (index, item) in prepared.enumerated() {
            if item.0.fullDiscount { continue }
            natural += item.1
            if item.0.discountable {
                discountable.append(item.1)
                discountableIndex.append(index)
            }
        }
        let target = max(0, bani(targetTotal))
        let needed = max(0, natural - target)
        let cuts = cuts(discountable, needed)
        var cutByLine = Array(repeating: 0, count: prepared.count)
        var cutSum = 0
        for (index, lineIndex) in discountableIndex.enumerated() {
            cutByLine[lineIndex] = cuts[index]
            cutSum += cuts[index]
        }
        let payment = max(0, natural - cutSum)
        var commands: [String] = []
        var notes: [String] = []
        let code = sanitize(fiscalCode ?? "", max: 20)
        if !code.isEmpty {
            commands.append("CF^\(code)")
        }
        for (index, item) in prepared.enumerated() {
            let line = item.0
            let price = bani(line.unitPrice)
            let qty = milli(line.quantity)
            let group = (1...5).contains(line.vatGroup) ? line.vatGroup : 1
            commands.append("S^\(sanitize(line.name, max: 42))^\(price)^\(qty)^buc^\(group)^1")
            if line.fullDiscount {
                commands.append("DV^\(item.1)")
            } else if cutByLine[index] > 0 {
                commands.append("DV^\(cutByLine[index])")
            }
            let note = sanitize(line.note ?? "", max: 42)
            if !note.isEmpty {
                notes.append(note)
            }
        }
        for note in notes {
            commands.append("TL^\(note)")
        }
        if !documentUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            commands.append("CB^\(documentUrl.trimmingCharacters(in: .whitespacesAndNewlines))^4")
        }
        commands.append("CB^\(adDateconta)^4")
        commands.append("CB^\(adBeauty)^4")
        let enteredBani = splitEntered.map { bani($0) }
        let parts = splitBani(payment: payment, entered: enteredBani, enteredIsCash: splitEnteredIsCash)
        if splitEntered != nil {
            if parts.cash > 0 {
                commands.append("P^1^\(parts.cash)")
            }
            if parts.card > 0 {
                commands.append("P^2^\(parts.card)")
            }
        } else {
            let cashIn = paymentType == 1 && tender > 0 ? bani(tender) : 0
            let sent = cashIn > payment ? cashIn : payment
            commands.append("P^\(paymentType)^\(sent)")
        }
        let cashTaken = splitEntered != nil ? parts.cash : (paymentType == 1 ? payment : 0)
        let cardTaken = splitEntered != nil ? parts.card : (paymentType == 2 ? payment : 0)
        return BuiltReceipt(
            commands: commands,
            payment: Decimal(payment) / 100,
            cashTaken: Decimal(cashTaken) / 100,
            cardTaken: Decimal(cardTaken) / 100
        )
    }

    static func split(payment: Decimal, entered: Decimal, enteredIsCash: Bool) -> (cash: Decimal, card: Decimal) {
        let parts = splitBani(payment: bani(payment), entered: bani(entered), enteredIsCash: enteredIsCash)
        return (Decimal(parts.cash) / 100, Decimal(parts.card) / 100)
    }

    static func pos(_ amount: Decimal) -> [String] {
        ["POS^\(max(0, bani(amount)))"]
    }

    static func report(_ kind: String) -> [String] {
        ["\(kind)^"]
    }

    static func nonFiscal(_ lines: [String], documentUrl: String) -> [String] {
        var commands: [String] = []
        for line in lines {
            for part in wrap(sanitize(line, max: 400), width: 42) where !part.isEmpty {
                commands.append("TL^\(part)")
            }
        }
        if !documentUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            commands.append("CB^\(documentUrl.trimmingCharacters(in: .whitespacesAndNewlines))^4")
        }
        commands.append("CB^\(adDateconta)^4")
        commands.append("CB^\(adBeauty)^4")
        return commands
    }

    static func failure(_ reply: FiscalNetStation.Reply, fallback: String) -> String {
        if reply.timedOut {
            return L10n.tr("module.cashier.fiscal_timeout")
        }
        if !reply.errorInfo.isEmpty {
            return fallback + "\n" + reply.errorInfo
        }
        if !reply.errorCode.isEmpty {
            return fallback + "\n" + reply.errorCode
        }
        return fallback
    }

    static func fileName(prefix: String, nonFiscal: Bool) -> String {
        let stamp = fileStamp.string(from: Date())
        let noise = Int.random(in: 1000...9999)
        let name = prefix + stamp + String(noise)
        return (nonFiscal ? "nf_" : "") + name + ".txt"
    }

    private static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmssSSS"
        return formatter
    }()

    private static func splitBani(payment: Int, entered: Int?, enteredIsCash: Bool) -> (cash: Int, card: Int) {
        guard let entered else { return (0, 0) }
        let total = max(0, payment)
        let taken = min(max(0, entered), total)
        let rest = total - taken
        if enteredIsCash { return (taken, rest) }
        return (rest, taken)
    }

    private static func bani(_ value: Decimal) -> Int {
        rounded(value * 100, scale: 0)
    }

    private static func milli(_ value: Decimal) -> Int {
        rounded(value * 1000, scale: 0)
    }

    private static func lineBani(_ unitPrice: Decimal, _ quantity: Decimal) -> Int {
        let price = bani(unitPrice)
        let qty = milli(quantity)
        return rounded(Decimal(price * qty) / 1000, scale: 0)
    }

    private static func rounded(_ value: Decimal, scale: Int) -> Int {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return NSDecimalNumber(decimal: result).intValue
    }

    private static func cuts(_ gross: [Int], _ needed: Int) -> [Int] {
        var result = Array(repeating: 0, count: gross.count)
        guard needed > 0, !gross.isEmpty else { return result }
        let sum = gross.reduce(0, +)
        guard sum > 0 else { return result }
        let left = min(needed, sum)
        var allocated = 0
        for index in gross.indices {
            let share: Int
            if index == gross.count - 1 {
                share = left - allocated
            } else {
                share = rounded(Decimal(gross[index] * left) / Decimal(sum), scale: 0)
            }
            let clamped = max(0, min(gross[index], min(share, left - allocated)))
            result[index] = clamped
            allocated += clamped
        }
        var drift = left - result.reduce(0, +)
        var index = result.count - 1
        while index >= 0 && drift != 0 {
            let step = drift > 0 ? min(gross[index] - result[index], drift) : -min(result[index], -drift)
            result[index] += step
            drift -= step
            index -= 1
        }
        return result
    }

    private static func sanitize(_ value: String, max: Int) -> String {
        var text = ""
        for character in value {
            if character == "^" || character == "\r" || character == "\n" || character == "\t" {
                text.append(" ")
                continue
            }
            switch character {
            case "ă", "â": text.append("a")
            case "Ă", "Â": text.append("A")
            case "î": text.append("i")
            case "Î": text.append("I")
            case "ș", "ş": text.append("s")
            case "Ș", "Ş": text.append("S")
            case "ț", "ţ": text.append("t")
            case "Ț", "Ţ": text.append("T")
            default: text.append(character)
            }
        }
        var collapsed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while collapsed.contains("  ") {
            collapsed = collapsed.replacingOccurrences(of: "  ", with: " ")
        }
        if collapsed.count <= max { return collapsed }
        return String(collapsed.prefix(max)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func wrap(_ text: String, width: Int) -> [String] {
        var rest = text
        var lines: [String] = []
        while rest.count > width {
            let end = rest.index(rest.startIndex, offsetBy: width)
            let head = rest[..<end]
            let cut = head.lastIndex(of: " ").map { head.distance(from: head.startIndex, to: $0) } ?? width
            let split = cut < 8 ? width : cut
            let index = rest.index(rest.startIndex, offsetBy: split)
            lines.append(String(rest[..<index]).trimmingCharacters(in: .whitespaces))
            rest = String(rest[index...]).trimmingCharacters(in: .whitespaces)
        }
        if !rest.isEmpty { lines.append(rest) }
        return lines
    }
}

enum FiscalNetStation {
    struct Reply {
        var bonOk = 0
        var number = ""
        var errorCode = ""
        var errorInfo = ""
        var authorization = ""
        var timedOut = false
        var incomplete = false
    }

    private static let bookmarkKey = "fiscalnet.bonuri.bookmark"

    static var isReady: Bool {
        guard let url = resolve() else { return false }
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        let raspuns = url.deletingLastPathComponent().appendingPathComponent("Raspuns", isDirectory: true)
        return FileManager.default.fileExists(atPath: url.path)
            && FileManager.default.fileExists(atPath: raspuns.path)
    }

    static func save(_ url: URL) -> String? {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        let raspuns = url.deletingLastPathComponent().appendingPathComponent("Raspuns", isDirectory: true)
        guard FileManager.default.fileExists(atPath: raspuns.path) else {
            return L10n.tr("module.cashier.fiscal_no_reply_folder")
        }
        do {
            let data = try url.bookmarkData(options: bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static func send(fileName: String, commands: [String], timeout: TimeInterval) async -> Reply {
        guard let bonuri = resolve() else {
            return Reply(errorInfo: L10n.tr("module.cashier.fiscal_no_folder"))
        }
        let started = bonuri.startAccessingSecurityScopedResource()
        defer { if started { bonuri.stopAccessingSecurityScopedResource() } }
        let raspuns = bonuri.deletingLastPathComponent().appendingPathComponent("Raspuns", isDirectory: true)
        guard FileManager.default.fileExists(atPath: raspuns.path) else {
            return Reply(errorInfo: L10n.tr("module.cashier.fiscal_no_reply_folder"))
        }
        let finalURL = bonuri.appendingPathComponent(fileName)
        let replyURL = raspuns.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: replyURL)
        let body = commands.joined(separator: "\r\n") + "\r\n"
        do {
            try body.write(to: finalURL, atomically: true, encoding: .utf8)
        } catch {
            return Reply(errorInfo: error.localizedDescription)
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: replyURL.path),
               let text = try? String(contentsOf: replyURL, encoding: .utf8) {
                let parsed = parse(text)
                if !parsed.incomplete { return parsed }
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return Reply(timedOut: true)
    }

    private static func parse(_ text: String) -> Reply {
        var map: [String: String] = [:]
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let split = line.firstIndex(of: "="), split != line.startIndex else { continue }
            map[String(line[..<split]).trimmingCharacters(in: .whitespaces).lowercased()] = String(line[line.index(after: split)...]).trimmingCharacters(in: .whitespaces)
        }
        guard let okText = map["bonok"], let ok = Int(okText) else {
            return Reply(incomplete: true)
        }
        return Reply(
            bonOk: ok,
            number: map["nrbon"] ?? "",
            errorCode: map["errcode"] ?? "",
            errorInfo: map["errinfo"] ?? "",
            authorization: map["codautorizare"] ?? "",
            incomplete: false
        )
    }

    private static var bookmarkOptions: URL.BookmarkCreationOptions {
        #if targetEnvironment(macCatalyst) || os(macOS)
        return .withSecurityScope
        #else
        return []
        #endif
    }

    private static var resolveOptions: URL.BookmarkResolutionOptions {
        #if targetEnvironment(macCatalyst) || os(macOS)
        return .withSecurityScope
        #else
        return []
        #endif
    }

    private static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: resolveOptions, relativeTo: nil, bookmarkDataIsStale: &stale)
    }
}

enum FiscalPrompt {
    @MainActor
    static func choose(message: String, accept: String, decline: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: L10n.tr("module.cashier.notice_title"), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: decline, style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            alert.addAction(UIAlertAction(title: accept, style: .default) { _ in
                continuation.resume(returning: true)
            })
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive })
                    ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                  let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
                    ?? scene.windows.first?.rootViewController else {
                continuation.resume(returning: false)
                return
            }
            var top = root
            while let presented = top.presentedViewController {
                top = presented
            }
            top.present(alert, animated: true)
        }
    }
}
