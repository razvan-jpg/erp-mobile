import Foundation

enum NameFormatter {
    /// Capitalizează prima literă și prima literă după spațiu sau "-".
    static func formatName(_ input: String) -> String {
        guard !input.isEmpty else { return input }

        var result = ""
        var capitalizeNext = true

        for character in input {
            if character == " " || character == "-" {
                result.append(character)
                capitalizeNext = true
            } else if capitalizeNext, character.isLetter {
                result.append(String(character).uppercased())
                capitalizeNext = false
            } else {
                result.append(String(character).lowercased())
                capitalizeNext = false
            }
        }

        return result
    }
}
