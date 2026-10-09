import Foundation

enum SyncOperationExecutor {
    static func execute(_ item: SyncOutboxItem) async throws {
        try await OfflineWriteContext.$isSyncDrain.withValue(true) {
            try await executeDraining(item)
        }
    }

    private static func executeDraining(_ item: SyncOutboxItem) async throws {
        let companyId = item.companyId
        let data = item.payloadJSON
        let decoder = OfflineFileStore.jsonDecoder

        switch item.operationType {
        case .cashRegisterUpsert:
            let p = try decoder.decode(SyncPayloads.CashRegisterUpsert.self, from: data)
            _ = try await CashRegisterEntryService.insert(p.entry, companyId: p.companyId)

        case .cashRegisterDelete:
            let p = try decoder.decode(SyncPayloads.CashRegisterDelete.self, from: data)
            try await CashRegisterEntryService.delete(id: p.id, companyId: p.companyId)

        case .supplierInvoiceCreate:
            let p = try decoder.decode(SyncPayloads.SupplierInvoiceCreate.self, from: data)
            let created = try await SupplierService.createInvoice(
                companyId: p.companyId,
                supplierId: p.supplierId,
                numarFactura: p.numarFactura,
                dataFactura: p.dataFactura,
                dataScadenta: p.dataScadenta,
                sumaTotala: p.sumaTotala,
                sumaTva: p.sumaTva,
                moneda: p.moneda,
                status: p.status,
                observatii: p.observatii,
                workLocationId: p.workLocationId,
                warehouseId: p.warehouseId,
                createdBy: p.createdBy
            )
            if created.id != p.id {
                LocalDocumentStore.remap(localId: p.id, to: created.id, companyId: companyId)
            }

        case .supplierInvoiceUpdate:
            let p = try decoder.decode(SyncPayloads.SupplierInvoiceUpdate.self, from: data)
            let id = LocalDocumentStore.resolvedId(p.id, companyId: companyId)
            _ = try await SupplierService.updateInvoice(
                id: id,
                supplierId: p.supplierId,
                numarFactura: p.numarFactura,
                dataFactura: p.dataFactura,
                dataScadenta: p.dataScadenta,
                sumaTotala: p.sumaTotala,
                sumaTva: p.sumaTva,
                moneda: p.moneda,
                status: p.status,
                observatii: p.observatii,
                workLocationId: p.workLocationId,
                warehouseId: p.warehouseId
            )

        case .supplierInvoiceDelete:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await SupplierService.deleteInvoice(id: LocalDocumentStore.resolvedId(p.id, companyId: companyId))

        case .supplierInvoiceLinesReplace:
            let p = try decoder.decode(SyncPayloads.SupplierInvoiceLinesReplace.self, from: data)
            let invoiceId = LocalDocumentStore.resolvedId(p.invoiceId, companyId: companyId)
            let inputs = p.lines.map {
                SupplierService.InvoiceLineCreateInput(
                    productId: $0.productId ?? UUID(),
                    numarLinie: $0.numarLinie,
                    denumire: $0.denumire,
                    cantitate: $0.cantitate,
                    pretUnitar: $0.pretUnitar,
                    sumaLinie: $0.sumaLinie,
                    sumaTva: $0.sumaTva,
                    cotaTva: $0.cotaTva,
                    unitateMasura: $0.unitateMasura ?? "buc",
                    needsProductReview: $0.needsProductReview
                )
            }
            try await SupplierService.replaceInvoiceLines(
                companyId: p.companyId,
                invoiceId: invoiceId,
                lines: inputs
            )

        case .supplierPaymentCreate:
            let p = try decoder.decode(SyncPayloads.SupplierPaymentCreate.self, from: data)
            let invoiceId = p.invoiceId.map { LocalDocumentStore.resolvedId($0, companyId: companyId) }
            let created = try await SupplierService.createPayment(
                companyId: p.companyId,
                supplierId: p.supplierId,
                invoiceId: invoiceId,
                dataPlata: p.dataPlata,
                suma: p.suma,
                metodaPlata: p.metodaPlata,
                referinta: p.referinta,
                observatii: p.observatii,
                createdBy: p.createdBy
            )
            if created.id != p.id {
                LocalDocumentStore.remap(localId: p.id, to: created.id, companyId: companyId)
            }

        case .supplierPaymentUpdate:
            let p = try decoder.decode(SyncPayloads.SupplierPaymentUpdate.self, from: data)
            _ = try await SupplierService.updatePayment(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId),
                supplierId: p.supplierId,
                invoiceId: p.invoiceId.map { LocalDocumentStore.resolvedId($0, companyId: companyId) },
                dataPlata: p.dataPlata,
                suma: p.suma,
                metodaPlata: p.metodaPlata,
                referinta: p.referinta,
                observatii: p.observatii
            )

        case .supplierPaymentDelete:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await SupplierService.deletePayment(id: LocalDocumentStore.resolvedId(p.id, companyId: companyId))

        case .supplierReceptionClosed:
            let p = try decoder.decode(SyncPayloads.ReceptionClosed.self, from: data)
            try await SupplierService.setReceptionClosed(
                invoiceId: LocalDocumentStore.resolvedId(p.invoiceId, companyId: companyId),
                closed: p.closed
            )

        case .supplierCreditOffsetsReplace:
            let p = try decoder.decode(SyncPayloads.CreditOffsetsReplace.self, from: data)
            let creditId = LocalDocumentStore.resolvedId(p.creditNoteInvoiceId, companyId: companyId)
            let credit = try await SupplierService.fetchInvoice(id: creditId)
            let lines = p.offsets.map { offset in
                PaymentAllocationLine(
                    invoiceId: LocalDocumentStore.resolvedId(offset.targetInvoiceId, companyId: companyId),
                    numarFactura: "",
                    amount: offset.amount
                )
            }
            let plan = PaymentAllocationPlan(invoiceLines: lines, advanceAmount: 0)
            try await SupplierService.replaceCreditNoteOffsets(
                companyId: p.companyId,
                creditInvoice: credit,
                plan: plan
            )

        case .supplierNIRSave:
            try await executeNIRSave(data: data, companyId: companyId)

        case .supplierNIRDelete:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await SupplierNIRService.deleteNIR(id: LocalDocumentStore.resolvedId(p.id, companyId: companyId))

        case .stockTransferPost:
            let p = try decoder.decode(SyncPayloads.StockTransferPost.self, from: data)
            let remoteId = try await StockTransferService.postTransfer(
                companyId: p.companyId,
                dataBon: p.dataBon,
                sourceWarehouseId: p.sourceWarehouseId,
                destinationWarehouseId: p.destinationWarehouseId,
                observatii: p.observatii,
                lines: p.lines.map { ($0.productId, $0.quantity) }
            )
            if remoteId != p.localId {
                LocalDocumentStore.remap(localId: p.localId, to: remoteId, companyId: companyId)
            }

        case .stockTransferUpdate:
            let p = try decoder.decode(SyncPayloads.StockTransferUpdate.self, from: data)
            try await StockTransferService.updateTransfer(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId),
                dataBon: p.dataBon,
                sourceWarehouseId: p.sourceWarehouseId,
                destinationWarehouseId: p.destinationWarehouseId,
                observatii: p.observatii,
                lines: p.lines.map { ($0.productId, $0.quantity) }
            )

        case .stockTransferDelete:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await StockTransferService.deleteTransfer(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId)
            )

        case .physicalInventoryCreate:
            let p = try decoder.decode(SyncPayloads.PhysicalInventoryCreate.self, from: data)
            let created = try await PhysicalInventoryService.createInventory(
                companyId: p.companyId,
                dataInventar: p.dataInventar,
                observatii: p.observatii,
                createdBy: p.createdBy,
                warehouseId: p.warehouseId,
                populateFromStock: p.populateFromStock
            )
            if created.id != p.id {
                LocalDocumentStore.remap(localId: p.id, to: created.id, companyId: companyId)
            }

        case .physicalInventoryUpsertLine:
            let p = try decoder.decode(SyncPayloads.PhysicalInventoryUpsertLine.self, from: data)
            _ = try await PhysicalInventoryService.upsertLine(
                inventoryId: LocalDocumentStore.resolvedId(p.inventoryId, companyId: companyId),
                productId: p.productId,
                cantitateNumarata: p.cantitateNumarata,
                observatii: p.observatii
            )

        case .physicalInventoryFinalize:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await PhysicalInventoryService.finalize(
                inventoryId: LocalDocumentStore.resolvedId(p.id, companyId: companyId)
            )

        case .physicalInventoryDelete:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await PhysicalInventoryService.deleteInventory(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId)
            )

        case .physicalInventoryDeleteLine:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await PhysicalInventoryService.deleteLine(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId)
            )

        case .clientInvoiceCreate:
            let p = try decoder.decode(SyncPayloads.ClientInvoiceCreate.self, from: data)
            let created = try await ClientService.createInvoice(
                companyId: p.companyId,
                clientId: p.clientId,
                numarFactura: p.numarFactura,
                dataFactura: p.dataFactura,
                dataScadenta: p.dataScadenta,
                sumaTotala: p.sumaTotala,
                sumaTva: p.sumaTva,
                moneda: p.moneda,
                status: p.status,
                observatii: p.observatii,
                createdBy: p.createdBy
            )
            if created.id != p.id {
                LocalDocumentStore.remap(localId: p.id, to: created.id, companyId: companyId)
            }

        case .clientInvoiceUpdate:
            let p = try decoder.decode(SyncPayloads.ClientInvoiceUpdate.self, from: data)
            _ = try await ClientService.updateInvoice(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId),
                clientId: p.clientId,
                numarFactura: p.numarFactura,
                dataFactura: p.dataFactura,
                dataScadenta: p.dataScadenta,
                sumaTotala: p.sumaTotala,
                sumaTva: p.sumaTva,
                moneda: p.moneda,
                status: p.status,
                observatii: p.observatii
            )

        case .clientInvoiceDelete:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await ClientService.deleteInvoice(id: LocalDocumentStore.resolvedId(p.id, companyId: companyId))

        case .clientPaymentCreate:
            let p = try decoder.decode(SyncPayloads.ClientPaymentCreate.self, from: data)
            let created = try await ClientService.createPayment(
                companyId: p.companyId,
                clientId: p.clientId,
                invoiceId: p.invoiceId.map { LocalDocumentStore.resolvedId($0, companyId: companyId) },
                dataPlata: p.dataPlata,
                suma: p.suma,
                metodaPlata: p.metodaPlata,
                referinta: p.referinta,
                observatii: p.observatii,
                createdBy: p.createdBy
            )
            if created.id != p.id {
                LocalDocumentStore.remap(localId: p.id, to: created.id, companyId: companyId)
            }

        case .clientPaymentUpdate:
            let p = try decoder.decode(SyncPayloads.ClientPaymentUpdate.self, from: data)
            _ = try await ClientService.updatePayment(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId),
                clientId: p.clientId,
                invoiceId: p.invoiceId.map { LocalDocumentStore.resolvedId($0, companyId: companyId) },
                dataPlata: p.dataPlata,
                suma: p.suma,
                metodaPlata: p.metodaPlata,
                referinta: p.referinta,
                observatii: p.observatii
            )

        case .clientPaymentDelete:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await ClientService.deletePayment(id: LocalDocumentStore.resolvedId(p.id, companyId: companyId))

        case .zReportUpsertBatch:
            let p = try decoder.decode(SyncPayloads.ZReportUpsertBatch.self, from: data)
            let reports = p.reports.map { $0.asZReportData }
            _ = try await ClientZReportService.upsertReports(companyId: p.companyId, reports: reports)

        case .zReportDelete:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await ClientZReportService.deleteReport(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId),
                companyId: companyId
            )

        case .cmGroupCreate:
            let p = try decoder.decode(SyncPayloads.CMGroupCreate.self, from: data)
            let created = try await CMProductGroupService.createGroup(companyId: p.companyId, name: p.name)
            if created.id != p.id {
                LocalDocumentStore.remap(localId: p.id, to: created.id, companyId: companyId)
            }

        case .cmGroupRename:
            let p = try decoder.decode(SyncPayloads.CMGroupRename.self, from: data)
            _ = try await CMProductGroupService.renameGroup(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId),
                name: p.name
            )

        case .cmGroupDelete:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await CMProductGroupService.deleteGroup(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId)
            )

        case .cmSetProductGroups:
            let p = try decoder.decode(SyncPayloads.CMSetProductGroups.self, from: data)
            try await CMProductGroupService.setProductGroups(
                companyId: p.companyId,
                productId: p.productId,
                groupIds: p.groupIds.map { LocalDocumentStore.resolvedId($0, companyId: companyId) }
            )

        case .cmMenuCreate:
            let p = try decoder.decode(SyncPayloads.CMMenuCreate.self, from: data)
            let created = try await CMProductGroupService.createMenu(
                companyId: p.companyId,
                name: p.name,
                pretVanzare: p.pretVanzare,
                productIds: p.productIds,
                permiteSecundareMultiple: p.permiteSecundareMultiple
            )
            if created.id != p.id {
                LocalDocumentStore.remap(localId: p.id, to: created.id, companyId: companyId)
            }

        case .cmMenuUpdate:
            let p = try decoder.decode(SyncPayloads.CMMenuUpdate.self, from: data)
            _ = try await CMProductGroupService.updateMenu(
                menuId: LocalDocumentStore.resolvedId(p.id, companyId: companyId),
                companyId: p.companyId,
                name: p.name,
                pretVanzare: p.pretVanzare,
                isActive: p.isActive,
                productIds: p.productIds,
                permiteSecundareMultiple: p.permiteSecundareMultiple
            )

        case .cmMenuDelete:
            let p = try decoder.decode(SyncPayloads.UUIDPayload.self, from: data)
            try await CMProductGroupService.deleteMenu(
                id: LocalDocumentStore.resolvedId(p.id, companyId: companyId)
            )
        }
    }

    private static func executeNIRSave(data: Data, companyId: UUID) async throws {
        let p = try OfflineFileStore.jsonDecoder.decode(SyncPayloads.SupplierNIRSave.self, from: data)
        let invoiceId = LocalDocumentStore.resolvedId(p.invoiceId, companyId: companyId)
        let productsById = Dictionary(uniqueKeysWithValues: p.products.map { ($0.id, $0) })
        var conversions: [UUID: StockUnitConversion.Reception] = [:]
        for conversion in p.conversions {
            conversions[conversion.invoiceLineId] = conversion.asReception
        }

        if p.isUpdate {
            let nirId = LocalDocumentStore.resolvedId(p.nirId, companyId: companyId)
            try await SupplierNIRService.replaceNIRLines(
                nirId: nirId,
                companyId: p.companyId,
                invoiceLines: p.invoiceLines,
                productsById: productsById,
                conversions: conversions,
                workLocationId: p.workLocationId,
                warehouseId: p.warehouseId,
                updateReceptionBeforeInsert: true
            )
        } else {
            let nir = try await SupplierNIRService.createNIR(
                companyId: p.companyId,
                invoiceId: invoiceId,
                dataNir: p.dataNir,
                workLocationId: p.workLocationId,
                warehouseId: p.warehouseId,
                createdBy: p.createdBy
            )
            if nir.id != p.nirId {
                LocalDocumentStore.remap(localId: p.nirId, to: nir.id, companyId: companyId)
            }
            try await SupplierNIRService.replaceNIRLines(
                nirId: nir.id,
                companyId: p.companyId,
                invoiceLines: p.invoiceLines,
                productsById: productsById,
                conversions: conversions
            )
        }
    }
}

extension SyncPayloads.ZReportOfflineDTO {
    var asZReportData: ZReportData {
        var report = ZReportData()
        report.id = id
        report.zNumber = zNumber
        report.date = date
        report.totalVanzari = totalVanzari
        report.numerar = numerar
        report.card = card
        report.plataModerna = plataModerna
        report.vanzari21 = vanzari21
        report.tva21 = tva21
        report.vanzari11 = vanzari11
        report.tva11 = tva11
        report.vanzari11C = vanzari11C
        report.tva11C = tva11C
        report.vanzari0 = vanzari0
        report.firma = firma
        report.cui = cui
        report.locatieLabel = locatieLabel
        report.sourceFileName = sourceFileName
        report.ocrText = ocrText
        return report
    }

    init(report: ZReportData) {
        id = report.id
        zNumber = report.zNumber
        date = report.date
        totalVanzari = report.totalVanzari
        numerar = report.numerar
        card = report.card
        plataModerna = report.plataModerna
        vanzari21 = report.vanzari21
        tva21 = report.tva21
        vanzari11 = report.vanzari11
        tva11 = report.tva11
        vanzari11C = report.vanzari11C
        tva11C = report.tva11C
        vanzari0 = report.vanzari0
        firma = report.firma
        cui = report.cui
        locatieLabel = report.locatieLabel
        sourceFileName = report.sourceFileName
        ocrText = report.ocrText
        importDedupKey = report.importDedupKey
    }
}
