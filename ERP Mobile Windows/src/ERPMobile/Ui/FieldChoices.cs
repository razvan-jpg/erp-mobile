using System.Globalization;

namespace ERPMobile.Ui;

public sealed class FieldChoice
{
    public FieldChoice(string code, string label)
    {
        Code = code;
        Label = label;
    }

    public string Code { get; }
    public string Label { get; }
    public override string ToString() => Label;
}

public readonly record struct RelationSpec(string Table, string LabelField, string Caption);

public static class FieldChoices
{
    private static readonly string[] PreferredOrder =
    [
        "denumire", "name", "full_name", "last_name", "first_name", "title", "subject",
        "cod", "cod_bare", "employee_code", "tip", "unitate_masura", "unitate_achizitie",
        "factor_conversie", "cota_tva", "pret_vanzare", "status", "warehouse_type", "kind",
        "stage", "contract_type", "metoda_plata", "moneda", "currency", "priority", "category",
        "activity_type", "pipeline_type", "source"
    ];

    private static readonly Dictionary<string, string> Captions = new(StringComparer.Ordinal)
    {
        ["denumire"] = "Denumire",
        ["descriere"] = "Descriere",
        ["cod"] = "Cod",
        ["cod_bare"] = "Cod de bare",
        ["unitate_masura"] = "Unitate de măsură",
        ["unitate_achizitie"] = "UM achiziție",
        ["factor_conversie"] = "Factor conversie",
        ["cota_tva"] = "Cotă TVA",
        ["pret_vanzare"] = "Preț vânzare In Store",
        ["pret_vanzare_online"] = "Preț vânzare On Line",
        ["pret_achizitie"] = "Preț achiziție",
        ["is_active"] = "Activ",
        ["is_incasare"] = "Încasare",
        ["numar_factura"] = "Număr factură",
        ["data_factura"] = "Data factură",
        ["data_scadenta"] = "Data scadență",
        ["suma_totala"] = "Total",
        ["suma_platita"] = "Plătit",
        ["suma_tva"] = "TVA",
        ["moneda"] = "Monedă",
        ["currency"] = "Monedă",
        ["status"] = "Stare",
        ["observatii"] = "Observații",
        ["nr_zile_scadenta"] = "Zile scadență",
        ["telefon"] = "Telefon",
        ["phone"] = "Telefon",
        ["email"] = "Email",
        ["cui"] = "CUI",
        ["city"] = "Oraș",
        ["adresa"] = "Adresă",
        ["warehouse_type"] = "Tip depozit",
        ["kind"] = "Tip",
        ["stage"] = "Etapă",
        ["contract_type"] = "Tip contract",
        ["job_title"] = "Funcție",
        ["start_date"] = "Data început",
        ["end_date"] = "Data sfârșit",
        ["gross_salary"] = "Salariu brut",
        ["full_name"] = "Nume",
        ["employee_code"] = "Marcă",
        ["cnp"] = "CNP",
        ["iban"] = "IBAN",
        ["year"] = "An",
        ["month"] = "Lună",
        ["amount"] = "Sumă",
        ["explanation"] = "Explicație",
        ["document_number"] = "Document",
        ["entry_date"] = "Data",
        ["quote_number"] = "Număr ofertă",
        ["title"] = "Titlu",
        ["total_amount"] = "Total",
        ["subject"] = "Subiect",
        ["activity_type"] = "Tip activitate",
        ["due_at"] = "Scadență",
        ["priority"] = "Prioritate",
        ["category"] = "Categorie",
        ["ticket_number"] = "Număr tichet",
        ["organization_name"] = "Organizație",
        ["contact_name"] = "Contact",
        ["estimated_value"] = "Valoare",
        ["probability"] = "Probabilitate",
        ["source"] = "Sursă",
        ["pipeline_type"] = "Tip",
        ["name"] = "Nume",
        ["sort_order"] = "Ordine",
        ["numar_inventar"] = "Număr inventar",
        ["data_inventar"] = "Data inventar",
        ["metoda_plata"] = "Metodă de plată",
        ["referinta"] = "Referință",
        ["data_plata"] = "Data plății",
        ["suma"] = "Sumă",
        ["numar_nir"] = "Număr NIR",
        ["data_nir"] = "Data NIR",
        ["cpv"] = "CPV",
        ["first_name"] = "Prenume",
        ["last_name"] = "Nume",
        ["position"] = "Funcție",
        ["industry"] = "Industrie",
        ["cor_code"] = "COR",
        ["hours_per_day"] = "Ore / zi",
        ["receipt_number"] = "Număr bon",
        ["sale_date"] = "Data",
        ["z_number"] = "Nr. Z",
        ["report_date"] = "Data",
        ["total_vanzari"] = "Vânzări",
        ["numerar"] = "Numerar",
        ["card"] = "Card"
    };

    public static IReadOnlyList<string> Order(IEnumerable<string> keys)
    {
        var list = keys.ToList();
        var ordered = new List<string>();
        foreach (var key in PreferredOrder)
        {
            if (list.Contains(key))
                ordered.Add(key);
        }
        foreach (var key in list)
        {
            if (!ordered.Contains(key))
                ordered.Add(key);
        }
        return ordered;
    }

    public static string Caption(string table, string field)
    {
        if (Relation(field, out var relation))
            return relation.Caption;
        if (table == "products" && field == "tip")
            return "Categoria articolului";
        if (table == "stock_movements" && field == "tip")
            return "Tip mișcare";
        if (table == "company_cash_register_entries" && field == "kind")
            return "Tip operațiune";
        return Captions.TryGetValue(field, out var caption) ? caption : field.Replace('_', ' ');
    }

    public static bool Relation(string field, out RelationSpec spec)
    {
        switch (field)
        {
            case "supplier_id":
            case "partner_supplier_id":
                spec = new RelationSpec("suppliers", "denumire", "Furnizor");
                return true;
            case "client_id":
            case "partner_client_id":
                spec = new RelationSpec("clients", "denumire", "Client");
                return true;
            case "employee_id":
                spec = new RelationSpec("hr_employees", "full_name", "Angajat");
                return true;
            case "work_location_id":
            case "default_work_location_id":
                spec = new RelationSpec("company_work_locations", "denumire", "Punct de lucru");
                return true;
            case "warehouse_id":
                spec = new RelationSpec("company_warehouses", "denumire", "Depozit");
                return true;
            case "product_id":
                spec = new RelationSpec("products", "denumire", "Produs");
                return true;
            default:
                spec = default;
                return false;
        }
    }

    public static IReadOnlyList<FieldChoice>? Options(string table, string field)
    {
        if (table == "products" && field == "tip")
            return Pairs(
                "marfa", "Marfa",
                "materie_prima", "Materie prima",
                "produs_finit", "Produs finit",
                "ambalaj", "Ambalaj",
                "materiale_consumabile", "Materiale consumabile",
                "materiale_curatenie", "Materiale curatenie",
                "birotica", "Birotica",
                "servicii", "Servicii",
                "garantie", "Garantie",
                "obiect_inventar", "Obiect de inventar");
        if (field is "unitate_masura")
            return Pairs("Buc.", "Buc.", "Kg", "Kg", "Litru", "Litru");
        if (field is "unitate_achizitie")
            return Pairs("bax", "bax", "cutie", "cutie", "lada", "lada", "palet", "palet", "pachet", "pachet", "sac", "sac", "bidon", "bidon", "set", "set");
        if (field is "cota_tva")
            return Pairs("0", "0%", "11", "11%", "21", "21%");
        if (field is "status" && table is "supplier_invoices" or "client_invoices")
            return Pairs("neplatita", "Neplatita", "partial", "Partial", "platita", "Platita", "anulata", "Anulata");
        if (table == "company_warehouses" && field == "warehouse_type")
            return Pairs("en_detail", "En-detail", "en_gros", "En-gros", "productie", "Productie", "materii_prime", "Materii prime", "custodie", "Custodie", "vanzare", "Vanzare");
        if (table == "cm_product_groups" && field == "kind")
            return Pairs("custom", "Personalizata", "menus", "Meniuri", "ungrouped", "Negrupate");
        if (table == "stock_movements" && field == "tip")
            return Pairs("intrare", "Intrare", "iesire", "Ieșire");
        if (table == "company_cash_register_entries" && field == "kind")
            return Pairs(
                "incasare_client", "Chitanță încasare client",
                "plata_furnizor", "Chitanță plată furnizor",
                "ridicare_numerar_banca", "Ridicare numerar din bancă",
                "depunere_banca", "Depunere numerar în bancă",
                "incasare_diverse", "Încasare diverse",
                "plata_diverse", "Plată diverse");
        if (table == "hr_contracts" && field == "contract_type")
            return Pairs("cim", "CIM nedeterminat", "determined", "Durată determinată", "partTime", "Normă parțială");
        if (table == "hr_payroll_runs" && field == "status")
            return Pairs("draft", "Ciornă", "ready", "Pregătit", "closed", "Închis");
        if (table == "hr_timesheet_days" && field == "kind")
            return Pairs("work", "Lucru", "co", "CO", "cm", "CM", "rest", "Repaus");
        if (table == "physical_inventories" && field == "status")
            return Pairs("open", "Deschis", "finalized", "Finalizat", "cancelled", "Anulat");
        if (table == "crm_leads" && field == "stage")
            return Pairs("new", "Nou", "contacted", "Contact stabilit", "qualified", "Calificat", "proposal", "Ofertă trimisă", "negotiation", "Negociere", "won", "Câștigat", "lost", "Pierdut");
        if (table == "crm_leads" && field == "pipeline_type")
            return Pairs("lead", "Lead", "deal", "Tranzacție");
        if (table == "crm_quotes" && field == "status")
            return Pairs("draft", "Ciornă", "sent", "Trimisă", "accepted", "Acceptată", "rejected", "Respinsă");
        if (table == "crm_activities" && field == "activity_type")
            return Pairs("call", "Apel", "meeting", "Întâlnire", "email", "Email", "task", "Task", "note", "Notă");
        if (table == "crm_tickets" && field == "status")
            return Pairs("open", "Deschis", "in_progress", "În lucru", "resolved", "Rezolvat", "closed", "Închis");
        if (table == "crm_tickets" && field == "priority")
            return Pairs("low", "Scăzută", "normal", "Normală", "high", "Ridicată", "urgent", "Urgentă");
        if (table == "crm_tickets" && field == "category")
            return Pairs("billing", "Facturare", "delivery", "Livrări", "technical", "Tehnic", "contract", "Contract", "other", "Altele");
        if (field is "moneda" or "currency")
            return Pairs("RON", "RON", "EUR", "EUR", "USD", "USD", "GBP", "GBP");
        if (field == "metoda_plata")
            return Pairs("transfer", "Transfer", "numerar", "Numerar", "card", "Card", "altele", "Altele");
        return null;
    }

    public static bool UseFirstWhenEmpty(string table, string field)
    {
        if (table == "products" && field is "tip" or "unitate_masura" or "cota_tva")
            return true;
        return field is "status" or "warehouse_type" or "contract_type" or "metoda_plata"
            or "stage" or "kind" or "priority" or "activity_type" or "pipeline_type"
            or "moneda" or "currency";
    }

    public static string Display(string table, string field, string raw)
    {
        var options = Options(table, field);
        if (options == null || raw.Length == 0)
            return raw;
        var match = Match(options, raw);
        return match?.Label ?? raw;
    }

    public static FieldChoice? Match(IReadOnlyList<FieldChoice> options, string raw)
    {
        if (raw.Length == 0)
            return null;
        foreach (var option in options)
        {
            if (string.Equals(option.Code, raw, StringComparison.OrdinalIgnoreCase))
                return option;
        }
        if (decimal.TryParse(raw.Replace(',', '.'), NumberStyles.Number, CultureInfo.InvariantCulture, out var number))
        {
            foreach (var option in options)
            {
                if (decimal.TryParse(option.Code, NumberStyles.Number, CultureInfo.InvariantCulture, out var code) && code == number)
                    return option;
            }
        }
        var folded = FoldUnit(raw);
        foreach (var option in options)
        {
            if (FoldUnit(option.Code) == folded && folded.Length > 0)
                return option;
        }
        return null;
    }

    private static string FoldUnit(string value)
    {
        var text = value.Trim().TrimEnd('.').ToLowerInvariant();
        return text is "buc" or "bucata" or "h87" ? "buc" : text;
    }

    private static IReadOnlyList<FieldChoice> Pairs(params string[] pairs)
    {
        var list = new List<FieldChoice>(pairs.Length / 2);
        for (var i = 0; i + 1 < pairs.Length; i += 2)
            list.Add(new FieldChoice(pairs[i], pairs[i + 1]));
        return list;
    }
}
