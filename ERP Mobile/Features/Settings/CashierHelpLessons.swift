import Foundation

/// Lectiile casierului, mereu in romana si in engleza, cu poza apasarii.
struct CashierHelpLesson: Identifiable {
    let id: Int
    let ro: String
    let en: String
    let image: String
}

enum CashierHelpLessons {
    static let all: [CashierHelpLesson] = [
        CashierHelpLesson(
            id: 1,
            ro: "Pe ecranul casierului sunt trei patrate mari. Ca sa vindeti, apasati patratul rosu pe care scrie POS. Nu apasati altceva.",
            en: "On the cashier screen there are three big squares. To sell, press the red square that says POS. Do not press anything else.",
            image: "HelpCashier01"
        ),
        CashierHelpLesson(
            id: 2,
            ro: "Se deschid grupele de produse. Apasati o singura grupa, de exemplu Shaorma sau Bauturi. Produsele din grupa aceea apar pe ecran.",
            en: "The product groups open. Press one group only, for example Shaorma or Drinks. The products from that group appear on the screen.",
            image: "HelpCashier02"
        ),
        CashierHelpLesson(
            id: 3,
            ro: "Apasati o data pe produs. El intra pe bon cu cantitatea 1. Daca clientul vrea doua, apasati inca o data. Ca sa va intoarceti la grupe, apasati Inapoi la grupe.",
            en: "Press the product once. It goes on the receipt with quantity 1. If the customer wants two, press it once more. To go back to the groups, press Back to groups.",
            image: "HelpCashier03"
        ),
        CashierHelpLesson(
            id: 4,
            ro: "Daca ati pus un produs din greseala, uitati-va pe bon, la randul acela. Apasati × de pe rand. Butonul este mai mare, ca sa il apasati usor. Produsul iese de pe bon. Daca produsul avea garantie SGR, garantia iese odata cu el. Nu cautati SGR separat.",
            en: "If you put a product on the receipt by mistake, look at that line. Press the × on the line. The button is larger, so it is easy to press. The product leaves the receipt. If the product had an SGR deposit, the deposit leaves with it. Do not look for SGR on its own.",
            image: "HelpCashier04"
        ),
        CashierHelpLesson(
            id: 5,
            ro: "Daca firma cere CUI pe bon, apasati campul pe care scrie CUI client, optional. Scrieti numarul. Programul intreaba ANAF si scrie singur numele firmei. Daca numele nu este cel bun, apasati Fara CUI sau Corecteaza. Daca firma este inactiva sau radiata, bonul nu se emite. Fara CUI, bonul se emite normal.",
            en: "If the company wants a tax number on the receipt, press the field that says CUI client, optional. Type the number. The program asks ANAF and writes the company name by itself. If the name is wrong, press Without CUI or Correct. If the company is inactive or struck off, the receipt will not be issued. Without a CUI, the receipt is issued as usual.",
            image: "HelpCashier05"
        ),
        CashierHelpLesson(
            id: 6,
            ro: "Ca sa scoateti si factura odata cu bonul, bifati casuta Tipareste si factura fiscala. Butonul mare se schimba si scrie Emite bon si FF. Apasati-l. Intai iese bonul fiscal. Dupa el iese factura fiscala. Nu apasati de doua ori.",
            en: "To print the invoice together with the receipt, tick the box Print a fiscal invoice too. The big button changes and says Issue receipt and FF. Press it. The fiscal receipt comes out first. The fiscal invoice comes out after it. Do not press twice.",
            image: "HelpCashier06"
        ),
        CashierHelpLesson(
            id: 7,
            ro: "Daca nu vreti factura, lasati casuta nebifata. Butonul scrie Emite bon. Apasati-l. Iese numai bonul.",
            en: "If you do not want an invoice, leave the box unticked. The button says Issue receipt. Press it. Only the receipt comes out.",
            image: "HelpCashier07"
        ),
        CashierHelpLesson(
            id: 8,
            ro: "In magazin, apasati In Store. Pretul este pretul din magazin. Apoi alegeti cum plateste clientul. La Numerar scrieti cati bani v-a dat. Programul calculeaza restul si il arata la Rest. Daca banii sunt mai putini decat totalul, programul va spune si nu emite bonul.",
            en: "In the shop, press In Store. The price is the shop price. Then choose how the customer pays. For Cash, type how much money they gave you. The program works out the change and shows it at Change. If the money is less than the total, the program tells you and does not issue the receipt.",
            image: "HelpCashier08"
        ),
        CashierHelpLesson(
            id: 9,
            ro: "La Card nu scrieti nicio suma. Apasati Card. POS-ul de card incaseaza tot totalul. Apoi apasati Emite bon.",
            en: "For Card, do not type any amount. Press Card. The card machine takes the whole total. Then press Issue receipt.",
            image: "HelpCashier09"
        ),
        CashierHelpLesson(
            id: 10,
            ro: "La Numerar + Card scrieti o singura suma: ori numerarul, ori cardul. Programul pune restul pe cealalta metoda. Nu scrieti amandoua. Daca suma scrisa este mai mare decat totalul, programul va opreste.",
            en: "For Cash + Card, type one amount only: either the cash or the card. The program puts the rest on the other method. Do not type both. If the amount you typed is bigger than the total, the program stops you.",
            image: "HelpCashier10"
        ),
        CashierHelpLesson(
            id: 11,
            ro: "Pentru Glovo, Bolt sau Wolt apasati On line. Pretul este pretul de online, nu pretul din magazin. Plata este numai Moderna. Apasati Moderna, apoi apasati Glovo, Bolt sau Wolt. Trebuie sa alegeti una. Fara alegere, bonul nu se emite. In magazin nu folositi Moderna.",
            en: "For Glovo, Bolt or Wolt, press On line. The price is the online price, not the shop price. Payment is only Modern. Press Modern, then press Glovo, Bolt or Wolt. You must choose one. Without a choice, the receipt is not issued. In the shop, do not use Modern.",
            image: "HelpCashier11"
        ),
        CashierHelpLesson(
            id: 12,
            ro: "Puteti tine deschise pana la 4 bonuri. Sus sunt numerele 1, 2, 3 si 4. Apasati + ca sa deschideti inca un bon. Apasati numarul ca sa va intoarceti la bonul acela. × inchide numai un bon gol, pe care nu este niciun produs. Un bon care are produse nu se inchide cu ×. Intai emiteti-l sau stergeti produsele cu × de pe rand.",
            en: "You can keep up to 4 receipts open. At the top are the numbers 1, 2, 3 and 4. Press + to open another receipt. Press the number to go back to that receipt. × closes only an empty receipt, with no product on it. A receipt that has products does not close with ×. First issue it, or delete the products with the × on the line.",
            image: "HelpCashier12"
        ),
        CashierHelpLesson(
            id: 13,
            ro: "Ziua nu se inchide cat timp mai este un bon cu produse pe el. Apasati Raport Z numai dupa ce toate bonurile sunt emise sau golite. Daca mai este un bon cu articole, programul va opreste si scrie: Nu puteti inchide ziua. Mai sunt bonuri cu articole. Emiteti-le sau stergeti articolele, apoi apasati Raport Z. Dupa Raport Z tura se inchide si foaia de stoc se salveaza. Sus, inainte de Raport X, sunt + Numerar si - Numerar. + Numerar baga bani in casa. - Numerar scoate bani din casa. Scrieti suma pe tastatura numerica si apasati OK. Casa primeste banii. In fata lor este Raport Produse. Lista se deschide peste ecranul POS, in fereastra aplicatiei. Casierul o vede si fara drepturi de administrator. Alegeti Z-ul. Primul este Z-ul curent: In lucru - Neinchis. Vedeti produsele vandute, pe grupe, cu cantitatea, pretul de vanzare si totalul liniei. Garantia SGR este grupa ei. Fiecare grupa are subtotal, iar la final este totalul general. Butonul Print listeaza lista pe casa de marcat. Inapoi va intoarce la lista. Inchide inchide fereastra.",
            en: "The day does not close while a receipt still has products on it. Press Report Z only after every receipt is issued or emptied. If a receipt still has articles, the program stops you and writes: You cannot close the day. Receipts still have articles. Issue them or delete the articles, then press Report Z. After Report Z the shift closes and the stock sheet is saved. At the top, before Report X, there are + Cash and - Cash. + Cash puts money into the register. - Cash takes money out of the register. Type the amount on the numeric keypad and press OK. The register receives the money. In front of them is Product report. The list opens over the POS screen, inside the application window. The cashier sees it without administrator rights. Choose the Z. The first is the current Z: In progress - Not closed. You see the products sold, by group, with the quantity, the sale price and the line total. The SGR deposit is its own group. Each group has a subtotal, and the report ends with the grand total. The Print button lists it on the cash register. Back returns to the list. Close closes the window.",
            image: "HelpCashier13"
        ),
        CashierHelpLesson(
            id: 14,
            ro: "Ca sa faceti bonuri de productie, de transfer sau de consum, iesiti din POS si apasati patratul verde Productie. Acolo sunt trei butoane: Bon productie, Bon transfer si Bon consum. Apasati butonul de care aveti nevoie.",
            en: "To make production notes, transfer notes or consumption notes, leave POS and press the green square Production. There are three buttons: Production note, Transfer note and Consumption note. Press the button you need.",
            image: "HelpCashier14"
        ),
        CashierHelpLesson(
            id: 15,
            ro: "Exemplu: ati facut tepe de pui. Apasati Bon productie, apoi Bon productie nou. Alegeti DONER PUI. Reteta este inregistrata pentru 1 kg de DONER PUI. Nu scrieti 1. Scrieti toata cantitatea pe care ati facut-o. Daca ati facut 12 kg, scrieti 12. Pe Windows, la cantitate se deschide tastatura numerica. Programul scoate din stoc materiile pentru toti cei 12 kg.",
            en: "Example: you made chicken skewers. Press Production note, then New production note. Choose DONER PUI. The recipe is registered for 1 kg of DONER PUI. Do not type 1. Type the whole quantity you made. If you made 12 kg, type 12. On Windows, the quantity opens a numeric keypad. The program takes from stock the materials for all 12 kg.",
            image: "HelpCashier15"
        ),
        CashierHelpLesson(
            id: 16,
            ro: "Dupa bonul de productie faceti bonul de transfer pentru marfa care pleaca. Apasati Bon transfer, apoi Bon transfer nou. Daca alegeti Ploiești, destinatia se completeaza cu Agronomie, si invers. In lista intra si produsele finite, de exemplu DONER PUI. Cantitatea se scrie in campul galben de sub articol, sau apasati 123. Bonul se salveaza si daca stocul devine negativ. Pe bon treceti numai ce pleaca, nu tot ce ati produs daca o parte ramane la voi.",
            en: "After the production note, make the transfer note for the goods that leave. Press Transfer note, then New transfer note. If you pick Ploiești, the destination fills with Agronomie, and the other way around. Finished goods are in the list, for example DONER PUI. Type the quantity in the yellow field under the article, or press 123. The note is saved even if stock goes negative. On the note put only what leaves, not everything you produced if some of it stays with you.",
            image: "HelpCashier16"
        ),
        CashierHelpLesson(
            id: 17,
            ro: "La Raport Z programul face singur unele bonuri de productie, din vanzarile de pe bonurile fiscale. Cu acelea nu aveti treaba. Nu le cautati si nu le mai faceti o data. Voi faceti numai bonul de productie pentru ce ati preparat voi, cum este DONER PUI, si bonul de transfer pentru ce pleaca la Agronomie. Consumul urmeaza reteta si cand cantitatea este foarte mica. Stocul poate ajunge negativ, iar inchiderea nu se opreste din cauza asta. Daca dupa listarea Z-ului apare o eroare, apasati din nou Raport Z: casa nu mai listeaza, se salveaza foaia si se golesc incasarile.",
            en: "At Report Z the program makes some production notes by itself, from the sales on the fiscal receipts. Those are not your job. Do not look for them and do not make them again. You only make the production note for what you prepared yourselves, such as DONER PUI, and the transfer note for what leaves for Agronomie. Consumption follows the recipe even when the quantity is very small. Stock can go negative, and the close does not stop because of that. If an error appears after the Z is printed, press Report Z again: the register does not print again, the sheet is saved and the takings go back to 0.",
            image: "HelpCashier17"
        ),
        CashierHelpLesson(
            id: 18,
            ro: "Bonul de consum se face cand marfa iese si nu se vinde: protocol, rebut, marfa deteriorata si alte motive de acelasi fel. Apasati Bon consum, apoi Bon consum nou. Dupa data alegeti tura: 1 - ziua sau 2 - noapte. Dupa aprobare, consumul scade din foaia de stoc a acelei date si a acelei ture. Sus scrieti motivul. Pe un bon este un singur motiv. Nu puteti pune pe acelasi bon si protocol si rebut, pentru ca nu aveti decat un singur loc unde se scrie motivul. Faceti un bon pentru protocol si alt bon pentru rebut.",
            en: "A consumption note is made when goods leave and are not sold: protocol, scrap, damaged goods and other reasons of the same kind. Press Consumption note, then New consumption note. After the date, choose the shift: 1 - day or 2 - night. After approval, the consumption is taken from the stock sheet of that date and that shift. At the top, write the reason. One note has one reason only. You cannot put protocol and scrap on the same note, because there is only one place where the reason is written. Make one note for protocol and another note for scrap.",
            image: "HelpCashier18"
        ),
        CashierHelpLesson(
            id: 19,
            ro: "Apasati Adauga produs. Ca sa gasiti articolul, filtrati dupa categorie, denumire, cod sau cod de bare. Alegeti articolul. Sub el scrieti cantitatea. Pe Windows, la cantitate se deschide tastatura numerica. Daca ati gresit articolul, apasati Sterge pe randul lui. Motivul este obligatoriu. Trebuie cel putin un articol, iar la fiecare articol trebuie scrisa cantitatea. Fara motiv sau fara cantitate, bonul nu se salveaza.",
            en: "Press Add product. To find the article, filter by category, name, code or barcode. Choose the article. Under it, type the quantity. On Windows, the quantity opens a numeric keypad. If you chose the wrong article, press Delete on its line. The reason is required. There must be at least one article, and every article must have a quantity. Without a reason or without a quantity, the note is not saved.",
            image: "HelpCashier19"
        ),
        CashierHelpLesson(
            id: 20,
            ro: "Cand salvati bonul de consum, stocul nu scade. Salvarea nu este de ajuns. Un manager trebuie sa il aprobe. Managerul poate aproba tot bonul, cu Aproba bonul, sau numai liniile bifate, cu Salveaza aprobarea pe linii. Numai liniile aprobate ies din stoc. In lista vedeti Neaprobat, Aprobat partial sau Aprobat. Dupa aprobare nu mai puteti modifica sau sterge bonul. Managerul il poate redeschide.",
            en: "When you save the consumption note, stock does not go down. Saving is not enough. A manager must approve it. The manager can approve the whole note, with Approve the note, or only the ticked lines, with Save line approval. Only the approved lines leave the stock. In the list you see Not approved, Partially approved or Approved. After approval you can no longer change or delete the note. The manager can reopen it.",
            image: "HelpCashier20"
        ),
        CashierHelpLesson(
            id: 21,
            ro: "Daca foaia de stoc a fost deja emisa si apoi se aproba un bon de consum, programul reface foile de stoc de la data bonului pana la ultima foaie emisa. La fel se intampla daca managerul redeschide sau sterge un bon deja aprobat. Voi nu recalculati nimic. Programul o face cand managerul aproba.",
            en: "If the stock sheet was already issued and a consumption note is approved afterwards, the program redoes the stock sheets from the note date through the last issued sheet. The same happens if the manager reopens or deletes a note that was already approved. You do not recalculate anything. The program does it when the manager approves.",
            image: "HelpCashier21"
        ),
        CashierHelpLesson(
            id: 22,
            ro: "Foaia de stoc o vedeti pe patratul albastru Foaie stoc. Acolo sunt numai foile punctului vostru de lucru. Foaia se creeaza cand apasati Raport Z. Un click o deschide mare, pe tot ecranul, numai cu produsele care au avut intrari sau iesiri. La tura 2, data de pe foaie este cu o zi in urma. In antet apare si ora Z-ului. Pe Val. magazin, Val. online si Profit apare totalul. Categoria Garantie SGR apare numai cu valori, fara cantitati. Ultimul rand este Bani de predat, cu suma din numerar. Dupa aceea se trage o linie si scrie CONSUMURI: aprobate, scazute din stoc, cu produs si explicatie, apoi neaprobate, inca nescazute. O puteti lista sau salva PDF. Daca o cantitate de la inchidere nu se potriveste cu depozitul, cantitatea finala are semnul !. Voi nu scrieti foaia de mana.",
            en: "You see the stock sheet on the blue square Stock sheet. Only the sheets of your work location are there. The sheet is created when you press Report Z. A click opens it large, full screen, only with products that had inflows or outflows. For shift 2, the date on the sheet is the previous day. The header also shows the Z time. Val. magazin, Val. online and Profit show a total. The Guarantee SGR category shows values only, with no quantities. The last row is Bani de predat, with the cash amount. After that a line is drawn and it says CONSUMURI: approved, deducted from stock, with the product and the explanation, then unapproved, not yet deducted. You can print it or save the PDF. If a closing quantity does not match the warehouse, the closing quantity is marked with !. You do not write the sheet by hand.",
            image: "HelpCashier22"
        ),
        CashierHelpLesson(
            id: 23,
            ro: "Sus, in Ajutor, sunt patru butoane: Privacy, Termeni, Politica GDPR si Despre aplicatie. Apasati unul. Textul se deschide pe acelasi ecran. Ca sa va intoarceti la lectii, apasati Inapoi.",
            en: "At the top of Help there are four buttons: Privacy, Terms, GDPR policy and About the app. Press one. The text opens on the same screen. To come back to the lessons, press Back.",
            image: "HelpCashier23"
        ),
    ]
}
