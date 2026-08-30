import Foundation

enum ClientInvoiceDuplicateCheck {
    static func normalizeInvoiceNumber(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func normalizedInvoiceDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func roundedAmount(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }

    static func duplicateKeys(
        clientId: UUID,
        clientCUI: String?,
        number: String,
        issueDate: Date,
        totalAmount: Decimal
    ) -> [String] {
        var keys = [
            duplicateKey(
                clientId: clientId,
                number: number,
                issueDate: issueDate,
                totalAmount: totalAmount
            )
        ]
        if let clientCUI {
            keys.append(
                duplicateKeyByCUI(
                    cui: clientCUI,
                    number: number,
                    issueDate: issueDate,
                    totalAmount: totalAmount
                )
            )
        }
        return keys
    }

    static func duplicateKeys(
        for client: Client,
        number: String,
        issueDate: Date,
        totalAmount: Decimal
    ) -> [String] {
        duplicateKeys(
            clientId: client.id,
            clientCUI: EFacturaInvoiceParser.normalizeCUI(client.cui),
            number: number,
            issueDate: issueDate,
            totalAmount: totalAmount
        )
    }

    static func duplicateKeys(
        for invoice: ClientInvoiceRow,
        clientCuiById: [UUID: String]
    ) -> [String] {
        duplicateKeys(
            clientId: invoice.clientId,
            clientCUI: clientCuiById[invoice.clientId],
            number: invoice.numarFactura,
            issueDate: invoice.dataFactura,
            totalAmount: invoice.sumaTotala
        )
    }

    static func duplicateKeySet(
        from invoices: [ClientInvoiceRow],
        clients: [Client],
        excludingInvoiceId: UUID? = nil
    ) -> Set<String> {
        let clientCuiById = clientCuiMap(from: clients)
        return Set(
            invoices
                .filter { $0.id != excludingInvoiceId }
                .flatMap { duplicateKeys(for: $0, clientCuiById: clientCuiById) }
        )
    }

    static func isDuplicate(
        client: Client,
        number: String,
        issueDate: Date,
        totalAmount: Decimal,
        existingInvoices: [ClientInvoiceRow],
        clients: [Client],
        excludingInvoiceId: UUID? = nil
    ) -> Bool {
        findDuplicate(
            client: client,
            number: number,
            issueDate: issueDate,
            totalAmount: totalAmount,
            existingInvoices: existingInvoices,
            clients: clients,
            excludingInvoiceId: excludingInvoiceId
        ) != nil
    }

    static func findDuplicate(
        client: Client,
        number: String,
        issueDate: Date,
        totalAmount: Decimal,
        existingInvoices: [ClientInvoiceRow],
        clients: [Client],
        excludingInvoiceId: UUID? = nil
    ) -> ClientInvoiceRow? {
        let clientCuiById = clientCuiMap(from: clients)
        let candidateKeys = Set(
            duplicateKeys(
                for: client,
                number: number,
                issueDate: issueDate,
                totalAmount: totalAmount
            )
        )

        return existingInvoices.first { invoice in
            if invoice.id == excludingInvoiceId { return false }
            let keys = duplicateKeys(for: invoice, clientCuiById: clientCuiById)
            return keys.contains { candidateKeys.contains($0) }
        }
    }

    static func duplicateMessage(
        clientName: String,
        number: String,
        issueDate: Date,
        totalAmount: Decimal,
        currency: String
    ) -> String {
        L10n.tr(
            "invoices.error_duplicate",
            clientName,
            normalizeInvoiceNumber(number),
            SupplierFormatting.compactDate(issueDate),
            SupplierFormatting.compactAmount(totalAmount, code: currency)
        )
    }

    private static func clientCuiMap(from clients: [Client]) -> [UUID: String] {
        Dictionary(
            uniqueKeysWithValues: clients.compactMap { client -> (UUID, String)? in
                guard let cui = EFacturaInvoiceParser.normalizeCUI(client.cui) else { return nil }
                return (client.id, cui)
            }
        )
    }

    private static func duplicateKey(
        clientId: UUID,
        number: String,
        issueDate: Date,
        totalAmount: Decimal
    ) -> String {
        let day = normalizedInvoiceDay(issueDate)
        let amount = roundedAmount(totalAmount)
        return "id|\(clientId.uuidString)|\(normalizeInvoiceNumber(number))|\(day.timeIntervalSince1970)|\(amount)"
    }

    private static func duplicateKeyByCUI(
        cui: String,
        number: String,
        issueDate: Date,
        totalAmount: Decimal
    ) -> String {
        let day = normalizedInvoiceDay(issueDate)
        let amount = roundedAmount(totalAmount)
        return "cui|\(cui)|\(normalizeInvoiceNumber(number))|\(day.timeIntervalSince1970)|\(amount)"
    }
}
