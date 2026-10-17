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
            footerRomanian: "ERP Mobile · DATECONTA.RO · 17 octombrie 2026",
            footerEnglish: "ERP Mobile · DATECONTA.RO · October 17, 2026"
        )
    }

    /// Planificat pentru versiunea următoare — nu tot ce e aici va fi livrat; la release mută ce s-a făcut.
    private static var upcoming: WhatsNewUpcoming {
        WhatsNewUpcoming(
            targetVersionLabel: "1.0.421",
            romanianItems: [
                "BINA Smart Business: stabilizare lista Rapoarte Z in perioada si descarcare batch PDF-uri in romana (validare finala).",
                "Extragere Rapoarte Z: conectori Memgest, BOCP si Generic HTTP (pe langa BINA).",
                "Preluare BF din BINA: import linii detaliate pe bon (dincolo de sloturile generate din Documente Z).",
                "Manual Ajutor: capturi de ecran reale din modul Registru de casa.",
                "MT940: sabloane suplimentare de parsare extras banca (formate banci romanesti).",
                "Registru de casa: export direct in folder (ca la Rapoarte Z), fine-tuning pixel-perfect pe model PDF.",
            ],
            englishItems: [
                "BINA Smart Business: stabilize Z report listing by date range and batch Romanian PDF download (final validation).",
                "Z report extraction: Memgest, BOCP, and Generic HTTP connectors (in addition to BINA).",
                "BINA BF import: detailed receipt line items (beyond slots generated from Z Documents).",
                "Help manual: real in-app screenshots for the Cash register module.",
                "MT940: additional bank statement parsing templates (Romanian bank formats).",
                "Cash register: direct folder export (like Z reports), pixel-perfect PDF template tuning.",
            ]
        )
    }

    private static var releases: [WhatsNewRelease] {
        [
            release(
                "1.0.420", "17.10.2026",
                ro: [
                    "Raport Produse arată produsele pe grupe, cu prețul de vânzare și totalul liniei. Garanția SGR este grupa ei. Fiecare grupă are subtotal, iar la final este totalul general.",
                ],
                en: [
                    "Product report lists the products by group, with the sale price and the line total. The SGR deposit is its own group. Each group has a subtotal, and the report ends with the grand total.",
                ]
            ),
            release(
                "1.0.419", "17.10.2026",
                ro: [
                    "La bonul de consum, după dată alegeți tura: 1 — ziua sau 2 — noapte. După aprobare, consumul scade din foaia de stoc a acelei date și a acelei ture.",
                ],
                en: [
                    "On a consumption note, after the date you choose the shift: 1 — day or 2 — night. After approval, the consumption is taken from the stock sheet of that date and shift.",
                ]
            ),
            release(
                "1.0.418", "17.10.2026",
                ro: [
                    "În Raport Produse, după ce alegeți Z-ul, butonul Print listează produsele vândute pe casa de marcat.",
                ],
                en: [
                    "In Product report, after you pick a Z, Print sends the sold products to the fiscal printer.",
                ]
            ),
            release(
                "1.0.417", "17.10.2026",
                ro: [
                    "La închiderea turei, ecranul de așteptare alege la întâmplare: cifre verzi care curg, sau un zbor printre formule și cod Swift, C# și ASP.NET. Mesajul alb rămâne același.",
                ],
                en: [
                    "When the shift closes, the wait screen picks at random: falling green digits, or a flight through formulas and Swift, C#, and ASP.NET code. The white message stays the same.",
                ]
            ),
            release(
                "1.0.416", "17.10.2026",
                ro: [
                    "La închiderea turei, ecranul arată cifre verzi care curg și mesajul „Asteptati pentru inchiderea turei !!!” pe primul rând și „Calculez !!!” pe al doilea. Rămâne cât durează calculul, cel puțin 15 secunde.",
                ],
                en: [
                    "When the shift closes, the screen shows falling green digits and a two-line wait message. It stays for the whole calculation, at least 15 seconds.",
                ]
            ),
            release(
                "1.0.415", "17.10.2026",
                ro: [
                    "Pe foaia de stoc, profitul unui produs finit scade costul rețetei din vânzare. Bonurile de producție și foile au fost recalculate cu rețetele actuale.",
                ],
                en: [
                    "On the stock sheet, a finished good's profit subtracts the recipe cost from the sale. Production notes and stock sheets were recalculated with the current recipes.",
                ]
            ),
            release(
                "1.0.414", "17.10.2026",
                ro: [
                    "Ieșire din POS vă aduce direct la tile-urile Producție, POS și Foaie stoc.",
                ],
                en: [
                    "Exit from POS returns straight to the Production, POS, and Stock sheet tiles.",
                ]
            ),
            release(
                "1.0.413", "17.10.2026",
                ro: [
                    "MB3 100/SET (6421735000161) este unificat pe BFG 100 CASEROLE MB XPS 3COMP (396905). Stocul a trecut pe fișa principală. Intrările viitoare cu acest nume sau cod se leagă tot acolo.",
                ],
                en: [
                    "MB3 100/SET (6421735000161) is merged into BFG 100 CASEROLE MB XPS 3COMP (396905). Stock moved onto the main sheet. Future receipts with that name or code link there too.",
                ]
            ),
            release(
                "1.0.412", "17.10.2026",
                ro: [
                    "În rețetele la farfurie (shaorma, shaormaxx, crispy, aripioare și șnițel) intră caserola (1 buc.) și furculița (1 buc.).",
                ],
                en: [
                    "Plate recipes (shawarma, shaormaxx, crispy, wings, and schnitzel) now include the tray (1 pc) and the fork (1 pc).",
                ]
            ),
            release(
                "1.0.411", "17.10.2026",
                ro: [
                    "În rețeta PITA EXTRA intră colțarul (0,004 kg).",
                ],
                en: [
                    "The PITA EXTRA recipe now includes the corner wrap (0.004 kg).",
                ]
            ),
            release(
                "1.0.410", "17.10.2026",
                ro: [
                    "În rețetele SOS CURRY, KETCHUP, SAMURAI, TZATZIKI și USTUROI intră sosiera (1 buc.).",
                ],
                en: [
                    "SOS CURRY, KETCHUP, SAMURAI, TZATZIKI, and USTUROI recipes now include the sauce cup (1 pc).",
                ]
            ),
            release(
                "1.0.409", "17.10.2026",
                ro: [
                    "În rețetele MAXX BUCKET ARIPIOARE, CRISPY și MIXT intră și furculița (1 buc.).",
                ],
                en: [
                    "MAXX BUCKET ARIPIOARE, CRISPY, and MIXT recipes now also include the fork (1 pc).",
                ]
            ),
            release(
                "1.0.408", "17.10.2026",
                ro: [
                    "În rețetele MAXX BUCKET ARIPIOARE, CRISPY și MIXT intră cutia de carton 2500 (1 buc.).",
                ],
                en: [
                    "MAXX BUCKET ARIPIOARE, CRISPY, and MIXT recipes now include the 2500 carton (1 pc).",
                ]
            ),
            release(
                "1.0.407", "17.10.2026",
                ro: [
                    "În rețetele BOX PUI, BOX VITA și BOX MIXT intră cutia (1 buc.) și furculița (1 buc.).",
                ],
                en: [
                    "BOX PUI, BOX VITA, and BOX MIXT recipes now include the carton (1 pc) and the fork (1 pc).",
                ]
            ),
            release(
                "1.0.406", "17.10.2026",
                ro: [
                    "În rețetele de shaorma, chifle, sandwich, cheese kebab și falafel intră colțarul (0,004 kg) și hârtia (0,005 kg).",
                ],
                en: [
                    "Shawarma, bun, sandwich, cheese kebab, and falafel recipes now include the corner wrap (0.004 kg) and the paper (0.005 kg).",
                ]
            ),
            release(
                "1.0.405", "17.10.2026",
                ro: [
                    "Articol nou LIPIA CASEI, produs finit, în afara catalogului. Rețeta pentru o bucată: 0,05 kg făină, 0,0005 kg drojdie, 0,001 kg sare, 0,0015 l ulei și 0,0005 kg zahăr.",
                ],
                en: [
                    "New article LIPIA CASEI, a finished good, outside the catalog. The recipe for one piece: 0.05 kg flour, 0.0005 kg yeast, 0.001 kg salt, 0.0015 l oil, and 0.0005 kg sugar.",
                ]
            ),
            release(
                "1.0.404", "17.10.2026",
                ro: [
                    "Pe foaia de stoc, DONER PUI apare la materii prime și ambalaje, chiar dacă articolul este produs finit.",
                ],
                en: [
                    "On the stock sheet, DONER PUI is listed with raw materials and packaging, even though the article is a finished good.",
                ]
            ),
            release(
                "1.0.403", "17.10.2026",
                ro: [
                    "Un produs finit folosit în altă rețetă se scade din stocul lui. Rețeta lui se folosește doar pe bonul de producție care îl face. Bonurile automate de la închiderea turei și foile de stoc au fost recalculate.",
                ],
                en: [
                    "A finished good used in another recipe is taken from its own stock. Its recipe is used only on the production note that makes it. Automatic end-of-shift production notes and stock sheets were recalculated.",
                ]
            ),
            release(
                "1.0.402", "17.10.2026",
                ro: [
                    "În Administrator, filtrul de dată are Toate pe Bonuri, Z-uri, Facturi, Foi de stoc și Bonuri de consum. Toate este ales la deschidere.",
                ],
                en: [
                    "In Administrator, the date filter has All on Receipts, Z reports, Invoices, Stock sheets, and Consumption vouchers. All is selected when you open the list.",
                ]
            ),
            release(
                "1.0.401", "17.10.2026",
                ro: [
                    "În Administrator, Bonuri, Z-uri, Facturi și Bonurile de consum se filtrează după punctul de lucru și după dată. Data pornește de azi.",
                ],
                en: [
                    "In Administrator, Receipts, Z reports, Invoices, and Consumption vouchers filter by location and by date. The date starts on today.",
                ]
            ),
            release(
                "1.0.400", "17.10.2026",
                ro: [
                    "La fiecare raport Z, baza și TVA-ul pe cote se calculează din vânzările acelui Z, de fiecare dată când îl deschizi, din Vânzări sau din Administrator.",
                ],
                en: [
                    "On every Z report, the base and VAT per rate are calculated from that Z's sales each time you open it, from Sales or from Administrator.",
                ]
            ),
            release(
                "1.0.399", "17.10.2026",
                ro: [
                    "Pe raportul Z, baza și TVA-ul pe fiecare cotă sunt calculate din vânzările acelui Z, la fel în Vânzări și în Administrator.",
                ],
                en: [
                    "On a Z report, the base and VAT for each rate are calculated from that Z's sales, both in Sales and in Administrator.",
                ]
            ),
            release(
                "1.0.398", "16.10.2026",
                ro: [
                    "La click pe un raport Z se deschide pagina ca la casa: firmă, perioadă, încasări și TVA. Același document se descarcă PDF.",
                ],
                en: [
                    "Tapping a Z report opens the page used by the register: company, period, takings and VAT. The same document is downloaded as PDF.",
                ]
            ),
            release(
                "1.0.397", "16.10.2026",
                ro: [
                    "Raportul Z emis de la POS apare și în Vânzări, la Rapoarte Z, cu numerarul, cardul și plata modernă de pe casă.",
                ],
                en: [
                    "A Z report issued by the POS also appears in Sales, under Z reports, with the cash, card, and modern takings from the register.",
                ]
            ),
            release(
                "1.0.396", "16.10.2026",
                ro: [
                    "În Administrator, click pe un bon deschide PDF-ul acelui Z, nu pe cel din Z-ul curent. La Z-uri apar doar rapoartele emise de POS; click-ul le deschide, cu listare și descărcare PDF. Bonurile de consum sunt împărțite în De aprobat și Finalizate.",
                ],
                en: [
                    "In Administrator, tapping a receipt opens that Z report's PDF, not the one from the current Z. Z reports lists only the ones issued by the POS; a tap opens them, with print and PDF download. Consumption vouchers are split into To approve and Completed.",
                ]
            ),
            release(
                "1.0.395", "16.10.2026",
                ro: [
                    "Pe Acasă, după Nomenclatoare, administratorul și super-administratorul văd tile-ul Administrator: vânzări (bonuri, Z-uri și facturi), foi de stoc și bonuri de consum, pe toate punctele, cu căutare. Bonurile de consum se aprobă pe tot bonul sau pe linii.",
                ],
                en: [
                    "On Home, after Nomenclatoare, the administrator and super administrator see the Administrator tile: sales (receipts, Z reports, and invoices), stock sheets, and consumption vouchers, for every location, with search. Consumption vouchers can be approved for the whole voucher or line by line.",
                ]
            ),
            release(
                "1.0.394", "16.10.2026",
                ro: [
                    "La vânzarea modernă, discountul de pe bon se scrie în lei.",
                ],
                en: [
                    "On a modern sale, the receipt discount is an amount in lei.",
                ]
            ),
            release(
                "1.0.393", "16.10.2026",
                ro: [
                    "Raport Produse se vede și de către casier, fără drepturi de administrator.",
                ],
                en: [
                    "Product report is visible to the cashier, without administrator rights.",
                ]
            ),
            release(
                "1.0.392", "16.10.2026",
                ro: [
                    "Raport Produse arată produsele vândute, pe Z-ul închis și pe Z-ul curent.",
                ],
                en: [
                    "Product report shows the products sold, for a closed Z and for the current Z.",
                ]
            ),
            release(
                "1.0.391", "16.10.2026",
                ro: [
                    "Raport Produse se deschide peste ecranul POS, în fereastra aplicației.",
                ],
                en: [
                    "Product report opens over the POS screen, inside the application window.",
                ]
            ),
            release(
                "1.0.390", "16.10.2026",
                ro: [
                    "Raport Produse arată lista de Z-uri și, după alegere, produsele vândute.",
                ],
                en: [
                    "Product report shows the Z list and, after you choose one, the products sold.",
                ]
            ),
            release(
                "1.0.389", "16.10.2026",
                ro: [
                    "Pe POS, înainte de + Numerar, este Raport Produse. Alegeți Z-ul. Primul este Z-ul curent, În lucru - Neînchis. Se vede lista produselor vândute. Înapoi și Închide sunt în fereastră.",
                ],
                en: [
                    "On the POS, before + Cash, there is Product report. Choose the Z. The first is the current Z, In progress - Not closed. You see the products sold. Back and Close are in the window.",
                ]
            ),
            release(
                "1.0.388", "16.10.2026",
                ro: [
                    "Pe bon, butonul × care scoate produsul este mai mare, ca să se apese ușor.",
                ],
                en: [
                    "On the receipt, the × button that removes a product is larger, so it is easy to press.",
                ]
            ),
            release(
                "1.0.387", "16.10.2026",
                ro: [
                    "Pe ecranul POS, înainte de Raport X, sunt + Numerar și - Numerar. Se cere suma, pe Windows cu tastatura numerică, iar la OK casa bagă sau scoate banii.",
                ],
                en: [
                    "On the POS screen, before the X report, there are + Cash and - Cash. The amount is asked, on Windows with a numeric keypad, and at OK the register puts the money in or takes it out.",
                ]
            ),
            release(
                "1.0.386", "16.10.2026",
                ro: [
                    "Jos pe foaia de stoc, după centralizări, se trage o linie și urmează Consumuri: aprobate și scăzute din stoc, cu produs și explicație, apoi neaprobate, încă nescăzute. Intră și liniile parțiale.",
                ],
                en: [
                    "At the bottom of the stock sheet, after the totals, a line is drawn and then Consumptions: approved and deducted from stock, with the product and the explanation, then unapproved, not yet deducted. Partial lines are included.",
                ]
            ),
            release(
                "1.0.385", "16.10.2026",
                ro: [
                    "Pe foaia de stoc, lângă dată, apare ora la care s-a emis Z-ul. Se aplică și foii deja create.",
                ],
                en: [
                    "On the stock sheet, next to the date, the time the Z was issued is shown. This also applies to a sheet already created.",
                ]
            ),
            release(
                "1.0.384", "16.10.2026",
                ro: [
                    "Pe bară au intrat cei 40 lei numerar și 36 lei card listați de casă și lipsiți din program. Încasarea se scrie pe bară imediat ce casa a listat bonul.",
                ],
                en: [
                    "The bar now includes the 40 lei cash and 36 lei card that the register printed and the program was missing. The taking is written on the bar as soon as the register prints the receipt.",
                ]
            ),
            release(
                "1.0.383", "16.10.2026",
                ro: [
                    "Pe bara de jos a casei, Glovo, Bolt și Wolt apar adunate la Modernă, în loc de G, B și W.",
                ],
                en: [
                    "On the cashier bottom bar, Glovo, Bolt and Wolt are added together as Modern, instead of G, B and W.",
                ]
            ),
            release(
                "1.0.382", "16.10.2026",
                ro: [
                    "Pe foaia de stoc apare categoria Garanție cu SGR, numai pe valori, fără cantități de stoc, ca totalul să fie egal cu Z-ul. Ultimul rând este Bani de predat, cu suma din numerar. Se aplică și foii deja create.",
                ],
                en: [
                    "The stock sheet shows the Guarantee category with the SGR, on the values only, with no stock quantities, so the total matches the Z. The last row is Bani de predat, with the cash amount. This also applies to a sheet already created.",
                ]
            ),
            release(
                "1.0.381", "16.10.2026",
                ro: [
                    "Jos pe foaia de stoc sunt încasările: numerar, card și modernă (Glovo, Bolt, Wolt), apoi comparația cu Z-ul: foaie, Z și diferența. Se aplică și foii deja create.",
                ],
                en: [
                    "At the bottom of the stock sheet are the takings: cash, card and modern (Glovo, Bolt, Wolt), then the comparison with the Z: sheet, Z and the difference. This also applies to a sheet already created.",
                ]
            ),
            release(
                "1.0.380", "16.10.2026",
                ro: [
                    "Taxa de ambalaj apare pe foaia de stoc și intră în total. Z 389 din program este 517 lei, ca pe hârtie. O încasare fără bon listat pe casă nu intră în total și nici în Z.",
                ],
                en: [
                    "The packaging tax appears on the stock sheet and enters the total. Z 389 in the program is 517 lei, matching the paper. A taking without a receipt printed by the register is not in the total and not in the Z.",
                ]
            ),
            release(
                "1.0.379", "16.10.2026",
                ro: [
                    "Pe foaia de stoc, la tura 2 data scrisă este cu o zi în urmă. Se aplică și foii deja create.",
                ],
                en: [
                    "On the stock sheet, shift 2 writes the date as the previous day. This also applies to a sheet already created.",
                ]
            ),
            release(
                "1.0.378", "16.10.2026",
                ro: [
                    "Foaia de stoc arată totalul pe Val. magazin, Val. online și Profit, pe fiecare categorie și un total general. Se aplică și foii deja create.",
                ],
                en: [
                    "The stock sheet shows a total on store value, online value and profit, for each category and a grand total. This also applies to a sheet already created.",
                ]
            ),
            release(
                "1.0.377", "16.10.2026",
                ro: [
                    "Pe Windows, animația de la pornire a fost scoasă. Programul se deschide direct.",
                ],
                en: [
                    "On Windows, the startup animation is gone. The program opens directly.",
                ]
            ),
            release(
                "1.0.376", "16.10.2026",
                ro: [
                    "Foaia de stoc, inclusiv cea deja creată, arată doar produsele cu intrări sau ieșiri. Se deschide mare, pe tot ecranul, ca să o citiți, să o listați sau să o salvați.",
                ],
                en: [
                    "The stock sheet, including one already created, shows only products with inflows or outflows. It opens large, full screen, so you can read it, print it or save it.",
                ]
            ),
            release(
                "1.0.375", "16.10.2026",
                ro: [
                    "Factura AGRO 9 a fost acceptată în e-Factura. Pe listă apar id-ul de încărcare și id-ul de descărcare. XML-ul pune județul și sectorul din adresă, ca ANAF să o accepte.",
                ],
                en: [
                    "Invoice AGRO 9 was accepted in e-Factura. The list shows the upload id and the download id. The XML now sends the county and sector from the address, so ANAF accepts it.",
                ]
            ),
            release(
                "1.0.374", "16.10.2026",
                ro: [
                    "La Foaie stoc, un click pe foaia creată deschide PDF-ul în formatul foii, ca să o listați sau să o salvați.",
                ],
                en: [
                    "In Stock sheet, a click on a created sheet opens the PDF in the sheet layout, so you can print it or save it.",
                ]
            ),
            release(
                "1.0.372", "16.10.2026",
                ro: [
                    "Vânzări → Facturi este un tabel: număr, dată, client, CUI, total, stare, e-Factura, id încărcare și id descărcare. Un click deschide PDF-ul. Facturile noi se încarcă automat în SPV.",
                ],
                en: [
                    "Sales → Invoices is a table: number, date, client, tax id, total, status, e-Factura, upload id and download id. A click opens the PDF. New invoices upload to SPV automatically.",
                ]
            ),
            release(
                "1.0.371", "16.10.2026",
                ro: [
                    "Încasările Z 389 au ieșit din bara POS. Factura AGRO 9 către First Consulting (cf BF 9) este în Vânzări → Facturi și se trimite în e-Factura SPV.",
                    "Pe lista de facturi vedeți starea e-Factura și cele două id-uri ANAF: încărcare și descărcare. Factura de la casă intră singură în listă.",
                ],
                en: [
                    "Z 389 takings left the POS bar. Invoice AGRO 9 to First Consulting (from receipt 9) is in Sales → Invoices and is sent to e-Factura SPV.",
                    "The invoice list shows the e-Factura status and the two ANAF ids: upload and download. The register invoice is saved in the list.",
                ]
            ),
            release(
                "1.0.370", "16.10.2026",
                ro: [
                    "Pe bara de jos a POS-ului, după încasări, scrie BF = și numărul următorului bon fiscal.",
                ],
                en: [
                    "On the POS bottom bar, after the takings, BF = shows the number of the next fiscal receipt.",
                ]
            ),
            release(
                "1.0.369", "16.10.2026",
                ro: [
                    "În Vânzări → Rapoarte Z, un click pe Z deschide PDF-ul raportului, cu numărul, data și încasările.",
                ],
                en: [
                    "In Sales → Z reports, a click on a Z opens the report PDF, with the number, date and takings.",
                ]
            ),
            release(
                "1.0.368", "16.10.2026",
                ro: [
                    "În Vânzări → Bonuri, un click pe bon deschide PDF-ul listat de casă, cu liniile, prețurile și încasarea.",
                ],
                en: [
                    "In Sales → Receipts, a click on a receipt opens the PDF printed by the register, with the lines, prices and payment.",
                ]
            ),
            release(
                "1.0.367", "16.10.2026",
                ro: [
                    "Pe bonul de transfer, cantitatea e în câmp galben, ca să se vadă că se scrie. Dacă alegeți Ploiești, destinația se completează cu Agronomie, și invers. Bonul se salvează și dacă stocul devine negativ.",
                ],
                en: [
                    "On the transfer note, the quantity is in a yellow field so it is clear you can type. If you pick Ploiești, the destination fills with Agronomie, and the other way around. The note is saved even if stock goes negative.",
                ]
            ),
            release(
                "1.0.366", "16.10.2026",
                ro: [
                    "Pe bonul de transfer, cantitatea se scrie în câmpul de sub articol. Butonul 123 deschide tastatura numerică.",
                ],
                en: [
                    "On the transfer note, type the quantity in the field under the article. The 123 button opens the numeric keypad.",
                ]
            ),
            release(
                "1.0.364", "16.10.2026",
                ro: [
                    "Pe bonul de transfer apar și produsele finite, inclusiv DONER PUI. După producție la Ploiești, îl alegeți pe bon și îl trimiteți la Agronomie.",
                ],
                en: [
                    "Transfer notes now include finished goods, including DONER PUI. After production in Ploiești, pick it on the note and send it to Agronomie.",
                ]
            ),
            release(
                "1.0.365", "16.10.2026",
                ro: [
                    "La Raport Z, condimentul din reteta se scade si cand cantitatea este foarte mica. Se pastreaza cu 6 zecimale, sau cu 8 daca 6 nu ajung. Stocul poate ajunge negativ.",
                ],
                en: [
                    "At Report Z, a very small recipe quantity is still consumed. It is kept with 6 decimal places, or 8 when 6 are not enough. Stock can go negative.",
                ]
            ),
            release(
                "1.0.363", "16.10.2026",
                ro: [
                    "La Raport Z, un condiment din reteta mai mic de 0,0001 nu mai opreste inchiderea. Daca foaia nu s-a salvat dupa ce casa a listat Z-ul, apasati din nou Raport Z: casa nu mai listeaza, se salveaza foaia, se golesc incasarile si Z-ul intra la Vanzari.",
                ],
                en: [
                    "At Report Z, a recipe quantity under 0.0001 no longer stops the close. If the sheet was not saved after the register printed the Z, press Report Z again: it does not print again, the sheet is saved, the takings go back to 0, and the Z appears in Sales.",
                ]
            ),
            release(
                "1.0.362", "16.10.2026",
                ro: [
                    "Dupa ce casa listeaza bonul fiscal, ecranul de vanzare revine la alegerea categoriei, pentru bonul urmator.",
                ],
                en: [
                    "After the cash register prints the fiscal receipt, the sale screen returns to the category choice for the next receipt.",
                ]
            ),
            release(
                "1.0.361", "16.10.2026",
                ro: [
                    "Casierul vede seria de factura a punctului lui, fara drept de administrator. La Agronomie, Emite bon si FF foloseste seria AGRO.",
                ],
                en: [
                    "The cashier sees the invoice series of their location, without administrator rights. At Agronomie, Issue receipt and invoice uses the AGRO series.",
                ]
            ),
            release(
                "1.0.360", "16.10.2026",
                ro: [
                    "La card nu se mai trimite nimic la POS-ul bancar. Marcati suma manual. Daca spuneti ca plata a reusit, casa listeaza bonul.",
                ],
                en: [
                    "On card, nothing is sent to the bank POS. Mark the amount yourself. If you say the payment went through, the register prints the receipt.",
                ]
            ),
            release(
                "1.0.359", "16.10.2026",
                ro: [
                    "La card, suma pleaca intai la terminalul bancar. Daca banca accepta, casa listeaza bonul si il inregistreaza, ca inainte.",
                ],
                en: [
                    "On card, the amount goes to the bank terminal first. If the bank accepts, the register prints the receipt and records it, as before.",
                ]
            ),
            release(
                "1.0.358", "16.10.2026",
                ro: [
                    "Bonul fiscal pleaca direct la casa. Nu se mai opreste inainte de listare din cauza unei comenzi separate catre terminalul de card.",
                ],
                en: [
                    "The fiscal receipt goes straight to the register. It no longer stops before printing because of a separate command to the card terminal.",
                ]
            ),
            release(
                "1.0.357", "16.10.2026",
                ro: [
                    "Pe Windows, la bonul de consum, cantitatea deschide tastatura numerica.",
                ],
                en: [
                    "On Windows, the quantity on a consumption note opens a numeric keypad.",
                ]
            ),
            release(
                "1.0.356", "16.10.2026",
                ro: [
                    "Bonul fiscal se listeaza din nou fara sa astepte confirmarea operatorului. Dupa fiecare bon apare fereastra cu numarul si se inchide singura.",
                ],
                en: [
                    "The fiscal receipt prints again without waiting for the operator to confirm. After each receipt, the window with the number appears and closes by itself.",
                ]
            ),
            release(
                "1.0.355", "16.10.2026",
                ro: [
                    "Pe Windows, cantitatea de pe bonul de productie si de pe bonul de transfer deschide tastatura numerica. La plata cu cardul, fereastra sta in fata: dupa Plata a reusit, casa listeaza bonul si il inregistreaza.",
                ],
                en: [
                    "On Windows, the quantity on a production note and on a transfer note opens the numeric keypad. On card payment the confirmation stays in front: after Payment went through, the register prints the receipt and records it.",
                ]
            ),
            release(
                "1.0.354", "16.10.2026",
                ro: [
                    "Pe Windows, la bonul de productie si la bonul de transfer, cantitatea deschide tastatura numerica.",
                ],
                en: [
                    "On Windows, the quantity on a production note and on a transfer note opens a numeric keypad.",
                ]
            ),
            release(
                "1.0.353", "16.10.2026",
                ro: [
                    "La plata cu cardul, fereastra „Plata a reușit” apare din nou, ca să confirmați încasarea. După confirmare, casa listează bonul și îl închide, fără mesajul OK cu numărul bonului.",
                ],
                en: [
                    "On card payment, the “Payment went through” window appears again so you can confirm the charge. After you confirm, the register prints the receipt and closes it, without the OK message with the receipt number.",
                ]
            ),
            release(
                "1.0.352", "16.10.2026",
                ro: [
                    "Raportul X nu mai cere OK după listare. La Raport Z rămâne doar ecranul de așteptare până se închide tura, apoi dispare singur.",
                ],
                en: [
                    "The X report no longer asks for OK after printing. For the Z report, only the waiting overlay stays until the shift closes, then it disappears on its own.",
                ]
            ),
            release(
                "1.0.351", "16.10.2026",
                ro: [
                    "După listarea bonului pe casa de marcat, nu mai apare mesajul cu numărul bonului. Trebuie să apăsați OK doar dacă ceva nu a mers.",
                ],
                en: [
                    "After the cash register prints a receipt, the receipt-number message no longer appears. You only tap OK if something went wrong.",
                ]
            ),
            release(
                "1.0.350", "16.10.2026",
                ro: [
                    "Tabul Bonuri din Vanzari incarca bonurile din Z-ul curent si din Z-ul ales din lista.",
                ],
                en: [
                    "The Sales Receipts tab loads fiscal receipts for the current Z and for a saved Z picked from the list.",
                ]
            ),
            release(
                "1.0.349", "16.10.2026",
                ro: [
                    "In Vanzari, langa Rapoarte Z, tabul Bonuri arata bonurile fiscale din Z-ul curent si dintr-un Z salvat ales din lista.",
                ],
                en: [
                    "In Sales, next to Z reports, the Receipts tab lists fiscal receipts from the current Z and from a saved Z picked from the list.",
                ]
            ),
            release(
                "1.0.348", "15.10.2026",
                ro: [
                    "La importul XML, accesul la folder se pastreaza. Cand folderul de facturi se schimba, il alegi din nou, o data pentru folderul nou.",
                ],
                en: [
                    "On XML import, folder access stays saved. When the invoice folder changes, choose the new folder once.",
                ]
            ),
            release(
                "1.0.347", "15.10.2026",
                ro: [
                    "La importul XML, fisierul primeste in fata importata_ si cand nu faci NIR, inclusiv daca factura era deja in lista.",
                ],
                en: [
                    "On XML import, the file gets importata_ in front of its name even without a goods receipt, including when the invoice is already in the list.",
                ]
            ),
            release(
                "1.0.346", "15.10.2026",
                ro: [
                    "Dupa importul unei facturi XML, fisierul primeste in fata importata_, fie ca se face NIR, fie ca nu.",
                ],
                en: [
                    "After an invoice XML is imported, the file gets importata_ in front of its name, whether a goods receipt is created or not.",
                ]
            ),
            release(
                "1.0.345", "15.10.2026",
                ro: [
                    "La Raport Z, numerarul intra in registrul punctului de lucru si aceeasi suma pleaca ca transfer in casa sediu. La sediu se trece incasarea; daca nu exista registru in acea data, se creeaza cu soldul anterior din ultimul registru de sediu. Chitanta de la NIR platit cash este plata in casa sediu, la data facturii.",
                ],
                en: [
                    "On a Z report, cash is posted to that location's cash register and the same amount leaves as a transfer to headquarters. Headquarters records the receipt; if that date has no register, one is created with the opening balance from the previous headquarters register. A cash goods-receipt chit is a headquarters payment on the invoice date.",
                ]
            ),
            release(
                "1.0.344", "15.10.2026",
                ro: [
                    "Pe fisa articolului, ingredientele din reteta stau alfabetic dupa denumire. Le poti trage in sus sau in jos, iar ordinea ramane salvata.",
                ],
                en: [
                    "On the article sheet, recipe ingredients start in alphabetical order by name. Drag one up or down and that order stays saved.",
                ]
            ),
            release(
                "1.0.343", "15.10.2026",
                ro: [
                    "Reteta deschisa din fisa articolului ramane pe ecran pana o inchizi.",
                ],
                en: [
                    "A recipe opened from the article sheet stays on screen until you close it.",
                ]
            ),
            release(
                "1.0.342", "15.10.2026",
                ro: [
                    "Pe fisa articolului, daca exista reteta, butonul Vezi reteta / PDF o deschide si o salveaza in PDF.",
                ],
                en: [
                    "On the article sheet, when a recipe exists, View recipe / PDF opens it and saves it as a PDF.",
                ]
            ),
            release(
                "1.0.341", "15.10.2026",
                ro: [
                    "Importul de facturi XML din folder merge si pe iPhone si iPad.",
                ],
                en: [
                    "Importing invoice XML files from a folder also works on iPhone and iPad.",
                ]
            ),
            release(
                "1.0.340", "15.10.2026",
                ro: [
                    "Listele de produse, facturi si stocuri se deschid mai repede.",
                ],
                en: [
                    "Product, invoice, and stock lists open faster.",
                ]
            ),
            release(
                "1.0.339", "15.10.2026",
                ro: [
                    "Listele de facturi, produse si stocuri se incarca mai repede.",
                ],
                en: [
                    "Invoice, product, and stock lists load faster.",
                ]
            ),
            release(
                "1.0.338", "15.10.2026",
                ro: [
                    "Manualul casierului este fara diacritice. Textul si pozele nu mai au patratele.",
                ],
                en: [
                    "The cashier manual has no Romanian diacritics. The text and pictures no longer show empty boxes.",
                ]
            ),
            release(
                "1.0.337", "15.10.2026",
                ro: [
                    "După ce NIR-ul făcut dintr-un XML de factură este salvat ca PDF, fișierul XML rămâne în același loc și primește în față importat_.",
                ],
                en: [
                    "After the goods receipt made from an invoice XML is saved as a PDF, the XML file stays in the same place and gets importat_ in front of its name.",
                ]
            ),
            release(
                "1.0.336", "15.10.2026",
                ro: [
                    "Ajutorul casierului explică, în română și în engleză, fiecare apăsare: CUI pe bon, factura odată cu bonul, numerar, card, numerar + card și plata modernă, ștergerea unui articol, până la 4 bonuri, Raport Z numai după ce bonurile sunt închise, bonul de producție pentru DONER PUI, transferul către Agronomie și bonul de consum. La fiecare pas este o poză cu butonul de apăsat. Privacy, Termeni, Politica GDPR și Despre se deschid în același ecran.",
                ],
                en: [
                    "Cashier Help explains every press in Romanian and English: tax number on the receipt, the invoice together with the receipt, cash, card, cash + card and modern payment, deleting an article, up to 4 receipts, Report Z only after the receipts are closed, the production note for DONER PUI, the transfer to Agronomie, and the consumption note. Each step has a picture of the button to press. Privacy, Terms, GDPR policy and About open on the same screen.",
                ]
            ),
            release(
                "1.0.335", "15.10.2026",
                ro: [
                    "Un bon de consum aprobat după foaia de stoc recalculează foile de la data bonului până la ultima foaie emisă. La fel la redeschidere sau ștergere.",
                ],
                en: [
                    "A consumption note approved after a stock sheet recalculates the sheets from the note date through the last issued sheet. Reopening or deleting does the same.",
                ]
            ),
            release(
                "1.0.334", "15.10.2026",
                ro: [
                    "Bonul de consum nu se salvează fără motiv și fără cel puțin un articol, cu cantitate.",
                ],
                en: [
                    "A consumption note cannot be saved without a reason and at least one article, with a quantity.",
                ]
            ),
            release(
                "1.0.333", "15.10.2026",
                ro: [
                    "Pe bonul de consum, după produs se scrie cantitatea. Produsele se filtrează după categorie, denumire sau cod. O linie adăugată se poate șterge.",
                ],
                en: [
                    "On a consumption note, the quantity is entered after the product. Products filter by category, name, or code. An added line can be deleted.",
                ]
            ),
            release(
                "1.0.332", "15.10.2026",
                ro: [
                    "În Ajutor, sus, sunt butoanele Privacy, Termeni, Politica GDPR și Despre aplicație, și pentru casier.",
                ],
                en: [
                    "Help has Privacy, Terms, GDPR policy, and About at the top, for the cashier too.",
                ]
            ),
            release(
                "1.0.331", "15.10.2026",
                ro: [
                    "În Producție există Bon consum, și pentru casieri. Are motiv și produse din toată lista. Salvarea nu scade stocul. Managerul aprobă tot bonul sau doar liniile bifate, iar apoi bonul se blochează. Lista arată dacă este aprobat. Managerul îl poate redeschide, modifica sau șterge.",
                ],
                en: [
                    "Production includes Consumption note, for cashiers too. It has a reason and products from the whole list. Saving does not decrease stock. A manager approves the whole note or only the ticked lines, and then the note locks. The list shows whether it is approved. A manager can reopen, edit, or delete it.",
                ]
            ),
            release(
                "1.0.330", "15.10.2026",
                ro: [
                    "Categoria articolului este obligatorie. Nu se mai poate salva un produs fara categorie.",
                ],
                en: [
                    "The article category is required. A product can no longer be saved without a category.",
                ]
            ),
            release(
                "1.0.329", "15.10.2026",
                ro: [
                    "Importul de XML pentru NIR merge din nou. Garantie SGR ramane la categoria Garantie, fara grupa si fara stoc.",
                ],
                en: [
                    "XML import for goods receipts works again. The SGR deposit stays in the Guarantee category, with no group and no stock.",
                ]
            ),
            release(
                "1.0.328", "15.10.2026",
                ro: [
                    "Prima foaie de stoc porneste din stocul real al gestiunii punctului, nu din stocul total al firmei. Dupa inventar, stocul initial este cantitatea numarata a acelui punct.",
                ],
                en: [
                    "The first stock sheet starts from the real stock of the location's warehouse, not from the company total. After an inventory, the opening stock is that location's counted quantity.",
                ]
            ),
            release(
                "1.0.327", "15.10.2026",
                ro: [
                    "Garantie SGR este taxa, nu stoc. Nu are grupa, nu are stoc in gestiuni si nu intra pe foaia de stoc.",
                ],
                en: [
                    "SGR deposit is a fee, not stock. It has no group, no warehouse stock, and it is not on the stock sheet.",
                ]
            ),
            release(
                "1.0.326", "15.10.2026",
                ro: [
                    "La bonul de transfer există Bon transfer nou. Pleacă din gestiunea punctului și ajunge în cealaltă gestiune.",
                ],
                en: [
                    "Transfer notes have New transfer note. It leaves from your location's warehouse and arrives at the other warehouse.",
                ]
            ),
            release(
                "1.0.325", "15.10.2026",
                ro: [
                    "Pe Windows, la casierul de punct, lista de bonuri de producție nu se mai blochează. Puteți crea un bon și vă puteți întoarce.",
                ],
                en: [
                    "On Windows, a location cashier's production-note list no longer freezes. You can create a note and go back.",
                ]
            ),
            release(
                "1.0.324", "15.10.2026",
                ro: [
                    "Casierul de punct are Deconectare în meniul din stânga și sus în Casier. Închidere aplicație nu deloghează.",
                ],
                en: [
                    "A location cashier has Sign out in the left menu and at the top of Cashier. Quit does not sign out.",
                ]
            ),
            release(
                "1.0.323", "14.10.2026",
                ro: [
                    "Casierul de punct intră în aplicație pe firma lui și nu mai rămâne pe ecranul de pregătire.",
                ],
                en: [
                    "A location cashier signs in on their company and no longer stays on the preparing screen.",
                ]
            ),
            release(
                "1.0.322", "14.10.2026",
                ro: [
                    "În Casier, când sunt mai multe puncte de lucru, POS le deschide într-o fereastră ca să alegeți locația.",
                ],
                en: [
                    "In Cashier, when there is more than one work location, POS opens them in a window so you can choose the location.",
                ]
            ),
            release(
                "1.0.321", "14.10.2026",
                ro: [
                    "Jos pe foaia de stoc sunt totalurile comparative cu Z-ul și totalul de profit.",
                ],
                en: [
                    "The stock form shows comparison totals with the Z and the profit total at the bottom.",
                ]
            ),
            release(
                "1.0.320", "14.10.2026",
                ro: [
                    "Ajutorul descrie Casierul cu tile-urile colorate, foaia de stoc de după Raport Z și casierul de punct.",
                ],
                en: [
                    "Help describes Cashier with the colored tiles, the stock form after Report Z, and the location cashier.",
                ]
            ),
            release(
                "1.0.319", "14.10.2026",
                ro: [
                    "Casierii de punct intră direct în Casier, doar pe locația lor. Meniul are Casier, Ajutor, Ce este nou și Închidere. Firma nu se poate schimba.",
                ],
                en: [
                    "Location cashiers open Cashier directly, only for their location. The menu is Cashier, Help, What's New, and Quit. The company cannot be changed.",
                ]
            ),
            release(
                "1.0.318", "14.10.2026",
                ro: [
                    "Pe Mac, bonul fiscal din POS are fundal alb și text închis, ca liniile și totalul să se citească.",
                ],
                en: [
                    "On Mac, the POS fiscal receipt uses a white background and dark text, so the lines and the total stay readable.",
                ]
            ),
            release(
                "1.0.317", "14.10.2026",
                ro: [
                    "Foaie stoc este în Casier, nu pe Acasă. Tile-ul Producție are fundal verde, POS roșu și Foaie stoc albastru.",
                ],
                en: [
                    "Stock form is in Cashier, not on Home. The Production tile is green, POS is red, and Stock form is blue.",
                ]
            ),
            release(
                "1.0.316", "14.10.2026",
                ro: [
                    "Bonurile de producție și de transfer se filtrează după locație și dată, ca foile de stoc. Click-ul le deschide la vizualizare. La modificare sunteți avertizat: salvarea recalculează foile de stoc de la bonul afectat până astăzi.",
                ],
                en: [
                    "Production notes and transfer notes filter by location and date, like the stock sheets. A click opens them for viewing. Editing warns you: saving recalculates the stock sheets from the affected note through today.",
                ]
            ),
            release(
                "1.0.315", "14.10.2026",
                ro: [
                    "La fiecare Raport Z se salvează foaia de stoc a punctului de lucru și a turei. Lista din Foaie stoc arată data, tura, numărul Z și seria. Stocul final care nu bate cu gestiunea este scris cu roșu.",
                ],
                en: [
                    "Each Z report saves the stock sheet for that work location and shift. The Stock sheet list shows the date, shift, Z number, and series. A closing stock that does not match the warehouse is shown in red.",
                ]
            ),
            release(
                "1.0.314", "14.10.2026",
                ro: [
                    "La Raport Z, ecranul de vânzare se blochează până se închide tura. Se listează Raport X, apoi Raport Z. Produsele finite vândute primesc bon de producție: stocul lor revine la 0, iar materiile prime scad conform rețetei. Încasările din josul ecranului revin la 0.",
                ],
                en: [
                    "On the Z report, the sales screen stays blocked until the shift closes. The X report prints, then the Z report. Finished goods sold during the shift get a production note: their stock returns to 0, and raw materials decrease according to the recipe. The takings at the bottom return to 0.",
                ]
            ),
            release(
                "1.0.313", "14.10.2026",
                ro: [
                    "După Emite bon, când casa listează bonul, gestiunea scade cantitățile vândute. Pe fișa produsului apare ieșire prin BF, cu numărul bonului.",
                ],
                en: [
                    "After Issue receipt, once the cash register prints the receipt, the warehouse decreases the quantities sold. The product sheet shows an exit via fiscal receipt, with the receipt number.",
                ]
            ),
            release(
                "1.0.312", "14.10.2026",
                ro: [
                    "Un produs cu preț On line 0 nu se vinde online. Nu apare în catalog când bonul este pe On line și nu are profit On line.",
                ],
                en: [
                    "A product with an online price of 0 is not sold online. It does not appear in the catalog when the receipt is On line, and it has no online profit.",
                ]
            ),
            release(
                "1.0.311", "14.10.2026",
                ro: [
                    "Pe tile-urile din Articole, Profit In Store/bucată și Profit On line/bucată arată și procentul față de prețul de achiziție.",
                ],
                en: [
                    "On Articles tiles, in-store profit per unit and online profit per unit also show the percentage of the purchase price.",
                ]
            ),
            release(
                "1.0.310", "14.10.2026",
                ro: [
                    "NECTARIE: la SOS SAMURAI (84), SOS USTUROI (81) și SOS TZATZIKI (1462) prețul de producție este pentru 0,025 kg, ca la celelalte sosuri. Rețetele care îi folosesc s-au recalculat.",
                ],
                en: [
                    "NECTARIE: for SOS SAMURAI (84), SOS USTUROI (81) and SOS TZATZIKI (1462) the production price is for 0.025 kg, as for the other sauces. Recipes that use them were recalculated.",
                ]
            ),
            release(
                "1.0.309", "14.10.2026",
                ro: [
                    "Pe meniuri apar prețul de achiziție și cele două profituri, ca la articolele din catalog. Prețul de achiziție este suma costurilor produsului principal și ale produsului secundar obligatoriu.",
                ],
                en: [
                    "Menus show the purchase price and the two profits, as catalog articles do. The purchase price is the cost of the main product plus the required secondary product.",
                ]
            ),
            release(
                "1.0.308", "14.10.2026",
                ro: [
                    "Lista de articole nu se mai reîncarcă când derulezi peste capătul de sus sau de jos. Produsele rămân pe ecran.",
                ],
                en: [
                    "The articles list no longer reloads when you scroll past the top or the bottom. The products stay on screen.",
                ]
            ),
            release(
                "1.0.307", "14.10.2026",
                ro: [
                    "Pe tile-urile din Articole, profitul pe bucată apare doar la produsele din catalog. Vezi Profit In Store/bucată și Profit On line/bucată. La On line se scade 30% din prețul de vânzare, apoi prețul de achiziție.",
                ],
                en: [
                    "On Articles tiles, profit per unit appears only for catalog products. You see in-store profit per unit and online profit per unit. Online profit subtracts 30% of the sale price, then the purchase price.",
                ]
            ),
            release(
                "1.0.306", "14.10.2026",
                ro: [
                    "Pe fișa articolului apare prețul de achiziție fără TVA. Îl poți modifica. La fiecare factură furnizor și la fiecare NIR se actualizează singur, pe unitatea articolului.",
                ],
                en: [
                    "The article sheet shows the purchase price without VAT. You can edit it. Every supplier invoice and every goods receipt updates it, per the article unit.",
                ]
            ),
            release(
                "1.0.305", "14.10.2026",
                ro: [
                    "Profitul de pe tile folosește prețul de achiziție pe bucată sau pe kilogram. Berea, Granini și cartofii albi nu mai iau prețul pe cutie sau pe sac din factură. Rețetele care îi folosesc se recalculează.",
                ],
                en: [
                    "Tile profit uses the purchase price per piece or per kilogram. Beer, Granini, and white potatoes no longer take the case or sack price from the invoice. Recipes that use them are recalculated.",
                ]
            ),
            release(
                "1.0.304", "14.10.2026",
                ro: [
                    "Costul rețetei se calculează și dacă unei materii prime îi lipsește prețul de achiziție. Se recalculează când prețul apare sau se schimbă. Pe tile-ul din Articole apare un avertisment dacă rețeta nu are toate prețurile.",
                ],
                en: [
                    "Recipe cost is calculated even when a raw material has no purchase price. It recalculates when that price appears or changes. The Articles tile shows a warning when the recipe is missing prices.",
                ]
            ),
            release(
                "1.0.303", "14.10.2026",
                ro: [
                    "Foaie stoc se deschide direct pe listă. Tile-urile din modul au fost scoase.",
                ],
                en: [
                    "Stock form opens straight on the list. The tiles inside the module were removed.",
                ]
            ),
            release(
                "1.0.302", "14.10.2026",
                ro: [
                    "Modulul de pe Acasă se numește Foaie stoc.",
                ],
                en: [
                    "The Home module is named Stock form.",
                ]
            ),
            release(
                "1.0.301", "14.10.2026",
                ro: [
                    "Pe Fișa stoc, primul tile este Foaie stoc. Lista foilor se filtrează după locație și dată. Din foaie puteți tipări sau salva PDF-ul, inclusiv formularul gol.",
                ],
                en: [
                    "On Stock sheet, the first tile is Stock form. The list filters by location and date. From a form you can print or save the PDF, including a blank form.",
                ]
            ),
            release(
                "1.0.300", "14.10.2026",
                ro: [
                    "La Necesar comandă puteți filtra după categorii și grupe, ca la Articole. De exemplu doar marfă, sau doar băuturi. Lista, totalul și PDF-ul respectă filtrul.",
                ],
                en: [
                    "On Reorder needed you can filter by categories and groups, as in Articles. For example only merchandise, or only drinks. The list, the total, and the PDF follow the filter.",
                ]
            ),
            release(
                "1.0.299", "14.10.2026",
                ro: [
                    "La Necesar comandă, lista și PDF-ul arată cod, denumire, UM, stoc curent, de comandat, ultimul preț de cumpărare cu TVA și totalul liniei. Jos este totalul comenzii în lei.",
                ],
                en: [
                    "On Reorder needed, the list and the PDF show code, name, unit, current stock, quantity to order, the latest purchase price including VAT, and the line total. The order total in lei is at the bottom.",
                ]
            ),
            release(
                "1.0.298", "14.10.2026",
                ro: [
                    "La meniurile din POS, discountul de 100% pleacă la casă cu aceeași cotă ca produsul. La doză, cota este A.",
                ],
                en: [
                    "On POS menus, the 100% discount is sent to the cash register with the same VAT rate as the product. A can is rate A.",
                ]
            ),
            release(
                "1.0.297", "14.10.2026",
                ro: [
                    "Prețul tuturor rețetelor este recalculat din ultima achiziție. La un produs finit folosit în altă rețetă, prețul este costul lui de producție.",
                ],
                en: [
                    "Every recipe price is recalculated from the latest purchase. When a finished good is used in another recipe, its price is its production cost.",
                ]
            ),
            release(
                "1.0.296", "14.10.2026",
                ro: [
                    "NECTARIE: ceapa prăjită (411271), 0,015 kg, este în rețetele produselor finite din Farfurii & Box, Sandwich & Chifle și Shaorma.",
                ],
                en: [
                    "NECTARIE: fried onion (411271), 0.015 kg, is in the recipes of finished goods in Farfurii & Box, Sandwich & Chifle, and Shaorma.",
                ]
            ),
            release(
                "1.0.295", "14.10.2026",
                ro: [
                    "La Emite bon, sertarul se deschide și la Numerar + card, la fel ca la Numerar.",
                ],
                en: [
                    "On Issue receipt, the drawer also opens for cash + card, the same as for cash.",
                ]
            ),
            release(
                "1.0.294", "14.10.2026",
                ro: [
                    "La Emite bon, dacă încasarea este Numerar, casa de marcat deschide și sertarul. La celelalte încasări sertarul rămâne închis.",
                ],
                en: [
                    "On Issue receipt, if the payment is cash, the cash register also opens the drawer. For other payments the drawer stays closed.",
                ]
            ),
            release(
                "1.0.293", "14.10.2026",
                ro: [
                    "La casă, AQUA PLATĂ și AQUA MINERALĂ 0,5 L se trimit cu cota B. Limonadele clasică, lime, mandarin și melon se trimit cu cota A.",
                ],
                en: [
                    "At the register, still and sparkling water 0.5 L are sent with VAT rate B. Classic, lime, mandarin, and melon lemonades are sent with VAT rate A.",
                ]
            ),
            release(
                "1.0.292", "14.10.2026",
                ro: [
                    "Taxa ambalaj și Taxa ambalaj mică se trimit pe bon cu cota A (21%), nu cu B.",
                ],
                en: [
                    "Packaging tax and small packaging tax are sent on the receipt with VAT rate A (21%), not B.",
                ]
            ),
            release(
                "1.0.291", "14.10.2026",
                ro: [
                    "Zecimalele din Setări se aplică și la rețete, nu doar la stocuri. Prețurile rămân cu 2 zecimale.",
                ],
                en: [
                    "The decimals chosen in Settings also apply to recipes, not only to stock. Prices stay at 2 decimal places.",
                ]
            ),
            release(
                "1.0.290", "14.10.2026",
                ro: [
                    "În Setări poți alege 2, 3 sau 4 zecimale doar pentru cantitățile de stoc. La Nectarie sunt 4.",
                ],
                en: [
                    "In Settings you can choose 2, 3, or 4 decimal places for stock quantities only. Nectarie uses 4.",
                ]
            ),
            release(
                "1.0.289", "14.10.2026",
                ro: [
                    "NECTARIE: fișa 103921 se numește PORTOCALE. PORTOCALE 3-5 P și PORTOCALE SUC rămân aliasuri și se leagă tot acolo.",
                ],
                en: [
                    "NECTARIE: sheet 103921 is named PORTOCALE. PORTOCALE 3-5 P and PORTOCALE SUC stay aliases and still link there.",
                ]
            ),
            release(
                "1.0.288", "14.10.2026",
                ro: [
                    "NECTARIE: portocalele pentru suc (cod 103572) sunt pe fișa PORTOCALE 3-5 P (cod 103921). Stocul și recepțiile sunt împreună.",
                ],
                en: [
                    "NECTARIE: juice oranges (code 103572) are on the PORTOCALE 3-5 P sheet (code 103921). Stock and receipts are together.",
                ]
            ),
            release(
                "1.0.287", "13.10.2026",
                ro: [
                    "La Copiază rețetă, lista rămâne deschisă și arată doar produsele finite.",
                ],
                en: [
                    "Copy recipe stays open and lists only finished products.",
                ]
            ),
            release(
                "1.0.286", "13.10.2026",
                ro: [
                    "La rețetă, Copiază rețetă aduce liniile de la alt produs. Apoi le poți modifica.",
                ],
                en: [
                    "On a recipe, Copy recipe brings the lines from another product. You can edit them afterwards.",
                ]
            ),
            release(
                "1.0.285", "13.10.2026",
                ro: [
                    "Cantitățile din rețetă se scriu și se afișează cu 3 zecimale.",
                ],
                en: [
                    "Recipe quantities are entered and shown with 3 decimal places.",
                ]
            ),
            release(
                "1.0.284", "13.10.2026",
                ro: [
                    "La Necesar comandă, cantitatea de comandat este un câmp cu chenar și creion, ca să se vadă că se poate modifica.",
                ],
                en: [
                    "On Reorder needed, the quantity to order is a bordered field with a pencil, so it is clear you can change it.",
                ]
            ),
            release(
                "1.0.283", "13.10.2026",
                ro: [
                    "La Necesar comandă, lista e pe categorii. Cantitatea de comandat se poate modifica, iar articolele se pot adăuga sau scoate. Materialele consumabile au stoc optim 15, materialele de curățenie minim 1 și optim 3. Birotica nu intră automat.",
                ],
                en: [
                    "On Reorder needed, the list is grouped by category. You can edit the quantity to order and add or remove articles. Consumable materials have an optimal stock of 15, cleaning materials a minimum of 1 and an optimal stock of 3. Stationery is not included automatically.",
                ]
            ),
            release(
                "1.0.282", "13.10.2026",
                ro: [
                    "La Necesar comandă, cantitatea de comandat este stocul optim minus stocul real. Se poate tipări și salva PDF direct în folder.",
                ],
                en: [
                    "On Reorder needed, the quantity to order is optimal stock minus real stock. You can print it and save the PDF straight to a folder.",
                ]
            ),
            release(
                "1.0.281", "13.10.2026",
                ro: [
                    "La Articole apare Stoc optim. La toate articolele, în afară de produsele finite, stocul minim este 10 și stocul optim este 25.",
                ],
                en: [
                    "Articles have an Optimal stock field. Every article except finished goods has a minimum stock of 10 and an optimal stock of 25.",
                ]
            ),
            release(
                "1.0.280", "13.10.2026",
                ro: [
                    "La casă, tile-urile sunt semitransparente, ca să se vadă logo-ul din fundal, și catalogul se deschide mai repede.",
                ],
                en: [
                    "At the register, tiles are translucent so the background logo shows through, and the catalog opens faster.",
                ]
            ),
            release(
                "1.0.279", "13.10.2026",
                ro: [
                    "La casă, pe In Store plata este Numerar, Card sau Numerar + Card.",
                ],
                en: [
                    "At the register, In Store accepts Cash, Card, or Cash + card.",
                ]
            ),
            release(
                "1.0.278", "13.10.2026",
                ro: [
                    "La casă, pe On line singura plată este Modernă: Glovo, Bolt sau Wolt.",
                ],
                en: [
                    "At the register, On line accepts only Modern payment: Glovo, Bolt, or Wolt.",
                ]
            ),
            release(
                "1.0.277", "13.10.2026",
                ro: [
                    "La casă, un produs sau un meniu cu prețul de vânzare 0 nu se poate marca pe bon.",
                ],
                en: [
                    "At the register, a product or a menu with a sale price of 0 cannot be rung up.",
                ]
            ),
            release(
                "1.0.276", "13.10.2026",
                ro: [
                    "Meniurile au preț In Store și preț On Line. La casă, comutatorul alege prețul meniului.",
                ],
                en: [
                    "Menus have an In Store price and an On Line price. At the register, the switch picks the menu price.",
                ]
            ),
            release(
                "1.0.275", "13.10.2026",
                ro: [
                    "La Articole, grupele și categoriile se pot bifa mai multe deodată: toate, sau doar cele alese.",
                ],
                en: [
                    "On Articles, groups and categories can be checked several at a time: all of them, or only the ones you pick.",
                ]
            ),
            release(
                "1.0.274", "13.10.2026",
                ro: [
                    "La Articole, tile-urile și lista se pot sorta după nume sau după categoria articolului.",
                ],
                en: [
                    "On Articles, tiles and the list can be sorted by name or by article category.",
                ]
            ),
            release(
                "1.0.273", "12.10.2026",
                ro: [
                    "Pe bara din stânga, fiecare firmă are sigla ei. Dacă nu e încărcată, apare un pătrat cu inițialele firmei. Nectarie păstrează sigla ei.",
                ],
                en: [
                    "The left bar shows each company's logo. If none is saved, a square with the company initials appears. Nectarie keeps its own logo.",
                ]
            ),
            release(
                "1.0.272", "12.10.2026",
                ro: [
                    "Închidere aplicație este un buton 3D, centrat pe verticală în spațiul de sub siglă.",
                ],
                en: [
                    "Quit application is a 3D button, centered vertically in the space under the logo.",
                ]
            ),
            release(
                "1.0.271", "12.10.2026",
                ro: [
                    "Butonul Închidere aplicație este centrat pe verticală și pe orizontală în meniul din stânga.",
                ],
                en: [
                    "The Quit application button is centered vertically and horizontally in the left menu.",
                ]
            ),
            release(
                "1.0.270", "12.10.2026",
                ro: [
                    "Închidere aplicație din meniul din stânga este buton și închide fereastra fără delogare.",
                ],
                en: [
                    "Quit application in the left menu is a button and closes the window without signing out.",
                ]
            ),
            release(
                "1.0.269", "12.10.2026",
                ro: [
                    "La Articole, pe tile și în listă apare și stocul minim.",
                ],
                en: [
                    "On Articles, minimum stock also appears on the tile and in the list.",
                ]
            ),
            release(
                "1.0.268", "12.10.2026",
                ro: [
                    "La Articole, pe tile și în listă apar ambele prețuri de vânzare: In Store și On Line.",
                ],
                en: [
                    "On Articles, both sale prices appear on the tile and in the list: In Store and On line.",
                ]
            ),
            release(
                "1.0.267", "12.10.2026",
                ro: [
                    "La Nectarie, sigla apare și pe bara din stânga, sub meniu, într-un pătrat cât lățimea barei.",
                ],
                en: [
                    "At Nectarie, the logo also appears on the left bar, under the menu, in a square as wide as the bar.",
                ]
            ),
            release(
                "1.0.266", "12.10.2026",
                ro: [
                    "La Nectarie, ecranul de vânzare POS are sigla estompată 50% pe fundal, doar până la bon.",
                ],
                en: [
                    "At Nectarie, the POS sale screen shows the company logo faded to 50% on the catalog background, stopping at the receipt.",
                ]
            ),
            release(
                "1.0.265", "12.10.2026",
                ro: [
                    "NECTARIE: pe shaorme / box / chifle etc. rețetele folosesc din nou produsul finit DONER PUI; pieptul de pui rămâne doar în rețeta DONER PUI.",
                ],
                en: [
                    "NECTARIE: shaorma / box / bun recipes again use finished good DONER PUI; chicken breast stays only in the DONER PUI recipe.",
                ]
            ),
            release(
                "1.0.264", "12.10.2026",
                ro: [
                    "Inventar: pe fiecare produs apare categoria articolului; puteți sorta tabelul după categorie, nume, cod, stoc scriptic, numărat sau diferență.",
                ],
                en: [
                    "Stock take: each product shows its article category; you can sort the table by category, name, code, book stock, counted or difference.",
                ]
            ),
            release(
                "1.0.263", "12.10.2026",
                ro: [
                    "NECTARIE: retetele folosesc acum materiile prime din baza (CARTOFI ALBI, CURRY, PIEPT DE PUI, DONER VITA TOCAT) in locul codurilor BINA; ingredientele fara corespondent au fost eliminate.",
                ],
                en: [
                    "NECTARIE: recipes now use master raw materials from the database (CARTOFI ALBI, CURRY, chicken breast, DONER VITA TOCAT) instead of BINA codes; unmatched ingredients were removed.",
                ]
            ),
            release(
                "1.0.262", "12.10.2026",
                ro: [
                    "NECTARIE: *1201*1245SGR (QAB AQUA CARPATICA PLATA 0.5L) unificat pe AQUA PLATA 0.5 L (cod 1469).",
                ],
                en: [
                    "NECTARIE: *1201*1245SGR (QAB AQUA CARPATICA PLATA 0.5L) merged into AQUA PLATA 0.5 L (code 1469).",
                ]
            ),
            release(
                "1.0.261", "12.10.2026",
                ro: [
                    "NECTARIE: *340053107SGR (QAB AQUA CARPATICA CARBO 0.5L) unificat pe AQUA MINERALA 0.5 L (cod 1470).",
                ],
                en: [
                    "NECTARIE: *340053107SGR (QAB AQUA CARPATICA CARBO 0.5L) merged into AQUA MINERALA 0.5 L (code 1470).",
                ]
            ),
            release(
                "1.0.260", "12.10.2026",
                ro: [
                    "NECTARIE: sterse 14 articole tarife deseuri / TMB (coduri 6421735000120–0151 selectate).",
                ],
                en: [
                    "NECTARIE: removed 14 waste / TMB tariff products (selected codes 6421735000120–0151).",
                ]
            ),
            release(
                "1.0.259", "12.10.2026",
                ro: [
                    "NECTARIE: 11 coduri Q (cutii, hartie, seturi etc.) mutate pe tip ambalaj: 00014099, 00014000, 00014053/1, 00014098, 00014022, 00012743, 00009595, 00005040, 00008904, 00014285, 00005053/2.",
                ],
                en: [
                    "NECTARIE: 11 Q codes (boxes, paper, sets etc.) moved to packaging type: 00014099, 00014000, 00014053/1, 00014098, 00014022, 00012743, 00009595, 00005040, 00008904, 00014285, 00005053/2.",
                ]
            ),
            release(
                "1.0.258", "12.10.2026",
                ro: [
                    "NECTARIE: codul 00012442/1 (saci LDPE) mutat pe tip materiale curatenie.",
                ],
                en: [
                    "NECTARIE: code 00012442/1 (LDPE bags) moved to cleaning materials type.",
                ]
            ),
            release(
                "1.0.257", "12.10.2026",
                ro: [
                    "NECTARIE: codurile 00014865, 00004908 si 00004909 (manusi nitril Q) mutate pe tip materiale consumabile.",
                ],
                en: [
                    "NECTARIE: codes 00014865, 00004908 and 00004909 (Q nitrile gloves) moved to consumable materials type.",
                ]
            ),
            release(
                "1.0.256", "12.10.2026",
                ro: [
                    "NECTARIE: sterse articolele cu codurile 6421735000124 si 6421735000117.",
                ],
                en: [
                    "NECTARIE: removed products with codes 6421735000124 and 6421735000117.",
                ]
            ),
            release(
                "1.0.255", "12.10.2026",
                ro: [
                    "NECTARIE: master PEPSI ZERO VANILIE 0.33 L (cod 340063926); variantele CAN / DRS Vanilie se unifica pe aceasta fisa la NIR.",
                ],
                en: [
                    "NECTARIE: master PEPSI ZERO VANILIE 0.33 L (code 340063926); CAN / DRS Vanilla variants map to this item on NIR.",
                ]
            ),
            release(
                "1.0.254", "12.10.2026",
                ro: [
                    "NECTARIE: master PEPSI ZERO 0.5 L (cod 1471); QAB / PET Zero 0.5L se unifica pe aceasta fisa la NIR (Vanilie 330 ramane separata).",
                ],
                en: [
                    "NECTARIE: master PEPSI ZERO 0.5 L (code 1471); QAB / PET Zero 0.5L map to this item on NIR (Vanilla 330 stays separate).",
                ]
            ),
            release(
                "1.0.253", "12.10.2026",
                ro: [
                    "NECTARIE: master PEPSI TWIST 0.5 L (cod 1466); QAB / PET Twist 0.5L se unifica pe aceasta fisa la NIR.",
                ],
                en: [
                    "NECTARIE: master PEPSI TWIST 0.5 L (code 1466); QAB / PET Twist 0.5L map to this item on NIR.",
                ]
            ),
            release(
                "1.0.252", "12.10.2026",
                ro: [
                    "NECTARIE: master PEPSI COLA DOZA 0.33 L (cod 1472); QAB / CAN 0.33L se unifica pe aceasta fisa la NIR.",
                ],
                en: [
                    "NECTARIE: master PEPSI COLA DOZA 0.33 L (code 1472); QAB / CAN 0.33L map to this item on NIR.",
                ]
            ),
            release(
                "1.0.251", "12.10.2026",
                ro: [
                    "NECTARIE: master PEPSI COLA 0.5 L (cod 1465); QAB / PET 0.5L se unifica pe aceasta fisa la NIR (Twist / Zero / doza raman separate).",
                ],
                en: [
                    "NECTARIE: master PEPSI COLA 0.5 L (code 1465); QAB / PET 0.5L map to this item on NIR (Twist / Zero / can stay separate).",
                ]
            ),
            release(
                "1.0.250", "12.10.2026",
                ro: [
                    "NECTARIE: master MOUNTAIN DEW 0.5 L (cod 1475); variantele PET / SGR se unifica pe aceasta fisa la NIR.",
                ],
                en: [
                    "NECTARIE: master MOUNTAIN DEW 0.5 L (code 1475); PET / SGR variants map to this item on NIR.",
                ]
            ),
            release(
                "1.0.249", "12.10.2026",
                ro: [
                    "NECTARIE: master MIRINDA ORANGE DOZA 0.33 L (cod 1473); QAB / CAN 0.33L se unifica pe aceasta fisa la NIR.",
                ],
                en: [
                    "NECTARIE: master MIRINDA ORANGE DOZA 0.33 L (code 1473); QAB / CAN 0.33L map to this item on NIR.",
                ]
            ),
            release(
                "1.0.248", "12.10.2026",
                ro: [
                    "NECTARIE: master MIRINDA ORANGE 0.5 L (cod 1474); QAB / PET 0.5L se unifica pe aceasta fisa la NIR (doza 0.33 ramane separata).",
                ],
                en: [
                    "NECTARIE: master MIRINDA ORANGE 0.5 L (code 1474); QAB / PET 0.5L map to this item on NIR (0.33 can stays separate).",
                ]
            ),
            release(
                "1.0.247", "12.10.2026",
                ro: [
                    "NECTARIE: master LIPTON PIERSICI 0.5 L (cod 1467); QAB / ICE TEA PEACH 0.5L se unifica pe aceasta fisa la NIR.",
                ],
                en: [
                    "NECTARIE: master LIPTON PIERSICI 0.5 L (code 1467); QAB / ICE TEA PEACH 0.5L map to this item on NIR.",
                ]
            ),
            release(
                "1.0.246", "12.10.2026",
                ro: [
                    "NECTARIE: master LIPTON LAMAIE 0.5 L (cod 1468); QAB / ICE TEA LEMON 0.5L se unifica pe aceasta fisa la NIR.",
                ],
                en: [
                    "NECTARIE: master LIPTON LAMAIE 0.5 L (code 1468); QAB / ICE TEA LEMON 0.5L map to this item on NIR.",
                ]
            ),
            release(
                "1.0.245", "12.10.2026",
                ro: [
                    "NECTARIE: INC 33,5 mutat pe tip materiale consumabile.",
                ],
                en: [
                    "NECTARIE: INC 33,5 moved to consumable materials type.",
                ]
            ),
            release(
                "1.0.244", "12.10.2026",
                ro: [
                    "NECTARIE: master GRANINI 0.33 L (cod 1482); variantele SGR / arome de pe facturi se unifica pe aceasta fisa la NIR.",
                ],
                en: [
                    "NECTARIE: master GRANINI 0.33 L (code 1482); SGR / flavor invoice variants map to this item on NIR.",
                ]
            ),
            release(
                "1.0.243", "12.10.2026",
                ro: [
                    "NECTARIE: sterse articolele cu codurile 305579, 6421735000136, 340063895, 340063894, 721806, 103483 si 100192.",
                ],
                en: [
                    "NECTARIE: removed products with codes 305579, 6421735000136, 340063895, 340063894, 721806, 103483 and 100192.",
                ]
            ),
            release(
                "1.0.242", "12.10.2026",
                ro: [
                    "NECTARIE: sters articolul cu codul 378748 (CCA. 2,38 KG ARO MOZZARELLA).",
                ],
                en: [
                    "NECTARIE: removed product code 378748 (CCA. 2,38 KG ARO MOZZARELLA).",
                ]
            ),
            release(
                "1.0.241", "12.10.2026",
                ro: [
                    "NECTARIE: chirii, CEC deseuri si utilitati (coduri 6421735000152, 6421735000132, 6421735000153, 6421735000133, 6421735000143, 6421735000114, 6421735000142, 6421735000141) trec pe tip Servicii.",
                ],
                en: [
                    "NECTARIE: rents, waste CEC and utilities (codes 6421735000152, 6421735000132, 6421735000153, 6421735000133, 6421735000143, 6421735000114, 6421735000142, 6421735000141) moved to Services product kind.",
                ]
            ),
            release(
                "1.0.240", "12.10.2026",
                ro: [
                    "NIR / facturi: Tuborg sticla 0.33 L (inclusiv SGR) se leaga pe fisa „BERE TUBORG ST. 0.33 L” (cod 1479); doza 0.5 L ramane separata.",
                ],
                en: [
                    "GRN / invoices: Tuborg 0.33 L bottle (including SGR) links to “BERE TUBORG ST. 0.33 L” (code 1479); 0.5 L can stays separate.",
                ]
            ),
            release(
                "1.0.239", "12.10.2026",
                ro: [
                    "NIR / facturi: Tuborg doza 0.5 L (inclusiv SGR) se leaga pe fisa „BERE TUBORG DOZA 0.5 L” (cod 1481); sticla 0.33 L ramane separata.",
                ],
                en: [
                    "GRN / invoices: Tuborg 0.5 L can (including SGR) links to “BERE TUBORG DOZA 0.5 L” (code 1481); 0.33 L bottle stays separate.",
                ]
            ),
            release(
                "1.0.238", "12.10.2026",
                ro: [
                    "NIR / facturi: Carlsberg doza 0.5 L (inclusiv SGR promo) se leaga pe fisa „BERE CARLSBERG DOZA 0.5 L” (cod 1480); sticla 0.33 L ramane separata.",
                ],
                en: [
                    "GRN / invoices: Carlsberg 0.5 L can (including SGR promo) links to “BERE CARLSBERG DOZA 0.5 L” (code 1480); 0.33 L bottle stays separate.",
                ]
            ),
            release(
                "1.0.237", "12.10.2026",
                ro: [
                    "NIR / facturi: Carlsberg 0.33 L (inclusiv SGR promo) se leaga pe fisa „BERE CARLSBERG 0.33 L” (cod 1478); doza 0.5 L ramane separata.",
                ],
                en: [
                    "GRN / invoices: Carlsberg 0.33 L (including SGR promo) links to “BERE CARLSBERG 0.33 L” (code 1478); 0.5 L can stays separate.",
                ]
            ),
            release(
                "1.0.236", "12.10.2026",
                ro: [
                    "NIR / facturi: Bere Bucur blonda 0.35 L (inclusiv SGR promo) se leaga pe fisa „BERE BUCUR BLONDA 0.35 L” (cod 1484).",
                ],
                en: [
                    "GRN / invoices: Bere Bucur blonde 0.35 L (including SGR promo) links to “BERE BUCUR BLONDA 0.35 L” (code 1484).",
                ]
            ),
            release(
                "1.0.235", "12.10.2026",
                ro: [
                    "NIR / facturi: ayranul se leaga pe fisa „AYRAN” (cod 1116); iaurtul ramane separat.",
                ],
                en: [
                    "GRN / invoices: ayran links to “AYRAN” (code 1116); yogurt stays separate.",
                ]
            ),
            release(
                "1.0.234", "12.10.2026",
                ro: [
                    "NIR / facturi: aqua plata 0.5 L (inclusiv SGR) se leaga pe fisa „AQUA PLATA 0.5 L” (cod 1469); aqua minerala si 1 L raman separate.",
                ],
                en: [
                    "GRN / invoices: still water 0.5 L (including SGR) links to “AQUA PLATA 0.5 L” (code 1469); sparkling and 1 L stay separate.",
                ]
            ),
            release(
                "1.0.233", "12.10.2026",
                ro: [
                    "NIR / facturi: aqua minerala 0.5 L (inclusiv carbo/SGR) se leaga pe fisa „AQUA MINERALA 0.5 L” (cod 1470); aqua plata ramane separata.",
                ],
                en: [
                    "GRN / invoices: sparkling mineral water 0.5 L (including carbo/SGR) links to “AQUA MINERALA 0.5 L” (code 1470); still water stays separate.",
                ]
            ),
            release(
                "1.0.232", "12.10.2026",
                ro: [
                    "NIR / facturi: 7UP Lemon Lime 0.5 L (inclusiv SGR) se leaga pe fisa „7UP LEMON LIME 0.5 L” (cod 1477); lamaile proaspete raman pe „LAMAI”.",
                ],
                en: [
                    "GRN / invoices: 7UP Lemon Lime 0.5 L (including SGR) links to “7UP LEMON LIME 0.5 L” (code 1477); fresh lemons stay on “LAMAI”.",
                ]
            ),
            release(
                "1.0.231", "12.10.2026",
                ro: [
                    "NECTARIE: sterse articolele cu codurile 381968, 214307, 128583 si 369646.",
                ],
                en: [
                    "NECTARIE: removed products with codes 381968, 214307, 128583 and 369646.",
                ]
            ),
            release(
                "1.0.230", "12.10.2026",
                ro: [
                    "NECTARIE: articolul cu codul 720653 (Abonament Lunar Comax Pro Plus) trece pe tip Servicii.",
                ],
                en: [
                    "NECTARIE: product code 720653 (Abonament Lunar Comax Pro Plus) moved to Services product kind.",
                ]
            ),
            release(
                "1.0.229", "12.10.2026",
                ro: [
                    "NIR / facturi: varza rosie se leaga pe fisa „VARZA ROSIE” (cod 103563); varza alba ramane separata.",
                ],
                en: [
                    "GRN / invoices: red cabbage links to “VARZA ROSIE” (code 103563); white cabbage stays separate.",
                ]
            ),
            release(
                "1.0.228", "12.10.2026",
                ro: [
                    "NIR / facturi: varza alba (inclusiv varza noua) se leaga pe fisa „VARZA ALBA” (cod 389762); varza rosie ramane separata.",
                ],
                en: [
                    "GRN / invoices: white cabbage (including “new” cabbage) links to “VARZA ALBA” (code 389762); red cabbage stays separate.",
                ]
            ),
            release(
                "1.0.227", "12.10.2026",
                ro: [
                    "NIR / facturi: uleiul floarea-soarelui (ULEI FL / MC etc.) se leaga pe fisa „ULEI FLOAREA SOARELUI” (cod 104861), UM Litru; uleiul de palmier ramane separat.",
                ],
                en: [
                    "GRN / invoices: sunflower oil (ULEI FL / MC, etc.) links to “ULEI FLOAREA SOARELUI” (code 104861), stock unit Litre; palm oil stays separate.",
                ]
            ),
            release(
                "1.0.226", "12.10.2026",
                ro: [
                    "NECTARIE: articolul cu codul 6421735000164 (TOTAL BAZA DE IMPOZITARE TVA 21%) trece pe tip Servicii.",
                ],
                en: [
                    "NECTARIE: product code 6421735000164 (TOTAL BAZA DE IMPOZITARE TVA 21%) moved to Services product kind.",
                ]
            ),
            release(
                "1.0.225", "12.10.2026",
                ro: [
                    "NIR / facturi: tortilla 27cm curcuma se leaga pe fisa „TORTILLA 27CM CURCUMA” (cod 6421735000137).",
                ],
                en: [
                    "GRN / invoices: 27cm turmeric tortilla links to “TORTILLA 27CM CURCUMA” (code 6421735000137).",
                ]
            ),
            release(
                "1.0.224", "12.10.2026",
                ro: [
                    "NECTARIE: tarifele TMB / depozitare (coduri 6421735000200, 6421735000178, 6421735000201, 6421735000179, 6421735000199, 6421735000177, 6421735000198, 6421735000176) trec pe tip Servicii.",
                ],
                en: [
                    "NECTARIE: TMB / storage tariffs (codes 6421735000200, 6421735000178, 6421735000201, 6421735000179, 6421735000199, 6421735000177, 6421735000198, 6421735000176) moved to Services product kind.",
                ]
            ),
            release(
                "1.0.223", "12.10.2026",
                ro: [
                    "NIR / facturi: zaharul (inclusiv 1KG ARO HT) se leaga pe fisa „ZAHAR” (cod 217912), materie prima activa, UM Kg.",
                ],
                en: [
                    "GRN / invoices: sugar (including 1KG ARO HT) links to “ZAHAR” (code 217912), active raw material, stock unit Kg.",
                ]
            ),
            release(
                "1.0.222", "12.10.2026",
                ro: [
                    "NECTARIE: sterse articolele cu codurile 1008, 1070, 1013, 1010, 1133, 1034, 1028, 1442 si 1054.",
                ],
                en: [
                    "NECTARIE: removed products with codes 1008, 1070, 1013, 1010, 1133, 1034, 1028, 1442 and 1054.",
                ]
            ),
            release(
                "1.0.221", "12.10.2026",
                ro: [
                    "NIR / facturi: sosul cedar (inclusiv galon 5 L) se leaga pe fisa „SOS CEDAR” (cod 6421735000154), UM Litru.",
                ],
                en: [
                    "GRN / invoices: cedar sauce (including 5 L gallon) links to “SOS CEDAR” (code 6421735000154), stock unit Litre.",
                ]
            ),
            release(
                "1.0.220", "12.10.2026",
                ro: [
                    "NIR / facturi: salata verde (inclusiv iceberg) se leaga pe fisa „SALATA VERDE” (cod 103717); salatele finite raman separate.",
                ],
                en: [
                    "GRN / invoices: green lettuce (including iceberg) links to “SALATA VERDE” (code 103717); finished salads stay separate.",
                ]
            ),
            release(
                "1.0.219", "12.10.2026",
                ro: [
                    "NIR / facturi: rosiile (RO, P, MC ciorchine etc.) se leaga pe fisa „ROSII” (cod 103616); sosurile de rosii raman separate.",
                ],
                en: [
                    "GRN / invoices: tomatoes (RO, P, MC cluster, etc.) link to “ROSII” (code 103616); tomato sauces stay separate.",
                ]
            ),
            release(
                "1.0.218", "12.10.2026",
                ro: [
                    "NECTARIE: articolele cu codurile 6421735000196, 6421735000205, 6421735000204, 6421735000191, 6421735000190, 6421735000166, 6421735000165, 0000369 si 503308 trec pe tip Servicii.",
                ],
                en: [
                    "NECTARIE: products with codes 6421735000196, 6421735000205, 6421735000204, 6421735000191, 6421735000190, 6421735000166, 6421735000165, 0000369 and 503308 moved to Services product kind.",
                ]
            ),
            release(
                "1.0.217", "12.10.2026",
                ro: [
                    "NIR / facturi: pulpele de pui dezosate (cu piele) se leaga pe fisa „PULPE DE PUI DEZOSATE CU PIELE” (cod 6421735000135); pieptul ramane separat.",
                ],
                en: [
                    "GRN / invoices: boneless chicken thighs (with skin) link to “PULPE DE PUI DEZOSATE CU PIELE” (code 6421735000135); breast stays separate.",
                ]
            ),
            release(
                "1.0.216", "12.10.2026",
                ro: [
                    "NIR / facturi: portocalele pentru suc se leaga pe fisa „PORTOCALE SUC” (cod 103572); PORTOCALE 3-5 P si bauturile orange raman separate.",
                ],
                en: [
                    "GRN / invoices: juice oranges link to “PORTOCALE SUC” (code 103572); PORTOCALE 3-5 P and orange drinks stay separate.",
                ]
            ),
            release(
                "1.0.215", "12.10.2026",
                ro: [
                    "NIR / facturi: portocalele (3-5 P) se leaga pe fisa „PORTOCALE 3-5 P” (cod 103921); PORTOCALE SUC si bauturile orange raman separate.",
                ],
                en: [
                    "GRN / invoices: oranges (3-5 P) link to “PORTOCALE 3-5 P” (code 103921); juice oranges and orange drinks stay separate.",
                ]
            ),
            release(
                "1.0.214", "12.10.2026",
                ro: [
                    "NIR / facturi: pita se leaga pe fisa „PITA” (cod 6421735000138); lipie tip C si PITA EXTRA raman separate.",
                ],
                en: [
                    "GRN / invoices: pita links to “PITA” (code 6421735000138); tip C flatbread and PITA EXTRA stay separate.",
                ]
            ),
            release(
                "1.0.213", "12.10.2026",
                ro: [
                    "NIR / facturi: pieptul de pui dezosat (cu piele) se leaga pe fisa „PIEPT DE PUI DEZ CU PIELE” (cod 6421735000113); pulpele raman separate.",
                ],
                en: [
                    "GRN / invoices: boneless chicken breast (with skin) links to “PIEPT DE PUI DEZ CU PIELE” (code 6421735000113); thighs stay separate.",
                ]
            ),
            release(
                "1.0.212", "12.10.2026",
                ro: [
                    "NIR / facturi: patrunjelul se leaga pe fisa „PATRUNJEL” (cod 103712).",
                ],
                en: [
                    "GRN / invoices: parsley links to “PATRUNJEL” (code 103712).",
                ]
            ),
            release(
                "1.0.211", "12.10.2026",
                ro: [
                    "NECTARIE: manusile nitrile (coduri 214469 si 211758) trec pe tip Materiale consumabile.",
                ],
                en: [
                    "NECTARIE: nitrile gloves (codes 214469 and 211758) moved to Consumables product kind.",
                ]
            ),
            release(
                "1.0.210", "12.10.2026",
                ro: [
                    "NIR / facturi: mini bagheta 120GR se leaga pe fisa „MINI BAGHETA 120GR” (cod 6421735000140).",
                ],
                en: [
                    "GRN / invoices: mini baguette 120GR links to “MINI BAGHETA 120GR” (code 6421735000140).",
                ]
            ),
            release(
                "1.0.209", "12.10.2026",
                ro: [
                    "NECTARIE: sterse articolele cu codurile 1051, 1011, 1033 si 1243 (inclusiv mozzarella inactiva din retetele Cheese Kebab).",
                ],
                en: [
                    "NECTARIE: removed products with codes 1051, 1011, 1033 and 1243 (including inactive mozzarella from Cheese Kebab recipes).",
                ]
            ),
            release(
                "1.0.208", "12.10.2026",
                ro: [
                    "NIR / facturi: lipie tip C 750G se leaga pe fisa „LIPIE TIP C 750G” (cod 6421735000112); tip 600G si pita raman separate.",
                ],
                en: [
                    "GRN / invoices: tip C 750G flatbread links to “LIPIE TIP C 750G” (code 6421735000112); 600G tip and pita stay separate.",
                ]
            ),
            release(
                "1.0.207", "12.10.2026",
                ro: [
                    "NIR / facturi: Lay's sare (inclusiv 40G/BLT/BAX/DTS) se leaga pe fisa „LAY'S SARE” (cod 340059584); sarea de bucatarie ramane pe „SARE”.",
                ],
                en: [
                    "GRN / invoices: Lay's salt chips (including 40G/BLT/BAX/DTS) link to “LAY'S SARE” (code 340059584); cooking salt stays on “SARE”.",
                ]
            ),
            release(
                "1.0.206", "12.10.2026",
                ro: [
                    "NECTARIE: texte fara diacritice in baza de date (produse, categorii/grupe, module, facturi, stocuri, CRM, HR) si etichete tip produs (Materie prima, Marfa, Materiale curatenie, Birotica etc.).",
                ],
                en: [
                    "NECTARIE: database texts without diacritics (products, categories/groups, modules, invoices, stock, CRM, HR) and product-kind labels (raw material, merchandise, cleaning materials, stationery, etc.).",
                ]
            ),
            release(
                "1.0.205", "12.10.2026",
                ro: [
                    "Casier → Productie → Bon productie: creati bonuri numerotate si datate automat (gestiune, produs finit, cantitate). La salvare creste stocul produsului finit si scade consumul din reteta (materii prime, marfa; produsele finite din reteta se expanda 1/1).",
                ],
                en: [
                    "Cashier → Production → Production note: create auto-numbered and dated notes (warehouse, finished good, quantity). On save, finished-good stock increases and recipe consumption decreases (raw materials, merchandise; nested finished goods expand 1/1).",
                ]
            ),
            release(
                "1.0.204", "12.10.2026",
                ro: [
                    "Produse: „DONER PUI” (produs finit cu rețetă) — folosit în shaorme/chifle/extra carne pui; în rețetă puteți adăuga și produse finite (consum 1/1 din rețeta lor) pe lângă materii prime și marfă.",
                ],
                en: [
                    "Products: “DONER PUI” (finished good with recipe) — used in chicken wraps/buns/extra meat; recipes can also include finished goods (1/1 of their own recipe) besides raw materials and merchandise.",
                ]
            ),
            release(
                "1.0.203", "12.10.2026",
                ro: [
                    "NIR / facturi: lămâile (inclusiv plasă 500G) se leagă pe fișa „LAMAI”; băuturile și detergentul cu aromă lămâie rămân separate.",
                ],
                en: [
                    "GRN / invoices: fresh lemons (including 500G nets) link to “LAMAI”; lemon drinks and dish detergent stay separate.",
                ]
            ),
            release(
                "1.0.202", "12.10.2026",
                ro: [
                    "NIR / facturi: Hot Marinade (inclusiv Seasoning 1/1 KG) se leagă pe fișa „HOT MARINADE”.",
                ],
                en: [
                    "GRN / invoices: Hot Marinade (including Seasoning 1/1 KG packs) links to “HOT MARINADE”.",
                ]
            ),
            release(
                "1.0.201", "12.10.2026",
                ro: [
                    "NIR / facturi: falafel 450G (Edenia etc.) se leagă pe fișa „FALAFEL 450G”; meniul finit din catalog rămâne separat.",
                ],
                en: [
                    "GRN / invoices: 450G falafel (Edenia etc.) links to “FALAFEL 450G”; the catalog finished menu stays separate.",
                ]
            ),
            release(
                "1.0.200", "12.10.2026",
                ro: [
                    "NIR / facturi: crustă crispy (ACG 1/10 KG etc.) se leagă pe fișa „CRUSTA CRISPY”; meniurile crispy din catalog rămân separate.",
                ],
                en: [
                    "GRN / invoices: crispy coating (ACG 1/10 KG etc.) links to “CRUSTA CRISPY”; catalog crispy menus stay separate.",
                ]
            ),
            release(
                "1.0.199", "12.10.2026",
                ro: [
                    "NIR / facturi: Condimix (inclusiv Gustos 1/1 KG) se leagă pe fișa „CONDIMIX”.",
                ],
                en: [
                    "GRN / invoices: Condimix (including Gustos 1/1 KG packs) links to “CONDIMIX”.",
                ]
            ),
            release(
                "1.0.198", "12.10.2026",
                ro: [
                    "NIR / facturi: bait / batter pentru șnițel (BATTER 300 FS etc.) se leagă pe fișa „BAIT SNITEL”.",
                ],
                en: [
                    "GRN / invoices: schnitzel batter / bait (BATTER 300 FS etc.) links to “BAIT SNITEL”.",
                ]
            ),
            release(
                "1.0.197", "12.10.2026",
                ro: [
                    "NIR / facturi: Doner vită tocat (inclusiv linii cu LOT) se leagă pe fișa „DONER VITA TOCAT”; stocurile pe loturi au fost unificate.",
                ],
                en: [
                    "GRN / invoices: minced beef döner (including LOT lines) links to “DONER VITA TOCAT”; lot stocks were merged.",
                ]
            ),
            release(
                "1.0.196", "12.10.2026",
                ro: [
                    "NIR / facturi: chiflele mari se leagă pe fișa „CHIFLE MARI” (nu pe chiflele din catalog / produse finite).",
                ],
                en: [
                    "GRN / invoices: large buns link to “CHIFLE MARI” (not catalog finished-product bun sandwiches).",
                ]
            ),
            release(
                "1.0.195", "12.10.2026",
                ro: [
                    "NIR / facturi: Ceko Pizza (inclusiv FIRST 2.3KG / bax) se leagă pe fișa „CEKO PIZZA”.",
                ],
                en: [
                    "GRN / invoices: Ceko Pizza (including FIRST 2.3KG / case packs) links to “CEKO PIZZA”.",
                ]
            ),
            release(
                "1.0.194", "12.10.2026",
                ro: [
                    "NIR / facturi: ceapa roșie se leagă pe fișa „CEAPA ROSIE” (separat de galbenă și prăjită).",
                ],
                en: [
                    "GRN / invoices: red onions link to “CEAPA ROSIE” (separate from yellow and fried).",
                ]
            ),
            release(
                "1.0.193", "12.10.2026",
                ro: [
                    "NIR / facturi: ceapa prăjită / fulgi se leagă pe fișa „CEAPA PRAJITA” (separat de galbenă și roșie).",
                ],
                en: [
                    "GRN / invoices: fried onion / flakes link to “CEAPA PRAJITA” (separate from yellow and red).",
                ]
            ),
            release(
                "1.0.192", "12.10.2026",
                ro: [
                    "NIR / facturi: ceapa galbenă / albă (inclusiv 10KG) se leagă pe fișa „CEAPA GALBENA”; roșie și prăjită rămân separate.",
                ],
                en: [
                    "GRN / invoices: yellow / white onions (including 10KG packs) link to “CEAPA GALBENA”; red and fried onions stay separate.",
                ]
            ),
            release(
                "1.0.191", "12.10.2026",
                ro: [
                    "NIR / facturi: castraveții murați se leagă pe fișa „CASTRAVETI MURATI” (separat de Fabio / proaspeți).",
                ],
                en: [
                    "GRN / invoices: pickled cucumbers link to “CASTRAVETI MURATI” (separate from Fabio / fresh).",
                ]
            ),
            release(
                "1.0.190", "12.10.2026",
                ro: [
                    "NIR / facturi: castraveții proaspeți (inclusiv Fabio) se leagă pe fișa „CASTRAVETI FABIO”; murăturile rămân separate.",
                ],
                en: [
                    "GRN / invoices: fresh cucumbers (including Fabio) link to “CASTRAVETI FABIO”; pickled cucumbers stay separate.",
                ]
            ),
            release(
                "1.0.189", "12.10.2026",
                ro: [
                    "Articole: categorie nouă „Birotică” (stocabilă) — pe fișă, NIR, transferuri și inventar.",
                ],
                en: [
                    "Articles: new “Stationery” category (stockable) — on the product sheet, GRN, transfers and stock take.",
                ]
            ),
            release(
                "1.0.188", "12.10.2026",
                ro: [
                    "Articole: categorie nouă „Servicii” (nestocabilă) — pe fișă, NIR și filtre; exclusă din inventar (ex. asistență juridică).",
                ],
                en: [
                    "Articles: new “Services” category (non-stockable) — on the product sheet, GRN and filters; excluded from stock take (e.g. legal assistance).",
                ]
            ),
            release(
                "1.0.187", "12.10.2026",
                ro: [
                    "NIR / facturi: detergent vase, soluție aragaz și spray aragaz se leagă automat pe fișele existente și pe categoria Materiale curățenie.",
                ],
                en: [
                    "GRN / invoices: dish detergent, hob cleaner and hob spray auto-match existing articles and the Cleaning materials category.",
                ]
            ),
            release(
                "1.0.186", "12.10.2026",
                ro: [
                    "Articole: categorie nouă „Materiale curățenie” (stocabilă), selectabilă pe fișă, NIR, control stoc și inventar — separată de Materiale consumabile.",
                ],
                en: [
                    "Articles: new “Cleaning materials” category (stockable), available on the product sheet, GRN, stock control and stock take — separate from Consumable materials.",
                ]
            ),
            release(
                "1.0.185", "12.10.2026",
                ro: [
                    "Iconițe pe Mac: la hover apare imediat un tip cu ce face butonul (fix pentru Catalyst, unde tipul de sistem nu se vedea).",
                ],
                en: [
                    "Mac icons: hover shows a tip explaining the button (fix for Catalyst, where the system tooltip did not appear).",
                ]
            ),
            release(
                "1.0.184", "12.10.2026",
                ro: [
                    "Control / print stoc: filtrare pe una sau mai multe gestiuni (sau toate) și pe categorii; PDF cu număr de pagină.",
                    "Articole (fără produs finit): câmp Cantitate minimă pe fișă.",
                    "Stocuri → Necesar comandă: listă doar pentru articole cu minim completat, când stocul curent e sub minim (inclusiv stoc negativ).",
                ],
                en: [
                    "Stock control / print: filter by one or more warehouses (or all) and categories; PDF page numbers.",
                    "Articles (except finished goods): Minimum quantity on the product card.",
                    "Stocks → Reorder needed: only articles with a minimum set, when current stock is below that minimum (including negative stock).",
                ]
            ),
            release(
                "1.0.183", "12.10.2026",
                ro: [
                    "Iconițe: dacă țineți cursorul pe o iconiță (toolbar, buton +, meniu …), apare o scurtă explicație a acțiunii.",
                ],
                en: [
                    "Icons: hover an icon (toolbar, + button, … menu) to see a short tip explaining what it does.",
                ]
            ),
            release(
                "1.0.182", "12.10.2026",
                ro: [
                    "Articole: fiecare articol are cod obligatoriu și unic pe societate. Articolele fără cod au primit automat un număr; la creare, dacă lăsați gol, se alocă următorul liber.",
                ],
                en: [
                    "Articles: every article must have a unique code per company. Articles without a code were backfilled; on create, if left empty, the next free number is assigned.",
                ]
            ),
            release(
                "1.0.181", "12.10.2026",
                ro: [
                    "Control / print stoc și inventar: pe Mac, Export PDF deschide dialogul de salvare în folder (nu meniul de partajare).",
                ],
                en: [
                    "Stock control and stock take: on Mac, Export PDF opens the save-to-folder dialog (not the share menu).",
                ]
            ),
            release(
                "1.0.180", "12.10.2026",
                ro: [
                    "Articole: categorie nouă „Garanție” (ex. Garantie SGR) — nestocabilă; nu mai intră la inventar ca materie primă / consumabile.",
                ],
                en: [
                    "Articles: new “Deposit / guarantee” category (e.g. SGR deposit) — non-stockable; no longer treated as raw material / consumables in stock take.",
                ]
            ),
            release(
                "1.0.179", "12.10.2026",
                ro: [
                    "Stocuri: Control / print stoc — alegeți gestiunea, vedeți stocul (opțional pe categorii), export PDF sau tipărire, fără inventar.",
                ],
                en: [
                    "Inventory: Stock control / print — pick a warehouse, review stock (optionally by category), export PDF or print, without a stock take.",
                ]
            ),
            release(
                "1.0.178", "12.10.2026",
                ro: [
                    "Inventar: listare, export PDF și print grupat pe categorii (marfă, materii prime, produse finite etc.).",
                ],
                en: [
                    "Stock take: list, PDF export, and print grouped by category (merchandise, raw materials, finished goods, etc.).",
                ]
            ),
            release(
                "1.0.177", "12.10.2026",
                ro: [
                    "Inventar (doar superadmin): buton „Adu întregul stoc pe 0” — golește complet stocul gestiunii selectate, cu confirmare.",
                ],
                en: [
                    "Stock take (superadmin only): “Set entire stock to 0” clears all stock for the selected warehouse, with confirmation.",
                ]
            ),
            release(
                "1.0.176", "12.10.2026",
                ro: [
                    "Articole: pe listă apare numărul total de articole din baza de date (și „X din Y” la filtrare / căutare).",
                ],
                en: [
                    "Articles: the list shows the total number of articles in the database (and “X of Y” when filtering / searching).",
                ]
            ),
            release(
                "1.0.175", "12.10.2026",
                ro: [
                    "Inventar fizic: la creare se încarcă toate produsele (fără produse finite), inclusiv stoc 0, într-un tabel editabil cu sortare, căutare și ștergere linii.",
                    "Stocul se actualizează doar la finalizare (cu proces-verbal). Celulă goală = stoc neschimbat; 0 = stoc zero. Inventarul finalizat se poate redeschide pentru corecturi.",
                ],
                en: [
                    "Physical inventory: on create, all products load (excluding finished goods), including zero stock, in an editable table with sort, search, and row delete.",
                    "Stock updates only on finalize (with difference report). Empty cell = stock unchanged; 0 = zero stock. Finalized inventories can be reopened for corrections.",
                ]
            ),
            release(
                "1.0.174", "12.10.2026",
                ro: [
                    "Gestiune Nectarie: materiile prime cu CARTOFI se unifică automat pe CARTOFI ALBI la NIR / recepții viitoare (fără catalog).",
                ],
                en: [
                    "Nectarie inventory: raw-material potato lines map automatically to CARTOFI ALBI on future NIR / receipts (not in catalog).",
                ]
            ),
            release(
                "1.0.173", "12.10.2026",
                ro: [
                    "Gestiune Nectarie: produsele A.URSUS Cooler… se unifică automat pe URSUS Cooler 0.5 L la NIR / recepții viitoare.",
                ],
                en: [
                    "Nectarie inventory: A.URSUS Cooler… lines map automatically to catalog item URSUS Cooler 0.5 L on future NIR / receipts.",
                ]
            ),
            release(
                "1.0.172", "12.10.2026",
                ro: [
                    "Gestiune Nectarie: variantele ULEI FL / MC ulei floarea-soarelui se unifică automat pe materia primă ULEI FLOAREA SOARELUI la NIR / recepții viitoare (fără catalog).",
                ],
                en: [
                    "Nectarie inventory: ULEI FL / MC sunflower oil variants map automatically to raw material ULEI FLOAREA SOARELUI on future NIR / receipts (not in catalog).",
                ]
            ),
            release(
                "1.0.171", "12.10.2026",
                ro: [
                    "Articole / Catalog: comutator tile-uri / listă. Click pe articol deschide fișa de editare în ambele moduri.",
                ],
                en: [
                    "Articles / Catalog: switch between tiles and list. Tapping an item opens the edit sheet in both modes.",
                ]
            ),
            release(
                "1.0.170", "12.10.2026",
                ro: [
                    "Articole / Catalog: pe tile, stocul apare pe punctele de lucru (ex. Agronomie, Ploiești). In Store / On Line rămân etichete de preț, nu de stoc.",
                ],
                en: [
                    "Articles / Catalog: tiles show stock per work location (e.g. Agronomie, Ploiești). In Store / Online stay as price labels, not stock.",
                ]
            ),
            release(
                "1.0.169", "12.10.2026",
                ro: [
                    "Gestiune Nectarie: promo Granini 0.33 (SGR / arome) se unifică automat pe GRANINI 0.33 L la NIR / recepții viitoare.",
                ],
                en: [
                    "Nectarie inventory: Granini 0.33 SGR / flavor promo lines map automatically to catalog item GRANINI 0.33 L on future NIR / receipts.",
                ]
            ),
            release(
                "1.0.168", "12.10.2026",
                ro: [
                    "Gestiune Nectarie: promo Tuborg sticlă 0.33 (SGR) se unifică automat pe BERE TUBORG ST. 0.33 L la NIR / recepții viitoare.",
                ],
                en: [
                    "Nectarie inventory: Tuborg 0.33 bottle SGR promo lines map automatically to catalog item BERE TUBORG ST. 0.33 L on future NIR / receipts.",
                ]
            ),
            release(
                "1.0.167", "12.10.2026",
                ro: [
                    "Gestiune Nectarie: promo Tuborg doză 0.5 (SGR) se unifică automat pe BERE TUBORG DOZA 0.5 L la NIR / recepții viitoare.",
                ],
                en: [
                    "Nectarie inventory: Tuborg 0.5 can SGR promo lines map automatically to catalog item BERE TUBORG DOZA 0.5 L on future NIR / receipts.",
                ]
            ),
            release(
                "1.0.166", "12.10.2026",
                ro: [
                    "Nomenclatoare → Articole (și Catalog): pe fiecare tile apare stocul pe punct de lucru (suma gestiunilor legate de locație).",
                ],
                en: [
                    "Master data → Articles (and Catalog): each tile shows stock per work location (sum of warehouses linked to that location).",
                ]
            ),
            release(
                "1.0.165", "12.10.2026",
                ro: [
                    "Gestiune Nectarie: promo Bere Bucur blondă 0.35 (SGR) se unifică automat pe BERE BUCUR BLONDA 0.35 L la NIR / recepții viitoare.",
                ],
                en: [
                    "Nectarie inventory: Bere Bucur blonde 0.35 SGR promo lines map automatically to catalog item BERE BUCUR BLONDA 0.35 L on future NIR / receipts.",
                ]
            ),
            release(
                "1.0.164", "12.10.2026",
                ro: [
                    "Gestiune Nectarie: promo Carlsberg doză 0.5 (SGR) se unifică automat pe BERE CARLSBERG DOZA 0.5 L la NIR / recepții viitoare.",
                ],
                en: [
                    "Nectarie inventory: Carlsberg 0.5 can SGR promo lines map automatically to catalog item BERE CARLSBERG DOZA 0.5 L on future NIR / receipts.",
                ]
            ),
            release(
                "1.0.163", "12.10.2026",
                ro: [
                    "Gestiune Nectarie: promo Carlsberg 0.33 (SGR) se unifică automat pe articolul din catalog BERE CARLSBERG 0.33 L la NIR / recepții viitoare.",
                ],
                en: [
                    "Nectarie inventory: Carlsberg 0.33 SGR promo lines map automatically to catalog item BERE CARLSBERG 0.33 L on future NIR / receipts.",
                ]
            ),
            release(
                "1.0.162", "12.10.2026",
                ro: [
                    "În Setări → e-Factura (SPV), contabilul primește pe email un link valabil 7 zile. Data până la care este autorizat se citește din SPV. Butoane: Prelungește conectarea, Revocă conectarea, Reautorizează SPV.",
                ],
                en: [
                    "In Settings → e-Factura (SPV), the accountant receives an email link valid for 7 days. The authorization end date is read from SPV. Buttons: Extend connection, Revoke connection, Reauthorize SPV.",
                ]
            ),
            release(
                "1.0.161", "11.10.2026",
                ro: [
                    "Cererea de autorizare e-Factura pleacă pe emailul contabilului din aplicație. Nu mai depinde de programul de mail de pe calculator.",
                ],
                en: [
                    "The e-Factura authorization request is emailed to the accountant from the app. It no longer depends on the mail program on the computer.",
                ]
            ),
            release(
                "1.0.160", "11.10.2026",
                ro: [
                    "În Setări → e-Factura (SPV), emailul contabilului se salvează și cererea de autorizare pornește.",
                ],
                en: [
                    "In Settings → e-Factura (SPV), the accountant email saves and the authorization request starts.",
                ]
            ),
            release(
                "1.0.159", "11.10.2026",
                ro: [
                    "Pe bon se poate plăti și numerar și card: scrieți o sumă, restul se pune pe cealaltă metodă.",
                ],
                en: [
                    "A receipt can be paid with both cash and card: type one amount and the rest goes to the other method.",
                ]
            ),
            release(
                "1.0.158", "10.10.2026",
                ro: [
                    "Pe bonul fiscal, comutatorul In Store / On line alege prețul din tile-uri. Același preț intră pe bon.",
                ],
                en: [
                    "On the fiscal receipt, the In Store / On line switch chooses the tile price. That same price goes on the receipt.",
                ]
            ),
            release(
                "1.0.157", "10.10.2026",
                ro: [
                    "Fiecare articol are Preț vânzare In Store și Preț vânzare On Line. On Line pornește cu prețul de vânzare care exista. La casă se folosește prețul In Store.",
                ],
                en: [
                    "Each item has an in-store sale price and an online sale price. Online starts from the sale price that already existed. The cash register uses the in-store price.",
                ]
            ),
            release(
                "1.0.156", "10.10.2026",
                ro: [
                    "Pe bara de jos, încasările Glovo, Bolt și Wolt apar ca G, B și W.",
                ],
                en: [
                    "On the bottom bar, Glovo, Bolt, and Wolt takings appear as G, B, and W.",
                ]
            ),
            release(
                "1.0.155", "10.10.2026",
                ro: [
                    "Pe ecranul de vânzare, bonul fiscal din dreapta ocupă toată înălțimea. Barele de sus și de jos se opresc la bon.",
                ],
                en: [
                    "On the sale screen, the fiscal receipt on the right fills the height. The top and bottom bars stop at the receipt.",
                ]
            ),
            release(
                "1.0.154", "10.10.2026",
                ro: [
                    "La vânzare, stocul nu se mai scade. Descărcarea de gestiune se va stabili separat.",
                ],
                en: [
                    "A sale no longer reduces stock. The inventory discharge will be set up separately.",
                ]
            ),
            release(
                "1.0.153", "09.10.2026",
                ro: [
                    "Pe bonul fiscal, discountul de 100% stă imediat sub băutură. Totalul casei de marcat este totalul din aplicație.",
                ],
                en: [
                    "On the fiscal receipt, the 100% discount sits directly under the drink. The cash register total is the total shown in the app.",
                ]
            ),
            release(
                "1.0.152", "09.10.2026",
                ro: [
                    "Pe bonul fiscal, discountul de 100% al produsului din meniu se scade ca sumă. Totalul casei de marcat rămâne totalul din aplicație.",
                ],
                en: [
                    "On the fiscal receipt, a menu product’s 100% discount is subtracted as an amount. The cash register total stays the total shown in the app.",
                ]
            ),
            release(
                "1.0.151", "09.10.2026",
                ro: [
                    "POS trimite bonul fiscal, factura, raportul X și raportul Z către Datecs FP-700 prin FiscalNet.",
                    "La plata cu card, suma pleacă întâi la POS-ul bancar. Bonul se emite după ce banca acceptă, cu numărul întors de imprimantă.",
                ],
                en: [
                    "POS sends the fiscal receipt, the invoice, and the X and Z reports to the Datecs FP-700 through FiscalNet.",
                    "For a card payment, the amount goes to the bank POS first. The receipt is issued after the bank accepts, with the number returned by the printer.",
                ]
            ),
            release(
                "1.0.150", "09.10.2026",
                ro: [
                    "Dacă la emitere nu este internet, bonul și factura se salvează fără codul QR și fără mesaj de eroare.",
                ],
                en: [
                    "If there is no internet when issuing, the receipt and the invoice are saved without the QR code and without an error.",
                ]
            ),
            release(
                "1.0.149", "09.10.2026",
                ro: [
                    "Pe tile, meniul arată denumirea dată la creare, nu numele produsului principal.",
                ],
                en: [
                    "On the tile, a menu shows the name given when it was created, not the main product's name.",
                ]
            ),
            release(
                "1.0.148", "09.10.2026",
                ro: [
                    "Codul QR mare de pe bon și de pe factură deschide PDF-ul documentului.",
                    "Discountul procentual se aplică la restul bonului. SGR rămâne la prețul întreg.",
                ],
                en: [
                    "The large QR code on the receipt and on the invoice opens that document's PDF.",
                    "The percentage discount applies to the rest of the receipt. SGR stays at its full price.",
                ]
            ),
            release(
                "1.0.147", "09.10.2026",
                ro: [
                    "Codul QR cu datele bonului și ale facturii este un pătrat cât lățimea hârtiei. Sub el, pe același rând, sunt două coduri mai mici: factura.dateconta.ro și beautymanager.net.",
                ],
                en: [
                    "The QR code with the receipt and invoice data is a square as wide as the paper. Under it, on the same row, are two smaller codes: factura.dateconta.ro and beautymanager.net.",
                ]
            ),
            release(
                "1.0.146", "09.10.2026",
                ro: [
                    "Jos, pe bonul fiscal și pe factură, apare un cod QR cu toate datele documentului. Același cod se tipărește și la casa de marcat, când imprimanta este legată.",
                ],
                en: [
                    "At the bottom of the fiscal receipt and the invoice there is a QR code with the whole document. The same code is printed on the fiscal printer when it is connected.",
                ]
            ),
            release(
                "1.0.145", "09.10.2026",
                ro: [
                    "Pe factură, fiecare linie arată și procentul de TVA. Jos scrie Baza, TVA și Total, fără semnul egal.",
                ],
                en: [
                    "On the invoice, each line also shows its VAT percent. Below, Baza, VAT, and Total are written without an equals sign.",
                ]
            ),
            release(
                "1.0.144", "09.10.2026",
                ro: [
                    "La emiterea bonului, stocul produselor se scade fără eroarea de dată lipsă.",
                ],
                en: [
                    "When the receipt is issued, product stock decreases without the missing-date error.",
                ]
            ),
            release(
                "1.0.143", "09.10.2026",
                ro: [
                    "Pe Windows, la pornire apare aceeași animație ca pe Mac, timp de 10 secunde: 5 secunde „Se inițializează...” cu versiunea, apoi 5 secunde „Se încarcă societățile”.",
                ],
                en: [
                    "On Windows, startup shows the same animation as on Mac, for 10 seconds: 5 seconds of “Initializing...” with the version, then 5 seconds of “Loading companies”.",
                ]
            ),
            release(
                "1.0.142", "09.10.2026",
                ro: [
                    "CUI-ul clientului de pe bon și de pe factură se scrie ca la ANAF: cu RO dacă firma este plătitoare de TVA, fără RO dacă nu este.",
                ],
                en: [
                    "The client tax ID on the receipt and on the invoice is written as ANAF shows it: with RO when the company is a VAT payer, and without RO when it is not.",
                ]
            ),
            release(
                "1.0.141", "09.10.2026",
                ro: [
                    "Pe bon, înainte de metoda de plată, puteți aplica un discount procentual. Totalul de încasat și cotele de TVA scad cu acel procent.",
                ],
                en: [
                    "On the receipt, before the payment method, you can apply a percentage discount. The amount due and the VAT bands decrease by that percent.",
                ]
            ),
            release(
                "1.0.140", "09.10.2026",
                ro: [
                    "La crearea meniului, o bifă stabilește dacă la vânzare se pot alege mai multe produse secundare. Fără bifă se alege un singur secundar. Fiecare meniu primește un cod de produs unic.",
                ],
                en: [
                    "When a menu is created, a checkbox sets whether the sale can include several secondary products. Without it, only one secondary can be chosen. Each menu receives a unique product code.",
                ]
            ),
            release(
                "1.0.139", "09.10.2026",
                ro: [
                    "Manualul povestește unde se creează meniurile, cum se trece CUI-ul pe bon și unde se listează facturile clienților.",
                ],
                en: [
                    "The manual explains where menus are created, how the tax ID is entered on the receipt, and where client invoices are listed.",
                ]
            ),
            release(
                "1.0.138", "09.10.2026",
                ro: [
                    "Dacă ANAF arată că firma de pe CUI este radiată sau inactivă, nu se poate emite bonul sau factura. Mesajul roșu arată denumirea, CUI-ul și starea, cu variantele Fără CUI sau Corectează.",
                ],
                en: [
                    "If ANAF shows that the company for the tax ID is struck off or inactive, the receipt and the invoice cannot be issued. The red message shows the name, the tax ID, and the status, with the choices to drop the tax ID or correct it.",
                ]
            ),
            release(
                "1.0.137", "09.10.2026",
                ro: [
                    "La casă, alegeți secundarele meniului, inclusiv pe cel obligatoriu, și trebuie ales cel puțin unul. Pe bon, secundarul are prețul întreg, iar sub el apare discount 100%.",
                ],
                en: [
                    "At the register you choose the menu’s secondary products, including the required one, and at least one must be selected. On the receipt the secondary shows its full price, with a 100% discount line under it.",
                ]
            ),
            release(
                "1.0.136", "09.10.2026",
                ro: [
                    "În grupa Meniuri, coșul de gunoi este în dreapta fiecărui meniu. Pe Windows, Meniu nou, Modifică și Șterge deschid meniul ca să adăugați, schimbați sau ștergeți produsele din el.",
                ],
                en: [
                    "In the Menus group, the trash can sits on the right of each menu. On Windows, New menu, Edit, and Delete open the menu so you can add, change, or remove its products.",
                ]
            ),
            release(
                "1.0.135", "09.10.2026",
                ro: [
                    "Meniul arată poza produsului principal, la casă și în listă.",
                ],
                en: [
                    "A menu shows the photo of its main product, at the register and in the list.",
                ]
            ),
            release(
                "1.0.134", "09.10.2026",
                ro: [
                    "Pe factură, fiecare linie de pe bon arată cantitatea, prețul fără TVA, valoarea și TVA-ul.",
                ],
                en: [
                    "On the invoice, each receipt line shows the quantity, the price without VAT, the value, and the VAT.",
                ]
            ),
            release(
                "1.0.133", "09.10.2026",
                ro: [
                    "Pe bon, fiecare produs din meniu își păstrează cota de TVA și este marcat cu ea, de exemplu A 21% sau B 11%.",
                ],
                en: [
                    "On the receipt, each product in a menu keeps its own VAT rate and is marked with it, for example A 21% or B 11%.",
                ]
            ),
            release(
                "1.0.132", "09.10.2026",
                ro: [
                    "Un meniu are un produs principal și produse secundare: unul obligatoriu și până la 10 opționale. La casă alegeți secundarele vândute. Pe bon, meniul nu are cotă și preț; principalul ia prețul meniului, secundarele au discount 100%, iar SGR-ul se scade din principal. Stocul produselor din meniu scade la emitere.",
                ],
                en: [
                    "A menu has one main product and secondary products: one required and up to 10 optional. At the register you choose which optional products are sold. On the receipt the menu has no VAT rate and no price; the main product carries the menu price, secondaries show a 100% discount, and SGR is deducted from the main product. Stock for the menu products decreases when the receipt is issued.",
                ]
            ),
            release(
                "1.0.131", "09.10.2026",
                ro: [
                    "Bonul fiscal și factura fiscală sunt pe lățimea hârtiei de 80 mm, ca rola imprimantei.",
                ],
                en: [
                    "The fiscal receipt and the fiscal invoice use 80 mm paper, the width of the printer roll.",
                ]
            ),
            release(
                "1.0.130", "09.10.2026",
                ro: [
                    "La Articole, criteriul de grupe include Meniuri. Alegerea lui arată meniurile, nu doar grupele de produse.",
                ],
                en: [
                    "In Articles, the group filter includes Menus. Choosing it shows the menus, not only the product groups.",
                ]
            ),
            release(
                "1.0.129", "09.10.2026",
                ro: [
                    "Pe bonul fiscal, sub total, apar brutul și TVA-ul pe fiecare cotă. Pe factură, înainte de total, scrie baza și TVA-ul.",
                ],
                en: [
                    "On the fiscal receipt, under the total, the gross and VAT appear for each rate. On the invoice, the base and the VAT are written before the total.",
                ]
            ),
            release(
                "1.0.128", "09.10.2026",
                ro: [
                    "Pe bon, cantitatea 1 nu se mai scrie lângă produs. Apare doar când este mai mare, iar la SGR-ul cumulat se scrie mereu.",
                ],
                en: [
                    "On the receipt, a quantity of 1 is no longer written next to the product. It appears only when it is higher, and the cumulated SGR always shows its quantity.",
                ]
            ),
            release(
                "1.0.127", "09.10.2026",
                ro: [
                    "Garanția SGR de pe mai multe produse se adună într-un singur rând, pe bonul de pe ecran și în PDF.",
                ],
                en: [
                    "The SGR deposit from several products is added into a single line, on the receipt on screen and in the PDF.",
                ]
            ),
            release(
                "1.0.126", "09.10.2026",
                ro: [
                    "Pe bonul și factura fiscală salvate în PDF, lângă denumirea produsului nu mai apare litera de TVA.",
                ],
                en: [
                    "On the fiscal receipt and invoice saved as PDF, the VAT letter no longer appears next to the product name.",
                ]
            ),
            release(
                "1.0.125", "09.10.2026",
                ro: [
                    "Pe bonul și factura fiscală salvate în PDF, ultimul rând este „Document generat cu ERP Mobile by DateConta”, centrat.",
                ],
                en: [
                    "On the fiscal receipt and invoice saved as PDF, the last line is “Document generat cu ERP Mobile by DateConta”, centered.",
                ]
            ),
            release(
                "1.0.124", "09.10.2026",
                ro: [
                    "Pe bonul și factura fiscală salvate în PDF, denumirea lungă trece pe rândul următor și nu mai acoperă prețul.",
                ],
                en: [
                    "On the fiscal receipt and invoice saved as PDF, a long name wraps onto the next line and no longer covers the price.",
                ]
            ),
            release(
                "1.0.123", "09.10.2026",
                ro: [
                    "În POS, punctele de lucru se aleg din tile-uri așezate unul lângă altul.",
                ],
                en: [
                    "In POS, work locations are chosen from tiles placed side by side.",
                ]
            ),
            release(
                "1.0.122", "09.10.2026",
                ro: [
                    "Pe bon, fiecare produs se poate șterge cu × înainte să închideți bonul.",
                ],
                en: [
                    "On the receipt, each product can be removed with × before you close the receipt.",
                ]
            ),
            release(
                "1.0.121", "09.10.2026",
                ro: [
                    "În POS, încasările de pe bara de jos sunt centrate, iar produsele încap câte patru pe rând.",
                ],
                en: [
                    "In POS, the takings on the bottom bar are centered, and four products fit on each row.",
                ]
            ),
            release(
                "1.0.120", "09.10.2026",
                ro: [
                    "În Ajutor, capitolul Casier — vânzare POS explică pas cu pas catalogul, bonul, CUI-ul, factura fiscală și încasările de la ultimul Z.",
                ],
                en: [
                    "In Help, the Cashier — POS sale chapter explains the catalog, the receipt, the tax ID, the fiscal invoice, and the takings since the last Z, step by step.",
                ]
            ),
            release(
                "1.0.119", "09.10.2026",
                ro: [
                    "Dacă pe bon este trecut CUI, butonul Modernă devine inactiv.",
                ],
                en: [
                    "If a client tax ID is on the receipt, the Modern button becomes inactive.",
                ]
            ),
            release(
                "1.0.118", "09.10.2026",
                ro: [
                    "La plata modernă alegeți Glovo, Bolt sau Wolt. Pe bara de jos a POS-ului se văd încasările de la ultimul Z: numerar, card, Glovo, Bolt și Wolt.",
                ],
                en: [
                    "Modern payment asks you to choose Glovo, Bolt, or Wolt. The POS bottom bar shows takings since the last Z: cash, card, Glovo, Bolt, and Wolt.",
                ]
            ),
            release(
                "1.0.117", "09.10.2026",
                ro: [
                    "Cu bifa Tipărește și factură fiscală, butonul devine Emite bon și FF. Dacă imprimanta nu este legată, se salvează două PDF-uri: bonul și factura.",
                ],
                en: [
                    "With Also print a fiscal invoice checked, the button becomes Issue receipt and invoice. If the printer is not connected, two PDFs are saved: the receipt and the invoice.",
                ]
            ),
            release(
                "1.0.116", "09.10.2026",
                ro: [
                    "După verificarea CUI-ului la ANAF, pe bon apare denumirea clientului, sub câmpul CUI.",
                ],
                en: [
                    "After the tax ID is checked with ANAF, the client name appears on the receipt, under the tax ID field.",
                ]
            ),
            release(
                "1.0.115", "09.10.2026",
                ro: [
                    "Setări → e-Factura (SPV): trimiteți email contabilului pentru autorizare cu semnătura lui electronică. Acolo vedeți starea și până când este valabilă.",
                ],
                en: [
                    "Settings → e-Factura (SPV): email the accountant to authorize the company with their electronic signature. The same screen shows the status and how long the authorization is valid.",
                ]
            ),
            release(
                "1.0.114", "09.10.2026",
                ro: [
                    "Dacă bonul are CUI, apare bifa Tipărește și factură fiscală. La emitere se tipărește întâi bonul fiscal, apoi factura fiscală pe 57 mm. Seria fiecărui punct de lucru se stabilește în Nomenclatoare → Societăți → Serii documente.",
                ],
                en: [
                    "When a receipt has a tax ID, the checkbox Also print a fiscal invoice appears. On issue, the fiscal receipt is printed first, then the 57 mm fiscal invoice. Each work location series is set in Master data → Companies → Document series.",
                ]
            ),
            release(
                "1.0.113", "09.10.2026",
                ro: [
                    "Pe Windows, Enter la CUI-ul de pe bon îl verifică la ANAF. Dacă este corect rămâne pe bon; dacă nu, îl puteți corecta sau reveni fără CUI.",
                ],
                en: [
                    "On Windows, Enter on the receipt tax ID checks it with ANAF. If it is valid it stays on the receipt; if not, you can correct it or go back without a tax ID.",
                ]
            ),
            release(
                "1.0.112", "09.10.2026",
                ro: [
                    "Pe Windows, click pe CUI client din POS deschide aceeași tastatură numerică. Enter o închide.",
                ],
                en: [
                    "On Windows, clicking the client tax ID in POS opens the same numeric keypad. Enter closes it.",
                ]
            ),
            release(
                "1.0.111", "09.10.2026",
                ro: [
                    "Pe Windows, click pe suma primită din POS deschide o tastatură numerică. Enter o închide.",
                ],
                en: [
                    "On Windows, clicking the amount received in POS opens a numeric keypad. Enter closes it.",
                ]
            ),
            release(
                "1.0.110", "09.10.2026",
                ro: [
                    "Pe bonul din POS: cotă A 21%, B 11% sau D 0%. Încasare numerar, card sau plată modernă (Glovo, Bolt, Wolt). La numerar introduceți suma primită și vedeți restul. Până la 4 bonuri deschise, fiecare cu CUI client.",
                ],
                en: [
                    "On the POS receipt: VAT group A 21%, B 11%, or D 0%. Payment by cash, card, or modern payment (Glovo, Bolt, Wolt). For cash, enter the amount received and see the change. Up to 4 open receipts, each with a client tax ID.",
                ]
            ),
            release(
                "1.0.109", "09.10.2026",
                ro: [
                    "După punctul de lucru, POS arată ecranul de vânzare: catalogul în stânga și bonul în dreapta. Produsul apăsat intră pe bon, cu SGR-ul din fișă.",
                ],
                en: [
                    "After the work location, POS shows the sale screen: the catalog on the left and the receipt on the right. A tapped product is added to the receipt, with the SGR from its sheet.",
                ]
            ),
            release(
                "1.0.108", "08.10.2026",
                ro: [
                    "Pe Windows, modificarea unui articol folosește aceeași fișă ca pe Mac, cu poza articolului.",
                ],
                en: [
                    "On Windows, editing an article uses the same sheet as on Mac, including the article photo.",
                ]
            ),
            release(
                "1.0.107", "08.10.2026",
                ro: [
                    "În POS, denumirea produsului este centrată pe tile.",
                ],
                en: [
                    "In POS, the product name is centered on the tile.",
                ]
            ),
            release(
                "1.0.106", "08.10.2026",
                ro: [
                    "La Articole, căutarea găsește și codul. Lista se poate filtra opțional după grupa de catalog.",
                ],
                en: [
                    "In Articles, search also matches the code. The list can optionally be filtered by catalog group.",
                ]
            ),
            release(
                "1.0.105", "08.10.2026",
                ro: [
                    "În POS, Înapoi la grupe este buton, în stânga jos, când sunteți într-o grupă.",
                ],
                en: [
                    "In POS, Back to groups is a button at the bottom left when you are inside a group.",
                ]
            ),
            release(
                "1.0.104", "08.10.2026",
                ro: [
                    "Pe Windows, aplicația acoperă tot ecranul, inclusiv bara de start, până la Închidere.",
                ],
                en: [
                    "On Windows, the app covers the whole screen, including the taskbar, until you close it.",
                ]
            ),
            release(
                "1.0.103", "08.10.2026",
                ro: [
                    "Pe tile-ul din POS, codul produsului este în stânga, în fața denumirii.",
                ],
                en: [
                    "On the POS product tile, the product code is on the left, in front of the name.",
                ]
            ),
            release(
                "1.0.102", "08.10.2026",
                ro: [
                    "În POS, grupele de catalog și produsele din grupă sunt afișate în ordine alfabetică.",
                ],
                en: [
                    "In POS, catalog groups and the products inside a group are shown in alphabetical order.",
                ]
            ),
            release(
                "1.0.101", "08.10.2026",
                ro: [
                    "În POS, Ieșire este în dreapta jos. Înapoi la grupe apare în stânga aceleiași bare, când sunteți într-o grupă.",
                ],
                en: [
                    "In POS, Exit is at the bottom right. Back to groups appears on the left of the same bar when you are inside a group.",
                ]
            ),
            release(
                "1.0.100", "08.10.2026",
                ro: [
                    "Acasă → Casier: Producție (Bon producție, Bon transfer) și POS. POS umple ecranul, pe punctul de lucru ales, cu grupele de catalog și produsele ca tile-uri (poză, cod, denumire, preț în RON).",
                ],
                en: [
                    "Home → Cashier: Production (production note, transfer note) and POS. POS fills the screen for the chosen work location, with catalog groups and products as tiles (photo, code, name, price in RON).",
                ]
            ),
            release(
                "1.0.099", "08.10.2026",
                ro: [
                    "Pe Windows, Ajutor conține același manual de utilizare ca pe Mac și iPhone: cuprins, capitole și capturi.",
                ],
                en: [
                    "On Windows, Help contains the same user manual as on Mac and iPhone: contents, chapters and screenshots.",
                ]
            ),
            release(
                "1.0.098", "08.10.2026",
                ro: [
                    "Când revine internetul, datele rămase nesincronizate se trimit singure, pe Mac și pe Windows.",
                ],
                en: [
                    "When the internet returns, unsynced data is sent automatically on Mac and Windows.",
                ]
            ),
            release(
                "1.0.097", "08.10.2026",
                ro: [
                    "Nomenclatoare pe Windows are aceleași intrări ca pe Mac: Societăți, Parteneri, Catalog, Articole, Persoane și Conturi. La Societăți sunt Parametrizare, puncte de lucru și depozite.",
                    "Clienți, HR și Fișa de stoc se deschid pe aceleași secțiuni ca pe Mac.",
                    "Setări → Înapoi rămâne în aplicație. Sync offline arată conexiunea și operațiile salvate fără internet, cu Sincronizează acum și Renunță.",
                ],
                en: [
                    "Nomenclatoare on Windows uses the same entries as on Mac: Companies, Partners, Catalog, Articles, People and Accounts. Companies includes setup, work locations and warehouses.",
                    "Clients, HR and the stock sheet open on the same sections as on Mac.",
                    "Settings → Back stays in the app. Offline sync shows the connection and operations saved without internet, with Sync now and Discard.",
                ]
            ),
            release(
                "1.0.096", "08.10.2026",
                ro: [
                    "Utilitare Windows: Creare fișier import ZETTA citește PDF-urile și pozele de Raport Z, arată sumele ca să le corectați și salvează Excel-ul de notă contabilă.",
                    "Z-uri scanate → import Zetta pe Windows: fiecare pagină este un Z, Nr. înreg. pornește de la numărul ales, iar Excel-ul se salvează pe firmă.",
                ],
                en: [
                    "Windows utilities: Create ZETTA import file reads Z-report PDFs and photos, shows the amounts so you can correct them, and saves the journal Excel.",
                    "Scanned Z reports → Zetta import on Windows: each page is one Z, Nr. înreg. starts from the number you choose, and the Excel is saved per company.",
                ]
            ),
            release(
                "1.0.095", "08.10.2026",
                ro: [
                    "Pe Windows, Ieșire a fost scos din bara din stânga. Delogarea este în Setări → Deconectare. Închidere rămâne în bară și nu vă deloghează.",
                ],
                en: [
                    "On Windows, Sign out was removed from the left bar. Sign out is in Settings → Sign out. Close stays on the bar and does not sign you out.",
                ]
            ),
            release(
                "1.0.094", "08.10.2026",
                ro: [
                    "Aplicația Windows are aceeași versiune cu Mac și iPhone. Rămâneți autentificat până la Ieșire; Închidere închide fereastra fără delogare.",
                    "Setări Windows: limbă, utilizatori, sync, setări Zetta, scurtătură pe Desktop, administrare societăți și deconectare — aceleași intrări ca pe Mac.",
                    "La modificare, categoria articolului și celelalte câmpuri cu variante se aleg din listă.",
                    "Utilitare Windows: arhivă MT940 din extrasul bancar și Excel NextUp din nota contabilă PDF.",
                ],
                en: [
                    "The Windows app uses the same version as Mac and iPhone. You stay signed in until Sign out; Close quits the window without signing out.",
                    "Windows Settings: language, users, sync, Zetta settings, desktop shortcut, company administration and sign out — the same entries as on Mac.",
                    "When editing, the article category and the other choice fields use a list.",
                    "Windows utilities: an MT940 archive from the bank statement and a NextUp Excel file from the payroll journal PDF.",
                ]
            ),
            release(
                "1.0.093", "07.10.2026",
                ro: [
                    "Vânzări → Facturi clienți: autentificare RO e-Factura prin email către contabil, apoi Trimite în e-Factura (XML UBL + PDF) cu stare pe factură.",
                ],
                en: [
                    "Sales → Customer invoices: RO e-Factura authentication via email to the accountant, then Send to e-Factura (UBL XML + PDF) with per-invoice status.",
                ]
            ),
            release(
                "1.0.092", "07.10.2026",
                ro: [
                    "Vânzări → Vânzare casă marcat: listă Rapoarte Z tip BINA (Detalii, PDF, Documente, Sumă), fișă Z cu plăți/TVA, bonuri pe Z (PDF/Email/Crează factură) și grid Facturi clienți.",
                    "Preluare BF: generare sloturi de bonuri din câmpul Documente al Rapoartelor Z deja importate.",
                ],
                en: [
                    "Sales → Fiscal cash sale: BINA-style Z report list (Details, PDF, Documents, Total), Z sheet with payments/VAT, receipts per Z (PDF/Email/Create invoice) and customer invoice cards.",
                    "BF import: generate receipt slots from the Documents field of already imported Z reports.",
                ]
            ),
            release(
                "1.0.091", "07.10.2026",
                ro: [
                    "Fișa produsului: Produse adiționale (bon) — legați ex. Garantie SGR; la vânzare apar pe bon ca linii separate, cu prețul și cota TVA ale adiționalului (fără marcare manuală pe casă).",
                ],
                en: [
                    "Product sheet: Add-on products (receipt) — link e.g. SGR deposit; on sale they appear as separate receipt lines with the add-on’s own price and VAT (no manual ringing at the till).",
                ]
            ),
            release(
                "1.0.090", "07.10.2026",
                ro: [
                    "Nomenclatoare → Catalog → Grupe CM: fiecare grupă afișează câte produse (sau meniuri) conține.",
                ],
                en: [
                    "Master data → Catalog → CM groups: each group shows how many products (or menus) it contains.",
                ]
            ),
            release(
                "1.0.089", "07.10.2026",
                ro: [
                    "Vânzări → Vânzare casă marcat: alegeți întâi Rapoarte X sau Rapoarte Z; la Z vedeți lista pe punct de lucru și bonurile aferente (implicit cele de la ultimul Z / tura deschisă).",
                ],
                en: [
                    "Sales → Fiscal cash register sale: choose X or Z reports first; for Z you see the list per work location and related receipts (default: since last Z / open shift).",
                ]
            ),
            release(
                "1.0.088", "07.10.2026",
                ro: [
                    "Facturi furnizor: la creare/import, avertisment dacă există deja o factură cu aceeași dată, furnizor, număr și valoare (sau aceeași dată+furnizor+valoare când numărul e greșit) — puteți continua totuși.",
                    "NIR: pe formular apar valoarea totală a facturii și bifa „Factură plătită cash” (implicit inactivă); la activare se creează plata prin chitanță cu data facturii în registrul de casă al punctului de lucru.",
                ],
                en: [
                    "Supplier invoices: on create/import, a warning if an invoice already exists with the same date, supplier, number and amount (or same date+supplier+amount when the number is wrong) — you can still continue.",
                    "GRN: the form shows the invoice total and an “Invoice paid in cash” checkbox (off by default); when on, a cash receipt payment is created on the invoice date in the cash register for that work location.",
                ]
            ),
            release(
                "1.0.087", "07.10.2026",
                ro: [
                    "Vânzări → Vânzare casă marcat: bonuri fiscale pe punct de lucru, dată și tură (tura se închide la emiterea Raportului Z). Pentru Nectarie: cele 2 puncte din nomenclator; la alte firme — punctele definite.",
                ],
                en: [
                    "Sales → Fiscal cash register sale: fiscal receipts by work location, date and shift (a shift closes when a Z report is issued). For Nectarie: the 2 locations from master data; for other companies — their defined locations.",
                ]
            ),
            release(
                "1.0.086", "07.10.2026",
                ro: [
                    "Vânzări → Preluare BF din BINA: ecranul este pe hold deocamdată (mesaj pe ecran); rămâne tab-ul pentru reluare ulterioară.",
                ],
                en: [
                    "Sales → Import BF from BINA: screen is on hold for now (in-app message); tab kept for a later return.",
                ]
            ),
            release(
                "1.0.085", "07.10.2026",
                ro: [
                    "Lucru offline: poți salva NIR, facturi, transferuri, inventar, casă, Rapoarte Z și catalog CM fără internet; se sincronizează automat la reconectare.",
                    "Bara de jos arată Offline / N în sync; în Setări → Sync offline poți reîncerca sau renunța la operațiile în așteptare.",
                ],
                en: [
                    "Offline work: save NIR, invoices, transfers, inventory, cash register, Z reports and CM catalog without internet; they sync automatically when back online.",
                    "Bottom bar shows Offline / N pending; Settings → Offline sync lets you retry or discard queued operations.",
                ]
            ),
            release(
                "1.0.084", "05.10.2026",
                ro: [
                    "Liste: ultimele rânduri nu mai intră sub bara de jos (Catalog / grupe CM și restul ecranelor).",
                ],
                en: [
                    "Lists: last rows no longer sit under the bottom status bar (Catalog / CM groups and other screens).",
                ]
            ),
            release(
                "1.0.083", "05.10.2026",
                ro: [
                    "Setări: Utilizatori (și Societăți admin) se deschid din nou corect pe Mac/iPad.",
                ],
                en: [
                    "Settings: Users (and admin Companies) open correctly again on Mac/iPad.",
                ]
            ),
            release(
                "1.0.082", "05.10.2026",
                ro: [
                    "Nomenclatoare → Catalog: tab-uri Grupe CM (grupe, Meniuri, Produse fără grupă) și Produse; pe fișa produsului — Grupa CM (1–2 grupe).",
                ],
                en: [
                    "Master data → Catalog: CM Groups tab (groups, Menus, Ungrouped products) and Products; product sheet — CM group (1–2 groups).",
                ]
            ),
            release(
                "1.0.081", "05.10.2026",
                ro: [
                    "Vânzări: două tab-uri — Preluare BF din BINA și Vânzare casă marcat.",
                ],
                en: [
                    "Sales: two tabs — Import BF from BINA and Fiscal cash register sale.",
                ]
            ),
            release(
                "1.0.080", "05.10.2026",
                ro: [
                    "Acasă: tile nou Vânzări.",
                ],
                en: [
                    "Home: new Sales tile.",
                ]
            ),
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
