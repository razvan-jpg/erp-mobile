import SwiftUI
import UniformTypeIdentifiers

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
    @State private var fiscalReady = FiscalNetStation.isReady
    @State private var pickFiscalFolder = false
    @State private var cardAcceptedKey: String?
    @State private var fiscalBusy = false
    @State private var closingShift = false
    @State private var shiftClosed = false

    init(location: CompanyWorkLocation, onExit: @escaping () -> Void) {
        self.location = location
        self.onExit = onExit
        let first = PosTicket()
        _tickets = State(initialValue: [first])
        _activeTicketId = State(initialValue: first.id)
    }

    private var sideBySide: Bool { sizeClass != .compact }

    var body: some View {
        Group {
            if sideBySide {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        header
                        catalog
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        footer
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background { nectarieCatalogBackground }
                    .clipped()
                    receipt
                }
            } else {
                VStack(spacing: 0) {
                    header
                    VStack(spacing: 12) {
                        catalog
                            .background { nectarieCatalogBackground }
                            .clipped()
                        receipt
                            .frame(maxHeight: 460)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    footer
                }
            }
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
        .alert(L10n.tr("module.cashier.shift_closed"), isPresented: $shiftClosed) {
            Button("OK", role: .cancel) {}
        }
        .overlay {
            if closingShift {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                    Text(L10n.tr("module.cashier.shift_wait"))
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)
            }
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
        .fileImporter(isPresented: $pickFiscalFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                if let error = FiscalNetStation.save(url) {
                    notice = error
                    fiscalReady = false
                } else {
                    fiscalReady = FiscalNetStation.isReady
                }
            }
        }
        .sheet(item: $menuOffer) { offer in
            MenuSaleSheet(offer: offer) { chosen in
                commitMenu(chosen)
            }
        }
    }

    private var showsNectarieLogo: Bool {
        guard let company = companyManager.currentCompany else { return false }
        if let cui = company.cui, let profile = FirmaRegistry.profile(forCUI: cui) {
            return profile.isNectarie
        }
        return Conturi.isNectarieFirma(company.denumire)
    }

    private var nectarieCatalogBackground: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGroupedBackground)
                if showsNectarieLogo {
                    Image("NectariePosLogo")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.5)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
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
                Task { await printReportX() }
            }
            reportButton(L10n.tr("module.cashier.report_z"), filled: true) {
                Task { await closeShift() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(showsNectarieLogo ? Color.white.opacity(0.55) : Color(.systemBackground))
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

            HStack(spacing: 8) {
                payButton("In Store", selected: !activeTicket.onlineSale) {
                    setPriceChannel(false)
                }
                payButton("On line", selected: activeTicket.onlineSale) {
                    setPriceChannel(true)
                }
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
                                    vat: row.vatRate,
                                    showVat: true,
                                    detailedVat: row.menuBlock != nil,
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
                payButton(L10n.tr("module.cashier.cash"), selected: activeTicket.pay == .cash, enabled: !activeTicket.onlineSale) {
                    guard !activeTicket.onlineSale else { return }
                    updateActive {
                        $0.pay = .cash
                        $0.modern = nil
                    }
                }
                payButton(L10n.tr("module.cashier.card"), selected: activeTicket.pay == .card, enabled: !activeTicket.onlineSale) {
                    guard !activeTicket.onlineSale else { return }
                    updateActive {
                        $0.pay = .card
                        $0.modern = nil
                    }
                }
                payButton(L10n.tr("module.cashier.modern"), selected: activeTicket.pay == .modern, enabled: activeTicket.onlineSale) {
                    guard activeTicket.onlineSale else { return }
                    updateActive { $0.pay = .modern }
                }
            }
            .padding(.top, 12)

            payButton(L10n.tr("module.cashier.pay_split"), selected: activeTicket.pay == .split, enabled: !activeTicket.onlineSale) {
                guard !activeTicket.onlineSale else { return }
                updateActive {
                    $0.pay = .split
                    $0.modern = nil
                }
            }
            .padding(.top, 8)

            if activeTicket.onlineSale && activeTicket.pay == .modern {
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

            if activeTicket.pay == .split {
                VStack(alignment: .leading, spacing: 8) {
                    splitAmountField(L10n.tr("module.cashier.cash"), text: splitCashField)
                    splitAmountField(L10n.tr("module.cashier.card"), text: splitCardField)
                    Text(splitHint.text)
                        .font(.caption2)
                        .foregroundColor(splitHint.warning ? .red : AppColors.secondary)
                }
                .padding(.top, 10)
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

            Button {
                pickFiscalFolder = true
            } label: {
                Text(fiscalReady ? L10n.tr("module.cashier.printer_ready") : L10n.tr("module.cashier.printer_pick"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: sideBySide ? 380 : nil, alignment: .top)
        .frame(maxWidth: sideBySide ? 380 : .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: sideBySide ? 0 : 16, style: .continuous))
        .overlay(alignment: .leading) {
            if sideBySide {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1)
            }
        }
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
        .background(showsNectarieLogo ? Color.white.opacity(0.55) : Color(.secondarySystemBackground))
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
                                .fill(Color.white.opacity(0.55))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var productGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(saleTiles) { tile in
                Button {
                    add(tile)
                } label: {
                    CasierProductTile(tile: tile, priceLabel: Self.ron(shownPrice(tile)))
                        .equatable()
                }
                .buttonStyle(.plain)
                .opacity(shownPrice(tile) <= 0 ? 0.4 : 1)
            }
        }
    }

    private var saleTiles: [CasierPosTile] {
        guard activeTicket.onlineSale else { return tiles }
        return tiles.filter { $0.onlinePrice > 0 }
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
                    if !next.isEmpty, $0.pay == .modern, !$0.onlineSale {
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
                .appControlHint(L10n.tr("common.new_ticket"))
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

    private func splitAmountField(_ title: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(PosChrome.navy)
                .frame(width: 88, alignment: .leading)
            TextField("0,00", text: text)
                .font(.title3.weight(.bold))
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
        }
    }

    private var splitCashField: Binding<String> {
        splitField(isCash: true)
    }

    private var splitCardField: Binding<String> {
        splitField(isCash: false)
    }

    private func splitField(isCash: Bool) -> Binding<String> {
        Binding(
            get: { Self.splitShown(activeTicket, isCash: isCash) },
            set: { value in
                let next = Self.normalizeTender(value)
                updateActive { ticket in
                    if next == Self.splitShown(ticket, isCash: isCash) { return }
                    ticket.splitAnchorCash = isCash
                    if isCash {
                        ticket.cashPartText = next
                    } else {
                        ticket.cardPartText = next
                    }
                }
            }
        )
    }

    private var splitHint: (text: String, warning: Bool) {
        if let problem = Self.splitProblem(activeTicket) {
            let empty = activeTicket.splitAnchorCash ? activeTicket.cashPartText.isEmpty : activeTicket.cardPartText.isEmpty
            return (problem, !empty)
        }
        return ("", false)
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
                .appControlHint(L10n.tr("module.cashier.remove_line"))
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
            ("G", takings.glovo),
            ("B", takings.bolt),
            ("W", takings.wolt)
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
        if let problem = Self.splitProblem(activeTicket) {
            notice = problem
            return
        }
        let companyId = companyManager.currentCompany?.id
        let locationId = location.id
        let ticket = activeTicket
        let amount = Self.ticketTotal(ticket)
        guard ticket.printFiscalInvoice, !ticket.cui.isEmpty else {
            if fiscalReady {
                guard !fiscalBusy else { return }
                fiscalBusy = true
                Task {
                    defer { fiscalBusy = false }
                    await printFiscalReceipt(ticket, channel: channel, amount: amount, companyId: companyId, locationId: locationId)
                }
                return
            }
            Task {
                do {
                    try await recordSale(ticket, channel: channel, amount: amount, locationId: locationId)
                    await loadTakings()
                    clearActiveTicket()
                    notice = L10n.tr("module.cashier.emit_recorded")
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
                    invoiceLines: Self.invoiceLines(ticket)
                )
                showSlipFolder = true
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    private func printFiscalReceipt(_ ticket: PosTicket, channel: String, amount: Decimal, companyId: UUID?, locationId: UUID) async {
        let outcome = await sendFiscalReceipt(ticket, channel: channel, amount: amount, companyId: companyId)
        guard let outcome else { return }
        guard outcome.reply.bonOk == 1, !outcome.reply.number.isEmpty else {
            var text = FiscalNet.failure(outcome.reply, fallback: L10n.tr("module.cashier.fiscal_refused"))
            if Self.chargesCard(channel), cardAcceptedKey == Self.cardKey(ticket) {
                text = L10n.tr("module.cashier.card_charged_retry") + "\n" + text
            }
            notice = text
            return
        }
        var recap = ""
        do {
            try await PosStockService.discharge(
                locationId: locationId,
                receiptNumber: outcome.reply.number,
                items: Self.stockItems(ticket)
            )
        } catch {
            recap = " " + error.localizedDescription
        }
        do {
            try await recordSale(ticket, channel: channel, amount: outcome.payment, locationId: locationId, cash: outcome.cashTaken, card: outcome.cardTaken)
            await loadTakings()
        } catch {
            recap += " " + error.localizedDescription
        }
        cardAcceptedKey = nil
        clearActiveTicket()
        var message = L10n.tr("module.cashier.fiscal_printed", outcome.reply.number) + recap
        if !outcome.reply.authorization.isEmpty {
            message += "\n" + L10n.tr("module.cashier.card_auth", outcome.reply.authorization)
        }
        notice = message
    }

    private func writeFiscalInvoice(to folder: URL, draft: SlipDraft) async {
        let accessed = folder.startAccessingSecurityScopedResource()
        defer { if accessed { folder.stopAccessingSecurityScopedResource() } }
        let ticket = activeTicket
        let outcome = await sendFiscalReceipt(ticket, channel: draft.takingChannel, amount: draft.takingAmount, companyId: companyManager.currentCompany?.id)
        guard let outcome else {
            slipDraft = nil
            return
        }
        guard outcome.reply.bonOk == 1, !outcome.reply.number.isEmpty else {
            var text = FiscalNet.failure(outcome.reply, fallback: L10n.tr("module.cashier.fiscal_refused"))
            if Self.chargesCard(draft.takingChannel), cardAcceptedKey == Self.cardKey(ticket) {
                text = L10n.tr("module.cashier.card_charged_retry") + "\n" + text
            }
            notice = text
            return
        }
        var invoiceNote = ""
        var invoiceName = ""
        let stamp = Self.slipStamp()
        let bonName = "Bon fiscal \(stamp.file).pdf"
        let note = L10n.tr("module.cashier.fiscal_printed", outcome.reply.number)
        do {
            let issued = try await DocumentSeriesService.consumeFiscalNumber(id: draft.seriesId)
            let company = companyManager.currentCompany
            let supplier = Self.supplierLines(company)
            var invoiceUrl = ""
            var invoicePath: String?
            if NetworkMonitor.shared.isOnline, let companyId = company?.id {
                let target = try PosDocumentStore.target(companyId: companyId)
                invoiceUrl = target.url
                invoicePath = target.path
                let draftPdf = PosSlipPdf.make(Self.invoiceRows(supplier: supplier, serie: issued.serie, number: issued.number, stamp: stamp, draft: draft, documentUrl: invoiceUrl, printedNote: "FP-700"))
                do {
                    try await PosDocumentStore.upload(path: target.path, data: draftPdf)
                } catch {
                    invoiceUrl = ""
                }
            }
            let paper = Self.invoicePaper(supplier: supplier, serie: issued.serie, number: issued.number, stamp: stamp.shown, draft: draft)
            let invoiceReply = await FiscalNetStation.send(
                fileName: FiscalNet.fileName(prefix: "ff", nonFiscal: true),
                commands: FiscalNet.nonFiscal(paper, documentUrl: invoiceUrl),
                timeout: 60
            )
            if invoiceReply.bonOk != 1 {
                invoiceNote = " " + FiscalNet.failure(invoiceReply, fallback: L10n.tr("module.cashier.invoice_print_failed"))
            }
            invoiceName = "Factura \(issued.serie) \(issued.number).pdf"
            let bon = PosSlipPdf.make(Self.receiptRows(supplier: supplier, location: location.denumire, stamp: stamp, draft: draft, documentUrl: outcome.documentUrl, printedNote: note))
            let invoiceNoteText = invoiceReply.bonOk == 1 ? "FP-700" : ""
            let invoice = PosSlipPdf.make(Self.invoiceRows(supplier: supplier, serie: issued.serie, number: issued.number, stamp: stamp, draft: draft, documentUrl: invoiceUrl, printedNote: invoiceNoteText))
            try bon.write(to: folder.appendingPathComponent(bonName), options: .atomic)
            try invoice.write(to: folder.appendingPathComponent(invoiceName), options: .atomic)
            if let invoicePath, !invoiceUrl.isEmpty, invoiceReply.bonOk == 1 {
                try? await PosDocumentStore.upload(path: invoicePath, data: invoice)
            }
        } catch {
            invoiceNote = " " + error.localizedDescription
        }
        var recap = ""
        do {
            try await PosStockService.discharge(
                locationId: location.id,
                receiptNumber: outcome.reply.number,
                items: Self.stockItems(ticket)
            )
        } catch {
            recap = " " + error.localizedDescription
        }
        do {
            try await recordSale(ticket, channel: draft.takingChannel, amount: outcome.payment, locationId: location.id, cash: outcome.cashTaken, card: outcome.cardTaken)
            await loadTakings()
        } catch {
            recap += " " + error.localizedDescription
        }
        cardAcceptedKey = nil
        clearActiveTicket()
        slipDraft = nil
        var message = note
        if !invoiceName.isEmpty {
            message += " " + L10n.tr("module.cashier.pdf_saved", bonName, invoiceName)
        }
        if !outcome.reply.authorization.isEmpty {
            message += " " + L10n.tr("module.cashier.card_auth", outcome.reply.authorization)
        }
        notice = message + invoiceNote + recap
    }

    private func sendFiscalReceipt(_ ticket: PosTicket, channel: String, amount: Decimal, companyId: UUID?) async -> (reply: FiscalNetStation.Reply, payment: Decimal, documentUrl: String, cashTaken: Decimal, cardTaken: Decimal)? {
        let tender = channel == "cash" ? (Self.parseMoney(ticket.tenderText) ?? 0) : 0
        let entry = channel == "split" ? Self.splitEntry(ticket) : nil
        let preview = FiscalNet.buildReceipt(
            fiscalCode: ticket.cui,
            lines: Self.fiscalLines(ticket),
            targetTotal: amount,
            paymentType: FiscalNet.payType(channel),
            tender: tender,
            documentUrl: "",
            splitEntered: entry?.amount,
            splitEnteredIsCash: entry?.isCash ?? true
        )
        let key = Self.cardKey(ticket)
        if Self.chargesCard(channel), preview.cardTaken > 0, cardAcceptedKey != key {
            let pos = await FiscalNetStation.send(fileName: FiscalNet.fileName(prefix: "pos", nonFiscal: false), commands: FiscalNet.pos(preview.cardTaken), timeout: 180)
            if pos.bonOk == 0 {
                notice = FiscalNet.failure(pos, fallback: L10n.tr("module.cashier.card_refused"))
                return nil
            }
            if pos.bonOk != 1 {
                let accepted = await FiscalPrompt.choose(
                    message: L10n.tr("module.cashier.card_unknown"),
                    accept: L10n.tr("module.cashier.card_accept"),
                    decline: L10n.tr("module.cashier.card_decline")
                )
                if !accepted { return nil }
            }
            cardAcceptedKey = key
        }
        var documentUrl = ""
        var documentPath: String?
        if NetworkMonitor.shared.isOnline, let companyId {
            if let target = try? PosDocumentStore.target(companyId: companyId) {
                documentUrl = target.url
                documentPath = target.path
            }
        }
        if let documentPath, !documentUrl.isEmpty {
            let company = companyManager.currentCompany
            let supplier = Self.supplierLines(company)
            let stamp = Self.slipStamp()
            let draft = Self.slipDraft(from: ticket, channel: channel, amount: preview.payment, seriesId: UUID())
            let pdf = PosSlipPdf.make(Self.receiptRows(supplier: supplier, location: location.denumire, stamp: stamp, draft: draft, documentUrl: documentUrl, printedNote: "FP-700"))
            do {
                try await PosDocumentStore.upload(path: documentPath, data: pdf)
            } catch {
                documentUrl = ""
            }
        }
        let built = FiscalNet.buildReceipt(
            fiscalCode: ticket.cui,
            lines: Self.fiscalLines(ticket),
            targetTotal: amount,
            paymentType: FiscalNet.payType(channel),
            tender: tender,
            documentUrl: documentUrl,
            splitEntered: entry?.amount,
            splitEnteredIsCash: entry?.isCash ?? true
        )
        let reply = await FiscalNetStation.send(fileName: FiscalNet.fileName(prefix: "bf", nonFiscal: false), commands: built.commands, timeout: 60)
        if reply.bonOk == 1, !reply.number.isEmpty, channel == "cash" || channel == "split" {
            _ = await FiscalNetStation.send(
                fileName: FiscalNet.fileName(prefix: "ds", nonFiscal: false),
                commands: FiscalNet.openDrawer(),
                timeout: 20
            )
        }
        if reply.bonOk == 1, !reply.number.isEmpty, let documentPath, !documentUrl.isEmpty {
            let company = companyManager.currentCompany
            let supplier = Self.supplierLines(company)
            let stamp = Self.slipStamp()
            let draft = Self.slipDraft(from: ticket, channel: channel, amount: built.payment, seriesId: UUID())
            let pdf = PosSlipPdf.make(Self.receiptRows(supplier: supplier, location: location.denumire, stamp: stamp, draft: draft, documentUrl: documentUrl, printedNote: L10n.tr("module.cashier.fiscal_printed", reply.number)))
            try? await PosDocumentStore.upload(path: documentPath, data: pdf)
        }
        return (reply, built.payment, documentUrl, built.cashTaken, built.cardTaken)
    }

    private static func stockItems(_ ticket: PosTicket) -> [PosStockService.Item] {
        var quantities: [UUID: Decimal] = [:]
        func add(_ id: UUID?, _ amount: Decimal) {
            guard let id, amount > 0 else { return }
            quantities[id, default: 0] += amount
        }
        for line in ticket.lines {
            if line.menuHeader { continue }
            add(line.productId ?? line.id, Decimal(line.quantity))
            for addon in line.addons {
                add(addon.productId, addon.perUnit * Decimal(line.quantity))
            }
        }
        let canal = ticket.onlineSale ? "online" : "in_store"
        return quantities.map { productId, quantity in
            PosStockService.Item(
                productId: productId,
                cantitate: NSDecimalNumber(decimal: quantity).doubleValue,
                canal: canal
            )
        }
    }

    private func recordSale(_ ticket: PosTicket, channel: String, amount: Decimal, locationId: UUID, cash: Decimal? = nil, card: Decimal? = nil) async throws {
        if ticket.pay == .split {
            let cashAmount: Decimal
            let cardAmount: Decimal
            if let cash, let card {
                cashAmount = cash
                cardAmount = card
            } else if let entry = Self.splitEntry(ticket) {
                let parts = FiscalNet.split(payment: amount, entered: entry.amount, enteredIsCash: entry.isCash)
                cashAmount = parts.cash
                cardAmount = parts.card
            } else {
                return
            }
            try await PosShiftTakingsService.record(locationId: locationId, channel: "cash", amount: cashAmount)
            try await PosShiftTakingsService.record(locationId: locationId, channel: "card", amount: cardAmount)
            return
        }
        try await PosShiftTakingsService.record(locationId: locationId, channel: channel, amount: amount)
    }

    private static func slipDraft(from ticket: PosTicket, channel: String, amount: Decimal, seriesId: UUID) -> SlipDraft {
        SlipDraft(
            seriesId: seriesId,
            cui: ticket.cui,
            clientName: ticket.clientName,
            clientAddress: ticket.clientAddress,
            payment: paymentLabel(ticket, payable: amount),
            tender: ticket.pay == .cash ? ticket.tenderText : "",
            total: money(amount),
            takingChannel: channel,
            takingAmount: amount,
            lines: slipLines(ticket),
            bands: vatBands(ticket),
            invoiceLines: invoiceLines(ticket)
        )
    }

    private static func fiscalLines(_ ticket: PosTicket) -> [FiscalNet.SaleLine] {
        var lines: [FiscalNet.SaleLine] = []
        var menu: String?
        for line in ticket.lines {
            if line.menuHeader {
                menu = line.name
                continue
            }
            let full = line.discountAmount > 0 || line.showsDiscount
            lines.append(FiscalNet.SaleLine(
                name: line.name,
                unitPrice: line.unitPrice,
                quantity: Decimal(line.quantity),
                vatGroup: FiscalNet.vatGroup(line.vatRate),
                fullDiscount: full,
                discountable: !full,
                note: menu
            ))
            menu = nil
            for addon in line.addons where !isSgr(addon.name) {
                lines.append(FiscalNet.SaleLine(
                    name: addon.name,
                    unitPrice: addon.unitPrice,
                    quantity: addon.perUnit * Decimal(line.quantity),
                    vatGroup: FiscalNet.vatGroup(addon.vatRate),
                    fullDiscount: false,
                    discountable: true,
                    note: nil
                ))
            }
        }
        for sgr in sgrLines(ticket.lines) where sgr.quantity > 0 && sgr.amount > 0 {
            lines.append(FiscalNet.SaleLine(
                name: sgr.name,
                unitPrice: sgr.amount / sgr.quantity,
                quantity: sgr.quantity,
                vatGroup: FiscalNet.vatGroup(sgr.vatRate),
                fullDiscount: false,
                discountable: false,
                note: nil
            ))
        }
        return lines
    }

    private static func cardKey(_ ticket: PosTicket) -> String {
        var text = ""
        for line in ticket.lines {
            text += "\(line.name)|\(line.quantity)|\(line.unitPrice)|\(line.discountAmount);"
            for addon in line.addons {
                text += "\(addon.name)|\(addon.perUnit)|\(addon.unitPrice);"
            }
        }
        text += ticket.discountText
        if ticket.pay == .split {
            text += "|split|\(ticket.splitAnchorCash ? "cash" : "card")|\(ticket.cashPartText)|\(ticket.cardPartText)"
        }
        return text
    }

    private static func invoicePaper(supplier: [String], serie: String, number: Int, stamp: String, draft: SlipDraft) -> [String] {
        var text = ["FACTURA FISCALA", "\(serie) \(number)", stamp]
        text.append(contentsOf: supplier)
        if !draft.clientName.isEmpty { text.append(draft.clientName) }
        if !draft.cui.isEmpty { text.append("CUI \(draft.cui)") }
        if !draft.clientAddress.isEmpty { text.append(draft.clientAddress) }
        for line in draft.invoiceLines {
            text.append(line.name)
            if !line.quantity.isEmpty {
                text.append("\(line.quantity)  \(line.value)  TVA \(line.vat)  \(line.vatPercent)")
            }
        }
        let net = draft.invoiceLines.reduce(Decimal.zero) { $0 + $1.netAmount }
        let vat = draft.invoiceLines.reduce(Decimal.zero) { $0 + $1.vatAmount }
        text.append("Baza \(ron(net))")
        text.append("TVA \(ron(vat))")
        text.append("TOTAL \(draft.total)")
        text.append("Incasare \(draft.payment)")
        return text
    }

    private func writeSlipPdfs(to folder: URL) async {
        guard let draft = slipDraft else { return }
        if fiscalReady {
            await writeFiscalInvoice(to: folder, draft: draft)
            return
        }
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
                try await recordSale(activeTicket, channel: draft.takingChannel, amount: draft.takingAmount, locationId: location.id)
                await loadTakings()
            } catch {
                recap = " " + error.localizedDescription
            }
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
            if $0.onlineSale {
                $0.pay = .modern
                $0.modern = nil
            } else {
                $0.pay = .cash
                $0.modern = nil
            }
            $0.cashPartText = ""
            $0.cardPartText = ""
            $0.splitAnchorCash = true
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

    private func printReportX() async {
        guard fiscalReady else {
            notice = L10n.tr("module.cashier.report_x_pending")
            return
        }
        guard !fiscalBusy else { return }
        fiscalBusy = true
        defer { fiscalBusy = false }
        let reply = await FiscalNetStation.send(fileName: FiscalNet.fileName(prefix: "x", nonFiscal: false), commands: FiscalNet.report("X"), timeout: 90)
        notice = reply.bonOk == 1
            ? L10n.tr("module.cashier.report_x_done")
            : FiscalNet.failure(reply, fallback: L10n.tr("module.cashier.report_x_failed"))
    }

    private func closeShift() async {
        guard !closingShift, !fiscalBusy else { return }
        guard fiscalReady else {
            notice = L10n.tr("module.cashier.report_x_pending")
            return
        }
        closingShift = true
        fiscalBusy = true
        defer {
            fiscalBusy = false
            closingShift = false
        }
        let reportX = await FiscalNetStation.send(
            fileName: FiscalNet.fileName(prefix: "x", nonFiscal: false),
            commands: FiscalNet.report("X"),
            timeout: 90
        )
        guard reportX.bonOk == 1 else {
            notice = FiscalNet.failure(reportX, fallback: L10n.tr("module.cashier.report_x_failed"))
            return
        }
        let reportZ = await FiscalNetStation.send(
            fileName: FiscalNet.fileName(prefix: "z", nonFiscal: false),
            commands: FiscalNet.report("Z"),
            timeout: 90
        )
        guard reportZ.bonOk == 1 else {
            notice = FiscalNet.failure(reportZ, fallback: L10n.tr("module.cashier.report_z_failed"))
            return
        }
        do {
            try await PosStockService.closeShiftProduction(locationId: location.id)
            try await PosStockService.createStockSheet(locationId: location.id, zNumber: reportZ.number)
            try await PosShiftTakingsService.closeZ(locationId: location.id)
            await loadTakings()
            shiftClosed = true
        } catch {
            notice = error.localizedDescription
        }
    }

    private static func chargesCard(_ channel: String) -> Bool {
        channel == "card" || channel == "split"
    }

    private static func splitShown(_ ticket: PosTicket, isCash: Bool) -> String {
        if ticket.splitAnchorCash == isCash {
            return isCash ? ticket.cashPartText : ticket.cardPartText
        }
        let source = ticket.splitAnchorCash ? ticket.cashPartText : ticket.cardPartText
        return remainderText(entered: source, total: ticketTotal(ticket))
    }

    private static func remainderText(entered: String, total: Decimal) -> String {
        guard let value = parseMoney(entered), value > 0, value < total else { return "" }
        return money(total - value)
    }

    private static func splitEntry(_ ticket: PosTicket) -> (amount: Decimal, isCash: Bool)? {
        guard ticket.pay == .split else { return nil }
        let text = ticket.splitAnchorCash ? ticket.cashPartText : ticket.cardPartText
        guard let amount = parseMoney(text), amount > 0, amount < ticketTotal(ticket) else { return nil }
        return (amount, ticket.splitAnchorCash)
    }

    private static func splitProblem(_ ticket: PosTicket) -> String? {
        guard ticket.pay == .split else { return nil }
        if splitEntry(ticket) != nil { return nil }
        let text = ticket.splitAnchorCash ? ticket.cashPartText : ticket.cardPartText
        if let amount = parseMoney(text), ticketTotal(ticket) > 0, amount >= ticketTotal(ticket) {
            return L10n.tr("module.cashier.split_over")
        }
        return L10n.tr("module.cashier.split_hint")
    }

    private static func takingChannel(_ ticket: PosTicket) -> String? {
        if ticket.onlineSale {
            return ticket.modern?.rawValue
        }
        switch ticket.pay {
        case .cash: return "cash"
        case .card: return "card"
        case .split: return "split"
        case .modern: return nil
        }
    }

    private static func paymentLabel(_ ticket: PosTicket, payable: Decimal? = nil) -> String {
        let due = payable ?? ticketTotal(ticket)
        switch ticket.pay {
        case .cash: return L10n.tr("module.cashier.cash")
        case .card: return L10n.tr("module.cashier.card")
        case .split:
            guard let entry = splitEntry(ticket) else { return L10n.tr("module.cashier.pay_split") }
            let parts = FiscalNet.split(payment: due, entered: entry.amount, enteredIsCash: entry.isCash)
            return "Numerar \(money(parts.cash)) + Card \(money(parts.card))"
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
                rows.append(("Discount 100%", Self.markedAmount(money(-line.discountAmount), vat: line.vatRate, marked: onMenu)))
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

    private static func receiptRows(supplier: [String], location: String, stamp: (shown: String, file: String), draft: SlipDraft, documentUrl: String, printedNote: String = "") -> [PosSlipPdf.Row] {
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
        rows.append(.center(printedNote.isEmpty ? "PDF — imprimanta fiscală nu este conectată" : printedNote, size: 6))
        rows.append(.line(" "))
        rows.append(.center("Document generat cu ERP Mobile by DateConta", size: 6))
        return rows
    }

    private static func invoiceRows(supplier: [String], serie: String, number: Int, stamp: (shown: String, file: String), draft: SlipDraft, documentUrl: String, printedNote: String = "") -> [PosSlipPdf.Row] {
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
        rows.append(.center(printedNote.isEmpty ? "80 mm · PDF — imprimanta fiscală nu este conectată" : printedNote, size: 6))
        rows.append(.line(" "))
        rows.append(.center("Document generat cu ERP Mobile by DateConta", size: 6))
        return rows
    }

    private func updateActive(_ change: (inout PosTicket) -> Void) {
        guard let index = tickets.firstIndex(where: { $0.id == activeTicketId }) else { return }
        change(&tickets[index])
    }

    private func setPriceChannel(_ online: Bool) {
        var removed = false
        updateActive { ticket in
            ticket.onlineSale = online
            if online {
                ticket.pay = .modern
            } else if ticket.pay == .modern {
                ticket.pay = .cash
                ticket.modern = nil
            }
            removed = Self.applyPriceChannel(&ticket)
        }
        if removed {
            notice = L10n.tr("module.cashier.zero_sale_price")
        }
    }

    private func shownPrice(_ tile: CasierPosTile) -> Decimal {
        activeTicket.onlineSale ? tile.onlinePrice : tile.storePrice
    }

    private static func channelPrice(store: Decimal, online: Decimal, onlineSale: Bool) -> Decimal {
        onlineSale ? online : store
    }

    @discardableResult
    private static func applyPriceChannel(_ ticket: inout PosTicket) -> Bool {
        let online = ticket.onlineSale
        for index in ticket.lines.indices {
            for addonIndex in ticket.lines[index].addons.indices {
                let addon = ticket.lines[index].addons[addonIndex]
                ticket.lines[index].addons[addonIndex].unitPrice = addon.charges
                    ? channelPrice(store: addon.storePrice, online: addon.onlinePrice, onlineSale: online)
                    : 0
            }
        }
        for index in ticket.lines.indices {
            var line = ticket.lines[index]
            if line.menuHeader {
                continue
            }
            if line.isMenuSecondary {
                let price = channelPrice(store: line.storePrice, online: line.onlinePrice, onlineSale: online)
                line.unitPrice = price
                line.discountAmount = price
            } else if line.isMenuMain {
                let block = line.menuBlock
                let sgr = ticket.lines.reduce(Decimal.zero) { partial, row in
                    guard row.menuBlock == block else { return partial }
                    return row.addons.reduce(partial) { sum, addon in
                        addon.charges ? sum + addon.perUnit * addon.unitPrice : sum
                    }
                }
                let menuPrice = Self.channelPrice(store: line.menuStorePrice, online: line.menuOnlinePrice, onlineSale: online)
                line.menuPrice = menuPrice
                line.unitPrice = max(Decimal.zero, menuPrice - sgr)
            } else {
                line.unitPrice = channelPrice(store: line.storePrice, online: line.onlinePrice, onlineSale: online)
            }
            ticket.lines[index] = line
        }
        let before = ticket.lines.count
        let doomedMenus = Set(ticket.lines.compactMap { line -> UUID? in
            guard line.isMenuMain, line.menuPrice <= 0, let block = line.menuBlock else { return nil }
            return block
        })
        ticket.lines.removeAll { line in
            if let block = line.menuBlock, doomedMenus.contains(block) {
                return true
            }
            if line.menuHeader || line.isMenuMain || line.isMenuSecondary {
                return false
            }
            return line.unitPrice <= 0
        }
        return ticket.lines.count != before
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
        if shownPrice(tile) <= 0 {
            notice = L10n.tr("module.cashier.zero_sale_price")
            return
        }
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
                unitPrice: shownPrice(tile),
                vatRate: tile.vatRate,
                quantity: 1,
                addons: extras(for: tile.productId),
                storePrice: tile.storePrice,
                onlinePrice: tile.onlinePrice
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
                storePrice: ref.pretVanzare,
                onlinePrice: ref.pretVanzareOnline,
                unitPrice: Self.channelPrice(
                    store: ref.pretVanzare,
                    online: ref.pretVanzareOnline,
                    onlineSale: activeTicket.onlineSale
                ),
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
                    storePrice: product.pretVanzare,
                    onlinePrice: product.pretVanzareOnline,
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
                storePrice: tile.storePrice,
                onlinePrice: tile.onlinePrice,
                main: main,
                secondaries: secondaries,
                allowsMultiple: tile.allowsMultipleSecondaries
            )
        } catch {
            notice = error.localizedDescription
        }
    }

    private func commitMenu(_ offer: MenuOffer) {
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
        rows.append(menuRow(
            offer.main,
            block: block,
            menuMain: true,
            menuStorePrice: offer.storePrice,
            menuOnlinePrice: offer.onlinePrice
        ))
        for choice in offer.secondaries where choice.selected {
            rows.append(menuRow(choice, showsDiscount: true, block: block))
        }
        updateActive { ticket in
            ticket.lines.append(contentsOf: rows)
            Self.applyPriceChannel(&ticket)
        }
    }

    private func menuRow(
        _ choice: MenuChoice,
        showsDiscount: Bool = false,
        block: UUID,
        menuMain: Bool = false,
        menuStorePrice: Decimal = 0,
        menuOnlinePrice: Decimal = 0
    ) -> PosCartRow {
        PosCartRow(
            id: UUID(),
            productId: choice.id,
            name: choice.name,
            unitPrice: 0,
            vatRate: choice.vatRate,
            quantity: 1,
            addons: choice.addons.map { addon in
                PosCartAddon(
                    id: UUID(),
                    productId: addon.productId,
                    name: addon.name,
                    perUnit: addon.perUnit,
                    storePrice: addon.storePrice,
                    onlinePrice: addon.onlinePrice,
                    unitPrice: 0,
                    vatRate: addon.vatRate,
                    charges: Self.isSgr(addon.name)
                )
            },
            showsDiscount: showsDiscount,
            menuBlock: block,
            storePrice: choice.storePrice,
            onlinePrice: choice.onlinePrice,
            menuPrice: menuStorePrice,
            menuStorePrice: menuStorePrice,
            menuOnlinePrice: menuOnlinePrice,
            isMenuMain: menuMain,
            isMenuSecondary: showsDiscount
        )
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
                        storePrice: menu.pretVanzare,
                        onlinePrice: menu.pretVanzareOnline,
                        vatRate: nil,
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
                        storePrice: product.pretVanzare,
                        onlinePrice: product.pretVanzareOnline,
                        vatRate: product.cotaTva,
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
    case split
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
    var onlineSale = false
    var cashPartText = ""
    var cardPartText = ""
    var splitAnchorCash = true
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
    var storePrice: Decimal = 0
    var onlinePrice: Decimal = 0
    var unitPrice: Decimal
    let vatRate: Decimal
    var charges = true
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
    var storePrice: Decimal = 0
    var onlinePrice: Decimal = 0
    var menuPrice: Decimal = 0
    var menuStorePrice: Decimal = 0
    var menuOnlinePrice: Decimal = 0
    var isMenuMain = false
    var isMenuSecondary = false

    var lineTotal: Decimal { unitPrice * Decimal(quantity) - discountAmount }
}

private struct CasierPosTile: Identifiable, Equatable {
    let id: String
    let productId: UUID?
    var isMenu = false
    var allowsMultipleSecondaries = false
    let name: String
    let code: String
    let storePrice: Decimal
    let onlinePrice: Decimal
    let vatRate: Decimal?
    let imageUrl: String?
}

private struct CasierProductTile: View, Equatable {
    let tile: CasierPosTile
    let priceLabel: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tile == rhs.tile && lhs.priceLabel == rhs.priceLabel
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ProductThumbnailView(imagineUrl: tile.imageUrl, contentMode: .fit, plate: Color.white.opacity(0.35))
                    .frame(maxWidth: 112, maxHeight: 112)
                VStack {
                    HStack {
                        Spacer()
                        Text(priceLabel)
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
                .fill(Color.white.opacity(0.55))
        )
    }
}

private struct MenuChoice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let vatRate: Decimal?
    let storePrice: Decimal
    let onlinePrice: Decimal
    var selected: Bool
    let addons: [PosCartAddon]
}

private struct MenuOffer: Identifiable, Hashable {
    let id: UUID
    let name: String
    let storePrice: Decimal
    let onlinePrice: Decimal
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
