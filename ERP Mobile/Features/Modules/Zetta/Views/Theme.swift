import SwiftUI

extension Color {
    static let canvasTop = Color(red: 0.93, green: 0.95, blue: 0.94)
    static let canvasBottom = Color(red: 0.82, green: 0.88, blue: 0.86)
    static let panelFill = Color(red: 0.99, green: 0.995, blue: 0.99)
    /// Text principal — contrast ridicat pe panouri deschise
    static let accentInk = Color(red: 0.08, green: 0.28, blue: 0.26)
    /// Etichete / meta — mai închis decât system `.secondary` (care dispare în Dark Mode)
    static let labelMuted = Color(red: 0.22, green: 0.38, blue: 0.36)
    static let fieldFill = Color(red: 0.94, green: 0.96, blue: 0.95)
    static let fieldStroke = Color(red: 0.12, green: 0.35, blue: 0.32).opacity(0.28)
    static let tableHeaderFill = Color(red: 0.88, green: 0.93, blue: 0.91)
    static let tableRowAlt = Color(red: 0.94, green: 0.97, blue: 0.96)
    static let accentWarm = Color(red: 0.78, green: 0.42, blue: 0.18)
    static let dangerSoft = Color(red: 0.75, green: 0.22, blue: 0.18)
    static let okSoft = Color(red: 0.12, green: 0.48, blue: 0.32)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next", size: 14).weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentInk.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next", size: 14).weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundStyle(Color.accentInk)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentInk.opacity(0.4), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct CompactSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next", size: 12).weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundStyle(Color.accentInk)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.accentInk.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension Decimal {
    var moneyString: String {
        let n = NSDecimalNumber(decimal: self)
        let f = NumberFormatter()
        f.locale = Locale(identifier: "ro_RO")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: n) ?? "\(self)"
    }
}
