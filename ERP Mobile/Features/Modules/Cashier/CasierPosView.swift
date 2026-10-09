import SwiftUI

struct CasierPosView: View {
    let location: CompanyWorkLocation
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var groups: [CMProductGroup] = []
    @State private var selectedGroup: CMProductGroup?
    @State private var tiles: [CasierPosTile] = []
    @State private var addonsByProduct: [UUID: [ProductSaleAddon]] = [:]
    @State private var tickets: [PosTicket]
    @State private var activeTicketId: UUID
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var notice: String?
    @State private var cuiBlock: CuiBlock?
    @State private var cuiLookup = 0
    @State private var showSlipFolder = false
    @State private var slipDraft: SlipDraft?
    @State private var takings = PosShiftTotals.zero
    @State private var menuOffer: MenuOffer?

    init(location: CompanyWorkLocation, onExit: @escaping () -> Void) {
        self.location = location
        self.onExit = onExit
        let first = PosTicket()
        _tickets = State(initialValue: [first])
        _activeTicketId = State(initialValue: first.id)
    }

    private var sideBySide: Bool { sizeClass != .compact }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if sideBySide {
                    HStack(alignment: .top, spacing: 16) {
                        catalog
                        receipt
                    }
                } else {
                    VStack(spacing: 12) {
                        catalog
                        receipt
                            .frame(maxHeight: 460)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .appTask { await loadGroups() }
        .appTask { await loadTakings() }
        .alert(L10n.tr("module.cashier.notice_title"), isPresented: noticeShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
        .sheet(item: $cuiBlock) { block in
            CuiBlockSheet(block: block) {
                let ticketId = block.ticketId
                updateActive {
                    guard $0.id == ticketId else { return }
                    $0.cui = ""
                    $0.clientName = ""
                    $0.clientAddress = ""
                    $0.cuiBlockStatus = ""
                    $0.cuiBlockName = ""
                    $0.printFiscalInvoice = false
                }
                cuiBlock = nil
            } onFix: {
                cuiBlock = nil
            }
        }
        .sheet(isPresented: $showSlipFolder) {
            DocumentDirectoryPicker(
                isPresented: $showSlipFolder,
                onPick: { url in
                    Task { await writeSlipPdfs(to: url) }
                },
                onCancel: { slipDraft = nil }
            )
        }
        .sheet(item: $menuOffer) { offer in
            MenuSaleSheet(offer: offer) { chosen in
                commitMenu(chosen)
            }
        }
    }

    private var noticeShown: Binding<Bool> {
        Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(PosChrome.navy)
                .lineLimit(2)
            Spacer(minLength: 8)
            reportButton(L10n.tr("module.cashier.report_x"), filled: false) {
                notice = L10n.tr("module.cashier.report_x_pending")
            }
            reportButton(L10n.tr("module.cashier.report_z"), filled: true) {
                Task { await closeShift() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
    }

    private var title: String {
        if let selectedGroup {
            return selectedGroup.name + " · " + location.denumire
        }
        return location.denumire
    }

    private var catalog: some View {
        ZStack {
            ScrollView {
                if selectedGroup == nil {
                    if groups.isEmpty && !isLoading {
                        Text(errorMessage ?? L10n.tr("module.cashier.no_groups"))
                            .foregroundColor(AppColors.secondary)
                            .padding()
                    } else {
                        groupGrid
                    }
                } else if tiles.isEmpty && !isLoading {
                    Text(errorMessage ?? L10n.tr("module.cashier.no_products"))
                        .foregroundColor(AppColors.secondary)
                        .padding()
                } else {
                    productGrid
                }
            }
            if isLoading {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(L10n.tr("module.cashier.receipt"))
                    .font(.title3.weight(.bold))
                    .foregroundColor(PosChrome.navy)
                Spacer(minLength: 4)
                ticketBar
            }
            .padding(.bottom, 8)

            TextField(L10n.tr("module.cashier.cui_placeholder"), text: cuiText)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.bottom, activeTicket.clientName.isEmpty ? (activeTicket.cui.isEmpty ? 8 : 4) : 2)

            if !activeTicket.clientName.isEmpty {
                Text(activeTicket.clientName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(PosChrome.navy)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, activeTicket.cui.isEmpty ? 8 : 4)
            }

            if !activeTicket.cui.isEmpty {
                Toggle(L10n.tr("module.cashier.print_fiscal_invoice"), isOn: printInvoice)
                    .tint(PosChrome.navy)
                Text(L10n.tr("module.cashier.print_fiscal_invoice_hint"))
                    .font(.caption2)
                    .foregroundColor(AppColors.secondary)
                    .padding(.bottom, 8)
            }

            ScrollView {
                if cart.isEmpty {
                    Text(L10n.tr("module.cashier.receipt_empty"))
                        .foregroundColor(AppColors.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 2) {
                        ForEach(cart) { row in
                            receiptLine(
                                qty: Self.shownQty(row.quantity),
                                name: row.name,
                                amount: row.menuHeader ? "" : Self.money(row.unitPrice * Decimal(row.quantity)),
                                vat: row.vatRate,
                                showVat: !row.menuHeader,
                                detailedVat: row.menuBlock != nil && !row.menuHeader,
                                addon: false,
                                onDelete: (row.menuBlock == nil || row.menuHeader) ? { removeLine(row.id) } : nil
                            )
                            if row.showsDiscount {
                                receiptLine(
                                    qty: "",
                                    name: "Discount 100%",
                                    amount: Self.money(-row.discountAmount),
                                    vat: nil,
                                    showVat: false,
                                    detailedVat: false,
                                    addon: true,
                                    onDelete: nil
                                )
                            }
                            ForEach(row.addons.filter { !Self.isSgr($0.name) }) { addon in
                                receiptLine(
                                    qty: "",
                                    name: addon.name,
                                    amount: Self.money(addon.perUnit * Decimal(row.quantity) * addon.unitPrice),
                                    vat: addon.vatRate,
                                    showVat: true,
                                    detailedVat: row.menuBlock != nil,
                                    addon: true,
                                    onDelete: nil
                                )
                            }
                        }
                        ForEach(Self.sgrLines(cart)) { line in
                            receiptLine(
                                qty: Self.qtyText(line.quantity),
                                name: line.name,
                                amount: Self.money(line.amount),
                                vat: line.vatRate,
                                showVat: true,
                                detailedVat: line.fromMenu,
                                addon: true,
                                onDelete: nil
                            )
                        }
                        if receiptDiscount > 0 {
                            receiptLine(
                                qty: "",
                                name: Self.discountTitle(activeTicket),
                                amount: Self.money(-receiptDiscount),
                                vat: nil,
                                showVat: false,
                                detailedVat: false,
                                addon: true,
                                onDelete: nil
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Text(L10n.tr("module.cashier.vat_legend"))
                .font(.caption2)
                .foregroundColor(AppColors.secondary)
                .padding(.top, 6)

            HStack {
                Text(L10n.tr("module.cashier.total"))
                Spacer()
                Text(Self.ron(cartTotal))
            }
            .font(.title3.weight(.bold))
            .foregroundColor(PosChrome.navy)
            .padding(.top, 8)

            HStack(spacing: 8) {
                Text("Discount %")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(PosChrome.navy)
                TextField("0", text: discountText)
                    .font(.title3.weight(.bold))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 84)
                Spacer(minLength: 8)
                if receiptDiscount > 0 {
                    Text(Self.money(-receiptDiscount))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(PosChrome.navy)
                }
            }
            .padding(.top, 10)

            HStack(spacing: 6) {
                payButton(L10n.tr("module.cashier.cash"), selected: activeTicket.pay == .cash) {
                    updateActive {
                        $0.pay = .cash
                        $0.modern = nil
                    }
                }
                payButton(L10n.tr("module.cashier.card"), selected: activeTicket.pay == .card) {
                    updateActive {
                        $0.pay = .card
                        $0.modern = nil
                    }
                }
                payButton(L10n.tr("module.cashier.modern"), selected: activeTicket.pay == .modern, enabled: activeTicket.cui.isEmpty) {
                    guard activeTicket.cui.isEmpty else { return }
                    updateActive { $0.pay = .modern }
                }
            }
            .padding(.top, 12)

            if activeTicket.pay == .modern && activeTicket.cui.isEmpty {
                HStack(spacing: 6) {
                    payButton(L10n.tr("module.cashier.glovo"), selected: activeTicket.modern == .glovo) {
                        updateActive {
                            $0.pay = .modern
                            $0.modern = .glovo
                        }
                    }
                    payButton(L10n.tr("module.cashier.bolt"), selected: activeTicket.modern == .bolt) {
                        updateActive {
                            $0.pay = .modern
                            $0.modern = .bolt
                        }
                    }
                    payButton(L10n.tr("module.cashier.wolt"), selected: activeTicket.modern == .wolt) {
                        updateActive {
                            $0.pay = .modern
                            $0.modern = .wolt
                        }
                    }
                }
                .padding(.top, 8)
            }

            if activeTicket.pay == .cash {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("module.cashier.tender"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        TextField("0,00", text: tenderText)
                            .font(.title3.weight(.bold))
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L10n.tr("module.cashier.change"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        Text(Self.money(changeAmount))
                            .font(.title3.weight(.bold))
                            .foregroundColor(PosChrome.navy)
                        if tenderIsShort {
                            Text(L10n.tr("module.cashier.tender_short"))
                                .font(.caption2)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.leading, 8)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color(.separator)).frame(width: 1)
                    }
                }
                .padding(.top, 10)
            }

            Button {
                emit()
            } label: {
                Text(activeTicket.printFiscalInvoice && !activeTicket.cui.isEmpty
                    ? L10n.tr("module.cashier.emit_with_invoice")
                    : L10n.tr("module.cashier.emit"))
                    .font(.title3.weight(.bold))
                    .foregroundColor(PosChrome.navy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(PosChrome.gold))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            Text(L10n.tr("module.cashier.printer_off"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .padding(16)
        .frame(width: sideBySide ? 380 : nil, alignment: .top)
        .frame(maxWidth: sideBySide ? 380 : .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    private var footer: some View {
        ZStack {
            Text(takingsLine)
                .font(.caption.weight(.semibold))
                .foregroundColor(PosChrome.navy)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 170)
            HStack {
                if selectedGroup != nil {
                    Button {
                        selectedGroup = nil
                        tiles = []
                        errorMessage = nil
                    } label: {
                        Text(L10n.tr("module.cashier.back_to_groups"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(PosChrome.navy))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                Button(action: onExit) {
                    Text(L10n.tr("module.cashier.exit"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.red))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
    }

    private var groupGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)], spacing: 16) {
            ForEach(groups) { group in
                Button {
                    Task { await open(group) }
                } label: {
                    Text(group.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(PosChrome.navy)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var productGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(tiles) { tile in
                Button {
                    add(tile)
                } label: {
                    CasierProductTile(tile: tile)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cart: [PosCartRow] {
        activeTicket.lines
    }

    private var activeTicket: PosTicket {
        tickets.first { $0.id == activeTicketId } ?? tickets[0]
    }

    private var cartTotal: Decimal {
        Self.ticketTotal(activeTicket)
    }

    private var receiptDiscount: Decimal {
        Self.percentCuts(activeTicket).discount
    }

    private var discountText: Binding<String> {
        Binding(
            get: { activeTicket.discountText },
            set: { value in
                let next = Self.normalizePercent(value)
                updateActive { $0.discountText = next }
            }
        )
    }

    private var receivedAmount: Decimal? {
        Self.parseMoney(activeTicket.tenderText)
    }

    private var changeAmount: Decimal {
        guard activeTicket.pay == .cash, let received = receivedAmount, received > cartTotal else { return 0 }
        return received - cartTotal
    }

    private var tenderIsShort: Bool {
        guard activeTicket.pay == .cash, let received = receivedAmount, received > 0 else { return false }
        return received < cartTotal
    }

    private var cuiText: Binding<String> {
        Binding(
            get: { activeTicket.cui },
            set: { value in
                let next = Self.normalizeCui(value)
                let ticketId = activeTicketId
                updateActive {
                    let changed = $0.cui != next
                    let sameDigits = Self.cuiDigits($0.cui) == Self.cuiDigits(next)
                    $0.cui = next
                    if next.isEmpty { $0.printFiscalInvoice = false }
                    if !next.isEmpty, $0.pay == .modern {
                        $0.pay = .cash
                        $0.modern = nil
                    }
                    if changed && !sameDigits {
                        $0.clientName = ""
                        $0.clientAddress = ""
                        $0.cuiBlockStatus = ""
                        $0.cuiBlockName = ""
                    }
                }
                scheduleClientLookup(cui: next, ticketId: ticketId)
            }
        )
    }

    private func scheduleClientLookup(cui: String, ticketId: UUID) {
        cuiLookup += 1
        let token = cuiLookup
        guard !cui.isEmpty else { return }
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard token == cuiLookup else { return }
            do {
                let company = try await AnafService.fetchCompany(cui: cui)
                guard token == cuiLookup else { return }
                let shown = Self.fiscalCui(digits: company.cui, vatPayer: company.platitorTva == true)
                if let status = company.fiscalBlockStatus {
                    updateActive {
                        guard $0.id == ticketId, Self.cuiDigits($0.cui) == Self.cuiDigits(cui) else { return }
                        $0.cui = shown
                        $0.clientName = ""
                        $0.clientAddress = ""
                        $0.cuiBlockStatus = status
                        $0.cuiBlockName = company.denumire
                    }
                    cuiBlock = CuiBlock(name: company.denumire, cui: shown, status: status, ticketId: ticketId)
                    return
                }
                updateActive {
                    guard $0.id == ticketId, Self.cuiDigits($0.cui) == Self.cuiDigits(cui) else { return }
                    $0.clientName = company.denumire
                    $0.clientAddress = company.adresa ?? ""
                    $0.cuiBlockStatus = ""
                    $0.cuiBlockName = ""
                    $0.cui = shown
                }
            } catch {
                guard token == cuiLookup else { return }
                updateActive {
                    guard $0.id == ticketId, $0.cui == cui else { return }
                    $0.clientName = ""
                    $0.clientAddress = ""
                }
            }
        }
    }

    private var printInvoice: Binding<Bool> {
        Binding(
            get: { activeTicket.printFiscalInvoice },
            set: { value in updateActive { $0.printFiscalInvoice = value && !$0.cui.isEmpty } }
        )
    }

    private var tenderText: Binding<String> {
        Binding(
            get: { activeTicket.tenderText },
            set: { value in updateActive { $0.tenderText = Self.normalizeTender(value) } }
        )
    }

    private var ticketBar: some View {
        HStack(spacing: 6) {
            ForEach(Array(tickets.enumerated()), id: \.element.id) { index, ticket in
                let selected = ticket.id == activeTicketId
                HStack(spacing: 2) {
                    Button {
                        activeTicketId = ticket.id
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                            if !ticket.lines.isEmpty {
                                Circle()
                                    .fill(selected ? Color.white : PosChrome.gold)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .foregroundColor(selected ? .white : PosChrome.navy)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected ? PosChrome.navy : Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(PosChrome.navy, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    if ticket.lines.isEmpty && tickets.count > 1 {
                        Button {
                            closeTicket(ticket.id)
                        } label: {
                            Text("×")
                                .font(.headline)
                                .foregroundColor(AppColors.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if tickets.count < 4 {
                Button {
                    openTicket()
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(PosChrome.navy)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(PosChrome.navy, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func reportButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(filled ? .white : PosChrome.navy)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(filled ? PosChrome.navy : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(PosChrome.navy, lineWidth: filled ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func payButton(_ title: String, selected: Bool, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(selected ? .white : PosChrome.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? PosChrome.navy : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PosChrome.navy, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private func removeLine(_ id: UUID) {
        updateActive { ticket in
            if let row = ticket.lines.first(where: { $0.id == id }), let block = row.menuBlock {
                ticket.lines.removeAll { $0.menuBlock == block }
            } else {
                ticket.lines.removeAll { $0.id == id }
            }
        }
    }

    private func receiptLine(qty: String, name: String, amount: String, vat: Decimal?, showVat: Bool, detailedVat: Bool = false, addon: Bool, onDelete: (() -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(qty)
                .font(.subheadline)
                .frame(width: 18, alignment: .leading)
            Text(name)
                .font(addon ? .subheadline : .body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(showVat ? Self.vatMark(vat, detailed: detailedVat) : "")
                .font(.caption.weight(.bold))
                .frame(width: detailedVat ? 52 : 14, alignment: .trailing)
            Text(amount)
                .font(addon ? .subheadline : .body)
            if let onDelete {
                Button(action: onDelete) {
                    Text("×")
                        .font(.body.weight(.bold))
                        .foregroundColor(.red)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("module.cashier.remove_line"))
            } else {
                Color.clear.frame(width: 22, height: 22)
            }
        }
        .foregroundColor(addon ? AppColors.secondary : PosChrome.navy)
    }

    private var takingsLine: String {
        [
            (L10n.tr("module.cashier.cash"), takings.cash),
            (L10n.tr("module.cashier.card"), takings.card),
            (L10n.tr("module.cashier.glovo"), takings.glovo),
            (L10n.tr("module.cashier.bolt"), takings.bolt),
            (L10n.tr("module.cashier.wolt"), takings.wolt)
        ]
        .map { "\($0.0) = \(Self.money($0.1))" }
        .joined(separator: "    ")
    }

    private func emit() {
        if cart.isEmpty {
            notice = L10n.tr("module.cashier.emit_empty")
            return
        }
        if !activeTicket.cuiBlockStatus.isEmpty {
            cuiBlock = CuiBlock(
                name: activeTicket.cuiBlockName,
                cui: activeTicket.cui,
                status: activeTicket.cuiBlockStatus,
                ticketId: activeTicket.id
            )
            return
        }
        guard let channel = Self.takingChannel(activeTicket) else {
            notice = L10n.tr("module.cashier.choose_modern")
            return
        }
        let companyId = companyManager.currentCompany?.id
        let locationId = location.id
        let ticket = activeTicket
        let amount = Self.ticketTotal(ticket)
        guard ticket.printFiscalInvoice, !ticket.cui.isEmpty else {
            Task {
                do {
                    try await PosShiftTakingsService.record(locationId: locationId, channel: channel, amount: amount)
                    let stockNote = await Self.consumeStock(Self.stockCuts(ticket))
                    await loadTakings()
                    clearActiveTicket()
                    notice = L10n.tr("module.cashier.emit_recorded") + stockNote
                } catch {
                    notice = error.localizedDescription
                }
            }
            return
        }
        Task {
            guard let companyId else {
                notice = L10n.tr("module.cashier.emit_invoice_no_series")
                return
            }
            do {
                guard let series = try await DocumentSeriesService.fiscalSeries(companyId: companyId, workLocationId: locationId) else {
                    notice = L10n.tr("module.cashier.emit_invoice_no_series")
                    return
                }
                var clientCui = ticket.cui
                var clientName = ticket.clientName
                var clientAddress = ticket.clientAddress
                if clientName.isEmpty || clientAddress.isEmpty {
                    if let company = try? await AnafService.fetchCompany(cui: ticket.cui) {
                        clientCui = Self.fiscalCui(digits: company.cui, vatPayer: company.platitorTva == true)
                        if clientName.isEmpty { clientName = company.denumire }
                        if clientAddress.isEmpty { clientAddress = company.adresa ?? "" }
                    }
                }
                slipDraft = SlipDraft(
                    seriesId: series.id,
                    cui: clientCui,
                    clientName: clientName,
                    clientAddress: clientAddress,
                    payment: Self.paymentLabel(ticket),
                    tender: ticket.pay == .cash ? ticket.tenderText : "",
                    total: Self.money(amount),
                    takingChannel: channel,
                    takingAmount: amount,
                    lines: Self.slipLines(ticket),
                    bands: Self.vatBands(ticket),
                    invoiceLines: Self.invoiceLines(ticket),
                    stock: Self.stockCuts(ticket)
                )
                showSlipFolder = true
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    private func writeSlipPdfs(to folder: URL) async {
        guard let draft = slipDraft else { return }
        let accessed = folder.startAccessingSecurityScopedResource()
        defer { if accessed { folder.stopAccessingSecurityScopedResource() } }
        do {
            let issued = try await DocumentSeriesService.consumeFiscalNumber(id: draft.seriesId)
            let company = companyManager.currentCompany
            let supplier = Self.supplierLines(company)
            let stamp = Self.slipStamp()
            let online = NetworkMonitor.shared.isOnline
            var bonUrl = ""
            var invoiceUrl = ""
            var bonPath: String?
            var invoicePath: String?
            if online, let companyId = company?.id {
                let bonTarget = try PosDocumentStore.target(companyId: companyId)
                let invoiceTarget = try PosDocumentStore.target(companyId: companyId)
                bonUrl = bonTarget.url
                invoiceUrl = invoiceTarget.url
                bonPath = bonTarget.path
                invoicePath = invoiceTarget.path
            }
            var bon = PosSlipPdf.make(Self.receiptRows(
                supplier: supplier,
                location: location.denumire,
                stamp: stamp,
                draft: draft,
                documentUrl: bonUrl
            ))
            var invoice = PosSlipPdf.make(Self.invoiceRows(
                supplier: supplier,
                serie: issued.serie,
                number: issued.number,
                stamp: stamp,
                draft: draft,
                documentUrl: invoiceUrl
            ))
            if let bonPath, let invoicePath {
                do {
                    try await PosDocumentStore.upload(path: bonPath, data: bon)
                    try await PosDocumentStore.upload(path: invoicePath, data: invoice)
                } catch {
                    bon = PosSlipPdf.make(Self.receiptRows(
                        supplier: supplier,
                        location: location.denumire,
                        stamp: stamp,
                        draft: draft,
                        documentUrl: ""
                    ))
                    invoice = PosSlipPdf.make(Self.invoiceRows(
                        supplier: supplier,
                        serie: issued.serie,
                        number: issued.number,
                        stamp: stamp,
                        draft: draft,
                        documentUrl: ""
                    ))
                }
            }
            let bonName = "Bon fiscal \(stamp.file).pdf"
            let invoiceName = "Factura \(issued.serie) \(issued.number).pdf"
            try bon.write(to: folder.appendingPathComponent(bonName), options: .atomic)
            try invoice.write(to: folder.appendingPathComponent(invoiceName), options: .atomic)
            var recap = ""
            do {
                try await PosShiftTakingsService.record(
                    locationId: location.id,
                    channel: draft.takingChannel,
                    amount: draft.takingAmount
                )
                await loadTakings()
            } catch {
                recap = " " + error.localizedDescription
            }
            recap += await Self.consumeStock(draft.stock)
            clearActiveTicket()
            notice = L10n.tr("module.cashier.pdf_saved", bonName, invoiceName) + recap
        } catch {
            notice = error.localizedDescription
        }
        slipDraft = nil
    }

    private func clearActiveTicket() {
        updateActive {
            $0.lines = []
            $0.cui = ""
            $0.clientName = ""
            $0.clientAddress = ""
            $0.cuiBlockStatus = ""
            $0.cuiBlockName = ""
            $0.tenderText = ""
            $0.printFiscalInvoice = false
            $0.pay = .cash
            $0.modern = nil
            $0.discountText = ""
        }
    }

    private func loadTakings() async {
        do {
            takings = try await PosShiftTakingsService.open(locationId: location.id)
        } catch {
            takings = .zero
        }
    }

    private func closeShift() async {
        do {
            try await PosShiftTakingsService.closeZ(locationId: location.id)
            await loadTakings()
            notice = L10n.tr("module.cashier.report_z_closed")
        } catch {
            notice = error.localizedDescription
        }
    }

    private static func takingChannel(_ ticket: PosTicket) -> String? {
        switch ticket.pay {
        case .cash: return "cash"
        case .card: return "card"
        case .modern: return ticket.modern?.rawValue
        }
    }

    private static func paymentLabel(_ ticket: PosTicket) -> String {
        switch ticket.pay {
        case .cash: return L10n.tr("module.cashier.cash")
        case .card: return L10n.tr("module.cashier.card")
        case .modern:
            switch ticket.modern {
            case .glovo: return L10n.tr("module.cashier.glovo")
            case .bolt: return L10n.tr("module.cashier.bolt")
            case .wolt: return L10n.tr("module.cashier.wolt")
            case nil: return L10n.tr("module.cashier.modern")
            }
        }
    }

    private static func subtotal(_ ticket: PosTicket) -> Decimal {
        ticket.lines.reduce(Decimal.zero) { partial, line in
            let addons = line.addons.reduce(Decimal.zero) { $0 + $1.perUnit * Decimal(line.quantity) * $1.unitPrice }
            return partial + line.lineTotal + addons
        }
    }

    private static func ticketTotal(_ ticket: PosTicket) -> Decimal {
        subtotal(ticket) - percentCuts(ticket).discount
    }

    private static func discountPercent(_ ticket: PosTicket) -> Decimal {
        guard let value = parseMoney(ticket.discountText), value > 0 else { return 0 }
        return min(value, 100)
    }

    private static func discountTitle(_ ticket: PosTicket) -> String {
        "Discount \(percent(discountPercent(ticket)))"
    }

    private static func invoiceLines(_ ticket: PosTicket) -> [InvoiceLine] {
        var rows: [InvoiceLine] = []
        for line in ticket.lines {
            if line.menuHeader {
                rows.append(InvoiceLine(name: line.name, quantity: "", unitNet: "", value: "", vat: "", netAmount: 0, vatAmount: 0))
                continue
            }
            let gross = line.unitPrice * Decimal(line.quantity)
            rows.append(invoiceFigure(line.name, Decimal(line.quantity), gross, line.vatRate))
            if line.showsDiscount {
                rows.append(invoiceFigure("Discount 100%", Decimal(line.quantity), -line.discountAmount, line.vatRate))
            }
            for addon in line.addons where !isSgr(addon.name) {
                let quantity = addon.perUnit * Decimal(line.quantity)
                rows.append(invoiceFigure(addon.name, quantity, quantity * addon.unitPrice, addon.vatRate))
            }
        }
        for line in sgrLines(ticket.lines) {
            rows.append(invoiceFigure(line.name, line.quantity, line.amount, line.vatRate))
        }
        let title = discountTitle(ticket)
        for cut in percentCuts(ticket).cuts where cut.gross != 0 {
            rows.append(invoiceFigure(title, 1, -cut.gross, Decimal(cut.rate)))
        }
        return rows
    }

    private static func invoiceFigure(_ name: String, _ quantity: Decimal, _ gross: Decimal, _ rate: Decimal?) -> InvoiceLine {
        let grossRounded = roundMoney(gross)
        let vat = extractedVat(grossRounded, rate)
        let net = grossRounded - vat
        let unit = quantity == 0 ? Decimal.zero : roundMoney(net / quantity)
        return InvoiceLine(
            name: name,
            quantity: qtyText(quantity),
            unitNet: money(unit),
            value: money(net),
            vat: money(vat),
            netAmount: net,
            vatAmount: vat,
            vatPercent: percent(rate ?? 0)
        )
    }

    private static func extractedVat(_ gross: Decimal, _ rate: Decimal?) -> Decimal {
        let percent = rate ?? 0
        if percent <= 0 || gross == 0 { return 0 }
        return roundMoney(gross * percent / (percent + 100))
    }

    private static func slipLines(_ ticket: PosTicket) -> [(name: String, amount: String)] {
        var rows: [(String, String)] = []
        for line in ticket.lines {
            if line.menuHeader {
                rows.append((Self.lineLabel(quantity: line.quantity, name: line.name), ""))
                continue
            }
            let onMenu = line.menuBlock != nil
            let amount = money(line.unitPrice * Decimal(line.quantity))
            rows.append((Self.lineLabel(quantity: line.quantity, name: line.name), Self.markedAmount(amount, vat: line.vatRate, marked: onMenu)))
            if line.showsDiscount {
                rows.append(("Discount 100%", money(-line.discountAmount)))
            }
            for addon in line.addons where !isSgr(addon.name) {
                let addonAmount = addon.perUnit * Decimal(line.quantity) * addon.unitPrice
                rows.append((addon.name, Self.markedAmount(money(addonAmount), vat: addon.vatRate, marked: onMenu)))
            }
        }
        for line in sgrLines(ticket.lines) {
            rows.append(("\(qtyText(line.quantity)) \(line.name)", Self.markedAmount(money(line.amount), vat: line.vatRate, marked: line.fromMenu)))
        }
        let discount = percentCuts(ticket).discount
        if discount > 0 {
            rows.append((discountTitle(ticket), money(-discount)))
        }
        return rows
    }

    private static func markedAmount(_ amount: String, vat: Decimal?, marked: Bool) -> String {
        guard marked else { return amount }
        let mark = vatMark(vat, detailed: true)
        return mark.isEmpty ? amount : "\(mark)  \(amount)"
    }

    private static func vatMark(_ rate: Decimal?, detailed: Bool) -> String {
        let letter = PosVat.letter(rate)
        guard !letter.isEmpty else { return "" }
        guard detailed, let rate else { return letter }
        return "\(letter) \(percent(rate))"
    }

    private static func percent(_ rate: Decimal) -> String {
        var source = rate
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let text = formatter.string(from: NSDecimalNumber(decimal: rounded)) ?? NSDecimalNumber(decimal: rounded).stringValue
        return text + "%"
    }

    private static func shownQty(_ quantity: Int) -> String {
        quantity > 1 ? String(quantity) : ""
    }

    private static func lineLabel(quantity: Int, name: String) -> String {
        quantity > 1 ? "\(quantity) \(name)" : name
    }

    private static func isSgr(_ name: String) -> Bool {
        name.range(of: "SGR", options: .caseInsensitive) != nil
    }

    private static func vatBands(_ ticket: PosTicket) -> [VatBand] {
        percentCuts(ticket).bands
    }

    private static func percentCuts(_ ticket: PosTicket) -> (discount: Decimal, cuts: [(rate: Int, gross: Decimal)], bands: [VatBand]) {
        var grossA = Decimal.zero
        var grossB = Decimal.zero
        var grossD = Decimal.zero
        var sgrA = Decimal.zero
        var sgrB = Decimal.zero
        var sgrD = Decimal.zero
        func add(_ rate: Decimal?, _ amount: Decimal, discountable: Bool) {
            switch PosVat.letter(rate) {
            case "A":
                if discountable { grossA += amount } else { sgrA += amount }
            case "B":
                if discountable { grossB += amount } else { sgrB += amount }
            default:
                if discountable { grossD += amount } else { sgrD += amount }
            }
        }
        for line in ticket.lines where !line.menuHeader {
            add(line.vatRate, line.lineTotal, discountable: true)
            for addon in line.addons {
                add(addon.vatRate, addon.perUnit * Decimal(line.quantity) * addon.unitPrice, discountable: !isSgr(addon.name))
            }
        }
        let percentValue = discountPercent(ticket)
        func share(_ gross: Decimal) -> Decimal {
            guard percentValue > 0, gross != 0 else { return 0 }
            return roundMoney(gross * percentValue / 100)
        }
        var cutA = share(grossA)
        var cutB = share(grossB)
        var cutD = share(grossD)
        let target = percentValue > 0 ? roundMoney((grossA + grossB + grossD) * percentValue / 100) : 0
        let drift = target - (cutA + cutB + cutD)
        if drift != 0 {
            if grossA >= grossB && grossA >= grossD && grossA != 0 {
                cutA += drift
            } else if grossB >= grossD && grossB != 0 {
                cutB += drift
            } else if grossD != 0 {
                cutD += drift
            }
        }
        cutA = min(max(Decimal.zero, cutA), grossA)
        cutB = min(max(Decimal.zero, cutB), grossB)
        cutD = min(max(Decimal.zero, cutD), grossD)
        var cuts: [(rate: Int, gross: Decimal)] = []
        if cutA != 0 { cuts.append((21, cutA)) }
        if cutB != 0 { cuts.append((11, cutB)) }
        if cutD != 0 { cuts.append((0, cutD)) }
        var bands: [VatBand] = []
        let netA = grossA - cutA + sgrA
        let netB = grossB - cutB + sgrB
        let netD = grossD - cutD + sgrD
        if netA != 0 { bands.append(makeBand(letter: "A", rate: 21, gross: netA)) }
        if netB != 0 { bands.append(makeBand(letter: "B", rate: 11, gross: netB)) }
        if netD != 0 { bands.append(makeBand(letter: "D", rate: 0, gross: netD)) }
        return (cutA + cutB + cutD, cuts, bands)
    }

    private static func makeBand(letter: String, rate: Int, gross: Decimal) -> VatBand {
        let vat = rate == 0 ? Decimal.zero : roundMoney(gross * Decimal(rate) / Decimal(100 + rate))
        return VatBand(letter: letter, rate: rate, gross: gross, vat: vat)
    }

    private static func roundMoney(_ value: Decimal) -> Decimal {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded
    }

    private struct SgrSlipLine: Identifiable {
        let id: String
        let name: String
        let quantity: Decimal
        let amount: Decimal
        let vatRate: Decimal
        let fromMenu: Bool
    }

    private static func sgrLines(_ rows: [PosCartRow]) -> [SgrSlipLine] {
        struct Key: Hashable {
            let name: String
            let price: Decimal
            let vat: Decimal
        }
        var order: [Key] = []
        var quantities: [Key: Decimal] = [:]
        var names: [Key: String] = [:]
        var fromMenu: [Key: Bool] = [:]
        for row in rows {
            for addon in row.addons where isSgr(addon.name) {
                let key = Key(name: addon.name.lowercased(), price: addon.unitPrice, vat: addon.vatRate)
                if quantities[key] == nil {
                    order.append(key)
                    names[key] = addon.name
                }
                quantities[key, default: 0] += addon.perUnit * Decimal(row.quantity)
                if row.menuBlock != nil {
                    fromMenu[key] = true
                }
            }
        }
        return order.map { key in
            let quantity = quantities[key] ?? 0
            return SgrSlipLine(
                id: "\(key.name)|\(key.price)|\(key.vat)",
                name: names[key] ?? "SGR",
                quantity: quantity,
                amount: quantity * key.price,
                vatRate: key.vat,
                fromMenu: fromMenu[key] == true
            )
        }
    }

    private static func qtyText(_ value: Decimal) -> String {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        if rounded == value {
            return NSDecimalNumber(decimal: value).stringValue
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? NSDecimalNumber(decimal: value).stringValue
    }

    private static func supplierLines(_ company: Company?) -> [String] {
        guard let company else { return [] }
        var lines = [company.denumire]
        if let cui = company.cui?.trimmingCharacters(in: .whitespacesAndNewlines), !cui.isEmpty {
            lines.append("CUI \(cui)")
        }
        if let address = company.adresa?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            lines.append(address)
        } else {
            let street = [company.hqStreet, company.hqStreetNumber]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let place = [company.hqCity, company.hqCounty]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            if !street.isEmpty { lines.append(street) }
            if !place.isEmpty { lines.append(place) }
        }
        return lines
    }

    private static func slipStamp() -> (shown: String, file: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        let shown = formatter.string(from: Date())
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return (shown, formatter.string(from: Date()))
    }

    private static func receiptRows(supplier: [String], location: String, stamp: (shown: String, file: String), draft: SlipDraft, documentUrl: String) -> [PosSlipPdf.Row] {
        var rows = [PosSlipPdf.Row.title("BON FISCAL")]
        rows.append(contentsOf: supplier.map { PosSlipPdf.Row.center($0, size: 7) })
        if !location.isEmpty { rows.append(.center(location, size: 7)) }
        rows.append(.center(stamp.shown, size: 8))
        rows.append(.line(" "))
        if !draft.cui.isEmpty { rows.append(.line("CUI client \(draft.cui)")) }
        if !draft.clientName.isEmpty { rows.append(.line(draft.clientName, bold: true)) }
        rows.append(.line(" "))
        for line in draft.lines {
            rows.append(.pair(line.name, line.amount))
        }
        rows.append(.line(" "))
        rows.append(.pair("TOTAL", draft.total, bold: true))
        for band in draft.bands {
            rows.append(.pair("BRUT \(band.letter)", Self.ron(band.gross)))
            rows.append(.pair("TVA \(band.rate)%", Self.ron(band.vat)))
        }
        rows.append(.line(draft.payment))
        if !draft.tender.isEmpty { rows.append(.line("Primește \(draft.tender)")) }
        rows.append(.line(" "))
        if !documentUrl.isEmpty { rows.append(.qr(documentUrl)) }
        rows.append(.center("PDF — imprimanta fiscală nu este conectată", size: 6))
        rows.append(.line(" "))
        rows.append(.center("Document generat cu ERP Mobile by DateConta", size: 6))
        return rows
    }

    private static func invoiceRows(supplier: [String], serie: String, number: Int, stamp: (shown: String, file: String), draft: SlipDraft, documentUrl: String) -> [PosSlipPdf.Row] {
        var rows = [PosSlipPdf.Row.title("FACTURĂ FISCALĂ")]
        rows.append(.center("\(serie) \(number)", size: 10))
        rows.append(.center(stamp.shown, size: 8))
        rows.append(.line(" "))
        rows.append(.line("FURNIZOR", bold: true))
        rows.append(contentsOf: supplier.map { PosSlipPdf.Row.line($0, size: 7) })
        rows.append(.line(" "))
        rows.append(.line("CLIENT", bold: true))
        if !draft.clientName.isEmpty { rows.append(.line(draft.clientName, bold: true)) }
        if !draft.cui.isEmpty { rows.append(.line("CUI \(draft.cui)")) }
        if !draft.clientAddress.isEmpty { rows.append(.line(draft.clientAddress, size: 7)) }
        rows.append(.line(" "))
        rows.append(.cells(["Cant.", "Preț f. TVA", "Valoare", "TVA", "%"], size: 6))
        for line in draft.invoiceLines {
            rows.append(.line(line.name, bold: true))
            if !line.quantity.isEmpty {
                rows.append(.cells([line.quantity, line.unitNet, line.value, line.vat, line.vatPercent]))
            }
        }
        rows.append(.line(" "))
        let net = draft.invoiceLines.reduce(Decimal.zero) { $0 + $1.netAmount }
        let vat = draft.invoiceLines.reduce(Decimal.zero) { $0 + $1.vatAmount }
        rows.append(.pair("Baza", Self.ron(net)))
        rows.append(.pair("TVA", Self.ron(vat)))
        rows.append(.pair("TOTAL", draft.total, bold: true))
        rows.append(.line("Încasare: \(draft.payment)"))
        rows.append(.line(" "))
        if !documentUrl.isEmpty { rows.append(.qr(documentUrl)) }
        rows.append(.center("80 mm · PDF — imprimanta fiscală nu este conectată", size: 6))
        rows.append(.line(" "))
        rows.append(.center("Document generat cu ERP Mobile by DateConta", size: 6))
        return rows
    }

    private func updateActive(_ change: (inout PosTicket) -> Void) {
        guard let index = tickets.firstIndex(where: { $0.id == activeTicketId }) else { return }
        change(&tickets[index])
    }

    private func openTicket() {
        guard tickets.count < 4 else {
            notice = L10n.tr("module.cashier.tickets_full")
            return
        }
        let ticket = PosTicket()
        tickets.append(ticket)
        activeTicketId = ticket.id
    }

    private func closeTicket(_ id: UUID) {
        guard tickets.count > 1, let index = tickets.firstIndex(where: { $0.id == id }), tickets[index].lines.isEmpty else { return }
        tickets.remove(at: index)
        if activeTicketId == id {
            activeTicketId = tickets[min(index, tickets.count - 1)].id
        }
    }

    private func add(_ tile: CasierPosTile) {
        if tile.isMenu {
            Task { await beginMenu(tile) }
            return
        }
        guard let key = UUID(uuidString: tile.id) else { return }
        updateActive { ticket in
            if let index = ticket.lines.firstIndex(where: { $0.id == key }) {
                ticket.lines[index].quantity += 1
                return
            }
            ticket.lines.append(PosCartRow(
                id: key,
                name: tile.name,
                unitPrice: tile.unitPrice,
                vatRate: tile.vatRate,
                quantity: 1,
                addons: extras(for: tile.productId)
            ))
        }
    }

    private func extras(for productId: UUID?) -> [PosCartAddon] {
        guard let productId else { return [] }
        return (addonsByProduct[productId] ?? []).compactMap { addon in
            guard let ref = addon.addon, addon.cantitate > 0 else { return nil }
            return PosCartAddon(
                id: addon.id,
                productId: addon.addonProductId,
                name: ref.denumire,
                perUnit: addon.cantitate,
                unitPrice: ref.pretVanzare,
                vatRate: ref.cotaTva
            )
        }
    }

    private func beginMenu(_ tile: CasierPosTile) async {
        guard let menuId = UUID(uuidString: tile.id) else { return }
        do {
            let lines = try await CMProductGroupService.fetchMenuLines(menuId: menuId)
            guard let mainLine = lines.first(where: { $0.role == "main" }) else {
                notice = "Completați meniul: un produs principal și un produs secundar."
                return
            }
            let secondaryLines = Array(lines.filter { $0.role == "secondary" }.prefix(11))
            guard !secondaryLines.isEmpty else {
                notice = "Completați meniul: un produs principal și un produs secundar."
                return
            }
            let ids = [mainLine.productId] + secondaryLines.map(\.productId)
            let products = try await ProductService.fetchProducts(ids: ids)
            let byId = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            let loaded = (try? await ProductSaleAddonService.fetchAddons(productIds: ids)) ?? [:]
            for (id, rows) in loaded {
                addonsByProduct[id] = rows
            }
            func choice(_ productId: UUID, selected: Bool) -> MenuChoice? {
                guard let product = byId[productId] else { return nil }
                return MenuChoice(
                    id: product.id,
                    name: product.denumire,
                    vatRate: product.cotaTva,
                    salePrice: product.pretVanzare,
                    selected: selected,
                    addons: extras(for: product.id)
                )
            }
            guard let main = choice(mainLine.productId, selected: true) else {
                notice = "Completați meniul: un produs principal și un produs secundar."
                return
            }
            let secondaries = secondaryLines.compactMap { choice($0.productId, selected: false) }
            guard !secondaries.isEmpty else {
                notice = "Completați meniul: un produs principal și un produs secundar."
                return
            }
            menuOffer = MenuOffer(
                id: menuId,
                name: tile.name,
                price: tile.unitPrice,
                main: main,
                secondaries: secondaries,
                allowsMultiple: tile.allowsMultipleSecondaries
            )
        } catch {
            notice = error.localizedDescription
        }
    }

    private func commitMenu(_ offer: MenuOffer) {
        let selected = [offer.main] + offer.secondaries.filter(\.selected)
        let sgr = selected.reduce(Decimal.zero) { partial, choice in
            partial + choice.addons.reduce(Decimal.zero) { sum, addon in
                Self.isSgr(addon.name) ? sum + addon.perUnit * addon.unitPrice : sum
            }
        }
        let mainPrice = max(Decimal.zero, offer.price - sgr)
        let block = UUID()
        var rows = [
            PosCartRow(
                id: block,
                name: offer.name,
                unitPrice: 0,
                vatRate: nil,
                quantity: 1,
                addons: [],
                showsAmount: false,
                showsVat: false,
                menuBlock: block,
                menuHeader: true
            )
        ]
        rows.append(menuRow(offer.main, price: mainPrice, block: block))
        for choice in offer.secondaries where choice.selected {
            rows.append(menuRow(choice, price: choice.salePrice, discount: choice.salePrice, showsDiscount: true, block: block))
        }
        updateActive { $0.lines.append(contentsOf: rows) }
    }

    private func menuRow(_ choice: MenuChoice, price: Decimal, discount: Decimal = 0, showsDiscount: Bool = false, block: UUID) -> PosCartRow {
        PosCartRow(
            id: UUID(),
            productId: choice.id,
            name: choice.name,
            unitPrice: price,
            vatRate: choice.vatRate,
            quantity: 1,
            addons: choice.addons.map { addon in
                PosCartAddon(
                    id: UUID(),
                    productId: addon.productId,
                    name: addon.name,
                    perUnit: addon.perUnit,
                    unitPrice: Self.isSgr(addon.name) ? addon.unitPrice : 0,
                    vatRate: addon.vatRate
                )
            },
            discountAmount: discount,
            showsDiscount: showsDiscount,
            menuBlock: block
        )
    }

    private static func stockCuts(_ ticket: PosTicket) -> [StockCut] {
        var totals: [UUID: Decimal] = [:]
        for line in ticket.lines where line.productId != nil {
            if let productId = line.productId {
                totals[productId, default: 0] += Decimal(line.quantity)
            }
            for addon in line.addons {
                if let productId = addon.productId {
                    totals[productId, default: 0] += addon.perUnit * Decimal(line.quantity)
                }
            }
        }
        return totals.compactMap { productId, quantity in
            quantity > 0 ? StockCut(productId: productId, quantity: quantity) : nil
        }
    }

    private static func consumeStock(_ items: [StockCut]) async -> String {
        do {
            try await PosShiftTakingsService.consumeStock(
                items: items.map { (productId: $0.productId, quantity: $0.quantity) }
            )
            return ""
        } catch {
            return " " + error.localizedDescription
        }
    }

    private func loadGroups() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            let all = try await CMProductGroupService.fetchGroups(companyId: companyId)
            groups = all
                .filter { $0.kind != .ungrouped }
                .sorted { Self.byName($0.name, $1.name) }
            if groups.isEmpty {
                errorMessage = L10n.tr("module.cashier.no_groups")
            }
        } catch {
            groups = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func open(_ group: CMProductGroup) async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        selectedGroup = group
        isLoading = true
        errorMessage = nil
        do {
            if group.kind == .menus {
                let menus = try await CMProductGroupService.fetchMenus(companyId: companyId)
                let active = menus.filter(\.isActive)
                let images = (try? await CMProductGroupService.fetchMainProductImages(menuIds: active.map(\.id))) ?? [:]
                tiles = active.map { menu in
                    CasierPosTile(
                        id: menu.id.uuidString,
                        productId: nil,
                        isMenu: true,
                        allowsMultipleSecondaries: menu.permiteSecundareMultiple,
                        name: menu.name,
                        code: menu.cod,
                        unitPrice: menu.pretVanzare,
                        vatRate: nil,
                        priceLabel: Self.ron(menu.pretVanzare),
                        imageUrl: images[menu.id]
                    )
                }.sorted { Self.byName($0.name, $1.name) }
            } else {
                let products = try await CMProductGroupService.fetchProducts(inGroupId: group.id, companyId: companyId)
                let active = products.filter(\.isActive)
                tiles = active.map { product in
                    CasierPosTile(
                        id: product.id.uuidString,
                        productId: product.id,
                        name: product.denumire,
                        code: product.cod ?? "",
                        unitPrice: product.pretVanzare,
                        vatRate: product.cotaTva,
                        priceLabel: Self.ron(product.pretVanzare),
                        imageUrl: product.imagineUrl
                    )
                }.sorted { Self.byName($0.name, $1.name) }
                if let loaded = try? await ProductSaleAddonService.fetchAddons(productIds: active.map(\.id)) {
                    for (id, rows) in loaded {
                        addonsByProduct[id] = rows
                    }
                }
            }
            if tiles.isEmpty {
                errorMessage = L10n.tr("module.cashier.no_products")
            }
        } catch {
            tiles = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private static func ron(_ value: Decimal) -> String {
        money(value) + " RON"
    }

    private static func money(_ value: Decimal) -> String {
        SupplierFormatting.amountString(value)
    }

    private static func parseMoney(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func cuiDigits(_ raw: String) -> String {
        var text = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        if text.hasPrefix("RO") {
            text.removeFirst(2)
        }
        return String(text.filter(\.isNumber))
    }

    private static func fiscalCui(digits: String, vatPayer: Bool) -> String {
        let number = cuiDigits(digits)
        guard !number.isEmpty else { return digits }
        return vatPayer ? "RO" + number : number
    }

    private static func normalizeCui(_ raw: String) -> String {
        let filtered = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        return String(filtered.prefix(12))
    }

    private static func normalizeTender(_ raw: String) -> String {
        var result = ""
        var separator = false
        for character in raw {
            if character.isNumber {
                result.append(character)
            } else if (character == "," || character == ".") && !separator {
                result.append(",")
                separator = true
            }
        }
        return String(result.prefix(12))
    }

    private static func normalizePercent(_ raw: String) -> String {
        var result = ""
        var separator = false
        var decimals = 0
        for character in raw {
            if character.isNumber {
                if separator {
                    guard decimals < 2 else { continue }
                    decimals += 1
                }
                result.append(character)
            } else if (character == "," || character == ".") && !separator && !result.isEmpty {
                result.append(",")
                separator = true
            }
            if result.count >= 6 { break }
        }
        if let value = parseMoney(result), value > 100 {
            return "100"
        }
        return result
    }

    private static func byName(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: .caseInsensitive, locale: Locale(identifier: "ro")) == .orderedAscending
    }
}

private enum PosChrome {
    static let navy = Color(red: 0.043, green: 0.122, blue: 0.227)
    static let gold = Color(red: 198 / 255, green: 161 / 255, blue: 90 / 255)
}

private enum PosVat {
    /// A = 21%, B = 11%, D = 0%. Cota de pe fișă se apropie de una din acestea.
    static func letter(_ rate: Decimal?) -> String {
        guard let rate else { return "" }
        if rate >= 19 { return "A" }
        if rate >= 9 { return "B" }
        return "D"
    }
}

private enum PosPay {
    case cash
    case card
    case modern
}

private enum PosModern: String {
    case glovo
    case bolt
    case wolt
}

private struct PosTicket: Identifiable {
    let id = UUID()
    var lines: [PosCartRow] = []
    var pay: PosPay = .cash
    var modern: PosModern?
    var tenderText = ""
    var cui = ""
    var clientName = ""
    var clientAddress = ""
    var cuiBlockStatus = ""
    var cuiBlockName = ""
    var printFiscalInvoice = false
    var discountText = ""
}

private struct CuiBlock: Identifiable {
    let id = UUID()
    let name: String
    let cui: String
    let status: String
    let ticketId: UUID
}

private struct CuiBlockSheet: View {
    let block: CuiBlock
    let onDrop: () -> Void
    let onFix: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Nu se poate emite BF / FF pentru clientul \(block.name) cu CUI \(block.cui), deoarece starea lui este: \(block.status)")
                .font(.body.weight(.bold))
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Fără CUI", action: onDrop)
                Button("Corectează", action: onFix)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 440)
    }
}

private struct VatBand {
    let letter: String
    let rate: Int
    let gross: Decimal
    let vat: Decimal
}

private struct SlipDraft {
    let seriesId: UUID
    let cui: String
    let clientName: String
    let clientAddress: String
    let payment: String
    let tender: String
    let total: String
    let takingChannel: String
    let takingAmount: Decimal
    let lines: [(name: String, amount: String)]
    let bands: [VatBand]
    let invoiceLines: [InvoiceLine]
    let stock: [StockCut]
}

private struct InvoiceLine {
    let name: String
    let quantity: String
    let unitNet: String
    let value: String
    let vat: String
    let netAmount: Decimal
    let vatAmount: Decimal
    var vatPercent: String = ""
}

private struct PosCartAddon: Identifiable, Hashable {
    let id: UUID
    let productId: UUID?
    let name: String
    let perUnit: Decimal
    let unitPrice: Decimal
    let vatRate: Decimal
}

private struct PosCartRow: Identifiable {
    let id: UUID
    var productId: UUID?
    var name: String
    var unitPrice: Decimal
    var vatRate: Decimal?
    var quantity: Int
    var addons: [PosCartAddon]
    var showsAmount = true
    var showsVat = true
    var discounted = false
    var discountAmount: Decimal = 0
    var showsDiscount = false
    var menuBlock: UUID?
    var menuHeader = false

    var lineTotal: Decimal { unitPrice * Decimal(quantity) - discountAmount }
}

private struct CasierPosTile: Identifiable {
    let id: String
    let productId: UUID?
    var isMenu = false
    var allowsMultipleSecondaries = false
    let name: String
    let code: String
    let unitPrice: Decimal
    let vatRate: Decimal?
    let priceLabel: String
    let imageUrl: String?
}

private struct CasierProductTile: View {
    let tile: CasierPosTile

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ProductThumbnailView(imagineUrl: tile.imageUrl, contentMode: .fit)
                    .frame(maxWidth: 112, maxHeight: 112)
                VStack {
                    HStack {
                        Spacer()
                        Text(tile.priceLabel)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(PosChrome.navy)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.systemBackground).opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    Spacer()
                }
                .padding(6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 128)

            HStack(alignment: .center, spacing: 0) {
                Text(tile.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(PosChrome.navy)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if !tile.code.isEmpty {
                Text(tile.code)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 228)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct StockCut: Hashable {
    let productId: UUID
    let quantity: Decimal
}

private struct MenuChoice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let vatRate: Decimal?
    let salePrice: Decimal
    var selected: Bool
    let addons: [PosCartAddon]
}

private struct MenuOffer: Identifiable, Hashable {
    let id: UUID
    let name: String
    let price: Decimal
    let main: MenuChoice
    var secondaries: [MenuChoice]
    var allowsMultiple: Bool
}

private struct MenuSaleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var offer: MenuOffer
    let onConfirm: (MenuOffer) -> Void

    init(offer: MenuOffer, onConfirm: @escaping (MenuOffer) -> Void) {
        _offer = State(initialValue: offer)
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Produs principal") {
                    Text(offer.main.name)
                }
                Section {
                    ForEach(offer.secondaries.indices, id: \.self) { index in
                        Toggle(offer.secondaries[index].name, isOn: Binding(
                            get: { offer.secondaries[index].selected },
                            set: { on in
                                if offer.allowsMultiple {
                                    offer.secondaries[index].selected = on
                                } else if on {
                                    for i in offer.secondaries.indices {
                                        offer.secondaries[i].selected = i == index
                                    }
                                } else {
                                    offer.secondaries[index].selected = false
                                }
                            }
                        ))
                    }
                } header: {
                    Text("Produse secundare")
                } footer: {
                    Text(offer.allowsMultiple
                         ? "Alegeți cel puțin un produs secundar."
                         : "Alegeți un singur produs secundar.")
                }
            }
            .navigationTitle(offer.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Renunță") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Adaugă pe bon") {
                        onConfirm(offer)
                        dismiss()
                    }
                    .disabled(offer.allowsMultiple
                              ? !offer.secondaries.contains(where: \.selected)
                              : offer.secondaries.filter(\.selected).count != 1)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 420)
    }
}
