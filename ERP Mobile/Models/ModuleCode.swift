import Foundation

enum ModuleCode {
    static let nomenclatoare = "nomenclatoare"
    static let supplierInvoicesPayments = "supplier_invoices_payments"
    static let clientInvoicesPayments = "client_invoices_payments"
    static let cashRegister = "cash_register"
    static let bankStatement = "bank_statement"
    static let inventory = "inventory"
    static let stockSheet = "stock_sheet"
    static let products = "products"

    static let dashboardHiddenCodes: Set<String> = [products]
    static let adminOnlyCodes: Set<String> = [nomenclatoare]
}
