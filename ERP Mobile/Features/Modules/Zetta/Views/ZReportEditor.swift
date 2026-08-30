import SwiftUI

struct ZReportEditor: View {
    @Binding var report: ZReportData
    @State private var showBalanceGap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.sourceFileName.isEmpty ? "Raport Z" : report.sourceFileName)
                        .font(.custom("Avenir Next", size: 16).weight(.bold))
                        .foregroundStyle(Color.accentInk)
                    Text("Locația: \(report.locationDisplay)")
                        .font(.custom("Avenir Next", size: 12).weight(.semibold))
                        .foregroundStyle(Color.labelMuted)
                }
                Spacer()
                turaBadge
                balanceBadge
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Firmă")
                TextField("Denumire firmă de pe Z", text: $report.firma)
                    .textFieldStyle(.roundedBorder)
                    .font(.custom("Avenir Next", size: 15).weight(.semibold))
                    .foregroundStyle(Color.accentInk)
                    .onChange(of: report.firma) { newValue in
                        let normalized = Conturi.normalizedFirmaName(newValue)
                        if normalized != newValue {
                            report.firma = normalized
                        }
                        if let profile = FirmaRegistry.profile(matchingName: report.firma) {
                            report.firma = profile.displayName
                            report.cui = profile.cui
                            report.isNectarieFirma = profile.isNectarie
                        } else {
                            report.isNectarieFirma = Conturi.isNectarieFirma(report.firma)
                        }
                    }
                if !report.cui.isEmpty {
                    Text("CIF: RO\(report.cui)")
                        .font(.custom("Avenir Next", size: 12).weight(.medium))
                        .foregroundStyle(Color.labelMuted)
                }
                Toggle(isOn: $report.isNectarieFirma) {
                    Text(report.schemaLabel)
                        .font(.custom("Avenir Next", size: 13).weight(.semibold))
                        .foregroundStyle(Color.accentInk)
                }
                .toggleStyle(.switch)
                .tint(Color.okSoft)

                Toggle(isOn: $report.isNightShift) {
                    Text("Tura noapte (03:00–10:00)")
                        .font(.custom("Avenir Next", size: 13).weight(.semibold))
                        .foregroundStyle(Color.accentInk)
                }
                .toggleStyle(.switch)
                .tint(Color.accentWarm)
                .onChange(of: report.isNightShift) { isNight in
                    let cal = Calendar.current
                    let delta = isNight ? -1 : 1
                    if let next = cal.date(byAdding: .day, value: delta, to: cal.startOfDay(for: report.date)) {
                        report.date = next
                    }
                }

                if let printed = report.printDateTime {
                    Text("Tipărit: \(report.printDateTimeFormatted ?? DateFormats.displayDateTime(from: printed))")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Color.labelMuted)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                intField("Nr. Z", value: $report.zNumber)
                dateField
                moneyField("Vânzări 11% brut (B)", value: $report.vanzari11)
                moneyField("TVA 11%", value: $report.tva11)
                moneyField("Vânzări 21% brut (A)", value: $report.vanzari21)
                moneyField("TVA 21%", value: $report.tva21)
                if report.usesBacsisSchema || report.vanzari11C > 0 {
                    moneyField("Vânzări 11% brut (C)", value: $report.vanzari11C)
                    moneyField("TVA C 11%", value: $report.tva11C)
                }
                moneyField("Vânzări 0% (D / bacșiș)", value: $report.vanzari0)
                moneyField("Total vânzări", value: $report.totalVanzari)
                moneyField("Numerar", value: $report.numerar)
                moneyField("Card", value: $report.card)
                if report.usesBacsisSchema {
                    moneyField("Alte plăți", value: $report.altePlati)
                } else {
                    moneyField("Plată modernă", value: $report.plataModerna)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Document: \(report.documentNumber)")
                Text(report.usesBacsisSchema
                    ? "A+B+C+D = \(report.sumaVanzariCategorii.moneyString)  ·  Total = \(report.totalVanzari.moneyString)  ·  N+C+Alte = \(report.sumaPlatiEfective.moneyString)"
                    : report.usesCashCardOnlyPayments
                    ? "A+B+D = \(report.sumaVanzariCategorii.moneyString)  ·  Total = \(report.totalVanzari.moneyString)  ·  N+C = \(report.sumaPlatiEfective.moneyString)"
                    : "A+B+D = \(report.sumaVanzariCategorii.moneyString)  ·  Total = \(report.totalVanzari.moneyString)  ·  N+C+M = \(report.sumaPlatiEfective.moneyString)")
                Text("Notă: vânzările A/B/C sunt brute (TVA inclus). În NC: TVA + net + D.")
            }
            .font(.custom("Avenir Next", size: 13).weight(.semibold))
            .foregroundStyle(Color.accentInk)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.panelFill)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        )
        .sheet(isPresented: $showBalanceGap) {
            BalanceGapSheet(report: report)
        }
    }

    private var turaBadge: some View {
        Text(report.turaLabel)
            .font(.custom("Avenir Next", size: 11).weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(report.isNightShift ? Color.accentWarm.opacity(0.22) : Color.accentInk.opacity(0.14))
            .foregroundStyle(report.isNightShift ? Color.accentWarm : Color.accentInk)
            .clipShape(Capsule())
    }

    private var balanceBadge: some View {
        Group {
            if report.isBalanced {
                Text("Echilibrat")
                    .font(.custom("Avenir Next", size: 11).weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.okSoft.opacity(0.18))
                    .foregroundStyle(Color.okSoft)
                    .clipShape(Capsule())
            } else {
                Button {
                    showBalanceGap = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Diferență!")
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.custom("Avenir Next", size: 11).weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.dangerSoft.opacity(0.18))
                    .foregroundStyle(Color.dangerSoft)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                #if os(macOS)
                .help("Apasă pentru a vedea unde nu bat sumele")
                #endif
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldLabel("Data NC")
            HStack {
                Text(report.dateFormatted)
                    .font(.custom("Avenir Next", size: 15).weight(.semibold))
                    .foregroundStyle(Color.accentInk)
                Spacer()
                AppDatePicker(selection: $report.date, style: .iconOnly)
                    .tint(Color.accentInk)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.fieldFill)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.fieldStroke, lineWidth: 1)
            )
        }
    }

    private func intField(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldLabel(title)
            TextField(title, value: value, format: IntegerFormatStyle<Int>().grouping(.never))
                .textFieldStyle(.roundedBorder)
                .font(.custom("Avenir Next", size: 15).weight(.semibold))
                .foregroundStyle(Color.accentInk)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        }
    }

    private func moneyField(_ title: String, value: Binding<Decimal>) -> some View {
        EditableMoneyField(title: title, value: value)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.custom("Avenir Next", size: 12).weight(.semibold))
            .foregroundStyle(Color.labelMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Câmp sumă editabil liber — fără „3” → „3.00” în timpul tastării.
private struct EditableMoneyField: View {
    let title: String
    @Binding var value: Decimal

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.custom("Avenir Next", size: 12).weight(.semibold))
                .foregroundStyle(Color.labelMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("0.00", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.custom("Avenir Next", size: 15).weight(.semibold))
                .foregroundStyle(Color.accentInk)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .focused($isFocused)
                .onAppear { refreshDisplay() }
                .onChange(of: value) { _ in
                    guard !isFocused else { return }
                    refreshDisplay()
                }
                .onChange(of: isFocused) { focused in
                    if focused {
                        refreshForEditing()
                    } else {
                        commit(from: text)
                        refreshDisplay()
                    }
                }
                .onChange(of: text) { newValue in
                    guard isFocused else { return }
                    commit(from: newValue)
                }
                .onSubmit {
                    commit(from: text)
                    refreshDisplay()
                }
        }
    }

    private func refreshDisplay() {
        guard value != 0 else {
            text = ""
            return
        }
        text = Self.displayFormatter.string(from: value as NSDecimalNumber) ?? ""
    }

    private func refreshForEditing() {
        guard value != 0 else {
            text = ""
            return
        }
        var amount = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 2, .plain)
        text = NSDecimalNumber(decimal: rounded).stringValue
    }

    private func commit(from raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            if value != 0 { value = 0 }
            return
        }
        let normalized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let parsed = Decimal(string: normalized) else { return }
        if parsed != value { value = parsed }
    }

    private static let displayFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }()
}

struct RowsPreview: View {
    let rows: [NotaContabilaRow]

    private let headers = ["NC", "Jurnal", "Doc", "Debit", "Credit", "Valoare", "Cota"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Previzualizare notă contabilă (\(rows.count) rânduri)")
                .font(.custom("Avenir Next", size: 15).weight(.bold))
                .foregroundStyle(Color.accentInk)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: 0) {
                            cell("\(row.nrInreg)", width: 36)
                            cell(row.jurnal, width: 52)
                            cell(row.numarDocument, width: 72)
                            cell(row.contDebit, width: 64)
                            cell(row.contCredit, width: 64)
                            cell(row.valoare.moneyString, width: 88)
                            cell(row.cotaTva.map { NSDecimalNumber(decimal: $0).stringValue } ?? "", width: 44)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(index.isMultiple(of: 2) ? Color.tableRowAlt : Color.white)
                    }
                }
                .padding(.vertical, 6)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.fieldStroke, lineWidth: 1)
            )
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(zip(headers, [36, 52, 72, 64, 64, 88, 44] as [CGFloat])), id: \.0) { title, width in
                Text(title)
                    .font(.custom("Avenir Next", size: 12).weight(.bold))
                    .foregroundStyle(Color.accentInk)
                    .frame(width: width, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color.tableHeaderFill)
    }

    private func cell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(Color.accentInk)
            .frame(width: width, alignment: .leading)
            .lineLimit(1)
    }
}

// MARK: - Detaliu diferență (PDF POS)

private struct BalanceGapSheet: View {
    let report: ZReportData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Control sume — Z \(report.zNumber)")
                    .font(.custom("Avenir Next", size: 18).weight(.bold))
                    .foregroundStyle(Color.accentInk)
                Spacer()
                Button("Închide") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }

            Text("Liniile roșii nu bat cu totalul de pe bon — verifică categoriile A/B/C/D și plățile.")
                .font(.custom("Avenir Next", size: 13).weight(.medium))
                .foregroundStyle(Color.labelMuted)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(report.balanceCheckLines) { line in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: line.isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(line.isOK ? Color.okSoft : Color.dangerSoft)
                                .font(.system(size: 16, weight: .semibold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.title)
                                    .font(.custom("Avenir Next", size: 14).weight(.bold))
                                    .foregroundStyle(Color.accentInk)
                                Text(line.detail)
                                    .font(.custom("Avenir Next", size: 13).weight(.medium))
                                    .foregroundStyle(line.isOK ? Color.labelMuted : Color.dangerSoft)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(line.isOK ? Color.okSoft.opacity(0.08) : Color.dangerSoft.opacity(0.08))
                        )
                    }
                }
            }
        }
        .padding(20)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }
}
