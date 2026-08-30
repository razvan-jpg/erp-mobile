import SwiftUI
import UIKit

struct FormTextField: View {
    let title: String
    @Binding var text: String
    var isRequired: Bool = false
    var errorMessage: String? = nil
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: AppTextAutocapitalization = .sentences
    var autocorrectionDisabled: Bool = false
    var preserveExactTextCase: Bool = false
    var placeholder: String? = nil
    var axis: Axis? = nil
    var lineLimit: ClosedRange<Int>? = nil

    private var displayTitle: String {
        isRequired ? "\(title) *" : title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayTitle)
                .font(.caption)
                .foregroundColor(errorMessage == nil ? AppColors.secondary : .red)
            Group {
                if isSecure {
                    SecureField(displayTitle, text: $text)
                } else if axis != nil {
                    configuredTextField(
                        TextEditor(text: $text)
                            .frame(minHeight: 88)
                    )
                } else {
                    configuredTextField(
                        TextField(placeholder ?? displayTitle, text: $text)
                    )
                }
            }
            .textFieldStyle(.roundedBorder)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(errorMessage == nil ? Color.clear : Color.red, lineWidth: 1)
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private func configuredTextField<F: View>(_ field: F) -> some View {
        if preserveExactTextCase {
            field
                .keyboardType(keyboardType)
                .autocapitalization(autocapitalization.uiKitValue)
                .autocorrectionDisabled(autocorrectionDisabled)
                .textCase(.none)
        } else {
            field
                .keyboardType(keyboardType)
                .autocapitalization(autocapitalization.uiKitValue)
                .autocorrectionDisabled(autocorrectionDisabled)
        }
    }
}

/// Câmp îngust (etichetă deasupra, control mic) pentru linii factură / NIR pe un singur rând.
struct CompactFormField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .decimalPad
    var width: CGFloat? = nil
    var autocapitalization: AppTextAutocapitalization = .never
    var autocorrectionDisabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(AppColors.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            TextField("0", text: $text)
                .font(.subheadline)
                .keyboardType(keyboardType)
                .autocapitalization(autocapitalization.uiKitValue)
                .autocorrectionDisabled(autocorrectionDisabled)
                .textFieldStyle(.roundedBorder)
                .compactLineControl()
        }
        .frame(width: width, alignment: .leading)
    }
}

extension View {
    func compactLineControl() -> some View {
#if targetEnvironment(macCatalyst)
        controlSize(.small)
#else
        self
#endif
    }
}
