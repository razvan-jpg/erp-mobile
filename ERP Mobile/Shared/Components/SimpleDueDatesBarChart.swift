import SwiftUI

struct SimpleDueDatesBarChart: View {
    let items: [(label: String, amount: Decimal, color: Color)]
    let currencyCode: String

    private var maxAmount: Double {
        let values = items.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
        return max(values.max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    Text(SupplierFormatting.currency(item.amount, code: currencyCode))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    GeometryReader { proxy in
                        let height = max(8, proxy.size.height * CGFloat(NSDecimalNumber(decimal: item.amount).doubleValue / maxAmount))
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(item.color)
                                .frame(height: height)
                        }
                    }

                    Text(item.label)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 143)
    }
}
