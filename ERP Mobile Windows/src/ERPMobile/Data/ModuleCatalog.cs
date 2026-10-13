namespace ERPMobile.Data;

public sealed record ColumnSpec(string Field, string Header);

public sealed record ListSpec(
    string Title,
    string Table,
    string Order,
    bool CompanyScoped,
    bool AllowWrite,
    ColumnSpec[] Columns,
    string? ExtraFilter = null);

public static class ModuleCatalog
{
    public static IReadOnlyList<ListSpec> ForModule(string code) => code switch
    {
        "nomenclatoare" => Nomenclatoare,
        "supplier_invoices_payments" => Suppliers,
        "client_invoices_payments" => Clients,
        "sales" => Sales,
        "cash_register" => CashRegister,
        "inventory" => Inventory,
        "stock_sheet" => StockSheet,
        "hr" => Hr,
        "products" => Products,
        _ => Array.Empty<ListSpec>()
    };

    public static IReadOnlyList<ListSpec> Crm { get; } =
    [
        List("Lead-uri", "crm_leads", "created_at.desc", "title", "Titlu", "organization_name", "Organizație", "contact_name", "Contact", "stage", "Etapă", "estimated_value", "Valoare", "email", "Email") with { ExtraFilter = "pipeline_type=eq.lead" },
        List("Tranzacții", "crm_leads", "created_at.desc", "title", "Titlu", "organization_name", "Organizație", "stage", "Etapă", "estimated_value", "Valoare", "probability", "Probabilitate") with { ExtraFilter = "pipeline_type=eq.deal" },
        List("Contacte", "crm_contacts", "last_name.asc", "last_name", "Nume", "first_name", "Prenume", "email", "Email", "phone", "Telefon", "position", "Funcție"),
        List("Companii CRM", "crm_companies", "name.asc", "name", "Nume", "cui", "CUI", "email", "Email", "phone", "Telefon", "industry", "Industrie"),
        List("Oferte", "crm_quotes", "created_at.desc", "quote_number", "Număr", "title", "Titlu", "status", "Stare", "total_amount", "Total", "currency", "Monedă"),
        List("Activități", "crm_activities", "due_at.asc", "subject", "Subiect", "activity_type", "Tip", "due_at", "Scadență", "completed_at", "Finalizat"),
        List("Tichete", "crm_tickets", "created_at.desc", "ticket_number", "Număr", "subject", "Subiect", "status", "Stare", "priority", "Prioritate")
    ];

    private static IReadOnlyList<ListSpec> Nomenclatoare { get; } =
    [
        List("Puncte de lucru", "company_work_locations", "denumire.asc", "denumire", "Denumire", "city", "Oraș", "telefon", "Telefon", "is_active", "Activ"),
        List("Depozite", "company_warehouses", "denumire.asc", "cod", "Cod", "denumire", "Denumire", "warehouse_type", "Tip", "is_active", "Activ"),
        List("Grupe catalog", "cm_product_groups", "sort_order.asc", "name", "Nume", "kind", "Tip", "sort_order", "Ordine"),
        List("Produse", "products", "denumire.asc", "cod", "Cod", "denumire", "Denumire", "pret_vanzare", "In Store", "pret_vanzare_online", "On Line", "cantitate_minima", "Stoc minim", "cantitate_optima", "Stoc optim", "cod_bare", "Cod bare", "unitate_masura", "UM", "tip", "Categorie", "is_active", "Activ")
    ];

    private static IReadOnlyList<ListSpec> Suppliers { get; } =
    [
        List("Furnizori", "suppliers", "denumire.asc", "denumire", "Denumire", "cui", "CUI", "telefon", "Telefon", "email", "Email", "nr_zile_scadenta", "Zile scadență", "is_active", "Activ"),
        List("Facturi", "supplier_invoices", "data_factura.desc", "numar_factura", "Număr", "data_factura", "Data", "data_scadenta", "Scadență", "suma_totala", "Total", "suma_platita", "Plătit", "status", "Stare", "moneda", "Monedă"),
        List("NIR", "supplier_nirs", "data_nir.desc", "numar_nir", "Număr NIR", "data_nir", "Data"),
        List("Plăți", "supplier_payments", "data_plata.desc", "data_plata", "Data", "suma", "Sumă", "metoda_plata", "Metodă", "referinta", "Referință"),
        List("Scadențe", "supplier_invoices", "data_scadenta.asc", "numar_factura", "Număr", "data_factura", "Data", "data_scadenta", "Scadență", "suma_totala", "Total", "suma_platita", "Plătit", "status", "Stare") with { ExtraFilter = "status=neq.platita&status=neq.anulata" }
    ];

    private static IReadOnlyList<ListSpec> Clients { get; } =
    [
        List("Clienți", "clients", "denumire.asc", "denumire", "Denumire", "cui", "CUI", "telefon", "Telefon", "email", "Email", "nr_zile_scadenta", "Zile scadență", "is_active", "Activ"),
        List("Facturi", "client_invoices", "data_factura.desc", "numar_factura", "Număr", "data_factura", "Data", "data_scadenta", "Scadență", "suma_totala", "Total", "suma_platita", "Plătit", "status", "Stare", "moneda", "Monedă"),
        List("Plăți", "client_payments", "data_plata.desc", "data_plata", "Data", "suma", "Sumă", "metoda_plata", "Metodă", "referinta", "Referință"),
        List("Scadențe", "client_invoices", "data_scadenta.asc", "numar_factura", "Număr", "data_scadenta", "Scadență", "suma_totala", "Total", "suma_platita", "Plătit", "status", "Stare") with { ExtraFilter = "status=neq.platita&status=neq.anulata" },
        List("Bonuri Z", "company_z_reports", "report_date.desc", "z_number", "Nr. Z", "report_date", "Data", "total_vanzari", "Vânzări", "numerar", "Numerar", "card", "Card")
    ];

    private static IReadOnlyList<ListSpec> Sales { get; } =
    [
        List("Bonuri fiscale", "company_fiscal_sale_receipts", "sale_date.desc", "receipt_number", "Număr", "sale_date", "Data", "total_amount", "Total", "numerar", "Numerar", "card", "Card", "source", "Sursă"),
        List("Rapoarte Z", "company_z_reports", "report_date.desc", "z_number", "Nr. Z", "report_date", "Data", "total_vanzari", "Vânzări", "numerar", "Numerar", "card", "Card", "plata_moderna", "Plată modernă")
    ];

    private static IReadOnlyList<ListSpec> CashRegister { get; } =
    [
        List("Registru de casă", "company_cash_register_entries", "entry_date.desc", "entry_date", "Data", "document_number", "Document", "kind", "Tip", "explanation", "Explicație", "amount", "Sumă", "is_incasare", "Încasare")
    ];

    private static IReadOnlyList<ListSpec> Inventory { get; } =
    [
        ReadOnly("Stocuri", "product_stocks", "updated_at.desc", "product_id", "Produs", "cantitate", "Cantitate"),
        ReadOnly("Mișcări", "stock_movements", "created_at.desc", "tip", "Tip", "cantitate", "Cantitate", "unitate_masura", "UM", "sursa", "Sursă", "referinta", "Referință", "created_at", "Creat"),
        List("Inventar fizic", "physical_inventories", "data_inventar.desc", "numar_inventar", "Număr", "data_inventar", "Data", "status", "Stare")
    ];

    private static IReadOnlyList<ListSpec> StockSheet { get; } =
    [
        ReadOnly("Stoc curent", "product_stocks", "updated_at.desc", "product_id", "Produs", "cantitate", "Cantitate", "updated_at", "Actualizat"),
        ReadOnly("Mișcări", "stock_movements", "created_at.desc", "tip", "Tip", "cantitate", "Cantitate", "sursa", "Sursă", "referinta", "Referință", "created_at", "Creat")
    ];

    private static IReadOnlyList<ListSpec> Hr { get; } =
    [
        List("Angajați", "hr_employees", "full_name.asc", "employee_code", "Marcă", "full_name", "Nume", "cnp", "CNP", "phone", "Telefon", "is_active", "Activ"),
        List("Contracte", "hr_contracts", "start_date.desc", "job_title", "Funcție", "contract_type", "Tip", "start_date", "Început", "end_date", "Sfârșit", "gross_salary", "Brut"),
        List("State de plată", "hr_payroll_runs", "year.desc", "year", "An", "month", "Lună", "status", "Stare"),
        ReadOnly("Linii stat", "hr_payroll_lines", "created_at.desc", "gross_amount", "Brut", "net_amount", "Net", "cas_amount", "CAS", "tax_amount", "Impozit", "hours_worked", "Ore"),
        ReadOnly("Pontaj", "hr_timesheet_days", "work_date.desc", "work_date", "Data", "kind", "Tip", "hours", "Ore", "start_time", "Început", "end_time", "Sfârșit")
    ];

    private static IReadOnlyList<ListSpec> Products { get; } =
    [
        List("Produse", "products", "denumire.asc", "cod", "Cod", "denumire", "Denumire", "pret_vanzare", "In Store", "pret_vanzare_online", "On Line", "cantitate_minima", "Stoc minim", "cantitate_optima", "Stoc optim", "cod_bare", "Cod bare", "unitate_masura", "UM", "tip", "Categorie", "is_active", "Activ")
    ];

    private static ListSpec List(string title, string table, string order, params string[] pairs)
        => Build(title, table, order, allowWrite: true, extra: null, pairs);

    private static ListSpec ReadOnly(string title, string table, string order, params string[] pairs)
        => Build(title, table, order, allowWrite: false, extra: null, pairs);

    private static ListSpec Build(string title, string table, string order, bool allowWrite, string? extra, string[] pairs)
    {
        var columns = new ColumnSpec[pairs.Length / 2];
        for (var i = 0; i < columns.Length; i++)
            columns[i] = new ColumnSpec(pairs[i * 2], pairs[i * 2 + 1]);
        return new ListSpec(title, table, order, CompanyScoped: true, allowWrite, columns, extra);
    }
}
