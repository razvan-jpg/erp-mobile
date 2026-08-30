import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppDatePickerStyle {
    /// Câmp compact cu data formatată + pictogramă calendar.
    case compactField
    /// Doar pictograma calendar (data e afișată separat).
    case iconOnly
}

/// DatePicker cu calendar în popover care se închide automat după selectarea datei.
/// Folosiți acest component pentru orice alegere de dată din calendar în app.
struct AppDatePicker: View {
    @Binding var selection: Date
    var displayedComponents: DatePickerComponents = .date
    var style: AppDatePickerStyle = .compactField

    @State private var isCalendarPresented = false
    @State private var draftSelection: Date

    init(
        selection: Binding<Date>,
        displayedComponents: DatePickerComponents = .date,
        style: AppDatePickerStyle = .compactField
    ) {
        _selection = selection
        self.displayedComponents = displayedComponents
        self.style = style
        _draftSelection = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        Button {
            draftSelection = selection
            isCalendarPresented = true
        } label: {
            labelContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.tr("date.picker_accessibility"))
        .popover(isPresented: $isCalendarPresented, arrowEdge: .bottom) {
            calendarContent
        }
    }

    @ViewBuilder
    private var labelContent: some View {
        switch style {
        case .compactField:
            HStack(spacing: 6) {
                Text(displayString(for: selection))
                    .foregroundColor(AppColors.primary)
                Spacer(minLength: 0)
                Image(systemName: "calendar")
                    .foregroundColor(Color.accentColor)
            }
        case .iconOnly:
            Image(systemName: "calendar")
                .foregroundColor(Color.accentColor)
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        Group {
            if displayedComponents == .date {
                AutoDismissDateCalendarHost(
                    selection: $draftSelection,
                    onDateSelected: commitDraftSelection
                )
            } else {
                DatePicker(
                    "",
                    selection: committingDateBinding($draftSelection, onCommit: commitDraftSelection),
                    displayedComponents: displayedComponents
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
        }
        .padding(12)
        .frame(minWidth: 320)
        .modifier(AppPopoverCompactAdaptationModifier())
    }

    private func commitDraftSelection() {
        selection = draftSelection
        DispatchQueue.main.async {
            isCalendarPresented = false
        }
    }

    private func displayString(for date: Date) -> String {
        if displayedComponents == .date {
            return SupplierFormatting.inputDateString(date)
        }
        return SupplierFormatting.dateTime(date)
    }
}

/// Calendar doar-dată care notifică imediat după alegerea zilei.
private struct AutoDismissDateCalendarHost: View {
    @Binding var selection: Date
    var onDateSelected: () -> Void

    var body: some View {
#if canImport(UIKit)
        if #available(iOS 16.0, *) {
            AutoDismissDateCalendarView(selection: $selection, onDateSelected: onDateSelected)
        } else {
            AutoDismissDateCalendarFallback(selection: $selection, onDateSelected: onDateSelected)
        }
#else
        AutoDismissDateCalendarFallback(selection: $selection, onDateSelected: onDateSelected)
#endif
    }
}

#if canImport(UIKit)
@available(iOS 16.0, *)
private struct AutoDismissDateCalendarView: UIViewRepresentable {
    @Binding var selection: Date
    var onDateSelected: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, onDateSelected: onDateSelected)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar.current
        calendarView.locale = Locale(identifier: "ro_RO")
        let behavior = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = behavior
        context.coordinator.selectionBehavior = behavior
        context.coordinator.applySelection(from: selection, to: behavior)
        return calendarView
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        guard let behavior = context.coordinator.selectionBehavior else { return }
        context.coordinator.applySelection(from: selection, to: behavior)
    }

    final class Coordinator: NSObject, UICalendarSelectionSingleDateDelegate {
        var selection: Binding<Date>
        var onDateSelected: () -> Void
        weak var selectionBehavior: UICalendarSelectionSingleDate?
        private var suppressSelectionCallback = false

        init(selection: Binding<Date>, onDateSelected: @escaping () -> Void) {
            self.selection = selection
            self.onDateSelected = onDateSelected
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard !suppressSelectionCallback else { return }
            guard let dateComponents,
                  let date = Calendar.current.date(from: dateComponents) else { return }
            self.selection.wrappedValue = Calendar.current.startOfDay(for: date)
            DispatchQueue.main.async {
                self.onDateSelected()
            }
        }

        func applySelection(from date: Date, to behavior: UICalendarSelectionSingleDate) {
            let day = Calendar.current.startOfDay(for: date)
            let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
            suppressSelectionCallback = true
            behavior.setSelected(components, animated: false)
            DispatchQueue.main.async {
                self.suppressSelectionCallback = false
            }
        }
    }
}
#endif

private struct AutoDismissDateCalendarFallback: View {
    @Binding var selection: Date
    var onDateSelected: () -> Void

    var body: some View {
        DatePicker(
            "",
            selection: committingDateBinding($selection, onCommit: onDateSelected),
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
    }
}

private struct AppPopoverCompactAdaptationModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationCompactAdaptation(.popover)
        } else {
            content
        }
    }
}

private func committingDateBinding(_ binding: Binding<Date>, onCommit: @escaping () -> Void) -> Binding<Date> {
    Binding(
        get: { binding.wrappedValue },
        set: { newValue in
            binding.wrappedValue = newValue
            onCommit()
        }
    )
}
