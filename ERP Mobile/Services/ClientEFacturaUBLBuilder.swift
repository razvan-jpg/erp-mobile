import Foundation

/// Minimal UBL 2.1 / CIUS-RO Invoice XML for header-only client invoices (one summary line).
enum ClientEFacturaUBLBuilder {
    static func makeXML(
        company: Company,
        invoice: ClientInvoiceRow,
        buyerCUI: String?,
        buyerAddress: String?
    ) -> Data {
        let sellerCUI = normalizeCUI(company.cui) ?? ""
        let sellerScheme = company.cifCountryPrefix.isEmpty ? "RO" : company.cifCountryPrefix
        let buyerRaw = normalizeCUI(buyerCUI)
        let buyerScheme = buyerRaw == nil ? "RO" : sellerScheme
        let buyerEndpoint = buyerRaw ?? "0000000000000"
        let currency = invoice.moneda.isEmpty ? "RON" : invoice.moneda.uppercased()
        let issueDate = ymd(invoice.dataFactura)
        let dueDate = ymd(invoice.dataScadenta ?? invoice.dataFactura)
        let total = invoice.sumaTotala
        let vat = invoice.sumaTva
        let net = max(total - vat, 0)
        let vatPercent: Decimal = {
            guard net > 0, vat > 0 else { return company.platitorTva ? 19 : 0 }
            let ratio = (vat / net) * 100
            let rounded = NSDecimalNumber(decimal: ratio).rounding(accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )).decimalValue
            return rounded
        }()

        let sellerName = xmlEscape(company.denumire)
        let sellerAddress = xmlEscape(company.adresa ?? companyDisplayAddress(company))
        let buyerName = xmlEscape(invoice.clientName)
        let buyerAddr = xmlEscape(buyerAddress ?? "")
        let invoiceId = xmlEscape(invoice.numarFactura)
        let lineName = xmlEscape(L10n.tr("efactura.ubl_line_summary", invoice.numarFactura))
        let note = xmlEscape(invoice.observatii ?? "")

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
            xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
            xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
          <cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:efactura.mfinante.ro:CIUS-RO:1.0.1</cbc:CustomizationID>
          <cbc:ID>\(invoiceId)</cbc:ID>
          <cbc:IssueDate>\(issueDate)</cbc:IssueDate>
          <cbc:DueDate>\(dueDate)</cbc:DueDate>
          <cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>
          <cbc:DocumentCurrencyCode>\(currency)</cbc:DocumentCurrencyCode>
          \(note.isEmpty ? "" : "<cbc:Note>\(note)</cbc:Note>")
          <cac:AccountingSupplierParty>
            <cac:Party>
              <cac:PartyLegalEntity>
                <cbc:RegistrationName>\(sellerName)</cbc:RegistrationName>
                <cbc:CompanyID schemeID="\(sellerScheme)">\(sellerCUI)</cbc:CompanyID>
              </cac:PartyLegalEntity>
              <cac:PostalAddress>
                <cbc:StreetName>\(sellerAddress)</cbc:StreetName>
                <cac:Country><cbc:IdentificationCode>RO</cbc:IdentificationCode></cac:Country>
              </cac:PostalAddress>
              <cac:PartyTaxScheme>
                <cbc:CompanyID>\(sellerScheme)\(sellerCUI)</cbc:CompanyID>
                <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
              </cac:PartyTaxScheme>
            </cac:Party>
          </cac:AccountingSupplierParty>
          <cac:AccountingCustomerParty>
            <cac:Party>
              <cac:PartyLegalEntity>
                <cbc:RegistrationName>\(buyerName)</cbc:RegistrationName>
                <cbc:CompanyID schemeID="\(buyerScheme)">\(buyerEndpoint)</cbc:CompanyID>
              </cac:PartyLegalEntity>
              <cac:PostalAddress>
                <cbc:StreetName>\(buyerAddr)</cbc:StreetName>
                <cac:Country><cbc:IdentificationCode>RO</cbc:IdentificationCode></cac:Country>
              </cac:PostalAddress>
              <cac:PartyTaxScheme>
                <cbc:CompanyID>\(buyerScheme)\(buyerEndpoint)</cbc:CompanyID>
                <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
              </cac:PartyTaxScheme>
            </cac:Party>
          </cac:AccountingCustomerParty>
          <cac:TaxTotal>
            <cbc:TaxAmount currencyID="\(currency)">\(decimalString(vat))</cbc:TaxAmount>
            <cac:TaxSubtotal>
              <cbc:TaxableAmount currencyID="\(currency)">\(decimalString(net))</cbc:TaxableAmount>
              <cbc:TaxAmount currencyID="\(currency)">\(decimalString(vat))</cbc:TaxAmount>
              <cac:TaxCategory>
                <cbc:ID>\(vat > 0 ? "S" : "Z")</cbc:ID>
                <cbc:Percent>\(decimalString(vatPercent))</cbc:Percent>
                <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
              </cac:TaxCategory>
            </cac:TaxSubtotal>
          </cac:TaxTotal>
          <cac:LegalMonetaryTotal>
            <cbc:LineExtensionAmount currencyID="\(currency)">\(decimalString(net))</cbc:LineExtensionAmount>
            <cbc:TaxExclusiveAmount currencyID="\(currency)">\(decimalString(net))</cbc:TaxExclusiveAmount>
            <cbc:TaxInclusiveAmount currencyID="\(currency)">\(decimalString(total))</cbc:TaxInclusiveAmount>
            <cbc:PayableAmount currencyID="\(currency)">\(decimalString(total))</cbc:PayableAmount>
          </cac:LegalMonetaryTotal>
          <cac:InvoiceLine>
            <cbc:ID>1</cbc:ID>
            <cbc:InvoicedQuantity unitCode="H87">1</cbc:InvoicedQuantity>
            <cbc:LineExtensionAmount currencyID="\(currency)">\(decimalString(net))</cbc:LineExtensionAmount>
            <cac:Item>
              <cbc:Name>\(lineName)</cbc:Name>
              <cac:ClassifiedTaxCategory>
                <cbc:ID>\(vat > 0 ? "S" : "Z")</cbc:ID>
                <cbc:Percent>\(decimalString(vatPercent))</cbc:Percent>
                <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
              </cac:ClassifiedTaxCategory>
            </cac:Item>
            <cac:Price>
              <cbc:PriceAmount currencyID="\(currency)">\(decimalString(net))</cbc:PriceAmount>
            </cac:Price>
          </cac:InvoiceLine>
        </Invoice>
        """

        return Data(xml.utf8)
    }

    private static func companyDisplayAddress(_ company: Company) -> String {
        [company.hqStreet, company.hqStreetNumber, company.hqCity, company.hqCounty]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private static func normalizeCUI(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let digits = raw.uppercased().replacingOccurrences(of: "RO", with: "").filter(\.isNumber)
        return digits.isEmpty ? nil : digits
    }

    private static func ymd(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func decimalString(_ value: Decimal) -> String {
        let n = NSDecimalNumber(decimal: value)
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.numberStyle = .decimal
        return f.string(from: n) ?? "0.00"
    }

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
