import SwiftUI

struct ModuleDestinationView: View {
    let module: AppModule

    var body: some View {
        switch module.code {
        case ModuleCode.nomenclatoare:
            NomenclatoareView(module: module)
        case ModuleCode.supplierInvoicesPayments:
            SupplierInvoicesPaymentsView(module: module)
        case ModuleCode.clientInvoicesPayments:
            ClientsModuleView(module: module)
        case ModuleCode.cashRegister:
            CashRegisterModuleView(module: module)
        case ModuleCode.bankStatement:
            ModulePlaceholderView(module: module)
        case ModuleCode.inventory:
            InventoryView(module: module)
        case ModuleCode.stockSheet:
            StockSheetModuleView(module: module)
        case ModuleCode.products:
            ProductsView(module: module)
        default:
            ModulePlaceholderView(module: module)
        }
    }
}
