import SwiftUI

struct DateInputField: View {
    let title: String
    @Binding var date: Date
    var isRequired: Bool = false

    @State private var text = ""

    private var displayTitle: String {
        isRequired ? "\(title) *" : title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayTitle)
                .font(.caption)
                .foregroundColor(AppColors.secondary)

            HStack(spacing: 8) {
                TextField(L10n.tr("date.format_placeholder"), text: $text)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) { newValue in
                        if let parsed = SupplierFormatting.parseInputDate(newValue) {
                            date = parsed
                        }
                    }

                AppDatePicker(selection: $date, style: .iconOnly)
            }

            Text(L10n.tr("date.format_hint"))
                .font(.caption2)
                .foregroundColor(AppColors.tertiary)
        }
        .onAppear {
            text = SupplierFormatting.inputDateString(date)
        }
        .onChange(of: date) { newValue in
            let formatted = SupplierFormatting.inputDateString(newValue)
            if text != formatted {
                text = formatted
            }
        }
    }
}
