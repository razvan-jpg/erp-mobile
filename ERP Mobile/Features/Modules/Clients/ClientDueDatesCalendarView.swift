import SwiftUI

struct ClientDueDatesCalendarView: View {
    let days: [ClientDueDateCalendarDay]
    let onSelectClient: (DueDateCalendarClientRow) -> Void

    @State private var selectedDay: ClientDueDateCalendarDay?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("due_dates.calendar_hint"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
                .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days) { day in
                    ClientDueDateCalendarDayCell(
                        day: day,
                        isToday: Calendar.current.isDate(day.date, inSameDayAs: today)
                    ) {
                        guard day.hasAmount else { return }
                        selectedDay = day
                    }
                }
            }
            .padding(.horizontal)

            calendarLegend
                .padding(.horizontal)
        }
        .sheet(item: $selectedDay) { day in
            ClientDueDateCalendarDayDetailSheet(day: day, onSelectClient: onSelectClient)
        }
    }

    private var calendarLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(color: .red, text: L10n.tr("due_dates.calendar_legend_overdue"))
            legendRow(color: .orange, text: L10n.tr("due_dates.calendar_legend_today"))
            legendRow(color: .blue, text: L10n.tr("due_dates.calendar_legend_overflow"))
        }
        .font(.caption2)
        .foregroundColor(AppColors.secondary)
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

private struct ClientDueDateCalendarDayCell: View {
    let day: ClientDueDateCalendarDay
    let isToday: Bool
    let onTap: () -> Void

    private var backgroundColor: Color {
        if day.containsOverdue { return Color.red.opacity(0.14) }
        if day.containsOverflow { return Color.blue.opacity(0.12) }
        if isToday { return Color.orange.opacity(0.14) }
        return Color(.secondarySystemBackground)
    }

    private var borderColor: Color {
        if day.containsOverdue { return .red.opacity(0.45) }
        if day.containsOverflow { return .blue.opacity(0.45) }
        if isToday { return .orange.opacity(0.55) }
        return Color.secondary.opacity(0.2)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(SupplierFormatting.weekdayName(day.date))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(SupplierFormatting.date(day.date))
                    .font(.caption2)
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if day.hasAmount {
                    Text(SupplierFormatting.currency(day.totalAmount, code: day.moneda))
                        .font(.caption.bold())
                        .foregroundColor(day.containsOverdue ? .red : .primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .multilineTextAlignment(.center)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(AppColors.tertiary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(backgroundColor))
            .appFullOverlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!day.hasAmount)
    }
}

private struct ClientDueDateCalendarDayDetailSheet: View {
    let day: ClientDueDateCalendarDay
    let onSelectClient: (DueDateCalendarClientRow) -> Void

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            List {
                if day.containsOverdue {
                    Text(L10n.tr("due_dates.calendar_detail_overdue_note"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                if day.containsOverflow {
                    Text(L10n.tr("due_dates.calendar_detail_overflow_note"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }

                Section {
                    ForEach(day.clientRows) { row in
                        Button {
                            presentationMode.wrappedValue.dismiss()
                            onSelectClient(row)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.clientName)
                                        .font(.headline)
                                        .foregroundColor(AppColors.primary)
                                    Text(L10n.tr("due_dates.invoice_count", row.invoiceCount))
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                }
                                Spacer()
                                Text(SupplierFormatting.currency(row.totalAmount, code: row.moneda))
                                    .font(.subheadline.bold())
                                    .foregroundColor(day.containsOverdue ? .red : .orange)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text(
                        L10n.tr(
                            "due_dates.calendar_day_detail_title",
                            SupplierFormatting.date(day.date),
                            SupplierFormatting.currency(day.totalAmount, code: day.moneda)
                        )
                    )
                }
            }
            .navigationTitle(L10n.tr("due_dates.calendar_detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.ok")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .modifier(MediumLargeSheetDetentsModifier())
    }
}

private struct MediumLargeSheetDetentsModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.presentationDetents([.medium, .large])
        } else {
            content
        }
    }
}
