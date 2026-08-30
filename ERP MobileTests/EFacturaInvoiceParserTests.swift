import Foundation
import Testing
@testable import ERPMobile

struct EFacturaInvoiceParserTests {
    @Test func parsesBuyerCUIFromPartyLegalEntityForNonVATPayer() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
                 xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
                 xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
            <cbc:ID>FAC-100</cbc:ID>
            <cbc:IssueDate>2026-07-04</cbc:IssueDate>
            <cbc:DocumentCurrencyCode>RON</cbc:DocumentCurrencyCode>
            <cac:AccountingSupplierParty>
                <cac:Party>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>Furnizor Test SRL</cbc:RegistrationName>
                        <cbc:CompanyID>RO11111111</cbc:CompanyID>
                    </cac:PartyLegalEntity>
                    <cac:PartyTaxScheme>
                        <cbc:CompanyID>RO11111111</cbc:CompanyID>
                    </cac:PartyTaxScheme>
                </cac:Party>
            </cac:AccountingSupplierParty>
            <cac:AccountingCustomerParty>
                <cac:Party>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>Client Test SRL</cbc:RegistrationName>
                        <cbc:CompanyID>49296198</cbc:CompanyID>
                    </cac:PartyLegalEntity>
                </cac:Party>
            </cac:AccountingCustomerParty>
            <cac:LegalMonetaryTotal>
                <cbc:TaxInclusiveAmount>100.00</cbc:TaxInclusiveAmount>
            </cac:LegalMonetaryTotal>
            <cac:InvoiceLine>
                <cbc:ID>1</cbc:ID>
                <cbc:InvoicedQuantity unitCode="H87">1</cbc:InvoicedQuantity>
                <cac:Item>
                    <cbc:Name>Produs test</cbc:Name>
                </cac:Item>
                <cac:Price>
                    <cbc:PriceAmount>100.00</cbc:PriceAmount>
                </cac:Price>
            </cac:InvoiceLine>
        </Invoice>
        """

        let parsed = try EFacturaInvoiceParser.parse(data: Data(xml.utf8))
        #expect(EFacturaInvoiceParser.resolvedPartyCUI(parsed.customer) == "49296198")
        #expect(parsed.customer.name == "Client Test SRL")
    }

    @Test func parsesBuyerCUIFromPartyIdentification() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
                 xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
                 xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
            <cbc:ID>FAC-200</cbc:ID>
            <cbc:IssueDate>2026-07-06</cbc:IssueDate>
            <cbc:DocumentCurrencyCode>RON</cbc:DocumentCurrencyCode>
            <cac:AccountingSupplierParty>
                <cac:Party>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>Furnizor Test SRL</cbc:RegistrationName>
                        <cbc:CompanyID>RO11111111</cbc:CompanyID>
                    </cac:PartyLegalEntity>
                    <cac:PartyTaxScheme>
                        <cbc:CompanyID>RO11111111</cbc:CompanyID>
                    </cac:PartyTaxScheme>
                </cac:Party>
            </cac:AccountingSupplierParty>
            <cac:AccountingCustomerParty>
                <cac:Party>
                    <cac:PartyIdentification>
                        <cbc:ID schemeID="RO:CUI">49296198</cbc:ID>
                    </cac:PartyIdentification>
                    <cac:PartyName>
                        <cbc:Name>Client Test SRL</cbc:Name>
                    </cac:PartyName>
                </cac:Party>
            </cac:AccountingCustomerParty>
            <cac:LegalMonetaryTotal>
                <cbc:TaxInclusiveAmount>250.00</cbc:TaxInclusiveAmount>
            </cac:LegalMonetaryTotal>
            <cac:InvoiceLine>
                <cbc:ID>1</cbc:ID>
                <cbc:InvoicedQuantity unitCode="H87">1</cbc:InvoicedQuantity>
                <cac:Item>
                    <cbc:Name>Produs test</cbc:Name>
                </cac:Item>
                <cac:Price>
                    <cbc:PriceAmount>250.00</cbc:PriceAmount>
                </cac:Price>
            </cac:InvoiceLine>
        </Invoice>
        """

        let parsed = try EFacturaInvoiceParser.parse(data: Data(xml.utf8))
        #expect(EFacturaInvoiceParser.resolvedPartyCUI(parsed.customer) == "49296198")
        #expect(parsed.customer.name == "Client Test SRL")
    }

    @Test func prefersPartyTaxSchemeCUIOverEmailEndpointAndTradeRegister() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
                 xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
                 xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
            <cbc:ID>NSC nr. 16420</cbc:ID>
            <cbc:IssueDate>2026-06-03</cbc:IssueDate>
            <cbc:DocumentCurrencyCode>RON</cbc:DocumentCurrencyCode>
            <cac:AccountingSupplierParty>
                <cac:Party>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>NIDO SMART CONSULTING S.R.L.</cbc:RegistrationName>
                    </cac:PartyLegalEntity>
                    <cac:PartyTaxScheme>
                        <cbc:CompanyID>RO38748468</cbc:CompanyID>
                    </cac:PartyTaxScheme>
                </cac:Party>
            </cac:AccountingSupplierParty>
            <cac:AccountingCustomerParty>
                <cac:Party>
                    <cbc:EndpointID schemeID="EM">maria.serban1@gmail.com</cbc:EndpointID>
                    <cac:PartyIdentification>
                        <cbc:ID>J40/23557/2022</cbc:ID>
                    </cac:PartyIdentification>
                    <cac:PartyTaxScheme>
                        <cbc:CompanyID>RO47240786</cbc:CompanyID>
                        <cac:TaxScheme/>
                    </cac:PartyTaxScheme>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>BUNATATI LA MARIA SRL</cbc:RegistrationName>
                    </cac:PartyLegalEntity>
                </cac:Party>
            </cac:AccountingCustomerParty>
            <cac:LegalMonetaryTotal>
                <cbc:TaxInclusiveAmount>145.20</cbc:TaxInclusiveAmount>
            </cac:LegalMonetaryTotal>
            <cac:InvoiceLine>
                <cbc:ID>1</cbc:ID>
                <cbc:InvoicedQuantity unitCode="H87">1</cbc:InvoicedQuantity>
                <cac:Item>
                    <cbc:Name>Servicii test</cbc:Name>
                </cac:Item>
                <cac:Price>
                    <cbc:PriceAmount>145.20</cbc:PriceAmount>
                </cac:Price>
            </cac:InvoiceLine>
        </Invoice>
        """

        let parsed = try EFacturaInvoiceParser.parse(data: Data(xml.utf8))
        #expect(EFacturaInvoiceParser.resolvedPartyCUI(parsed.customer) == "47240786")
        #expect(parsed.customer.email == "maria.serban1@gmail.com")
        #expect(parsed.customer.nrRegCom == "J40/23557/2022")
        #expect(parsed.customer.name == "BUNATATI LA MARIA SRL")
    }

    @Test func normalizesDuplicateInvoiceLineNumbers() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
                 xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
                 xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
            <cbc:ID>CMX260000004147</cbc:ID>
            <cbc:IssueDate>2026-07-16</cbc:IssueDate>
            <cbc:DocumentCurrencyCode>RON</cbc:DocumentCurrencyCode>
            <cac:AccountingSupplierParty>
                <cac:Party>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>Furnizor Test SRL</cbc:RegistrationName>
                        <cbc:CompanyID>RO11111111</cbc:CompanyID>
                    </cac:PartyLegalEntity>
                </cac:Party>
            </cac:AccountingSupplierParty>
            <cac:AccountingCustomerParty>
                <cac:Party>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>Client Test SRL</cbc:RegistrationName>
                        <cbc:CompanyID>49296198</cbc:CompanyID>
                    </cac:PartyLegalEntity>
                </cac:Party>
            </cac:AccountingCustomerParty>
            <cac:LegalMonetaryTotal>
                <cbc:TaxInclusiveAmount>300.00</cbc:TaxInclusiveAmount>
            </cac:LegalMonetaryTotal>
            <cac:InvoiceLine>
                <cbc:ID>1</cbc:ID>
                <cbc:InvoicedQuantity unitCode="H87">1</cbc:InvoicedQuantity>
                <cac:Item><cbc:Name>Produs 1</cbc:Name></cac:Item>
                <cac:Price><cbc:PriceAmount>100.00</cbc:PriceAmount></cac:Price>
            </cac:InvoiceLine>
            <cac:InvoiceLine>
                <cbc:ID>1</cbc:ID>
                <cbc:InvoicedQuantity unitCode="H87">1</cbc:InvoicedQuantity>
                <cac:Item><cbc:Name>Produs 2</cbc:Name></cac:Item>
                <cac:Price><cbc:PriceAmount>100.00</cbc:PriceAmount></cac:Price>
            </cac:InvoiceLine>
            <cac:InvoiceLine>
                <cbc:ID>3</cbc:ID>
                <cbc:InvoicedQuantity unitCode="H87">1</cbc:InvoicedQuantity>
                <cac:Item><cbc:Name>Produs 3</cbc:Name></cac:Item>
                <cac:Price><cbc:PriceAmount>100.00</cbc:PriceAmount></cac:Price>
            </cac:InvoiceLine>
        </Invoice>
        """

        let parsed = try EFacturaInvoiceParser.parse(data: Data(xml.utf8))
        #expect(parsed.lines.count == 3)
        #expect(parsed.lines.map(\.lineNumber) == [1, 2, 3])
    }

    @Test func detectsCreditNoteRootElement() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <CreditNote xmlns="urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2">
            <cbc:ID>1600443823</cbc:ID>
        </CreditNote>
        """

        let data = Data(xml.utf8)
        #expect(EFacturaInvoiceParser.isCreditNote(data: data))
        #expect(EFacturaInvoiceParser.documentRootElement(in: data) == "CreditNote")
    }

    @Test func parsesCreditNoteWithNegativeAmounts() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <CreditNote xmlns="urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2"
                    xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
                    xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
            <cbc:ID>1600443823</cbc:ID>
            <cbc:IssueDate>2026-07-27</cbc:IssueDate>
            <cbc:CreditNoteTypeCode>381</cbc:CreditNoteTypeCode>
            <cbc:DocumentCurrencyCode>RON</cbc:DocumentCurrencyCode>
            <cac:AccountingSupplierParty>
                <cac:Party>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>QUADRANT - AMROQ BEVERAGES SRL</cbc:RegistrationName>
                        <cbc:CompanyID>RO6811508</cbc:CompanyID>
                    </cac:PartyLegalEntity>
                    <cac:PartyTaxScheme>
                        <cbc:CompanyID>RO6811508</cbc:CompanyID>
                    </cac:PartyTaxScheme>
                </cac:Party>
            </cac:AccountingSupplierParty>
            <cac:AccountingCustomerParty>
                <cac:Party>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>NECTARIE 20XXV S.R.L.</cbc:RegistrationName>
                        <cbc:CompanyID>RO51159591</cbc:CompanyID>
                    </cac:PartyLegalEntity>
                    <cac:PartyTaxScheme>
                        <cbc:CompanyID>RO51159591</cbc:CompanyID>
                    </cac:PartyTaxScheme>
                </cac:Party>
            </cac:AccountingCustomerParty>
            <cac:TaxTotal>
                <cbc:TaxAmount currencyID="RON">1222.31</cbc:TaxAmount>
            </cac:TaxTotal>
            <cac:LegalMonetaryTotal>
                <cbc:TaxInclusiveAmount currencyID="RON">7042.83</cbc:TaxInclusiveAmount>
            </cac:LegalMonetaryTotal>
            <cac:CreditNoteLine>
                <cbc:ID>1</cbc:ID>
                <cbc:CreditedQuantity unitCode="H87">1.00</cbc:CreditedQuantity>
                <cbc:LineExtensionAmount currencyID="RON">5820.52</cbc:LineExtensionAmount>
                <cac:Item>
                    <cbc:Name>Red Com Jun 2026</cbc:Name>
                    <cac:ClassifiedTaxCategory>
                        <cbc:Percent>21.00</cbc:Percent>
                    </cac:ClassifiedTaxCategory>
                </cac:Item>
                <cac:Price>
                    <cbc:PriceAmount currencyID="RON">5820.5200</cbc:PriceAmount>
                </cac:Price>
            </cac:CreditNoteLine>
        </CreditNote>
        """

        let parsed = try EFacturaInvoiceParser.parse(data: Data(xml.utf8))
        #expect(parsed.isCreditNote)
        #expect(parsed.invoiceNumber == "1600443823")
        #expect(parsed.taxInclusiveAmount == -7042.83)
        #expect(parsed.taxAmount == -1222.31)
        #expect(parsed.lines.count == 1)
        #expect(parsed.lines[0].lineTotal == -5820.52)
        #expect(parsed.lines[0].quantity == 1)
    }

    @Test func preservesIssueDateFromXMLWithoutTimezoneShift() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
                 xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
                 xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
            <cbc:ID>FAC-DATE</cbc:ID>
            <cbc:IssueDate>2026-07-25</cbc:IssueDate>
            <cbc:DocumentCurrencyCode>RON</cbc:DocumentCurrencyCode>
            <cac:AccountingSupplierParty>
                <cac:Party>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>Furnizor Test SRL</cbc:RegistrationName>
                        <cbc:CompanyID>RO11111111</cbc:CompanyID>
                    </cac:PartyLegalEntity>
                </cac:Party>
            </cac:AccountingSupplierParty>
            <cac:AccountingCustomerParty>
                <cac:Party>
                    <cac:PartyLegalEntity>
                        <cbc:RegistrationName>Client Test SRL</cbc:RegistrationName>
                        <cbc:CompanyID>49296198</cbc:CompanyID>
                    </cac:PartyLegalEntity>
                </cac:Party>
            </cac:AccountingCustomerParty>
            <cac:LegalMonetaryTotal>
                <cbc:TaxInclusiveAmount>100.00</cbc:TaxInclusiveAmount>
            </cac:LegalMonetaryTotal>
            <cac:InvoiceLine>
                <cbc:ID>1</cbc:ID>
                <cbc:InvoicedQuantity unitCode="H87">1</cbc:InvoicedQuantity>
                <cac:Item>
                    <cbc:Name>Produs test</cbc:Name>
                </cac:Item>
                <cac:Price>
                    <cbc:PriceAmount>100.00</cbc:PriceAmount>
                </cac:Price>
            </cac:InvoiceLine>
        </Invoice>
        """

        let parsed = try EFacturaInvoiceParser.parse(data: Data(xml.utf8))
        let issueDate = try #require(parsed.issueDate)

        let stored = DateFormatter()
        stored.calendar = Calendar(identifier: .gregorian)
        stored.locale = Locale(identifier: "en_US_POSIX")
        stored.timeZone = TimeZone(secondsFromGMT: 0)
        stored.dateFormat = "yyyy-MM-dd"
        #expect(stored.string(from: issueDate) == "2026-07-25")
        #expect(SupplierFormatting.date(issueDate) == "25/07/2026")
    }
}
