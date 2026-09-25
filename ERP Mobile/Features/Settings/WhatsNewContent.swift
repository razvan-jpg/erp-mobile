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
            footerRomanian: "ERP Mobile · DATECONTA.RO · 25 septembrie 2026",
            footerEnglish: "ERP Mobile · DATECONTA.RO · September 25, 2026"
        )
    }

    /// Planificat pentru versiunea următoare — nu tot ce e aici va fi livrat; la release mută ce s-a făcut.
    private static var upcoming: WhatsNewUpcoming {
        WhatsNewUpcoming(
            targetVersionLabel: "1.0.080",
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
                "1.0.079", "25.09.2026",
                ro: [
                    "Performanță Mac: fără overlay blocat la editare transfer, PDF generat în fundal, print direct (conturi, fișă stoc, inventar, NIR) fără sheet intermediar.",
                ],
                en: [
                    "Mac performance: no stuck loading overlay when editing transfers, PDF built in the background, direct print (accounts, stock sheet, inventory, GRN) without an intermediate sheet.",
                ]
            ),
            release(
                "1.0.078", "25.09.2026",
                ro: [
                    "Print PDF pe Mac: panoul de tipărire apare imediat din preview (fără blocaj până la Esc).",
                ],
                en: [
                    "PDF print on Mac: the print panel opens immediately from preview (no freeze until Esc).",
                ]
            ),
            release(
                "1.0.077", "25.09.2026",
                ro: [
                    "Bon de transfer: dacă ștergeți toate liniile și salvați, bonul se șterge și stocul revine pe gestiunea de plecare; la modificare, stocurile pe ambele gestiuni se actualizează.",
                ],
                en: [
                    "Transfer note: if you remove all lines and save, the note is deleted and stock returns to the source warehouse; on edit, stocks at both warehouses are updated.",
                ]
            ),
            release(
                "1.0.076", "25.09.2026",
                ro: [
                    "Editare bon de transfer pe Mac: buton coș pe fiecare linie pentru ștergerea articolelor existente.",
                ],
                en: [
                    "Edit transfer note on Mac: trash button on each line to remove existing items.",
                ]
            ),
            release(
                "1.0.075", "25.09.2026",
                ro: [
                    "Import e-Factura: dacă denumirea e doar similară cu un articol existent, nu se creează fișă nouă — pe NIR confirmați (păstrați articolul sau creați unul nou), ca la cantitatea dedusă din denumire.",
                ],
                en: [
                    "e-Invoice import: if the name is only similar to an existing item, no new sheet is created — on the GRN you confirm (keep the item or create a new one), like quantities inferred from the name.",
                ]
            ),
            release(
                "1.0.074", "25.09.2026",
                ro: [
                    "Roșii și ardei kapia din facturi: variantele (RO, P, MC ciorchine, kapia…) se leagă la „ROSII RO” și „ARDEI KAPIA ROSU”; pe Nectarie stocurile au fost unificate.",
                ],
                en: [
                    "Tomatoes and kapia peppers from invoices: variants (RO, P, MC cluster, kapia…) link to “ROSII RO” and “ARDEI KAPIA ROSU”; Nectarie stocks were merged.",
                ]
            ),
            release(
                "1.0.073", "25.09.2026",
                ro: [
                    "Import e-Factura: sufixele LOT din denumire sunt ignorate — o singură fișă pe produs (ex. Doner Vita, ulei palmier).",
                    "Nectarie: unificate cele 21 fișe Doner pe lot → „DONER VITA TOCAT” și variantele de ulei → o fișă fără LOT.",
                ],
                en: [
                    "e-Invoice import: LOT suffixes in the name are ignored — one sheet per product (e.g. Doner Vita, palm oil).",
                    "Nectarie: merged 21 Doner lot sheets → “DONER VITA TOCAT” and palm-oil variants → one sheet without LOT.",
                ]
            ),
            release(
                "1.0.072", "25.09.2026",
                ro: [
                    "Cartofi albi/noi din facturi: toate variantele (RO 50+, NOI, MC 10KG…) se leagă la fișa unică „CARTOFI ALBI IMP”; pe Nectarie stocurile au fost unificate.",
                ],
                en: [
                    "White/new potatoes from invoices: all variants (RO 50+, NOI, MC 10KG…) link to the single “CARTOFI ALBI IMP” sheet; Nectarie stocks were merged.",
                ]
            ),
            release(
                "1.0.071", "25.09.2026",
                ro: [
                    "Import e-Factura: dacă există deja un produs cu aceeași denumire pe firmă, se folosește fișa existentă (nu se mai creează duplicat).",
                    "Curățare Nectarie: unificate fișele duplicate „ardei iute” și „CASTRAVETI MURATI” (stoc cumulativ).",
                ],
                en: [
                    "e-Invoice import: if a product with the same name already exists for the company, the existing sheet is reused (no more duplicates).",
                    "Nectarie cleanup: merged duplicate “ardei iute” and “CASTRAVETI MURATI” sheets (stock summed).",
                ]
            ),
            release(
                "1.0.070", "25.09.2026",
                ro: [
                    "Bonuri de transfer pe Mac: buton coș de gunoi pe fiecare rând, pe lângă swipe.",
                ],
                en: [
                    "Transfer notes on Mac: trash button on each row, in addition to swipe.",
                ]
            ),
            release(
                "1.0.069", "25.09.2026",
                ro: [
                    "Aviz de expediție (bon de transfer): se deschide în PDF pentru listare/print, cu salvare pe disc ca la NIR.",
                ],
                en: [
                    "Dispatch note (transfer note): opens in PDF for listing/print, with disk save like the GRN.",
                ]
            ),
            release(
                "1.0.068", "25.09.2026",
                ro: [
                    "Bon de transfer: vedeți stocul disponibil pe gestiunea sursă, introduceți cantitatea, iar la salvare stocurile pe gestiuni se actualizează automat.",
                    "Bon salvat: modificare, ștergere (cu impact pe stoc) și listare PDF ca Aviz de expediție pentru însoțirea mărfii.",
                ],
                en: [
                    "Transfer note: see available stock at the source warehouse, enter the quantity; saving updates warehouse stocks automatically.",
                    "Saved notes: edit, delete (with stock impact), and list as a PDF dispatch note to accompany the goods.",
                ]
            ),
            release(
                "1.0.067", "25.09.2026",
                ro: [
                    "Lista facturi furnizor: pe fiecare factură vedeți dacă recepția e completă („Factură închisă”) sau puteți Adăuga recepție / Închide restul.",
                    "Închiderea recepției nu modifică stocul; anularea unui NIR deschis, fără salvare, nici ea.",
                ],
                en: [
                    "Supplier invoice list: each invoice shows if reception is complete (“Invoice closed”) or you can Add reception / Close the remainder.",
                    "Closing reception does not change stock; cancelling an opened GRN without saving also leaves stock unchanged.",
                ]
            ),
            release(
                "1.0.066", "25.09.2026",
                ro: [
                    "Re-import e-Factura: factura cu NIR pe jumătate de cantitate (aceeași UM) nu mai apare ca duplicat — se deschide NIR pe rest.",
                    "Bon de transfer: remediat ecranul blocat pe „Se încarcă…” (în special pe Mac).",
                ],
                en: [
                    "e-Invoice re-import: an invoice with a half-quantity GRN (same UoM) is no longer treated as a duplicate — opens a GRN for the remainder.",
                    "Transfer note: fixed the screen stuck on “Loading…” (especially on Mac).",
                ]
            ),
            release(
                "1.0.065", "25.09.2026",
                ro: [
                    "Factură cu NIR parțial: puteți face un NIR nou pe restul nerecepționat (aceeași sau altă gestiune).",
                    "Re-import e-Factura pe o factură incompletă: deschide NIR pe rest, fără a importa din nou factura.",
                ],
                en: [
                    "Invoice with a partial GRN: create another GRN for the unreceived remainder (same or another warehouse).",
                    "Re-importing e-Invoice for an incomplete invoice: open a GRN for the remainder without importing again.",
                ]
            ),
            release(
                "1.0.064", "25.09.2026",
                ro: [
                    "Stocuri: remediat ciclul de reîncărcare când deschideți Bon de transfer (în special pe Mac) — ecranul nu se mai recreează la nesfârșit.",
                    "Listele de stocuri / articole se actualizează local după salvare, fără a recrea tot ecranul.",
                ],
                en: [
                    "Inventory: fixed the reload loop when opening Transfer note (especially on Mac) — the screen no longer remounts endlessly.",
                    "Stock / article lists refresh locally after save, without remounting the whole screen.",
                ]
            ),
            release(
                "1.0.063", "24.09.2026",
                ro: [
                    "Factură furnizor: mai multe NIR-uri, câte unul pe gestiune. Dacă schimbați gestiunea și salvați, stocul se mută automat.",
                    "Stocuri: bon de transfer între gestiuni pentru materii prime, marfă, ambalaje și consumabile, la data bonului.",
                    "Inventar pe gestiunea aleasă. La salvare, stocul scriptic devine cantitatea numărată, iar diferențele rămân ca proces-verbal.",
                ],
                en: [
                    "Supplier invoice: several goods receipt notes, one per warehouse. Changing the warehouse and saving moves the stock.",
                    "Inventory: transfer note between warehouses for raw materials, merchandise, packaging, and consumables, on the note date.",
                    "Stock take for the selected warehouse. On save, book stock becomes the counted quantity, and differences are kept as a report.",
                ]
            ),
            release(
                "1.0.062", "19.09.2026",
                ro: [
                    "Fișa furnizor: Sold factură = restul acelei facturi, Sold final = soldul total după document. Storno-ul alocat scade restul facturilor de plată și nu se mai poate realoca (ex. Quadrant).",
                ],
                en: [
                    "Supplier account sheet: Invoice balance = that invoice’s remainder, Final balance = running total after the document. An allocated credit note reduces payable remainders and cannot be reallocated (e.g. Quadrant).",
                ]
            ),
            release(
                "1.0.061", "11.09.2026",
                ro: [
                    "HR → Listări: Excel NextUp din stat (brut, CAS 25%, CASS 10%, impozit 10%, CAM 2,25%), fără PDF Saga. Aceleași opțiuni ca la Utilitare: notă simplă sau sume strânse în 4311, plus preview înainte de salvare.",
                ],
                en: [
                    "HR → Listings: NextUp Excel from payroll (gross, 25% CAS, 10% CASS, 10% tax, 2.25% CAM), no Saga PDF. Same options as Utilities: simple note or amounts collected in 4311, plus preview before saving.",
                ]
            ),
            release(
                "1.0.060", "11.09.2026",
                ro: [
                    "Utilitare: lângă Nr. notei alegeți notă simplă sau sume strânse în 4311 (după 444, 4315, 4316, 436 se adaugă debitul și 4311 pe credit). Preview notă contabilă înainte de salvare.",
                ],
                en: [
                    "Utilities: next to the note number choose a simple note or amounts collected in 4311 (after 444, 4315, 4316, 436 the debit and 4311 credit are added). Journal-note preview before saving.",
                ]
            ),
            release(
                "1.0.059", "11.09.2026",
                ro: [
                    "Utilitare: nota Saga cu % (un debit, mai multe credite) se exportă în NextUp ca perechi 1:1 — același cont de debit, cu suma fiecărui credit, nu totalul cumulat.",
                ],
                en: [
                    "Utilities: Saga notes with % (one debit, several credits) export to NextUp as 1:1 pairs — the same debit account with each credit’s amount, not the combined total.",
                ]
            ),
            release(
                "1.0.058", "11.09.2026",
                ro: [
                    "Utilitare: nota contabilă PDF din Saga (cont debitor / creditor, sume 66 660.00, % la rețineri) se citește și devine Excel de import salarii NextUp.",
                ],
                en: [
                    "Utilities: Saga journal-note PDFs (debit/credit accounts, amounts like 66 660.00, % withholdings) are read into the NextUp salary import Excel.",
                ]
            ),
            release(
                "1.0.057", "11.09.2026",
                ro: [
                    "Utilitare: Creare fișier import stat în NextUp din notă contabilă PDF — încărcați PDF-ul notei de salarii și obțineți Excel-ul pe modelul de 21 coloane.",
                    "Manual Ajutor: Utilitare actualizat.",
                ],
                en: [
                    "Utilities: Create NextUp payroll import from a journal-note PDF — upload the salary note PDF and get the 21-column Excel.",
                    "Help manual: Utilities updated.",
                ]
            ),
            release(
                "1.0.056", "11.09.2026",
                ro: [
                    "HR: angajați, contracte, stat lunar (CO, CM, sporuri pe om), pontaj generat din stat + orarul firmei, listări PDF și Excel NextUp pe modelul de salarii.",
                ],
                en: [
                    "HR: employees, contracts, monthly payroll (leave, sick leave, bonuses per person), timesheet from payroll plus the company schedule, PDF listings and NextUp Excel on the salary model.",
                ]
            ),
            release(
                "1.0.055", "11.09.2026",
                ro: [
                    "Module ERP: tile HR pe dashboard, pentru societatea activă. Permisiunile se setează în Utilizatori.",
                ],
                en: [
                    "ERP modules: HR tile on the dashboard, for the active company. Permissions are set in Users.",
                ]
            ),
            release(
                "1.0.054", "09.09.2026",
                ro: [
                    "Rapoarte Z BINA în engleză: vânzările pe cote TVA (BRUT A/B/D) se citesc din nou corect — suma de după „VAT 21%” nu mai e ignorată.",
                ],
                en: [
                    "English BINA Z reports: VAT group sales (BRUT A/B/D) are read again — the amount after “VAT 21%” is no longer skipped.",
                ]
            ),
            release(
                "1.0.053", "09.09.2026",
                ro: [
                    "Manual Ajutor: procedura Excel pentru NextUp (Z-uri scanate și Clienți → Zetta) și cum ajung încasările în Registrul de casă — fără buton „Trimite în RC”, doar Generează registre după salvare.",
                ],
                en: [
                    "Help manual: NextUp Excel procedure (scanned Z reports and Clients → Zetta) and how receipts reach the cash register — no “Send to RC” button; Generate registers after saving.",
                ]
            ),
            release(
                "1.0.052", "09.09.2026",
                ro: [
                    "Z-uri scanate: PDF-ul cu toate paginile este scan-ul original (toate paginile, în ordine), nu o reconstrucție. Excel-ul rămâne din valorile citite.",
                    "Manual Ajutor: Utilitare actualizat.",
                ],
                en: [
                    "Scanned Z reports: the combined PDF is the original scan (all pages, in order), not a reconstruction. Excel still uses the values that were read.",
                    "Help manual: Utilities updated.",
                ]
            ),
            release(
                "1.0.051", "09.09.2026",
                ro: [
                    "Z-uri scanate: se citește pagina întreagă pe două coloane (etichetă + valoare), ca pe model. Fără număr Z nu mai apar sume false din stratul scannerului.",
                    "Manual Ajutor: Utilitare actualizat.",
                ],
                en: [
                    "Scanned Z reports: each page is read as two columns (label + value), like the model. Without a Z number, scanner leftover amounts are no longer kept.",
                    "Help manual: Utilities updated.",
                ]
            ),
            release(
                "1.0.050", "09.09.2026",
                ro: [
                    "Z-uri scanate → import Zetta: Recitește pe paginile necitite; previzualizare PDF și Excel fără să salvați fișierul.",
                    "Manual Ajutor: Utilitare actualizat.",
                ],
                en: [
                    "Scanned Z reports → Zetta import: Reread unread pages; preview PDF and Excel without saving the file.",
                    "Help manual: Utilities updated.",
                ]
            ),
            release(
                "1.0.049", "09.09.2026",
                ro: [
                    "Z-uri scanate → import Zetta: un fișier cu mai multe Z-uri = aceeași firmă și un singur Excel; fiecare pagină este un Z; PDF-urile se completează pe modelul salvat Raport_Z_model.pdf.",
                    "Manual Ajutor: Utilitare actualizat.",
                ],
                en: [
                    "Scanned Z reports → Zetta import: one file with several Zs = the same firm and a single Excel; each page is one Z; PDFs are filled on the saved Raport_Z_model.pdf layout.",
                    "Help manual: Utilities updated.",
                ]
            ),
            release(
                "1.0.048", "09.09.2026",
                ro: [
                    "Z-uri scanate → import Zetta: Excel-ul și PDF-urile sunt pe firma citită de pe Z, nu pe societatea din bara de jos. Fiecare PDF are data Z-ului. Salvare separată: un PDF cu toate, PDF-uri per Z, sau Excel.",
                    "Manual Ajutor: Utilitare actualizat.",
                ],
                en: [
                    "Scanned Z reports → Zetta import: Excel and PDFs use the firm read from the Z, not the company in the status bar. Each PDF has the Z date. Save separately: one PDF with all, PDFs per Z, or Excel.",
                    "Help manual: Utilities updated.",
                ]
            ),
            release(
                "1.0.047", "09.09.2026",
                ro: [
                    "Utilitare Zetta: Excel-ul și PDF-urile se creează pe societatea activă, nu pe firma tipărită pe Z-ul scanat.",
                    "Z-uri scanate: salvare separată — un PDF cu toate Z-urile, câte un PDF per Z (cu data Z-ului), sau Excel-ul.",
                    "Manual Ajutor: Utilitare actualizat.",
                ],
                en: [
                    "Zetta utilities: Excel and PDFs are created for the active company, not the firm printed on the scanned Z.",
                    "Scanned Z reports: save separately — one PDF with all Z reports, one PDF per Z (with the Z date), or the Excel file.",
                    "Help manual: Utilities updated.",
                ]
            ),
            release(
                "1.0.046", "09.09.2026",
                ro: [
                    "Utilitare: Z-uri scanate → import Zetta — încărcați poze sau PDF-uri cu Rapoarte Z; aplicația le citește pe modelul Raport_Z_model.pdf și creează fișierul de import Zetta.",
                    "Manual Ajutor: Utilitare actualizat.",
                ],
                en: [
                    "Utilities: Scanned Z reports → Zetta import — upload Z report photos or PDFs; the app reads them using Raport_Z_model.pdf and builds the Zetta import file.",
                    "Help manual: Utilities updated.",
                ]
            ),
            release(
                "1.0.045", "08.09.2026",
                ro: [
                    "Registru de casă: documentele create manual rămân în listă; dacă goliți registrele generate, la generare se pun din nou.",
                    "Filtru săptămâna curentă / luna curentă / toate și căutare în documente.",
                    "Tip nou: depunere numerar în bancă. La plata furnizor alegeți furnizorul din listă.",
                    "Manual Ajutor: Registru de casă actualizat.",
                ],
                en: [
                    "Cash register: manual documents stay in the list; if you clear generated registers, Generate puts them back.",
                    "Filter current week / current month / all, plus document search.",
                    "New type: cash deposit to bank. Supplier payments let you pick the supplier from the list.",
                    "Help manual: Cash register updated.",
                ]
            ),
            release(
                "1.0.044", "08.09.2026",
                ro: [
                    "Registru de casă: chitanțele adăugate manual nu mai dispar din listă și intră la Încasări / Plăți pe ziua documentului.",
                    "Facturile din Furnizori nu sunt operațiuni de casă — pentru Plăți folosiți Adaugă chitanță sau plata cu metoda Numerar.",
                    "Manual Ajutor: Registru de casă actualizat.",
                ],
                en: [
                    "Cash register: manual receipts no longer disappear from the list and go to Receipts / Payments on the document date.",
                    "Supplier invoices are not cash operations — for Payments use Add receipt or a payment with method Cash.",
                    "Help manual: Cash register updated.",
                ]
            ),
            release(
                "1.0.043", "08.09.2026",
                ro: [
                    "Registru de casă: sold inițial la începutul perioadei — îl completați o dată; dacă ați generat luna anterioară, soldul final se preia automat pe prima zi.",
                    "Pe Mac, Salvare și Trimitere din previzualizarea PDF nu mai deschid un ecran alb.",
                    "Manual Ajutor: Registru de casă actualizat.",
                ],
                en: [
                    "Cash register: opening balance at the start of the period — enter it once; if you generated the previous month, the closing balance is taken automatically on the first day.",
                    "On Mac, Save and Send from the PDF preview no longer open a blank screen.",
                    "Help manual: Cash register updated.",
                ]
            ),
            release(
                "1.0.042", "08.09.2026",
                ro: [
                    "Registru de casă: ultima zi din listă nu mai rămâne sub bara de jos — puteți derula și deschide PDF-ul.",
                    "După generare vedeți toate zilele din perioada aleasă, nu doar luna curentă.",
                    "Operațiunile manuale, plățile numerar furnizori și încasările numerar clienți intră în registru pe ziua de pe document.",
                    "Manual Ajutor: Registru de casă actualizat.",
                ],
                en: [
                    "Cash register: the last day in the list is no longer hidden under the bottom bar — you can scroll and open the PDF.",
                    "After generating you see every day in the selected period, not only the current month.",
                    "Manual operations, cash supplier payments and cash client collections go into the register on the document date.",
                    "Help manual: Cash register updated.",
                ]
            ),
            release(
                "1.0.041", "08.09.2026",
                ro: [
                    "Registru de casă: operațiunile nu mai dispar din listă când generați registrul. Rămân toate, cu data pe rând, și intră în registru pe ziua documentului.",
                    "Plățile numerar din Furnizori apar în aceeași listă (nu doar în PDF).",
                    "Manual Ajutor: Registru de casă actualizat.",
                ],
                en: [
                    "Cash register: operations no longer disappear from the list when you generate the register. They all stay, with the date on each row, and go into the register on the document day.",
                    "Cash supplier payments appear in the same list (not only in the PDF).",
                    "Help manual: Cash register updated.",
                ]
            ),
            release(
                "1.0.040", "08.09.2026",
                ro: [
                    "Data de pe document rămâne exact ziua introdusă: factură, NIR, scadență, registru de casă, inventar. Nu se mai mută cu o zi înapoi.",
                    "Documentele deja salvate cu ziua greșită nu se modifică singure — deschideți-le și puneți din nou data corectă.",
                    "Manual Ajutor: actualizat pentru datele de document.",
                ],
                en: [
                    "The date on a document stays the day you enter: invoice, GRN, due date, cash register, inventory. It is no longer shifted one day earlier.",
                    "Documents already saved on the wrong day are not changed automatically — open them and set the correct date again.",
                    "Help manual: updated for document dates.",
                ]
            ),
            release(
                "1.0.039", "08.09.2026",
                ro: [
                    "Clienți / Utilitare → Zetta: corectat crash-ul la derulare pe ecranul de import (tragere fișiere). Puteți derula lista fără să se închidă aplicația.",
                ],
                en: [
                    "Clients / Utilities → Zetta: fixed a crash when scrolling the import screen (file drop). You can scroll the list without the app quitting.",
                ]
            ),
            release(
                "1.0.038", "08.09.2026",
                ro: [
                    "Clienți → Zetta: același câmp ca la Utilitare — sus introduceți numărul primei note contabile, iar Excel-ul numerotează de acolo.",
                    "Manual Ajutor: Zetta actualizat pentru numerotarea notelor și la Clienți.",
                ],
                en: [
                    "Clients → Zetta: the same field as in Utilities — enter the first accounting note number at the top, and Excel numbers from there.",
                    "Help manual: Zetta updated for accounting note numbering in Clients as well.",
                ]
            ),
            release(
                "1.0.037", "08.09.2026",
                ro: [
                    "Utilitare → Creare fișier import ZETTA: sus introduceți numărul primei note contabile. În Excel, Nr. înreg. începe de acolo (ex. 1543, 1544…), câte un număr per Raport Z.",
                    "Manual Ajutor: Utilitare actualizat pentru numerotarea notelor contabile.",
                ],
                en: [
                    "Utilities → Create ZETTA import file: enter the first accounting note number at the top. In Excel, Nr. inreg. starts from there (e.g. 1543, 1544…), one number per Z report.",
                    "Help manual: Utilities updated for accounting note numbering.",
                ]
            ),
            release(
                "1.0.036", "06.09.2026",
                ro: [
                    "Lista facturi: implicit vedeți facturile create sau importate azi, indiferent de data de pe factură.",
                    "Intervalul de dată (1–31 august etc.) folosește data facturii, doar când îl activați.",
                    "Lista, preview-ul de import e-Factura și salvarea NIR sunt mai rapide — se încarcă doar ce e nevoie, nu toată baza.",
                    "Manual Ajutor: Furnizori actualizat pentru filtrul implicit și intervalul după data facturii.",
                ],
                en: [
                    "Invoice list: by default you see invoices created or imported today, regardless of the date on the invoice.",
                    "The date range (1–31 August etc.) uses the invoice date, only when you turn it on.",
                    "The list, e-Invoice import preview and GRN save are faster — only what you need is loaded, not the whole database.",
                    "Help manual: Suppliers updated for the default filter and invoice-date range.",
                ]
            ),
            release(
                "1.0.035", "05.09.2026",
                ro: [
                    "Lista facturi: se încarcă toate facturile (nu doar primele ~20) și filtrele (azi, luna, interval) folosesc data facturii, nu data importului.",
                    "La interval 1–31 august vedeți toate facturile din august, cu numărul afișat în listă. La fel la facturile clienți.",
                    "Manual Ajutor: Furnizori actualizat pentru filtrele după data facturii.",
                ],
                en: [
                    "Invoice list: all invoices are loaded (not just the first ~20) and filters (today, month, date range) use the invoice date, not the import date.",
                    "A 1–31 August range shows every August invoice, with the count in the list. Same for client invoices.",
                    "Help manual: Suppliers updated for invoice-date filters.",
                ]
            ),
            release(
                "1.0.034", "05.09.2026",
                ro: [
                    "Import e-Factura: dacă ați șters NIR-ul și factura a rămas, reimportul nu o mai omite ca duplicat — puteți genera din nou NIR-ul.",
                    "Manual Ajutor: Furnizori actualizat pentru reimport după ștergerea NIR.",
                ],
                en: [
                    "e-Invoice import: if you deleted the GRN and the invoice remained, reimport no longer skips it as a duplicate — you can create the GRN again.",
                    "Help manual: Suppliers updated for reimport after deleting a GRN.",
                ]
            ),
            release(
                "1.0.033", "31.08.2026",
                ro: [
                    "Import e-Factura: dacă articolul există deja (același cod furnizor sau cod de bare), se reia produsul existent — factura nu mai pică cu eroare de duplicat.",
                    "Dacă importul eșuează pe parcurs, factura incompletă se șterge automat ca să puteți reîncărca fișierul.",
                    "Manual Ajutor: Furnizori actualizat pentru reutilizarea articolelor la import.",
                ],
                en: [
                    "e-Invoice import: if the item already exists (same supplier code or barcode), the existing product is reused — the invoice no longer fails with a duplicate error.",
                    "If import fails mid-way, the incomplete invoice is deleted automatically so you can reload the file.",
                    "Help manual: Suppliers updated for reusing items on import.",
                ]
            ),
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
