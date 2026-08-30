import Foundation

/// Noutăți locale (RO + EN). La fiecare versiune importantă:
/// 1. Mută din `upcoming` itemii implementați în `releases` (release nou la început).
/// 2. Actualizează `upcoming` cu planul pentru versiunea următoare.
/// 3. Incrementează `MARKETING_VERSION` în proiect.
enum WhatsNewContent {
    static var document: WhatsNewDocument {
        WhatsNewDocument(
            upcoming: upcoming,
            releases: releases,
            footerRomanian: "ERP Mobile · DATECONTA.RO · 30 august 2026",
            footerEnglish: "ERP Mobile · DATECONTA.RO · August 30, 2026"
        )
    }

    /// Planificat pentru versiunea următoare — nu tot ce e aici va fi livrat; la release mută ce s-a făcut.
    private static var upcoming: WhatsNewUpcoming {
        WhatsNewUpcoming(
            targetVersionLabel: "1.0.033",
            romanianItems: [
                "BINA Smart Business: stabilizare listă Rapoarte Z în perioadă și descărcare batch PDF-uri în română (validare finală).",
                "Extragere Rapoarte Z: conectori Memgest, BOCP și Generic HTTP (pe lângă BINA).",
                "Manual Ajutor: capturi de ecran reale din modul Registru de casă.",
                "MT940: șabloane suplimentare de parsare extras bancă (formate bănci românești).",
                "Registru de casă: export direct în folder (ca la Rapoarte Z), fine-tuning pixel-perfect pe model PDF.",
            ],
            englishItems: [
                "BINA Smart Business: stabilize Z report listing by date range and batch Romanian PDF download (final validation).",
                "Z report extraction: Memgest, BOCP, and Generic HTTP connectors (in addition to BINA).",
                "Help manual: real in-app screenshots for the Cash register module.",
                "MT940: additional bank statement parsing templates (Romanian bank formats).",
                "Cash register: direct folder export (like Z reports), pixel-perfect PDF template tuning.",
            ]
        )
    }

    private static var releases: [WhatsNewRelease] {
        [
            release(
                "1.0.032", "30.08.2026",
                ro: [
                    "NIR: linia de conversie e precompletată pe toate articolele; atenționarea roșie rămâne doar la cantitățile deduse din denumire (ex. 10KG, 5L).",
                    "Conversia UM se face doar la Marfă și Materie primă. Ambalaj, consumabile și celelalte categorii sunt cheltuieli — fără conversie.",
                    "Manual Ajutor: Furnizori actualizat pentru conversie doar pe stoc (marfă / materie primă).",
                ],
                en: [
                    "GRN: the conversion line is pre-filled on every item; the red warning stays only for quantities inferred from the name (e.g. 10KG, 5L).",
                    "UoM conversion applies only to Merchandise and Raw material. Packaging, consumables and other categories are expenses — no conversion.",
                    "Help manual: Suppliers updated for conversion only on stock items (merchandise / raw material).",
                ]
            ),
            release(
                "1.0.031", "30.08.2026",
                ro: [
                    "NIR: linia de conversie (cantitate factură ↔ cantitate NIR) apare doar când programul nu e sigur — de exemplu 10KG în denumire și 1 buc pe factură.",
                    "Articolele clare rămân pe un rând, cu un rezumat scurt. Linia portocalie semnalează ce trebuie verificat.",
                    "Manual Ajutor: Furnizori actualizat pentru verificarea cantităților nesigure.",
                ],
                en: [
                    "GRN: the conversion line (invoice qty ↔ GRN qty) appears only when the app is unsure — e.g. 10KG in the name and 1 pc on the invoice.",
                    "Clear items stay on one row, with a short summary. The orange line flags what you should check.",
                    "Help manual: Suppliers updated for reviewing uncertain quantities.",
                ]
            ),
            release(
                "1.0.030", "30.08.2026",
                ro: [
                    "NIR recunoaște pachetele din denumire (10KG, 5KG, 5L, 500ML): 1 buc pe factură (sac, găleată) devine kg sau litri la recepție.",
                    "Pe fiecare articol vedeți cantitatea din factură și cantitatea NIR; le puteți corecta. Prețul de achiziție se recalculează, valoarea liniei rămâne.",
                    "Manual Ajutor: Furnizori actualizat pentru conversia din denumire (Metro, Lidl, B&B).",
                ],
                en: [
                    "GRN detects pack sizes in the name (10KG, 5KG, 5L, 500ML): 1 pc on the invoice (sack, bucket) becomes kg or litres at receipt.",
                    "Each item shows invoice quantity and GRN quantity; you can correct them. Purchase unit price recalculates, the line value stays.",
                    "Help manual: Suppliers updated for name-based conversion (Metro, Lidl, B&B).",
                ]
            ),
            release(
                "1.0.029", "30.08.2026",
                ro: [
                    "UM de stoc: vânzare doar la bucată, consum doar Kg sau Litru — selectabile pe fișa articolului.",
                    "UM de pe factură (bax, cutie, ladă, palet…) se pune la achiziție, cu factor (ex. 1 bax = 24 Buc.). Metro, Lidl, B&B etc. rămân pe UM lor.",
                    "La import, un articol nou facturat pe bax/cutie se creează pe Buc. + UM achiziție, nu pe bax ca stoc.",
                    "Manual Ajutor: Articole și Furnizori actualizate pentru UM vânzare/consum vs. factură.",
                ],
                en: [
                    "Stock UoM: sales are per piece only; consumption is Kg or litre — selectable on the item card.",
                    "Invoice UoM (crate, box, case, pallet…) goes to purchase, with a factor (e.g. 1 crate = 24 pcs). Metro, Lidl, B&B etc. keep their units.",
                    "On import, a new item invoiced in crates/boxes is created as pcs + purchase UoM, not as crate stock.",
                    "Help manual: Items and Suppliers updated for sales/consumption vs invoice UoM.",
                ]
            ),
            release(
                "1.0.028", "30.08.2026",
                ro: [
                    "Factură și NIR: fiecare articol pe un rând compact (denumire, cantități, prețuri), separat prin linie — mai ușor de urmărit pe Mac.",
                    "Editarea unui NIR salvat reîncarcă prețurile de vânzare și adaosul completate, nu le mai resetează la 0.",
                    "Manual Ajutor: Furnizori actualizat pentru liniile compacte și reîncărcarea prețurilor.",
                ],
                en: [
                    "Invoice and GRN: each item on one compact row (name, quantities, prices), separated by a line — easier to scan on Mac.",
                    "Editing a saved GRN reloads the sale prices and markup you entered, instead of resetting markup to 0.",
                    "Help manual: Suppliers updated for compact lines and restored sale prices.",
                ]
            ),
            release(
                "1.0.027", "30.08.2026",
                ro: [
                    "NIR în UM de vânzare/consum: factura poate rămâne pe bax, recepția și stocul se fac pe bucată (sau altă UM a articolului).",
                    "Fișa articolului: UM achiziție + factor (ex. 1 bax = 24 buc). Pe NIR puteți ajusta factorul sau cantitatea fără a schimba articolul.",
                    "Prețul de vânzare și adaosul se calculează pe UM de stoc. PDF-ul NIR notează conversia față de factură.",
                    "Manual Ajutor: Furnizori și Nomenclatoare actualizate pentru conversia UM.",
                ],
                en: [
                    "GRN in the sales/consumption UoM: the invoice can stay in crates; receipt and stock use pieces (or the item’s stock unit).",
                    "Item card: purchase UoM + factor (e.g. 1 crate = 24 pcs). On the GRN you can adjust the factor or quantity without changing the item.",
                    "Sale price and markup are calculated on the stock UoM. The GRN PDF notes the invoice conversion.",
                    "Help manual: Suppliers and Master data updated for UoM conversion.",
                ]
            ),
            release(
                "1.0.026", "27.08.2026",
                ro: [
                    "Fișa stoc: tile-ul de pe Dashboard deschide un ecran pe toată lățimea zonei de module ERP, cu tile-uri Actualizare stocuri inițiale și Generare fișă stoc.",
                    "Actualizare stocuri inițiale: cantitate și preț de deschidere pe articolele din fișa de stoc; stocul actual se ajustează cu diferența salvată.",
                    "Generare fișă stoc: lista și fișa contabilă (intrări/ieșiri, CMP, export) rămân ca înainte, din al doilea tile.",
                    "Manual Ajutor: capitol Fișa stoc actualizat pentru hub-ul cu două tile-uri.",
                ],
                en: [
                    "Stock sheet: the Dashboard tile opens a full-width hub in the ERP modules area, with Update opening stock and Generate stock sheet tiles.",
                    "Update opening stock: opening quantity and unit price for stock-sheet items; current stock is adjusted by the saved difference.",
                    "Generate stock sheet: the list and accounting card (inbound/outbound, WAC, export) stay as before, from the second tile.",
                    "Help manual: Stock sheet chapter updated for the two-tile hub.",
                ]
            ),
            release(
                "1.0.025", "27.08.2026",
                ro: [
                    "Modul Fișa stoc pe Dashboard: articolele marcate „Folosit în Foaie stoc”, cantitate, cost mediu ponderat și valoare; tap deschide fișa cu intrări/ieșiri.",
                    "Export listă și fișă individuală: print, PDF, Excel, trimitere — iconițe pe bara din dreapta.",
                    "Fișa furnizor/client: acțiunile din meniul cu 3 puncte sunt iconițe pe bara albă din dreapta.",
                    "Manual Ajutor: capitol nou Fișa stoc; actualizare fișe furnizor/client.",
                    "Migrare Supabase: modul stock_sheet (permisiuni copiate din Stocuri).",
                ],
                en: [
                    "Stock sheet module on the Dashboard: items marked “Used in stock sheet”, quantity, weighted average cost and value; tap opens the inbound/outbound card.",
                    "List and individual sheet export: print, PDF, Excel, send — icons on the right bar.",
                    "Supplier/client account: the 3-dot menu actions are icons on the white bar at the right.",
                    "Help manual: new Stock sheet chapter; supplier/client account actions updated.",
                    "Supabase migration: stock_sheet module (permissions copied from Inventory).",
                ]
            ),
            release(
                "1.0.024", "18.08.2026",
                ro: [
                    "Modul Registru de casă (Dashboard): generare registre zilnice din Rapoarte Z importate + chitanțe manuale; casă sediu și puncte de lucru; transferuri între case; sold negativ → „returnat avans spre decontare” (rotunjit la sute).",
                    "PDF registru pe model oficial (Registru_Casa_model.pdf): date în casete, cont casă centrat, sume aliniate, linie oblică pe rândurile goale; previzualizare și export.",
                    "Chitanțe manuale salvate în Supabase (company_cash_register_entries); migrare automată din stocare locală.",
                    "MT940: parsare extras PDF Raiffeisen (layout coloane); câte un fișier MT940 pe zi (MT940_FIRMA_YYYY-MM-DD.txt); arhivă ZIP.",
                    "Manual Ajutor: capitol nou Registru de casă; actualizare MT940 în Utilitare.",
                    "Migrări Supabase: company_cash_register_entries, template registru_casa_model.",
                ],
                en: [
                    "Cash register module (Dashboard): daily journals from imported Z reports + manual receipts; HQ and work locations; inter-location transfers; negative balance → “advance returned for settlement” (rounded to hundreds).",
                    "Register PDF on official template (Registru_Casa_model.pdf): values in boxes, centered cash account, aligned amounts, diagonal line on empty rows; preview and export.",
                    "Manual receipts saved in Supabase (company_cash_register_entries); automatic migration from local storage.",
                    "MT940: Raiffeisen PDF statement parsing (column layout); one MT940 file per day (MT940_FIRMA_YYYY-MM-DD.txt); ZIP archive.",
                    "Help manual: new Cash register chapter; MT940 section updated in Utilities.",
                    "Supabase migrations: company_cash_register_entries, registru_casa_model template.",
                ]
            ),
            release(
                "1.0.023", "31.07.2026",
                ro: [
                    "Tab CRM extins (stil Bitrix24): Panoramă, Lead-uri, Tranzacții Kanban, Listă, Contacte, Companii, Oferte, Activități, Analiză, Tichete.",
                    "Kanban tranzacții: coloane pe etape (Nou → Câștigat/Pierdut), mutare etapă din meniul cardului, metrici pipeline și valoare ponderată.",
                    "Companii și contacte CRM: sincronizare automată din Clienții ERP; adăugare, editare și ștergere manuală doar pentru societatea ERP activă.",
                    "Oferte comerciale: linii cu cantitate/preț, total automat, status draft/trimis/acceptat/resping.",
                    "Lead-uri convertibile în tranzacții; produse pe tranzacție din catalogul articolelor; responsabil din utilizatorii ERP ai societății.",
                    "Activități CRM (apel, întâlnire, task) și analiză: funnel vânzări, rată câștig, contacte/compani/oferte deschise.",
                    "Manual Ajutor: capitol nou CRM (secțiunea 12); renumerotare secțiuni Utilitare și Zetta.",
                    "Migrări Supabase: companii CRM, contacte, oferte, produse pe tranzacție, sincronizare automată ERP ↔ CRM.",
                ],
                en: [
                    "Extended CRM tab (Bitrix24-style): Overview, Leads, Deals Kanban, List, Contacts, Companies, Quotes, Activities, Analytics, Tickets.",
                    "Deals Kanban: columns by stage (New → Won/Lost), move stage from card menu, pipeline and weighted value metrics.",
                    "CRM companies and contacts: auto-sync from ERP Clients; manual add, edit, and delete for the active ERP company only.",
                    "Commercial quotes: lines with quantity/price, automatic total, draft/sent/accepted/rejected status.",
                    "Leads convertible to deals; deal products from item catalog; assignee from ERP company users.",
                    "CRM activities (call, meeting, task) and analytics: sales funnel, win rate, open contacts/companies/quotes.",
                    "Help manual: new CRM chapter (section 12); Utilities and Zetta sections renumbered.",
                    "Supabase migrations: CRM companies, contacts, quotes, deal products, automatic ERP ↔ CRM sync.",
                ]
            ),
            release(
                "1.0.022", "17.08.2026",
                ro: [
                    "Tab Utilitare în meniul principal: Import Zetta (standalone), arhivă MT940 zilnică și extragere Rapoarte Z din casă de marcat.",
                    "Import Zetta (Utilitare): același flux ca modulul Zetta — pe Mac Catalyst salvează direct fișierul ZETTA (.xlsx) în folderul ales, fără share sheet.",
                    "MT940: încarcă extras bancar (PDF/CSV/MT940) → generează câte un fișier MT940 pe zi → arhivă ZIP.",
                    "Extragere Rapoarte Z (BINA Smart Business): login automat, listă rapoarte în perioadă, descărcare batch PDF-uri în română pentru import Zetta.",
                    "Setări casă de marcat per societate (Supabase): credențiale BINA, folder export, locație POS.",
                    "Manual Ajutor extins: capitol Utilitare cu capturi de ecran; Zetta renumerotat la secțiunea 15.",
                ],
                en: [
                    "Utilities tab in main menu: Zetta import (standalone), daily MT940 archive, and Z report extraction from cash register software.",
                    "Zetta import (Utilities): same flow as the Zetta module — on Mac Catalyst saves the ZETTA file (.xlsx) directly to the chosen folder, no share sheet.",
                    "MT940: upload bank statement (PDF/CSV/MT940) → one MT940 file per day → ZIP archive.",
                    "Z report extraction (BINA Smart Business): automatic login, list reports in date range, batch download of Romanian PDFs for Zetta import.",
                    "Cash register settings per company (Supabase): BINA credentials, export folder, POS location.",
                    "Extended Help manual: Utilities chapter with screenshots; Zetta renumbered to section 15.",
                ]
            ),
            release(
                "1.0.021", "16.08.2026",
                ro: [
                    "Ecran de pornire: versiunea aplicației (v 1.0.021) afișată lângă „Se inițializează…”.",
                    "Setări Zetta (per societate): ture pe casă, case pe mai multe puncte de lucru, cont casă sediu, conturi CARD și PLATA MODERNA, cote TVA A–D cu tipuri vânzări și conturi editabile.",
                    "Notă contabilă din Raport Z: generare după setările salvate (cote, viramente, SGR/Bacșiș la 0%, coloana Partener Cont D/C pe 4111, omitere rânduri cu valoare 0).",
                    "Punct de lucru nou: depozit distinct creat automat în Nomenclatoare.",
                    "Setări Zetta: câmp „Cont folosit” editabil (max. 10 caractere), o singură opțiune per cotă TVA.",
                    "Contact suport actualizat: ERPMobile@dateconta.ro.",
                ],
                en: [
                    "Launch screen: app version (v 1.0.021) shown next to “Initializing…”.",
                    "Zetta settings (per company): register shifts, registers at multiple work locations, HQ cash account, CARD and MODERN PAYMENT accounts, VAT rates A–D with sale types and editable accounts.",
                    "Accounting note from Z report: generation from saved settings (rates, transfers, deposit/tip at 0%, Partner Account D/C on 4111, skip zero-value lines).",
                    "New work location: distinct warehouse created automatically in master data.",
                    "Zetta settings: editable “Account used” field (max 10 chars), one option per VAT rate.",
                    "Updated support contact: ERPMobile@dateconta.ro.",
                ]
            ),
            release(
                "1.0.020", "15.08.2026",
                ro: [
                    "Tab CRM în meniul principal: tichete suport pentru clienți (deschis, în lucru, rezolvat, închis), conversație pe tichet, deschidere tichet din fișa client.",
                    "Tab Ajutor: manual complet ERP (autentificare, dashboard, module, Zetta) cu capturi de ecran din aplicație.",
                    "Navigare rapidă în manual: link-uri în cuprins și buton „Înapoi la cuprins” în fiecare capitol.",
                    "Confidențialitate, Termeni și Despre aplicație mutate ca butoane în tab-ul Ajutor (eliminate din meniul principal).",
                    "Ce este nou: istoric versiuni afișat local, bilingv RO + EN, fără conexiune internet.",
                    "Dashboard: tile-uri noi Registru de casă și Extras de bancă.",
                    "Import Zetta: drag & drop JPG/PDF, picker fișiere pe iOS/Mac, acces security-scoped, mesaje de eroare vizibile la eșec.",
                    "Corecții avertismente compilare (concurrency Swift în modul Zetta).",
                    "Migrări Supabase: module registru casă/extras bancă, sistem CRM tichete și mesaje.",
                ],
                en: [
                    "CRM tab in main menu: client support tickets (open, in progress, resolved, closed), ticket conversation, open ticket from client account.",
                    "Help tab: full ERP manual (sign-in, dashboard, modules, Zetta) with in-app screenshots.",
                    "Quick manual navigation: table-of-contents links and “Back to contents” button in each chapter.",
                    "Privacy, Terms, and About app moved as buttons into the Help tab (removed from main menu).",
                    "What's New: version history shown locally, bilingual RO + EN, no internet required.",
                    "Dashboard: new Cash register and Bank statement tiles.",
                    "Zetta import: JPG/PDF drag & drop, file picker on iOS/Mac, security-scoped access, visible error messages on failure.",
                    "Build warning fixes (Swift concurrency in Zetta module).",
                    "Supabase migrations: cash register/bank statement modules, CRM tickets and messages system.",
                ]
            ),
            release(
                "1.0.019", "31.07.2026",
                ro: [
                    "Corecții minore de erori și îmbunătățiri.",
                    "NIR: permisiuni editare linii, corecții stoc la reintroducere/ștergere factură.",
                    "NIR: refolosire număr NIR eliberat la ștergerea facturii asociate.",
                ],
                en: [
                    "Minor bug fixes and improvements.",
                    "GRN: line edit permissions, stock corrections on line reinsert/invoice delete.",
                    "GRN: reuse released GRN number when deleting the linked invoice.",
                ]
            ),
            release(
                "1.0.018", "03.08.2026",
                ro: [
                    "Corecții minore de erori și îmbunătățiri.",
                    "Îmbunătățiri și corecții la întocmirea NIR-ului.",
                ],
                en: [
                    "Minor bug fixes and improvements.",
                    "Improvements and corrections in GRN preparation.",
                ]
            ),
            release(
                "1.0.017", "31.07.2026",
                ro: ["Corecții minore de erori și îmbunătățiri."],
                en: ["Minor bug fixes and improvements."]
            ),
            release(
                "1.0.016", "29.07.2026",
                ro: [
                    "Corecții minore de erori și îmbunătățiri.",
                    "Corecții la înregistrarea în fișa furnizor a facturilor storno sau Notelor de Credit, cu alocare pe facturi restante.",
                    "Catalog finalizat: stoc, preț achiziție/producție, preț vânzare, profit/bucată.",
                    "Rețete implementate pentru produse finite.",
                ],
                en: [
                    "Minor bug fixes and improvements.",
                    "Corrections for storno invoices and credit notes on supplier records, with allocation to outstanding invoices.",
                    "Catalog finalized: stock, purchase/production price, selling price, profit per unit.",
                    "Recipes implemented for finished products.",
                ]
            ),
            release(
                "1.0.015", "17.07.2026",
                ro: [
                    "Corecții minore de erori și îmbunătățiri.",
                    "Doar ADMIN — Categorii articol: Marfă, Materie primă, Produs finit, Ambalaj, Materiale consumabile.",
                    "Doar ADMIN — Început implementare Fișă de stoc, în paralel cu Catalog.",
                ],
                en: [
                    "Minor bug fixes and improvements.",
                    "ADMIN only — Item categories: Merchandise, Raw materials, Finished product, Packaging, Consumables.",
                    "ADMIN only — Started Stock sheet implementation alongside Catalog.",
                ]
            ),
            release("1.0.014", "16.07.2026", ro: ["Corecții minore de erori și îmbunătățiri."], en: ["Minor bug fixes and improvements."]),
            release("1.0.013", "15.07.2026", ro: ["Corecții minore de erori și îmbunătățiri."], en: ["Minor bug fixes and improvements."]),
            release("1.0.012", "14.07.2026", ro: ["Corecții minore de erori și îmbunătățiri."], en: ["Minor bug fixes and improvements."]),
            release("1.0.011", "11.07.2026", ro: ["Corecții minore de erori și îmbunătățiri."], en: ["Minor bug fixes and improvements."]),
            release(
                "1.0.010", "10.07.2026",
                ro: [
                    "Corecții minore de erori și îmbunătățiri.",
                    "Puncte de lucru și depozite în Nomenclatoare → Societăți.",
                    "Generare NIR după creare/import facturi furnizori, cu stoc doar pentru produse cu NIR.",
                ],
                en: [
                    "Minor bug fixes and improvements.",
                    "Work points and warehouses in Master data → Companies.",
                    "GRN generation after supplier invoice create/import, stock only for GRN products.",
                ]
            ),
            release("1.0.009", "09.07.2026", ro: ["Corecții minore de erori și îmbunătățiri."], en: ["Minor bug fixes and improvements."]),
            release(
                "1.0.008", "23.06.2026",
                ro: [
                    "Corecții minore de erori și îmbunătățiri.",
                    "Modificat calculul și afișarea pe fișa de cont furnizori/clienți.",
                    "Compatibil iOS 15+ și macOS Monterey (12)+.",
                ],
                en: [
                    "Minor bug fixes and improvements.",
                    "Changed calculation and display on supplier/client account sheets.",
                    "Compatible with iOS 15+ and macOS Monterey (12)+.",
                ]
            ),
            release(
                "1.0.007", "19.06.2026",
                ro: [
                    "Corecții minore de erori și îmbunătățiri.",
                    "Plăți/încasări: selectare mai multor facturi la alocare, cu completare automată.",
                ],
                en: [
                    "Minor bug fixes and improvements.",
                    "Payments/receipts: multi-invoice allocation with automatic field completion.",
                ]
            ),
            release(
                "1.0.006", "16.06.2026",
                ro: [
                    "Corecții minore de erori și îmbunătățiri.",
                    "Vizualizare calendar (1 lună) pe tab-ul Scadente.",
                    "Modul Clienți, structură similară Furnizori.",
                ],
                en: [
                    "Minor bug fixes and improvements.",
                    "Calendar view (1 month) on Due dates tab.",
                    "Clients module with structure similar to Suppliers.",
                ]
            ),
            release("1.0.005", "14.06.2026", ro: ["Corecții minore de erori și îmbunătățiri."], en: ["Minor bug fixes and improvements."]),
            release(
                "1.0.004", "12.06.2026",
                ro: [
                    "Aplicația rulează și pe macOS.",
                    "Ecran INFO la intrarea în aplicație.",
                    "Verificare update App Store la pornire.",
                ],
                en: [
                    "Application runs on macOS.",
                    "INFO screen on app launch.",
                    "App Store update check on startup.",
                ]
            ),
            release(
                "1.0.003", "07.06.2026",
                ro: [
                    "Import facturi din XML e-Factura (individual sau bulk din director/USB/cloud).",
                    "Modul Stocuri: Stoc / Mișcări / Inventar.",
                    "Modul Produse: Catalog / Articole / Rețete.",
                ],
                en: [
                    "Import invoices from e-Invoice XML (single or bulk from folder/USB/cloud).",
                    "Inventory module: Stock / Movements / Physical inventory.",
                    "Products module: Catalog / Items / Recipes.",
                ]
            ),
            release(
                "1.0.002", "06.06.2026",
                ro: [
                    "Plăți fără asociere în Referințe — restul se aplică după facturile plătite.",
                    "Fișă furnizor: scadență 0 → propune data facturii.",
                    "Factură nouă: opțiune Adaugă furnizor nou în listă.",
                    "Sume: max. 4 zecimale la introducere, rotunjire la 2 la salvare.",
                    "Filtre facturi: număr, interval dată, furnizor.",
                    "Filtre plăți: chitanță/OP, factură plătită, interval, furnizor.",
                    "Tab Scadente cu categorii: depășite, săptămâna curentă, viitoare.",
                ],
                en: [
                    "Unreferenced payments apply remainder after paid invoices.",
                    "Supplier sheet: 0 due days → propose invoice date.",
                    "New invoice: Add new supplier as first list option.",
                    "Amounts: up to 4 decimals on input, rounded to 2 on save.",
                    "Invoice filters: number, date range, supplier.",
                    "Payment filters: receipt/OP, paid invoice, date range, supplier.",
                    "Due dates tab: overdue, current week, upcoming.",
                ]
            ),
        ]
    }

    private static func release(
        _ version: String,
        _ dateLabel: String,
        ro: [String],
        en: [String]
    ) -> WhatsNewRelease {
        WhatsNewRelease(
            version: version,
            dateLabel: dateLabel,
            romanianItems: ro,
            englishItems: en
        )
    }
}
