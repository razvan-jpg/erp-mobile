import Foundation

enum OfflineOptimistic {
    static func supplierInvoice(
        id: UUID,
        supplierId: UUID,
        numarFactura: String,
        dataFactura: Date,
        dataScadenta: Date?,
        sumaTotala: Decimal,
        sumaTva: Decimal,
        moneda: String,
        status: InvoiceStatus,
        observatii: String?,
        workLocationId: UUID?,
        warehouseId: UUID?,
        createdBy: UUID?
    ) -> SupplierInvoice {
        SupplierInvoice(
            id: id,
            supplierId: supplierId,
            numarFactura: numarFactura,
            dataFactura: dataFactura,
            dataScadenta: dataScadenta,
            sumaTotala: sumaTotala,
            sumaTva: sumaTva,
            moneda: moneda,
            status: status,
            observatii: observatii,
            workLocationId: workLocationId,
            warehouseId: warehouseId,
            createdBy: createdBy,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static func supplierNIR(
        id: UUID,
        companyId: UUID,
        invoiceId: UUID,
        dataNir: Date,
        workLocationId: UUID?,
        warehouseId: UUID?,
        createdBy: UUID?
    ) -> SupplierNIR {
        SupplierNIR(
            id: id,
            companyId: companyId,
            invoiceId: invoiceId,
            numarNir: "LOCAL",
            dataNir: dataNir,
            workLocationId: workLocationId,
            warehouseId: warehouseId,
            createdBy: createdBy,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static func supplierPayment(
        id: UUID,
        supplierId: UUID,
        invoiceId: UUID?,
        dataPlata: Date,
        suma: Decimal,
        metodaPlata: PaymentMethod,
        referinta: String?,
        observatii: String?,
        createdBy: UUID?
    ) -> SupplierPayment {
        SupplierPayment(
            id: id,
            supplierId: supplierId,
            invoiceId: invoiceId,
            dataPlata: dataPlata,
            suma: suma,
            metodaPlata: metodaPlata,
            referinta: referinta,
            observatii: observatii,
            createdBy: createdBy,
            createdAt: Date()
        )
    }

    static func clientInvoice(
        id: UUID,
        clientId: UUID,
        numarFactura: String,
        dataFactura: Date,
        dataScadenta: Date?,
        sumaTotala: Decimal,
        sumaTva: Decimal,
        moneda: String,
        status: InvoiceStatus,
        observatii: String?,
        createdBy: UUID?
    ) -> ClientInvoice {
        ClientInvoice(
            id: id,
            clientId: clientId,
            numarFactura: numarFactura,
            dataFactura: dataFactura,
            dataScadenta: dataScadenta,
            sumaTotala: sumaTotala,
            sumaTva: sumaTva,
            sumaPlatita: 0,
            moneda: moneda,
            status: status,
            observatii: observatii,
            createdBy: createdBy,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static func clientPayment(
        id: UUID,
        clientId: UUID,
        invoiceId: UUID?,
        dataPlata: Date,
        suma: Decimal,
        metodaPlata: PaymentMethod,
        referinta: String?,
        observatii: String?,
        createdBy: UUID?
    ) -> ClientPayment {
        ClientPayment(
            id: id,
            clientId: clientId,
            invoiceId: invoiceId,
            dataPlata: dataPlata,
            suma: suma,
            metodaPlata: metodaPlata,
            referinta: referinta,
            observatii: observatii,
            createdBy: createdBy,
            createdAt: Date()
        )
    }

    static func physicalInventory(
        id: UUID,
        companyId: UUID,
        dataInventar: Date,
        observatii: String?,
        warehouseId: UUID?,
        numarInventar: String = "LOCAL"
    ) -> PhysicalInventory {
        PhysicalInventory(
            id: id,
            companyId: companyId,
            numarInventar: numarInventar,
            dataInventar: dataInventar,
            status: .open,
            observatii: observatii,
            warehouseId: warehouseId,
            createdAt: Date(),
            updatedAt: Date(),
            finalizedAt: nil
        )
    }

    static func cmGroup(id: UUID, companyId: UUID, name: String, sortOrder: Int) -> CMProductGroup {
        CMProductGroup(
            id: id,
            companyId: companyId,
            name: name,
            kind: .custom,
            isSystem: false,
            sortOrder: sortOrder,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static func cmMenu(
        id: UUID,
        companyId: UUID,
        name: String,
        pretVanzare: Decimal,
        pretVanzareOnline: Decimal? = nil,
        cod: String = "",
        permiteSecundareMultiple: Bool = false
    ) -> CMMenu {
        CMMenu(
            id: id,
            companyId: companyId,
            name: name,
            pretVanzare: pretVanzare,
            pretVanzareOnline: pretVanzareOnline,
            isActive: true,
            sortOrder: 0,
            cod: cod,
            permiteSecundareMultiple: permiteSecundareMultiple,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
