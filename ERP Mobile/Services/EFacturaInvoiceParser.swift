import Foundation

struct EFacturaParsedInvoice: Sendable {
    struct Party: Sendable {
        var name: String = ""
        var cui: String?
        var nrRegCom: String?
        var adresa: String?
        var email: String?
        var telefon: String?
        var iban: String?
    }

    struct Line: Sendable {
        var lineNumber: Int
        var name: String
        var description: String?
        var sellerCode: String?
        var barcode: String?
        var cpv: String?
        var quantity: Decimal
        var unitCode: String
        var unitPrice: Decimal?
        var lineTotal: Decimal?
        var lineTax: Decimal?
        var lineTaxPercent: Decimal?
    }

    var supplier = Party()
    var customer = Party()
    var invoiceNumber: String = ""
    var issueDate: Date?
    var dueDate: Date?
    var currency: String = "RON"
    var taxInclusiveAmount: Decimal?
    var taxAmount: Decimal?
    var invoiceTypeCode: String?
    var isCreditNote: Bool = false
    var lines: [Line] = []
}

enum EFacturaParserError: LocalizedError {
    case invalidXML
    case unsupportedRoot(String)
    case missingSupplierName
    case missingInvoiceNumber
    case missingIssueDate
    case missingAmount

    var errorDescription: String? {
        switch self {
        case .invalidXML:
            return L10n.tr("invoices.import_error_invalid_xml")
        case .unsupportedRoot(let name):
            return L10n.tr("invoices.import_error_unsupported_root", name)
        case .missingSupplierName:
            return L10n.tr("invoices.import_error_missing_supplier")
        case .missingInvoiceNumber:
            return L10n.tr("invoices.import_error_missing_number")
        case .missingIssueDate:
            return L10n.tr("invoices.import_error_missing_date")
        case .missingAmount:
            return L10n.tr("invoices.import_error_missing_amount")
        }
    }
}

enum EFacturaInvoiceParser {
    static func isCreditNote(data: Data) -> Bool {
        documentRootElement(in: data) == "CreditNote"
    }

    static func documentRootElement(in data: Data) -> String? {
        final class RootDetector: NSObject, XMLParserDelegate {
            var rootElement: String?

            func parser(
                _ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]
            ) {
                if rootElement == nil {
                    rootElement = Self.localName(elementName, qName)
                    parser.abortParsing()
                }
            }

            private static func localName(_ name: String, _ qName: String?) -> String {
                let raw = qName ?? name
                if let idx = raw.firstIndex(of: ":") {
                    return String(raw[raw.index(after: idx)...])
                }
                return raw
            }
        }

        let detector = RootDetector()
        let parser = XMLParser(data: data)
        parser.delegate = detector
        _ = parser.parse()
        return detector.rootElement
    }

    static func parse(data: Data) throws -> EFacturaParsedInvoice {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw EFacturaParserError.invalidXML
        }
        return try delegate.buildResult()
    }

    static func normalizeLineNumbers(_ invoice: inout EFacturaParsedInvoice) {
        invoice.lines = invoice.lines.enumerated().map { index, line in
            var normalized = line
            normalized.lineNumber = index + 1
            return normalized
        }
    }

    static func normalizeCUI(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return nil }
        let digits = trimmed.hasPrefix("RO") ? String(trimmed.dropFirst(2)) : trimmed
        let normalized = digits.filter(\.isNumber)
        return normalized.isEmpty ? nil : normalized
    }

    static func resolvedPartyCUI(_ party: EFacturaParsedInvoice.Party) -> String? {
        normalizeCUI(party.cui)
    }

    private static func isEmailEndpointScheme(_ scheme: String?) -> Bool {
        scheme?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() == "EM"
    }

    private static func looksLikeTradeRegister(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("/") || trimmed.hasPrefix("J")
    }

    private static func looksLikeCUI(_ value: String) -> Bool {
        if looksLikeTradeRegister(value) { return false }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("RO") {
            let digits = trimmed.dropFirst(2).filter(\.isNumber)
            return (2...10).contains(digits.count)
        }
        let digits = trimmed.filter(\.isNumber)
        guard (2...10).contains(digits.count) else { return false }
        return trimmed.count == digits.count
    }

    private static func isTaxIdentifierScheme(_ scheme: String?) -> Bool {
        guard let scheme else { return false }
        let normalized = scheme
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
        return [
            "VAT",
            "CUI",
            "CIF",
            "TIN",
            "RO:CUI",
            "RO:CIF",
            "RO:VAT",
            "0208",
            "9956"
        ].contains(normalized) || normalized.hasSuffix(":CUI") || normalized.hasSuffix(":CIF")
    }

    private struct LineDraft {
        var lineNumber: Int = 0
        var name: String = ""
        var description: String?
        var sellerCode: String?
        var barcode: String?
        var cpv: String?
        var quantity: Decimal?
        var unitCode: String = "buc"
        var unitPrice: Decimal?
        var lineTotal: Decimal?
        var lineTax: Decimal?
        var lineTaxPercent: Decimal?
        var standardItemIDScheme: String?
    }

    private final class ParserDelegate: NSObject, XMLParserDelegate {
        private var rootElement: String?
        private var currentText = ""

        private var supplierPartyDepth = 0
        private var customerPartyDepth = 0
        private var invoiceLineDepth = 0
        private var legalMonetaryTotalDepth = 0
        private var taxTotalDepth = 0
        private var postalAddressDepth = 0
        private var partyTaxSchemeDepth = 0
        private var partyLegalEntityDepth = 0
        private var partyIdentificationDepth = 0
        private var partyNameDepth = 0
        private var contactDepth = 0
        private var payeeFinancialAccountDepth = 0
        private var itemDepth = 0
        private var sellersItemDepth = 0
        private var standardItemDepth = 0
        private var manufacturersItemDepth = 0
        private var additionalItemPropertyDepth = 0
        private var pendingAdditionalItemPropertyName: String?
        private var commodityClassDepth = 0
        private var priceDepth = 0
        private var lineTaxTotalDepth = 0
        private var lineTaxSubtotalDepth = 0
        private var documentTaxSubtotalDepth = 0
        private var lineTaxCategoryDepth = 0
        private var classifiedTaxCategoryDepth = 0

        private var draft = EFacturaParsedInvoice()
        private var lineDraft: LineDraft?
        private var supplierAddressLines: [String] = []
        private var customerAddressLines: [String] = []
        private var pendingIdentificationScheme: String?
        private var pendingEndpointScheme: String?

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            currentText = ""
            let name = Self.localName(elementName, qName)

            if rootElement == nil {
                rootElement = name
            }

            switch name {
            case "AccountingSupplierParty":
                supplierPartyDepth += 1
            case "AccountingCustomerParty":
                customerPartyDepth += 1
            case "InvoiceLine", "CreditNoteLine":
                invoiceLineDepth += 1
                lineDraft = LineDraft()
            case "LegalMonetaryTotal":
                legalMonetaryTotalDepth += 1
            case "TaxTotal":
                if invoiceLineDepth > 0 {
                    lineTaxTotalDepth += 1
                } else {
                    taxTotalDepth += 1
                }
            case "PostalAddress":
                if supplierPartyDepth > 0 { postalAddressDepth += 1 }
                if customerPartyDepth > 0 { postalAddressDepth += 1 }
            case "PartyTaxScheme":
                if supplierPartyDepth > 0 || customerPartyDepth > 0 { partyTaxSchemeDepth += 1 }
            case "PartyLegalEntity":
                if supplierPartyDepth > 0 || customerPartyDepth > 0 { partyLegalEntityDepth += 1 }
            case "PartyIdentification":
                if supplierPartyDepth > 0 || customerPartyDepth > 0 { partyIdentificationDepth += 1 }
            case "PartyName":
                if supplierPartyDepth > 0 || customerPartyDepth > 0 { partyNameDepth += 1 }
            case "Contact":
                if supplierPartyDepth > 0 || customerPartyDepth > 0 { contactDepth += 1 }
            case "PayeeFinancialAccount":
                if supplierPartyDepth > 0 { payeeFinancialAccountDepth += 1 }
            case "Item":
                if invoiceLineDepth > 0 { itemDepth += 1 }
            case "SellersItemIdentification":
                if invoiceLineDepth > 0 { sellersItemDepth += 1 }
            case "StandardItemIdentification":
                if invoiceLineDepth > 0 { standardItemDepth += 1 }
            case "ManufacturersItemIdentification":
                if invoiceLineDepth > 0 { manufacturersItemDepth += 1 }
            case "AdditionalItemProperty":
                if invoiceLineDepth > 0 { additionalItemPropertyDepth += 1 }
            case "CommodityClassification":
                if invoiceLineDepth > 0 { commodityClassDepth += 1 }
            case "Price":
                if invoiceLineDepth > 0 { priceDepth += 1 }
            case "TaxSubtotal":
                if invoiceLineDepth > 0, lineTaxTotalDepth > 0 {
                    lineTaxSubtotalDepth += 1
                } else if taxTotalDepth > 0, invoiceLineDepth == 0 {
                    documentTaxSubtotalDepth += 1
                }
            case "TaxCategory", "ClassifiedTaxCategory":
                if invoiceLineDepth > 0 {
                    if lineTaxSubtotalDepth > 0 {
                        lineTaxCategoryDepth += 1
                    } else if name == "ClassifiedTaxCategory" {
                        classifiedTaxCategoryDepth += 1
                    }
                }
            case "InvoicedQuantity", "CreditedQuantity":
                if invoiceLineDepth > 0 {
                    let unit = attributeDict["unitCode"] ?? attributeDict["unitcode"]
                    if let unit, !unit.isEmpty {
                        lineDraft?.unitCode = unit
                    }
                }
            case "ID":
                if invoiceLineDepth > 0, standardItemDepth > 0 {
                    lineDraft?.standardItemIDScheme = attributeDict["schemeID"] ?? attributeDict["schemeid"]
                } else if partyIdentificationDepth > 0 {
                    pendingIdentificationScheme = attributeDict["schemeID"] ?? attributeDict["schemeid"]
                }
            case "EndpointID":
                if supplierPartyDepth > 0 || customerPartyDepth > 0 {
                    pendingEndpointScheme = attributeDict["schemeID"] ?? attributeDict["schemeid"]
                }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            let name = Self.localName(elementName, qName)
            let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            currentText = ""

            switch name {
            case "RegistrationName":
                if supplierPartyDepth > 0, partyLegalEntityDepth > 0, draft.supplier.name.isEmpty {
                    draft.supplier.name = text
                } else if customerPartyDepth > 0, partyLegalEntityDepth > 0, draft.customer.name.isEmpty {
                    draft.customer.name = text
                }
            case "CompanyID":
                if supplierPartyDepth > 0 {
                    if partyTaxSchemeDepth > 0 {
                        assignTaxIdentifier(text: text, to: &draft.supplier)
                    } else if partyLegalEntityDepth > 0 {
                        assignLegalEntityIdentifier(text: text, to: &draft.supplier)
                    }
                } else if customerPartyDepth > 0 {
                    if partyTaxSchemeDepth > 0 {
                        assignTaxIdentifier(text: text, to: &draft.customer)
                    } else if partyLegalEntityDepth > 0 {
                        assignLegalEntityIdentifier(text: text, to: &draft.customer)
                    }
                }
            case "StreetName", "AdditionalStreetName", "CityName", "CountrySubentity", "PostalZone":
                if supplierPartyDepth > 0, postalAddressDepth > 0, !text.isEmpty {
                    supplierAddressLines.append(text)
                } else if customerPartyDepth > 0, postalAddressDepth > 0, !text.isEmpty {
                    customerAddressLines.append(text)
                }
            case "ElectronicMail":
                if supplierPartyDepth > 0, contactDepth > 0, draft.supplier.email == nil {
                    draft.supplier.email = text
                } else if customerPartyDepth > 0, contactDepth > 0, draft.customer.email == nil {
                    draft.customer.email = text
                }
            case "Telephone":
                if supplierPartyDepth > 0, contactDepth > 0, draft.supplier.telefon == nil {
                    draft.supplier.telefon = text
                } else if customerPartyDepth > 0, contactDepth > 0, draft.customer.telefon == nil {
                    draft.customer.telefon = text
                }
            case "ID":
                if payeeFinancialAccountDepth > 0, draft.supplier.iban == nil {
                    draft.supplier.iban = text.replacingOccurrences(of: " ", with: "")
                } else if partyIdentificationDepth > 0, supplierPartyDepth > 0 {
                    assignPartyIdentification(
                        text: text,
                        scheme: pendingIdentificationScheme,
                        to: &draft.supplier
                    )
                    pendingIdentificationScheme = nil
                } else if partyIdentificationDepth > 0, customerPartyDepth > 0 {
                    assignPartyIdentification(
                        text: text,
                        scheme: pendingIdentificationScheme,
                        to: &draft.customer
                    )
                    pendingIdentificationScheme = nil
                } else if invoiceLineDepth > 0, sellersItemDepth > 0, lineDraft?.sellerCode == nil {
                    lineDraft?.sellerCode = text
                } else if invoiceLineDepth > 0, standardItemDepth > 0, lineDraft?.barcode == nil,
                          Self.shouldAcceptAsBarcode(text, scheme: lineDraft?.standardItemIDScheme) {
                    lineDraft?.barcode = Self.normalizeBarcode(text)
                    lineDraft?.standardItemIDScheme = nil
                } else if invoiceLineDepth > 0, manufacturersItemDepth > 0, lineDraft?.barcode == nil,
                          Self.looksLikeBarcode(text) {
                    lineDraft?.barcode = Self.normalizeBarcode(text)
                } else if invoiceLineDepth > 0, itemDepth == 0, priceDepth == 0, lineTaxTotalDepth == 0,
                          let lineNumber = Int(text), lineNumber > 0 {
                    lineDraft?.lineNumber = lineNumber
                } else if supplierPartyDepth == 0, customerPartyDepth == 0, invoiceLineDepth == 0,
                          legalMonetaryTotalDepth == 0, draft.invoiceNumber.isEmpty {
                    draft.invoiceNumber = text
                }
            case "IssueDate":
                if invoiceLineDepth == 0, draft.issueDate == nil {
                    draft.issueDate = Self.parseDate(text)
                }
            case "DueDate":
                if invoiceLineDepth == 0, draft.dueDate == nil {
                    draft.dueDate = Self.parseDate(text)
                }
            case "DocumentCurrencyCode":
                if !text.isEmpty { draft.currency = text.uppercased() }
            case "InvoiceTypeCode", "CreditNoteTypeCode":
                draft.invoiceTypeCode = text
            case "TaxInclusiveAmount":
                if legalMonetaryTotalDepth > 0, invoiceLineDepth == 0, draft.taxInclusiveAmount == nil {
                    draft.taxInclusiveAmount = Self.parseDecimal(text)
                }
            case "TaxAmount":
                if lineTaxTotalDepth > 0, invoiceLineDepth > 0 {
                    if let amount = Self.parseDecimal(text) {
                        if let existing = lineDraft?.lineTax {
                            lineDraft?.lineTax = existing + amount
                        } else {
                            lineDraft?.lineTax = amount
                        }
                    }
                } else if taxTotalDepth > 0, invoiceLineDepth == 0, documentTaxSubtotalDepth == 0 {
                    if let amount = Self.parseDecimal(text) {
                        if let existing = draft.taxAmount {
                            draft.taxAmount = existing + amount
                        } else {
                            draft.taxAmount = amount
                        }
                    }
                }
            case "Percent":
                if invoiceLineDepth > 0, lineDraft?.lineTaxPercent == nil,
                   lineTaxCategoryDepth > 0 || classifiedTaxCategoryDepth > 0,
                   let percent = Self.parseDecimal(text) {
                    lineDraft?.lineTaxPercent = percent
                }
            case "PayableAmount":
                if legalMonetaryTotalDepth > 0, invoiceLineDepth == 0, draft.taxInclusiveAmount == nil {
                    draft.taxInclusiveAmount = Self.parseDecimal(text)
                }
            case "InvoicedQuantity", "CreditedQuantity":
                if invoiceLineDepth > 0 {
                    lineDraft?.quantity = Self.parseDecimal(text)
                }
            case "LineExtensionAmount":
                if invoiceLineDepth > 0 {
                    lineDraft?.lineTotal = Self.parseDecimal(text)
                }
            case "PriceAmount":
                if invoiceLineDepth > 0, priceDepth > 0 {
                    lineDraft?.unitPrice = Self.parseDecimal(text)
                }
            case "Name":
                if supplierPartyDepth > 0, partyNameDepth > 0, draft.supplier.name.isEmpty, !text.isEmpty {
                    draft.supplier.name = text
                } else if customerPartyDepth > 0, partyNameDepth > 0, draft.customer.name.isEmpty, !text.isEmpty {
                    draft.customer.name = text
                } else if invoiceLineDepth > 0, additionalItemPropertyDepth > 0 {
                    pendingAdditionalItemPropertyName = text
                } else if invoiceLineDepth > 0, itemDepth > 0, lineDraft?.name.isEmpty == true {
                    lineDraft?.name = text
                }
            case "Value":
                if invoiceLineDepth > 0, additionalItemPropertyDepth > 0,
                   lineDraft?.barcode == nil,
                   Self.isBarcodePropertyName(pendingAdditionalItemPropertyName),
                   Self.looksLikeBarcode(text) {
                    lineDraft?.barcode = Self.normalizeBarcode(text)
                    pendingAdditionalItemPropertyName = nil
                }
            case "EndpointID":
                if supplierPartyDepth > 0 {
                    assignEndpointIdentifier(
                        text: text,
                        scheme: pendingEndpointScheme,
                        to: &draft.supplier
                    )
                } else if customerPartyDepth > 0 {
                    assignEndpointIdentifier(
                        text: text,
                        scheme: pendingEndpointScheme,
                        to: &draft.customer
                    )
                }
                pendingEndpointScheme = nil
            case "Description":
                if invoiceLineDepth > 0, itemDepth > 0, lineDraft?.description == nil {
                    lineDraft?.description = text
                }
            case "ItemClassificationCode":
                if invoiceLineDepth > 0, commodityClassDepth > 0, lineDraft?.cpv == nil {
                    lineDraft?.cpv = text
                }
            case "AccountingSupplierParty":
                supplierPartyDepth = max(0, supplierPartyDepth - 1)
                if supplierPartyDepth == 0, !supplierAddressLines.isEmpty, draft.supplier.adresa == nil {
                    draft.supplier.adresa = supplierAddressLines.joined(separator: ", ")
                    supplierAddressLines = []
                }
            case "AccountingCustomerParty":
                customerPartyDepth = max(0, customerPartyDepth - 1)
                if customerPartyDepth == 0, !customerAddressLines.isEmpty, draft.customer.adresa == nil {
                    draft.customer.adresa = customerAddressLines.joined(separator: ", ")
                    customerAddressLines = []
                }
            case "InvoiceLine", "CreditNoteLine":
                if let line = finalizeLineDraft() {
                    draft.lines.append(line)
                }
                lineDraft = nil
                invoiceLineDepth = max(0, invoiceLineDepth - 1)
            case "LegalMonetaryTotal":
                legalMonetaryTotalDepth = max(0, legalMonetaryTotalDepth - 1)
            case "TaxTotal":
                if lineTaxTotalDepth > 0 {
                    lineTaxTotalDepth = max(0, lineTaxTotalDepth - 1)
                } else {
                    taxTotalDepth = max(0, taxTotalDepth - 1)
                }
            case "TaxSubtotal":
                if lineTaxSubtotalDepth > 0 {
                    lineTaxSubtotalDepth = max(0, lineTaxSubtotalDepth - 1)
                } else {
                    documentTaxSubtotalDepth = max(0, documentTaxSubtotalDepth - 1)
                }
            case "TaxCategory", "ClassifiedTaxCategory":
                if name == "TaxCategory" {
                    lineTaxCategoryDepth = max(0, lineTaxCategoryDepth - 1)
                } else {
                    classifiedTaxCategoryDepth = max(0, classifiedTaxCategoryDepth - 1)
                }
            case "PostalAddress":
                postalAddressDepth = max(0, postalAddressDepth - 1)
            case "PartyTaxScheme":
                partyTaxSchemeDepth = max(0, partyTaxSchemeDepth - 1)
            case "PartyLegalEntity":
                partyLegalEntityDepth = max(0, partyLegalEntityDepth - 1)
            case "PartyIdentification":
                partyIdentificationDepth = max(0, partyIdentificationDepth - 1)
                pendingIdentificationScheme = nil
            case "PartyName":
                partyNameDepth = max(0, partyNameDepth - 1)
            case "Contact":
                contactDepth = max(0, contactDepth - 1)
            case "PayeeFinancialAccount":
                payeeFinancialAccountDepth = max(0, payeeFinancialAccountDepth - 1)
            case "Item":
                itemDepth = max(0, itemDepth - 1)
            case "SellersItemIdentification":
                sellersItemDepth = max(0, sellersItemDepth - 1)
            case "StandardItemIdentification":
                standardItemDepth = max(0, standardItemDepth - 1)
                lineDraft?.standardItemIDScheme = nil
            case "ManufacturersItemIdentification":
                manufacturersItemDepth = max(0, manufacturersItemDepth - 1)
            case "AdditionalItemProperty":
                additionalItemPropertyDepth = max(0, additionalItemPropertyDepth - 1)
                pendingAdditionalItemPropertyName = nil
            case "CommodityClassification":
                commodityClassDepth = max(0, commodityClassDepth - 1)
            case "Price":
                priceDepth = max(0, priceDepth - 1)
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {}

        private func assignTaxIdentifier(text: String, to party: inout EFacturaParsedInvoice.Party) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            party.cui = trimmed
        }

        private func assignLegalEntityIdentifier(text: String, to party: inout EFacturaParsedInvoice.Party) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            if party.cui == nil, EFacturaInvoiceParser.looksLikeCUI(trimmed) {
                party.cui = trimmed
                return
            }

            if party.nrRegCom == nil, EFacturaInvoiceParser.looksLikeTradeRegister(trimmed) {
                party.nrRegCom = trimmed
            }
        }

        private func assignPartyIdentification(
            text: String,
            scheme: String?,
            to party: inout EFacturaParsedInvoice.Party
        ) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            if EFacturaInvoiceParser.isTaxIdentifierScheme(scheme) {
                if party.cui == nil {
                    party.cui = trimmed
                }
                return
            }

            if party.nrRegCom == nil, EFacturaInvoiceParser.looksLikeTradeRegister(trimmed) {
                party.nrRegCom = trimmed
            } else if party.cui == nil, EFacturaInvoiceParser.looksLikeCUI(trimmed) {
                party.cui = trimmed
            }
        }

        private func assignEndpointIdentifier(
            text: String,
            scheme: String?,
            to party: inout EFacturaParsedInvoice.Party
        ) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            if EFacturaInvoiceParser.isEmailEndpointScheme(scheme) {
                if party.email == nil {
                    party.email = trimmed
                }
                return
            }

            if EFacturaInvoiceParser.isTaxIdentifierScheme(scheme),
               party.cui == nil {
                party.cui = trimmed
            }
        }

        private func finalizeLineDraft() -> EFacturaParsedInvoice.Line? {
            guard var current = lineDraft else { return nil }
            let trimmedName = current.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }

            if current.lineNumber <= 0 {
                current.lineNumber = nextAvailableLineNumber()
            } else {
                let usedNumbers = Set(draft.lines.map(\.lineNumber))
                if usedNumbers.contains(current.lineNumber) {
                    current.lineNumber = nextAvailableLineNumber()
                }
            }
            let quantity = current.quantity ?? 1
            let unitPrice = current.unitPrice ?? {
                guard let lineTotal = current.lineTotal, quantity != 0 else { return nil }
                return lineTotal / quantity
            }()
            let lineTotal = current.lineTotal ?? {
                guard let unitPrice else { return nil }
                return SupplierFormatting.roundAmount(unitPrice * quantity)
            }()

            var lineTax = current.lineTax
            var lineTaxPercent = current.lineTaxPercent

            if (lineTax == nil || lineTax == .zero),
               let percent = lineTaxPercent,
               let lineTotal,
               lineTotal > 0 {
                lineTax = SupplierFormatting.roundAmount(lineTotal * percent / 100)
            }

            if lineTaxPercent == nil,
               let lineTotal,
               lineTotal > 0,
               let lineTax,
               lineTax > 0 {
                var percent = lineTax / lineTotal * 100
                var rounded = Decimal()
                NSDecimalRound(&rounded, &percent, 2, .plain)
                lineTaxPercent = rounded
            }

            return EFacturaParsedInvoice.Line(
                lineNumber: current.lineNumber,
                name: trimmedName,
                description: current.description,
                sellerCode: current.sellerCode,
                barcode: Self.normalizeBarcode(current.barcode),
                cpv: current.cpv,
                quantity: quantity,
                unitCode: EFacturaUnitCode.normalize(current.unitCode.isEmpty ? "h87" : current.unitCode),
                unitPrice: unitPrice,
                lineTotal: lineTotal,
                lineTax: lineTax ?? .zero,
                lineTaxPercent: lineTaxPercent
            )
        }

        func buildResult() throws -> EFacturaParsedInvoice {
            guard rootElement == "Invoice" || rootElement == "CreditNote" else {
                throw EFacturaParserError.unsupportedRoot(rootElement ?? "—")
            }
            guard !draft.supplier.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw EFacturaParserError.missingSupplierName
            }
            guard !draft.invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw EFacturaParserError.missingInvoiceNumber
            }
            guard draft.issueDate != nil else {
                throw EFacturaParserError.missingIssueDate
            }
            guard draft.taxInclusiveAmount != nil else {
                throw EFacturaParserError.missingAmount
            }
            if rootElement == "CreditNote" {
                draft.isCreditNote = true
                Self.negateCreditNoteAmounts(&draft)
            } else {
                draft.taxAmount = Self.resolvedDocumentTaxAmount(for: draft)
            }
            EFacturaInvoiceParser.normalizeLineNumbers(&draft)
            return draft
        }

        private static func negateCreditNoteAmounts(_ draft: inout EFacturaParsedInvoice) {
            if let amount = draft.taxInclusiveAmount {
                draft.taxInclusiveAmount = -abs(amount)
            }

            draft.lines = draft.lines.map { line in
                var negated = line
                if let total = line.lineTotal {
                    negated.lineTotal = -abs(total)
                }
                if let tax = line.lineTax, tax != .zero {
                    negated.lineTax = -abs(tax)
                }
                return negated
            }

            if let headerTax = draft.taxAmount {
                draft.taxAmount = -abs(headerTax)
            } else {
                draft.taxAmount = Self.resolvedDocumentTaxAmount(for: draft)
            }
        }

        private func nextAvailableLineNumber() -> Int {
            var candidate = draft.lines.count + 1
            let usedNumbers = Set(draft.lines.map(\.lineNumber))
            while usedNumbers.contains(candidate) {
                candidate += 1
            }
            return candidate
        }

        private static func resolvedDocumentTaxAmount(for draft: EFacturaParsedInvoice) -> Decimal {
            if let headerTax = draft.taxAmount {
                return SupplierFormatting.roundAmount(headerTax)
            }
            guard !draft.lines.isEmpty else { return .zero }
            let lineSum = draft.lines.reduce(Decimal.zero) { partial, line in
                partial + (line.lineTax ?? .zero)
            }
            return SupplierFormatting.roundAmount(lineSum)
        }

        private static func localName(_ name: String, _ qName: String?) -> String {
            let raw = qName ?? name
            if let idx = raw.firstIndex(of: ":") {
                return String(raw[raw.index(after: idx)...])
            }
            return raw
        }

        private static func parseDate(_ text: String) -> Date? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            if let date = SupabaseDecoding.parseDate(String(trimmed.prefix(10))) {
                return date
            }

            let formatters = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"]
            for format in formatters {
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = format
                guard let date = formatter.date(from: trimmed) else { continue }

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                return calendar.date(from: components)
            }
            return nil
        }

        private static func parseDecimal(_ text: String) -> Decimal? {
            let normalized = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Decimal(string: normalized)
        }

        private static func normalizeBarcode(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return trimmed.replacingOccurrences(of: " ", with: "")
        }

        private static func looksLikeBarcode(_ value: String) -> Bool {
            guard let normalized = normalizeBarcode(value) else { return false }
            let digits = normalized.filter(\.isNumber)
            guard !digits.isEmpty else { return false }
            if digits.count == normalized.count {
                return [8, 12, 13, 14].contains(digits.count)
            }
            return normalized.count >= 4
        }

        private static func shouldAcceptAsBarcode(_ value: String, scheme: String?) -> Bool {
            guard looksLikeBarcode(value) else { return false }
            guard let scheme else { return true }
            return isBarcodeScheme(scheme)
        }

        private static func isBarcodeScheme(_ scheme: String) -> Bool {
            let normalized = scheme.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return ["0160", "0209", "0140", "EAN", "GTIN", "GTIN13", "GTIN14"].contains(normalized)
        }

        private static func isBarcodePropertyName(_ name: String?) -> Bool {
            guard let name else { return false }
            let normalized = name
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
                .replacingOccurrences(of: " ", with: "")
            return ["codbare", "coddebare", "barcode", "ean", "gtin", "gtin13", "gtin14"].contains(normalized)
        }
    }
}
