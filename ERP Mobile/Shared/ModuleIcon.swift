import Foundation

enum ModuleIcon {
    static func systemName(for code: String) -> String {
        switch code {
        case ModuleCode.nomenclatoare:
            return "tray.full.fill"
        case ModuleCode.supplierInvoicesPayments:
            return "doc.text.fill"
        case ModuleCode.clientInvoicesPayments:
            return "person.2.fill"
        case ModuleCode.cashRegister:
            return "banknote.fill"
        case ModuleCode.bankStatement:
            return "building.columns.fill"
        case ModuleCode.inventory:
            return "shippingbox.fill"
        case ModuleCode.stockSheet:
            return "list.bullet.rectangle.fill"
        case ModuleCode.hr:
            return "person.3.sequence.fill"
        case ModuleCode.products:
            return "books.vertical.fill"
        default:
            return "square.grid.2x2.fill"
        }
    }
}
