import SwiftUI

struct HRPeriodPicker: View {
    @Binding var period: HRMonthPeriod

    var body: some View {
        HStack {
            Button {
                shift(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(period.label)
                .font(.headline)
            Spacer()
            Button {
                shift(1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.borderless)
    }

    private func shift(_ delta: Int) {
        var month = period.month + delta
        var year = period.year
        if month < 1 {
            month = 12
            year -= 1
        } else if month > 12 {
            month = 1
            year += 1
        }
        period = HRMonthPeriod(year: year, month: month)
    }
}
