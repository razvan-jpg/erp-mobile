import Foundation

enum StockSheetLedgerBuilder {
    static func build(movements: [StockMovementDetailRow]) -> StockSheetLedgerResult {
        let sorted = movements.sorted { lhs, rhs in
            let leftDate = lhs.transactionDate
            let rightDate = rhs.transactionDate
            if leftDate != rightDate { return leftDate < rightDate }
            let leftCreated = lhs.createdAt ?? .distantPast
            let rightCreated = rhs.createdAt ?? .distantPast
            if leftCreated != rightCreated { return leftCreated < rightCreated }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        var stock: Decimal = 0
        var cmp: Decimal = 0
        var entries: [StockSheetLedgerEntry] = []

        for (index, movement) in sorted.enumerated() {
            switch movement.tip {
            case .intrare:
                let quantity = movement.cantitate
                let unitPrice = movement.unitPurchasePrice
                cmp = weightedAverage(
                    stock: stock,
                    currentCost: cmp,
                    inboundQuantity: quantity,
                    inboundPrice: unitPrice
                )
                stock += quantity
                let stockValue = stock > 0 ? stock * cmp : 0
                entries.append(
                    StockSheetLedgerEntry(
                        id: movement.id,
                        nrCrt: index + 1,
                        dataTranzactie: movement.transactionDate,
                        numarDocument: movement.documentNumber,
                        cantitateIntrare: quantity,
                        valoareIntrare: quantity * unitPrice,
                        cantitateIesire: 0,
                        valoareIesire: 0,
                        stocCantitate: stock,
                        stocValoare: stockValue
                    )
                )
            case .iesire:
                let quantity = movement.cantitate
                let exitCost = cmp
                stock -= quantity
                let stockValue = stock > 0 ? stock * cmp : 0
                entries.append(
                    StockSheetLedgerEntry(
                        id: movement.id,
                        nrCrt: index + 1,
                        dataTranzactie: movement.transactionDate,
                        numarDocument: movement.documentNumber,
                        cantitateIntrare: 0,
                        valoareIntrare: 0,
                        cantitateIesire: quantity,
                        valoareIesire: quantity * exitCost,
                        stocCantitate: stock,
                        stocValoare: stockValue
                    )
                )
            }
        }

        let weightedAverageCost = stock > 0 ? cmp : nil
        let finalValue = (weightedAverageCost ?? 0) * max(stock, 0)
        return StockSheetLedgerResult(
            entries: entries,
            weightedAverageCost: weightedAverageCost,
            finalQuantity: stock,
            finalValue: finalValue
        )
    }

    private static func weightedAverage(
        stock: Decimal,
        currentCost: Decimal,
        inboundQuantity: Decimal,
        inboundPrice: Decimal
    ) -> Decimal {
        let totalQuantity = stock + inboundQuantity
        guard totalQuantity > 0 else { return inboundPrice }
        return (stock * currentCost + inboundQuantity * inboundPrice) / totalQuantity
    }
}
