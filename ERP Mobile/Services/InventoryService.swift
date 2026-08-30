import Foundation
import Supabase

enum InventoryService {
    private static let client = SupabaseManager.client

    static func fetchStockRows(companyId: UUID) async throws -> [ProductStockRow] {
        try await client
            .from("product_stocks")
            .select("company_id, product_id, cantitate, updated_at, product:products(id, denumire, cod, cod_bare, unitate_masura, tip)")
            .eq("company_id", value: companyId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    static func fetchMovements(companyId: UUID, limit: Int = 200) async throws -> [StockMovementRow] {
        try await client
            .from("stock_movements")
            .select("id, company_id, product_id, tip, cantitate, unitate_masura, sursa, referinta, data_tranzactie, created_at, product:products(denumire, cod, cod_bare)")
            .eq("company_id", value: companyId.uuidString)
            .order("data_tranzactie", ascending: false)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func fetchProductMovements(companyId: UUID, productId: UUID) async throws -> [StockMovementDetailRow] {
        try await client
            .from("stock_movements")
            .select("""
                id, company_id, product_id, tip, cantitate, unitate_masura, sursa, referinta, data_tranzactie, created_at, invoice_id, invoice_line_id, pret_unitar,
                invoice:supplier_invoices(numar_factura, data_factura),
                invoice_line:supplier_invoice_lines(pret_unitar, suma_linie, suma_tva, cota_tva)
                """)
            .eq("company_id", value: companyId.uuidString)
            .eq("product_id", value: productId.uuidString)
            .order("data_tranzactie", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func fetchProductMovements(companyId: UUID, productIds: [UUID]) async throws -> [StockMovementDetailRow] {
        let uniqueIds = Array(Set(productIds))
        guard !uniqueIds.isEmpty else { return [] }

        var all: [StockMovementDetailRow] = []
        for chunk in stride(from: 0, to: uniqueIds.count, by: 80) {
            let slice = uniqueIds[chunk..<min(chunk + 80, uniqueIds.count)]
            let rows: [StockMovementDetailRow] = try await client
                .from("stock_movements")
                .select("""
                    id, company_id, product_id, tip, cantitate, unitate_masura, sursa, referinta, data_tranzactie, created_at, invoice_id, invoice_line_id, pret_unitar,
                    invoice:supplier_invoices(numar_factura, data_factura),
                    invoice_line:supplier_invoice_lines(pret_unitar, suma_linie, suma_tva, cota_tva)
                    """)
                .eq("company_id", value: companyId.uuidString)
                .in("product_id", values: slice.map(\.uuidString))
                .order("data_tranzactie", ascending: true)
                .order("created_at", ascending: true)
                .execute()
                .value
            all.append(contentsOf: rows)
        }
        return all
    }
}
