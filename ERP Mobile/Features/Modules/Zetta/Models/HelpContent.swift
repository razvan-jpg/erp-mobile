import Foundation

enum HelpContent {
    static let pageTitle = "Ajutor — \(ZettaAppInfo.appName)"
    static let subtitle = "Ghid complet: de la bonul Z la Excel pentru NextUp"
    static let lastUpdated = "Actualizat: 17 august 2026 · v\(ZettaAppInfo.version)"
    static let pdfScanTip = "Pentru a elimina ~90% din erorile de citire de pe bonurile termice, scanează toate Rapoartele Z într-un singur fișier PDF pe care apoi îl încarci în aplicație — în loc de poze."

    struct Section: Identifiable {
        let id: String
        let title: String
        let paragraphs: [String]
        let bullets: [String]
        let screenshots: [HelpScreenshotKind]
        let tip: String?

        init(
            id: String,
            title: String,
            paragraphs: [String],
            bullets: [String],
            screenshots: [HelpScreenshotKind] = [],
            tip: String? = nil
        ) {
            self.id = id
            self.title = title
            self.paragraphs = paragraphs
            self.bullets = bullets
            self.screenshots = screenshots
            self.tip = tip
        }
    }

    enum HelpScreenshotKind: String, CaseIterable, Hashable {
        case mainScreen
        case zReportCard
        case ncPreview
        case exportBar
        case headerButtons
        case xlsxWarning
        case xlsxPicker
        case xlsxContinue

        var assetName: String {
            switch self {
            case .mainScreen: return "HelpMainScreen"
            case .zReportCard: return "HelpZReportCard"
            case .ncPreview: return "HelpNcPreview"
            case .exportBar: return "HelpExportBar"
            case .headerButtons: return "HelpHeaderButtons"
            case .xlsxWarning: return "HelpXlsxWarning"
            case .xlsxPicker: return "HelpXlsxPicker"
            case .xlsxContinue: return "HelpXlsxContinue"
            }
        }
    }

    static var manualSections: [HelpManualSection] {
        sections.map { section in
            HelpManualSection(
                id: section.id,
                title: section.title,
                paragraphs: section.paragraphs,
                bullets: section.bullets,
                screenshotAssetNames: section.screenshots.map(\.assetName),
                tip: section.tip
            )
        }
    }

    static var zettaManualDocument: HelpManualDocument {
        HelpManualDocument(
            pageTitle: pageTitle,
            subtitle: subtitle,
            versionLine: L10n.tr("help.installed_version", ZettaAppInfo.version),
            lastUpdated: lastUpdated,
            footer: footer,
            sections: manualSections
        )
    }

    static let sections: [Section] = [
        Section(
            id: "overview",
            title: "1. Ce face aplicația",
            paragraphs: [
                "\(ZettaAppInfo.appName) citește Rapoarte Z (bon fiscal tipărit sau PDF POS) și generează automat rândurile de notă contabilă în format Excel, gata de import în NextUp.",
                "Fluxul standard: import → verificare sume → export Excel → import în NextUp. Poți relua și munca pe un NC_…xlsx salvat anterior: încarcă fișierul, adaugă Z-uri noi, exportă din nou cu nume actualizat (perioadă extinsă)."
            ],
            bullets: [
                "Suportă bonuri fiscale pe hârtie (OCR din poză) și PDF-uri POS Nectarie / Complex Magnolia (citire directă din text).",
                "Recomandat: scanează bonurile termice într-un singur PDF — mult mai puține erori decât la poze.",
                "Detectează automat firma (Nectarie, Hotel Impex, alte firme din registru) și schema de NC: 10 rânduri (Nectarie) sau 8 rânduri (alte firme).",
                "Dacă societatea are Setări Zetta configurate (Setări → Setări Zetta), NC folosește conturile și cotele TVA salvate — inclusiv CARD, PLATA MODERNA, viramente și SGR/Bacșiș la 0%.",
                "Nu trimite date pe internet — totul rămâne pe dispozitivul tău."
            ],
            screenshots: [],
            tip: pdfScanTip
        ),
        Section(
            id: "start",
            title: "2. Ecranul principal",
            paragraphs: [
                "Sus în dreapta ai Ajutor. Sub titlu găsești butoanele de import și zona de drag-and-drop.",
                "Pe iPhone/iPad: Galerie, Cameră și Încarcă xlsx salvat. Pe Mac: Încarcă JPG/PDF, Încarcă xlsx salvat sau trage fișierele în zona punctată."
            ],
            bullets: [
                "Golește — șterge toate Z-urile din sesiunea curentă (inclusiv sesiunea xlsx activă).",
                "Încarcă xlsx salvat — continuă pe un Excel NC exportat anterior de \(ZettaAppInfo.appName) (vezi secțiunea 9).",
                "Versiunea aplicației apare jos.",
                "Mesajele verzi (status) confirmă importul; mesajele roșii semnalează o problemă la un fișier anume."
            ],
            screenshots: [.mainScreen],
            tip: "\(pdfScanTip)\n\nPoți importa mai multe poze/PDF-uri dintr-o singură acțiune — fiecare bon devine un card separat."
        ),
        Section(
            id: "import-photo",
            title: "3. Import din poză (bon fiscal hârtie)",
            paragraphs: [
                "Fotografiază bonul Z tipărit pe hârtie — nu ecranul telefonului și nu o captură din aplicație.",
                "Include tot bonul: antet (firmă, Z NR), mijloc (vânzări A/B/D, plăți) și subsol (DATA/ORA tipărire).",
                "Alternativa recomandată: scanează bonurile termice într-un singur PDF (secțiunea 4) — mult mai puține erori decât OCR din poză."
            ],
            bullets: [
                "Folosește zoom 2× pe cameră — cifrele trebuie să fie lizibile.",
                "Lumină uniformă, fără reflexii; ține telefonul paralel cu bonul.",
                "Un singur Raport Z per poză. Dacă ai mai multe Z-uri, scanează-le într-un PDF (o pagină = un Z).",
                "Raport X este ignorat automat dacă apare pe bon."
            ],
            screenshots: [.mainScreen],
            tip: "\(pdfScanTip)\n\nWhatsApp comprimă pozele — preferă AirDrop, Fișiere sau PDF scanat."
        ),
        Section(
            id: "import-pdf",
            title: "4. Import din PDF (POS digital)",
            paragraphs: [
                "PDF-urile exportate din POS (ex. z-report_YYYYMMDD.pdf) sunt metoda cea mai precisă: aplicația citește textul încorporat, fără OCR.",
                "La fel funcționează un PDF obținut prin scanarea bonurilor termice — o pagină per Raport Z.",
                "Pe Mac poți trage PDF-ul direct în zonă. Pe iOS, alege PDF-ul din Galerie sau Fișiere."
            ],
            bullets: [
                "Fiecare pagină PDF = un Raport Z.",
                "Recunoaște: Numerar, Credit cards, Plată modernă, BRUT A/B/D, TVA, Locația (Agro / Ploiești).",
                "Etichetă „Plata modernă” fără sumă = 0 (nu se ia Total vânzări).",
                "„Card masă”, „Bon masă”, „Voucher” fără sumă sunt ignorate — suma de card vine de la „Credit cards”.",
                "Bon echilibrat → fără avertismente false; nu ți se cere „refă poza” la PDF."
            ],
            screenshots: [],
            tip: pdfScanTip
        ),
        Section(
            id: "z-card",
            title: "5. Cardul Raport Z (verificare & editare)",
            paragraphs: [
                "După import, fiecare Z apare ca un card cu toate câmpurile extrase. Verifică badge-ul verde „Echilibrat” — înseamnă că A+B+D = Total vânzări = Numerar+Card(+Plată modernă).",
                "Poți corecta manual orice câmp dacă OCR-ul a greșit o cifră. Dacă apar multe erori, reimportă din PDF scanat în loc de poză."
            ],
            bullets: [
                "Firmă — detectată automat; CIF-ul apare dedesubt. Toggle Nectarie schimbă schema 8/10 rânduri.",
                "Tura noapte (03:00–10:00) — pentru Nectarie: data NC = ziua tipăririi minus 1 zi.",
                "Data NC — ziua notei contabile; o poți schimba din calendar.",
                "Locația — AGRONOMIEI / PLOIESTI (de pe bon).",
                "Document — cod automat: z0259 (Nectarie Ploiești) sau z0259 (alt format).",
                "Badge roșu „Diferență!” (PDF) — apasă pentru detaliu linie cu linie unde nu bat sumele."
            ],
            screenshots: [.zReportCard],
            tip: "\(pdfScanTip)\n\nDacă un câmp e 0 dar pe bon există sumă, editează manual — previzualizarea NC se actualizează instant."
        ),
        Section(
            id: "zetta-settings",
            title: "6b. Setări Zetta (ERP Mobile)",
            paragraphs: [
                "În tab-ul Setări → Setări Zetta configurezi per societate cum se generează nota contabilă din Raport Z: ture pe casă, case pe mai multe puncte de lucru, cont casă sediu, conturi CARD și PLATA MODERNA, cote TVA A–D.",
                "Setările se salvează în cloud (Supabase) pentru societatea curentă. La import Z, previzualizarea și exportul Excel folosesc aceste conturi și cote — nu doar schemele implicite Nectarie/Impex."
            ],
            bullets: [
                "Ture pe casă — număr ture dacă societatea are mai multe schimburi pe aceeași casă.",
                "Puncte de lucru — dacă ai case pe locații diferite; la creare punct de lucru în Nomenclatoare se asociază automat un depozit.",
                "Cont casă în lei (5311) și cont casă sediu — conturi editabile („Cont folosit”, max. 10 caractere).",
                "Cont încasare CARD și PLATA MODERNA — mapate pe rândurile OD din NC.",
                "Cote TVA A–D — alegi tip vânzare (marfă, servicii, bacșiș, SGR etc.) și contul de venit/taxă; cota 0% poate include doar SGR/Bacșiș.",
                "Rândurile NC cu valoare 0 nu apar în Excel; coloana Partener Cont D/C pe 4111 se completează conform setărilor."
            ],
            screenshots: [],
            tip: "Configurează Setări Zetta înainte de primul import Z al societății — evită corecții manuale repetate în previzualizare."
        ),
        Section(
            id: "nc-schema",
            title: "6. Schema notei contabile",
            paragraphs: [
                "Nectarie 20XXV: 10 rânduri per Z — JV (TVA + venituri 11%/21% + scutit), RC (numerar + viramente interne), OD (card + plată modernă).",
                "Hotel Impex: 8 rânduri — bacșiș pe 462.1, fără plată modernă, repartizare 10% bacșiș.",
                "Clinica Prometeu: vânzări 0% = servicii pe cont 704 (nu bacșiș / nu 267.1).",
                "PMT Achiziții: vânzări 0% = marfă pe cont 707 (nu bacșiș / nu 267.1).",
                "Alte firme: 8 rânduri — garanție 267.1 la scutit, casă 5311, card 5125."
            ],
            bullets: [
                "Rândurile cu valoare 0 nu apar în Excel (ex. fără TVA 21%, fără plată modernă).",
                "Nr. înreg. (NC) — 1, 2, 3… câte un număr per Z, același pe toate rândurile acelui Z.",
                "Partenerul contabil (401.x) se completează automat după firmă și locație.",
                "Coloana Partener CIF rămâne goală — cerință NextUp; nu o completa manual.",
                "Format dată în Excel: yyyy-MM-dd (compatibil NextUp)."
            ],
            screenshots: [.ncPreview],
            tip: pdfScanTip
        ),
        Section(
            id: "preview",
            title: "7. Previzualizare NC",
            paragraphs: [
                "Sub cardurile Z apare tabelul „Previzualizare notă contabilă” — exact ce va ajunge în Excel.",
                "Coloane: NC, Jurnal, Doc, Debit, Credit, Valoare, Cotă TVA."
            ],
            bullets: [
                "Derulează orizontal pe telefon pentru toate coloanele.",
                "Numărul total de rânduri = suma rândurilor tuturor Z-urilor importate.",
                "Orice editare în cardul Z regenerează previzualizarea (cu scurt delay la tastare)."
            ],
            screenshots: [.ncPreview],
            tip: pdfScanTip
        ),
        Section(
            id: "export",
            title: "8. Export Excel & NextUp",
            paragraphs: [
                "Când toate Z-urile sunt corecte, apasă Exportă Excel (Mac) sau Exportă & trimite (iOS).",
                "Dacă ai Z-uri de la firme diferite, primești câte un fișier Excel per firmă.",
                "Numele fișierului se calculează automat: NC_<Firmă>_<CUI>_<perioadă>.xlsx — ex. NC_HOTEL_IMPEX_SRL_49209086_2026-07-01_2026-07-15.xlsx când Z-urile acoperă un interval de zile."
            ],
            bullets: [
                "Mac: alegi locația și numele (propus automat cu firmă, CUI și perioada Z-urilor).",
                "iOS: share sheet — WhatsApp, AirDrop, Mail, Fișiere (nume actualizat în fișierul partajat).",
                "Import în NextUp: Contabilitate → Import note contabile din Excel — un fișier per firmă.",
                "Verifică în NextUp că partenerul și jurnalul (JV/RC/OD) sunt recunoscute.",
                "La mai multe firme în aceeași sesiune: NC_Export_<perioadă>.xlsx sau câte un fișier per firmă."
            ],
            screenshots: [.exportBar],
            tip: "\(pdfScanTip)\n\nDupă ce ai încărcat un xlsx salvat, la export Mac îți propune folderul fișierului vechi, dar numele nou reflectă perioada completă."
        ),
        Section(
            id: "xlsx-resume",
            title: "9. Continuare pe xlsx salvat",
            paragraphs: [
                "Butonul Încarcă xlsx salvat (lângă import JPG/PDF) îți permite să reluci pe un Excel NC generat anterior de \(ZettaAppInfo.appName) — util când adaugi Z-uri în zilele următoare aceleiași firme.",
                "Aplicația nu păstrează fișiere pe dispozitiv: tu gestionezi NC_…xlsx exportat (Finder, iCloud, e-mail). La reîncărcare, Z-urile din fișier apar în listă și poți adăuga altele noi."
            ],
            bullets: [
                "1) Avertisment galben 30 s (tap în afară sau așteptare) — responsabilitate: continui doar cu Z-uri ale aceleiași societăți.",
                "2) Alegi fișierul .xlsx — acceptat doar format NC exportat de \(ZettaAppInfo.appName); alt Excel → „Fisier excel incompatibil!!!”.",
                "3) Confirmare albă 10 s (roșu): „Veți continua introducerea datelor pentru: [firmă], CUI [cui]” — din numele fișierului.",
                "4) Z-urile din Excel se încarcă; adaugi PDF scanat sau poze noi — duplicate (același nr. Z + firmă) sunt ignorate automat.",
                "5) Export: Mac deschide Salvare cu nume nou (perioada extinsă); nu suprascrie silențios fișierul vechi.",
                "Alt CUI / altă firmă în aceeași sesiune → Excel separat la export (câte un fișier pe firmă)."
            ],
            screenshots: [.xlsxWarning, .xlsxPicker, .xlsxContinue],
            tip: "\(pdfScanTip)\n\nPăstrează NC_…xlsx pe firmă și perioadă; la reîncărcare folosește același fișier sau ultima versiune exportată cu același CUI în nume."
        ),
        Section(
            id: "multi",
            title: "10. Mai multe Z-uri, duplicate, firme",
            paragraphs: [
                "Poți importa batch-uri succesive — Z-urile noi se adaugă la listă și se reordonează pentru export.",
                "Duplicate: același nr. Z + aceeași firmă (CUI) = ignorat — funcționează și după încărcarea unui xlsx salvat."
            ],
            bullets: [
                "Recomandat: scanează toate Z-urile într-un singur PDF — fiecare pagină devine un card separat.",
                "O poză cu 2–3 bonuri alăturate: OCR încearcă split automat; dacă eșuează, folosește PDF scanat.",
                "PDF multi-pagină: fiecare pagină devine un Z.",
                "Schimbă manual firma/locația dacă detectarea e greșită — afectează conturile și partenerul.",
                "Golește — resetează lista și sesiunile xlsx active înainte de o lucrare nouă."
            ],
            screenshots: [],
            tip: pdfScanTip
        ),
        Section(
            id: "troubleshoot",
            title: "11. Probleme frecvente",
            paragraphs: [
                "Majoritatea problemelor la poze se rezolvă scanând bonurile termice într-un singur PDF și reimportând. La PDF echilibrat, ignoră mesajele despre „refă poza”."
            ],
            bullets: [
                "Erori OCR frecvente — scanează Z-urile într-un PDF (o pagină = un Z) în loc de poze.",
                "„Nu recunosc Raport Z” — poză tăiată, neclară sau nu e bon Z.",
                "„Ai fotografiat ecranul aplicației” — fotografiază bonul hârtie, nu telefonul.",
                "„Fisier excel incompatibil!!!” — fișierul nu e NC exportat de \(ZettaAppInfo.appName); folosește doar NC_…xlsx generate de aplicație.",
                "Export eșuat după xlsx — alege locație cu drept de scriere; numele propus include perioada nouă (poate diferi de fișierul încărcat).",
                "„Diferență!” — verifică BRUT A/B/D vs plăți; editează manual sau reimportă PDF.",
                "Plată modernă greșită — pe PDF trebuie să fie suma de pe rând; lipsă = 0.",
                "Data NC greșită la tura noapte — verifică toggle „Tura noapte” și ora „Până la” de pe bon.",
                "Acces cameră refuzat (iOS) — Setări → \(ZettaAppInfo.appName) → Cameră."
            ],
            screenshots: [.headerButtons],
            tip: "\(pdfScanTip)\n\nContact: \(ZettaAppInfo.contactEmail) — menționează versiunea \(ZettaAppInfo.version) și atașează PDF-ul sau poza."
        )
    ]

    static let footer = "\(ZettaAppInfo.appName) · \(ZettaAppInfo.authorName) · \(ZettaAppInfo.contactEmail)"
}
