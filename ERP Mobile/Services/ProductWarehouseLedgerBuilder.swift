import Foundation

enum ProductWarehouseLedgerBuilder {
    static func build(
        movements: [StockMovementDetailRow]
    ) -> (entries: [ProductWarehouseLedgerEntry], weightedAverageCost: Decimal?, vatPercent: Decimal?) {
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
        var entries: [ProductWarehouseLedgerEntry] = []

        for (index, movement) in sorted.enumerated() {
            switch movement.tip {
            case .intrare:
                let quantity = movement.cantitate
                cmp = weightedAverage(
                    stock: stock,
                    currentCost: cmp,
                    inboundQuantity: quantity,
                    inboundPrice: movement.unitPurchasePrice
                )
                stock += quantity
                entries.append(
                    ProductWarehouseLedgerEntry(
                        id: movement.id,
                        nrCrt: index + 1,
                        dataTranzactie: movement.transactionDate,
                        numarDocument: movement.documentNumber,
                        fel: .intrare,
                        cantitate: quantity,
                        pret: movement.unitPurchasePrice,
                        stocFinal: stock
                    )
                )
            case .iesire:
                let quantity = movement.cantitate
                let exitCost = cmp
                stock -= quantity
                entries.append(
                    ProductWarehouseLedgerEntry(
                        id: movement.id,
                        nrCrt: index + 1,
                        dataTranzactie: movement.transactionDate,
                        numarDocument: movement.documentNumber,
                        fel: .iesire,
                        cantitate: -quantity,
                        pret: exitCost,
                        stocFinal: stock
                    )
                )
            }
        }

        let weightedAverageCost = stock > 0 ? cmp : nil
        let vatPercent = representativeVatPercent(from: sorted)
        return (entries, weightedAverageCost, vatPercent)
    }

    private static func representativeVatPercent(from movements: [StockMovementDetailRow]) -> Decimal? {
        for movement in movements.filter({ $0.tip == .intrare }).reversed() {
            if let percent = movement.vatPercent, percent > 0 {
                return percent
            }
        }
        return nil
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
