import Foundation

enum Validators {
    /// Valoare CNP pentru utilizatori care nu doresc divulgarea CNP (GDPR).
    static let gdprCNPPlaceholder = "0000000000000"

    static func isGDPRCNPPlaceholder(_ cnp: String) -> Bool {
        cnp == gdprCNPPlaceholder
    }

    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    static func isValidCNP(_ cnp: String) -> Bool {
        guard cnp.count == 13, cnp.allSatisfy(\.isNumber) else { return false }
        if isGDPRCNPPlaceholder(cnp) { return true }
        return validateCNPChecksum(cnp)
    }

    static func isValidPhone(_ phone: String) -> Bool {
        let digits = phone.filter(\.isNumber)
        return digits.count >= 10 && digits.count <= 13
    }

    /// Normalizează CUI/CIF pentru interogare ANAF (fără prefix RO, doar cifre).
    static func normalizedCUI(_ cui: String) -> String? {
        var cleaned = cui.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("RO") {
            cleaned = String(cleaned.dropFirst(2))
        }
        cleaned = cleaned.filter(\.isNumber)
        guard !cleaned.isEmpty, cleaned.count <= 10 else { return nil }
        return cleaned
    }

    private static func validateCNPChecksum(_ cnp: String) -> Bool {
        let controlKey = "279146358279"
        guard cnp.count == 13, controlKey.count == 12 else { return false }
        var sum = 0
        for (index, char) in cnp.prefix(12).enumerated() {
            guard let digit = char.wholeNumberValue,
                  let keyDigit = controlKey[controlKey.index(controlKey.startIndex, offsetBy: index)].wholeNumberValue
            else { return false }
            sum += digit * keyDigit
        }
        let remainder = sum % 11
        let control = remainder == 10 ? 1 : remainder
        guard let lastDigit = cnp.last?.wholeNumberValue else { return false }
        return control == lastDigit
    }
}
