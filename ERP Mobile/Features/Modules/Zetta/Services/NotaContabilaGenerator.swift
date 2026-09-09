import Foundation

enum NotaContabilaGenerator {
    /// Generează rândurile de notă contabilă pentru un Raport Z.
    /// Cu `config` (setări Zetta) → schema personalizată din NC_din_Z_exemple.xlsx.
    /// Fără config → scheme legacy (Nectarie / bacșiș / generic).
    static func generate(from z: ZReportData, nrInreg: Int, config: ZettaNCConfig? = nil) -> [NotaContabilaRow] {
        if let config {
            return generateFromSettings(from: z, nrInreg: nrInreg, config: config)
        }
        if z.isNectarieFirma {
            return generateNectarie(from: z, nrInreg: nrInreg)
        }
        if z.usesBacsisSchema {
            return generateBacsis(from: z, nrInreg: nrInreg)
        }
        return generateGeneric(from: z, nrInreg: nrInreg)
    }

    static func generate(
        from reports: [ZReportData],
        config: ZettaNCConfig? = nil,
        startingNrInreg: Int = 1
    ) -> [NotaContabilaRow] {
        let start = max(1, startingNrInreg)
        return reports.sortedForExport().enumerated().flatMap { index, report in
            generate(from: report, nrInreg: start + index, config: config)
        }
    }

    // MARK: - Setări Zetta (model NC_din_Z_exemple.xlsx)

    private static func generateFromSettings(
        from z: ZReportData,
        nrInreg: Int,
        config: ZettaNCConfig
    ) -> [NotaContabilaRow] {
        let ctx = RowContext(from: z, nrInreg: nrInreg)
        var rows: [NotaContabilaRow] = []

        for slot in ZettaVatSlot.allCases {
            let slotSettings = config.settings.vatSettings(for: slot)
            guard slotSettings.isEnabled else { continue }
            let amounts = slotAmounts(for: slot, z: z)

            if slotSettings.rate != .zero {
                if amounts.tva > 0 {
                    rows.append(ctx.row(
                        jurnal: "JV",
                        debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                        credit: Conturi.tvaColectata, creditTitlu: Conturi.tvaColectataTitlu,
                        valoare: amounts.tva, withPartner: true,
                        optiuneTva: "Taxabile",
                        cotaTva: Decimal(slotSettings.rate.rawValue),
                        codTvaSaft: Conturi.saftCode(for: slotSettings.rate)
                    ))
                }
                if amounts.net > 0 {
                    let revenue = slotSettings.revenueAccountForTaxedSales()
                    rows.append(ctx.row(
                        jurnal: "JV",
                        debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                        credit: revenue.account, creditTitlu: revenue.title,
                        valoare: amounts.net, withPartner: true,
                        optiuneTva: "Taxabile",
                        cotaTva: Decimal(slotSettings.rate.rawValue),
                        codTvaSaft: Conturi.saftCode(for: slotSettings.rate)
                    ))
                }
            } else if amounts.gross > 0 {
                rows.append(contentsOf: zeroRateRows(
                    ctx: ctx,
                    slotSettings: slotSettings,
                    valoare: amounts.gross
                ))
            }
        }

        appendCashRowsFromSettings(to: &rows, ctx: ctx, z: z, config: config)
        appendCardAndModernaFromSettings(to: &rows, ctx: ctx, z: z, settings: config.settings)

        return rows.filter { $0.valoare != 0 }
    }

    private static func slotAmounts(for slot: ZettaVatSlot, z: ZReportData) -> (tva: Decimal, net: Decimal, gross: Decimal) {
        switch slot {
        case .a: return (z.tva21, z.net21, z.vanzari21)
        case .b: return (z.tva11, z.net11, z.vanzari11)
        case .c: return (z.tva11C, z.tva11C, z.vanzari11C)
        case .d: return (0, z.vanzari0, z.vanzari0)
        }
    }

    /// Linia 6 din model — TVA 0%: SGR (267), Bacșiș (462 + 462/446.2) sau alt cont din setări.
    private static func zeroRateRows(
        ctx: RowContext,
        slotSettings: ZettaVatCategorySettings,
        valoare: Decimal
    ) -> [NotaContabilaRow] {
        guard valoare > 0 else { return [] }

        if slotSettings.hasBacsisEnabled {
            let bacsisAccount = slotSettings.resolvedAccount(for: .bacsis)
            return [
                ctx.row(
                    jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: bacsisAccount, creditTitlu: Conturi.title(for: bacsisAccount),
                    valoare: valoare, withPartner: true,
                    optiuneTva: "Neimpozabile", cotaTva: 0, codTvaSaft: Conturi.saft0
                ),
                ctx.row(
                    jurnal: "OD",
                    debit: bacsisAccount, debitTitlu: Conturi.title(for: bacsisAccount),
                    credit: Conturi.bacsis, creditTitlu: Conturi.bacsisTitlu,
                    valoare: valoare
                ),
            ]
        }

        let creditAccount: String
        let creditTitle: String
        if slotSettings.hasSGREnabled {
            creditAccount = slotSettings.resolvedAccount(for: .sgr)
            creditTitle = Conturi.title(for: creditAccount)
        } else if let mapping = slotSettings.salesMappings.first(where: \.isEnabled) {
            creditAccount = slotSettings.resolvedAccount(for: mapping.category)
            creditTitle = Conturi.title(for: creditAccount)
        } else {
            creditAccount = Conturi.garantie
            creditTitle = Conturi.garantieTitlu
        }

        return [
            ctx.row(
                jurnal: "JV",
                debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                credit: creditAccount, creditTitlu: creditTitle,
                valoare: valoare, withPartner: true,
                optiuneTva: "Neimpozabile", cotaTva: 0, codTvaSaft: Conturi.saft0
            ),
        ]
    }

    /// Liniile 7–9 (mai multe puncte) sau 7 (un singur punct) din model.
    private static func appendCashRowsFromSettings(
        to rows: inout [NotaContabilaRow],
        ctx: RowContext,
        z: ZReportData,
        config: ZettaNCConfig
    ) {
        let cash = z.numerar
        guard cash > 0 else { return }

        let casa = resolveCasaAccount(for: z, config: config)
        let sediu = config.settings.headquartersCasaAccount
        let sediuTitlu = Conturi.title(for: sediu)

        if config.hasMultipleWorkLocations {
            rows.append(ctx.row(
                jurnal: "RC",
                debit: casa.account, debitTitlu: casa.title,
                credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
                valoare: cash, withPartner: true
            ))
            rows.append(ctx.row(
                jurnal: "RC",
                debit: Conturi.viramente, debitTitlu: Conturi.viramenteTitlu,
                credit: casa.account, creditTitlu: casa.title,
                valoare: cash
            ))
            rows.append(ctx.row(
                jurnal: "RC",
                debit: sediu, debitTitlu: sediuTitlu,
                credit: Conturi.viramente, creditTitlu: Conturi.viramenteTitlu,
                valoare: cash
            ))
        } else {
            rows.append(ctx.row(
                jurnal: "RC",
                debit: casa.account, debitTitlu: casa.title,
                credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
                valoare: cash, withPartner: true
            ))
        }
    }

    /// Ultimele 2 linii din model — card (5125) și plată modernă (5113) din setări.
    private static func appendCardAndModernaFromSettings(
        to rows: inout [NotaContabilaRow],
        ctx: RowContext,
        z: ZReportData,
        settings: ZettaSettingsPayload
    ) {
        let cardAccount = settings.cardPaymentAccount
        let cardTitle = Conturi.title(for: cardAccount)
        let modernAccount = settings.modernPaymentAccount
        let modernTitle = Conturi.title(for: modernAccount)

        let modernValue = z.plataModerna + (z.usesBacsisSchema && z.altePlati > 0 ? z.altePlati : 0)

        if z.card > 0 {
            rows.append(ctx.row(
                jurnal: "RC",
                debit: cardAccount, debitTitlu: cardTitle,
                credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
                valoare: z.card, withPartner: true
            ))
        }
        if modernValue > 0 {
            rows.append(ctx.row(
                jurnal: "RC",
                debit: modernAccount, debitTitlu: modernTitle,
                credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
                valoare: modernValue, withPartner: true
            ))
        }
    }

    private static func resolveCasaAccount(for z: ZReportData, config: ZettaNCConfig) -> (account: String, title: String) {
        if let matched = matchWorkLocation(for: z, in: config.workLocations) {
            let account = config.settings.account(for: matched.id)
            return (account, Conturi.title(for: account))
        }
        if let first = config.workLocations.first {
            let account = config.settings.account(for: first.id)
            return (account, Conturi.title(for: account))
        }
        return (Conturi.casaGenerala, Conturi.casaGeneralaTitlu)
    }

    private static func matchWorkLocation(for z: ZReportData, in locations: [CompanyWorkLocation]) -> CompanyWorkLocation? {
        let label = Conturi.compactFirmaKey(z.locatieLabel.isEmpty ? z.punctLucru.shortName : z.locatieLabel)
        guard !label.isEmpty else { return locations.count == 1 ? locations.first : nil }

        if let exact = locations.first(where: { Conturi.compactFirmaKey($0.denumire) == label }) {
            return exact
        }
        if let partial = locations.first(where: {
            let key = Conturi.compactFirmaKey($0.denumire)
            return !key.isEmpty && (key.contains(label) || label.contains(key))
        }) {
            return partial
        }
        return locations.count == 1 ? locations.first : nil
    }

    // MARK: - Bacșiș legacy (GENIC, Hotel Impex, …)

    /// Ordine NC: TVA A → net A (707) → TVA B → net B (707) → TVA C → net C (701) → D (462)
    /// → repartizare 10% → Numerar → Card → Alte plăți (5113).
    private static func generateBacsis(from z: ZReportData, nrInreg: Int) -> [NotaContabilaRow] {
        let ctx = RowContext(from: z, nrInreg: nrInreg)

        var rows: [NotaContabilaRow] = [
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.tvaColectata, creditTitlu: Conturi.tvaColectataTitlu,
                    valoare: z.tva21, withPartner: true,
                    optiuneTva: "Taxabile", cotaTva: 21, codTvaSaft: Conturi.saft21),
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.venituri21, creditTitlu: Conturi.venituri21Titlu,
                    valoare: z.net21, withPartner: true,
                    optiuneTva: "Taxabile", cotaTva: 21, codTvaSaft: Conturi.saft21),
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.tvaColectata, creditTitlu: Conturi.tvaColectataTitlu,
                    valoare: z.tva11, withPartner: true,
                    optiuneTva: "Taxabile", cotaTva: 11, codTvaSaft: Conturi.saft11),
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.venituri21, creditTitlu: Conturi.venituri21Titlu,
                    valoare: z.net11, withPartner: true,
                    optiuneTva: "Taxabile", cotaTva: 11, codTvaSaft: Conturi.saft11),
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.tvaColectata, creditTitlu: Conturi.tvaColectataTitlu,
                    valoare: z.tva11C, withPartner: true,
                    optiuneTva: "Taxabile", cotaTva: 11, codTvaSaft: Conturi.saft11),
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.venituri11, creditTitlu: Conturi.venituri11Titlu,
                    valoare: z.net11C, withPartner: true,
                    optiuneTva: "Taxabile", cotaTva: 11, codTvaSaft: Conturi.saft11),
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.bacsisVenit, creditTitlu: Conturi.bacsisVenitTitlu,
                    valoare: z.vanzari0, withPartner: true,
                    optiuneTva: "Neimpozabile", cotaTva: 0, codTvaSaft: Conturi.saft0),
        ]

        if z.vanzari0 > 0 {
            let repartizare = round0(z.vanzari0 * Decimal(string: "0.10")!)
            if repartizare > 0 {
                rows.append(ctx.row(
                    jurnal: "OD",
                    debit: Conturi.bacsisVenit, debitTitlu: Conturi.bacsisVenitTitlu,
                    credit: Conturi.bacsis, creditTitlu: Conturi.bacsisTitlu,
                    valoare: repartizare
                ))
            }
        }

        let altePlati = z.altePlati > 0 ? z.altePlati : max(0, z.totalVanzari - z.numerar - z.card)

        rows.append(contentsOf: [
            ctx.row(jurnal: "RC",
                    debit: Conturi.casaGenerala, debitTitlu: Conturi.casaGeneralaTitlu,
                    credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
                    valoare: z.numerar, withPartner: true),
            ctx.row(jurnal: "RC",
                    debit: Conturi.card, debitTitlu: Conturi.cardTitlu,
                    credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
                    valoare: z.card, withPartner: true),
            ctx.row(jurnal: "RC",
                    debit: Conturi.plataModerna, debitTitlu: Conturi.plataModernaTitlu,
                    credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
                    valoare: altePlati, withPartner: true),
        ])

        return rows.filter { $0.valoare != 0 }
    }

    // MARK: - Nectarie legacy

    private static func generateNectarie(from z: ZReportData, nrInreg: Int) -> [NotaContabilaRow] {
        let ctx = RowContext(from: z, nrInreg: nrInreg)
        let cash = z.numerar
        let casa = z.punctLucru.casaPunct
        let casaTitlu = z.punctLucru.casaPunctTitlu

        let scutit = Conturi.scutitCredit(for: z)
        var rows: [NotaContabilaRow] = baseSalesRows(
            ctx: ctx, z: z,
            scutitCredit: scutit.cont, scutitCreditTitlu: scutit.titlu
        )
        rows.append(ctx.row(jurnal: "RC",
                            debit: casa, debitTitlu: casaTitlu,
                            credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
                            valoare: cash, withPartner: true))
        rows.append(contentsOf: [
            ctx.row(jurnal: "RC",
                    debit: Conturi.viramente, debitTitlu: Conturi.viramenteTitlu,
                    credit: casa, creditTitlu: casaTitlu,
                    valoare: cash),
            ctx.row(jurnal: "RC",
                    debit: Conturi.casaSediu, debitTitlu: Conturi.casaSediuTitlu,
                    credit: Conturi.viramente, creditTitlu: Conturi.viramenteTitlu,
                    valoare: cash),
        ])

        appendCardAndModernaRows(to: &rows, ctx: ctx, z: z)
        return rows.filter { $0.valoare != 0 }
    }

    // MARK: - Generic legacy (8 rânduri)

    private static func generateGeneric(from z: ZReportData, nrInreg: Int) -> [NotaContabilaRow] {
        let ctx = RowContext(from: z, nrInreg: nrInreg)
        let scutit = Conturi.scutitCredit(for: z)
        var rows: [NotaContabilaRow] = baseSalesRows(
            ctx: ctx, z: z,
            scutitCredit: scutit.cont, scutitCreditTitlu: scutit.titlu
        )
        rows.append(ctx.row(jurnal: "RC",
                            debit: Conturi.casaGenerala, debitTitlu: Conturi.casaGeneralaTitlu,
                            credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
                            valoare: z.numerar, withPartner: true))
        appendCardAndModernaRows(to: &rows, ctx: ctx, z: z)
        return rows.filter { $0.valoare != 0 }
    }

    // MARK: - Shared helpers

    private struct RowContext {
        let doc: String
        let dataNum: Int
        let partener: String
        let partenerNume: String
        let firmCUI: String
        let nrInreg: Int

        init(from z: ZReportData, nrInreg: Int) {
            self.nrInreg = nrInreg
            doc = z.documentNumber
            dataNum = z.dateYYYYMMDD
            let partenerInfo = Conturi.partener(for: z)
            partener = partenerInfo.cod
            partenerNume = partenerInfo.nume
            firmCUI = FirmaRegistry.profile(for: z)?.cui
                ?? FirmaRegistry.normalizeCUI(z.cui)
                ?? ""
        }

        func row(
            jurnal: String,
            debit: String, debitTitlu: String,
            credit: String, creditTitlu: String,
            valoare: Decimal,
            withPartner: Bool = false,
            optiuneTva: String = "",
            cotaTva: Decimal? = nil,
            codTvaSaft: String = ""
        ) -> NotaContabilaRow {
            NotaContabilaRow(
                nrInreg: nrInreg,
                jurnal: jurnal,
                dataYYYYMMDD: dataNum,
                numarDocument: doc,
                contDebit: debit,
                titluDebit: debitTitlu,
                contCredit: credit,
                titluCredit: creditTitlu,
                valoare: valoare,
                codPartener: withPartner ? partener : "",
                partenerCIF: "",
                partenerNume: withPartner ? partenerNume : "",
                firmCUI: firmCUI,
                optiuneTva: optiuneTva,
                cotaTva: cotaTva,
                codTvaSaft: codTvaSaft,
                moneda: "RON"
            )
        }
    }

    /// Rânduri 1–6: TVA/venituri B→A + scutit + numerar placeholder (generic/nectarie order).
    private static func baseSalesRows(
        ctx: RowContext,
        z: ZReportData,
        scutitCredit: String,
        scutitCreditTitlu: String
    ) -> [NotaContabilaRow] {
        [
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.tvaColectata, creditTitlu: Conturi.tvaColectataTitlu,
                    valoare: z.tva11, withPartner: true,
                    optiuneTva: "Taxabile", cotaTva: 11, codTvaSaft: Conturi.saft11),
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.venituri11, creditTitlu: Conturi.venituri11Titlu,
                    valoare: z.net11, withPartner: true,
                    optiuneTva: "Taxabile", cotaTva: 11, codTvaSaft: Conturi.saft11),
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.tvaColectata, creditTitlu: Conturi.tvaColectataTitlu,
                    valoare: z.tva21, withPartner: true,
                    optiuneTva: "Taxabile", cotaTva: 21, codTvaSaft: Conturi.saft21),
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: Conturi.venituri21, creditTitlu: Conturi.venituri21Titlu,
                    valoare: z.net21, withPartner: true,
                    optiuneTva: "Taxabile", cotaTva: 21, codTvaSaft: Conturi.saft21),
            ctx.row(jurnal: "JV",
                    debit: Conturi.clienti, debitTitlu: Conturi.clientiTitlu,
                    credit: scutitCredit, creditTitlu: scutitCreditTitlu,
                    valoare: z.vanzari0, withPartner: true,
                    optiuneTva: "Neimpozabile", cotaTva: 0, codTvaSaft: Conturi.saft0),
        ]
    }

    private static func appendCardAndModernaRows(to rows: inout [NotaContabilaRow], ctx: RowContext, z: ZReportData) {
        let cardOnlyNoCash = z.numerar == 0 && z.card > 0
        rows.append(ctx.row(
            jurnal: cardOnlyNoCash ? "RC" : "OD",
            debit: Conturi.card, debitTitlu: Conturi.cardTitlu,
            credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
            valoare: z.card, withPartner: !cardOnlyNoCash
        ))
        if z.plataModerna > 0 {
            rows.append(ctx.row(
                jurnal: "OD",
                debit: Conturi.plataModerna, debitTitlu: Conturi.plataModernaTitlu,
                credit: Conturi.clienti, creditTitlu: Conturi.clientiTitlu,
                valoare: z.plataModerna, withPartner: true
            ))
        }
    }

    private static func round0(_ value: Decimal) -> Decimal {
        var v = value
        var result = Decimal()
        NSDecimalRound(&result, &v, 0, .plain)
        return result
    }
}
