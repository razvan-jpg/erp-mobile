import Foundation
import Testing
@testable import ERPMobile

struct ProductImportTests {
    @Test func detectsDuplicateProductCodeError() {
        let error = NSError(
            domain: "PGRST",
            code: 409,
            userInfo: [
                NSLocalizedDescriptionKey:
                    #"duplicate key value violates unique constraint "idx__products_company_cod""#
            ]
        )
        #expect(ProductService.isProductUniqueConstraintViolation(error))
    }

    @Test func ignoresUnrelatedErrors() {
        let error = NSError(
            domain: "PGRST",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "invalid input syntax"]
        )
        #expect(ProductService.isProductUniqueConstraintViolation(error) == false)
    }

    @Test func productNamesMatchIgnoresCaseAndWhitespace() {
        #expect(ProductService.namesMatch("ardei iute", "Ardei Iute"))
        #expect(ProductService.namesMatch("  CASTRAVETI MURATI ", "castraveti murati"))
        #expect(ProductService.namesMatch("ardei iute", "ardei kapia") == false)
    }

    @Test func productNameIgnoringLotStripsLotSuffixes() {
        #expect(ProductService.productNameIgnoringLot("DONER VITA TOCAT LOT 18082026") == "DONER VITA TOCAT")
        #expect(
            ProductService.productNameIgnoringLot("ALFA ULEI DE PALMIER (OLEINA) CUTIE 18 L (LOT 36686)")
                == "ALFA ULEI DE PALMIER (OLEINA) CUTIE 18 L"
        )
        #expect(
            ProductService.productNameIgnoringLot("ALFA ULEI DE PALMIER (OLEINA) CUTIE 18L (18082026)")
                == "ALFA ULEI DE PALMIER (OLEINA) CUTIE 18 L"
        )
        #expect(ProductService.productNameIgnoringLot("CARTOFI ALBI IMP") == "CARTOFI ALBI IMP")
    }

    @Test func freshWhitePotatoImportNamesMapToCanonicalSheet() {
        #expect(ProductService.isFreshWhitePotatoImportName("CARTOFI ALBI IMP"))
        #expect(ProductService.isFreshWhitePotatoImportName("CARTOFI ALBI RO 50+"))
        #expect(ProductService.isFreshWhitePotatoImportName("CARTOFI NOI RO"))
        #expect(ProductService.isFreshWhitePotatoImportName("MC CARTOFI ALBI 10KG"))
        #expect(ProductService.isFreshWhitePotatoImportName("NC: 07019090 - CARTOFI ALBI RO CAL I LOT 3004"))
        #expect(ProductService.isFreshWhitePotatoImportName("CARTOFI ROSII 50+") == false)
        #expect(ProductService.isFreshWhitePotatoImportName("CARTOFI DULCI") == false)
        #expect(ProductService.isFreshWhitePotatoImportName("CARTOFI CONGELATI MARQUISE") == false)
        #expect(ProductService.isFreshWhitePotatoImportName("CARTOFI PAI VID KG") == false)
    }

    @Test func tomatoAndKapiaImportNamesMapToCanonicalSheets() {
        #expect(ProductService.isFreshTomatoImportName("ROSII"))
        #expect(ProductService.isFreshTomatoImportName("ROSII RO"))
        #expect(ProductService.isFreshTomatoImportName("ROSII P"))
        #expect(ProductService.isFreshTomatoImportName("MC ROSII CIORCHINE"))
        #expect(ProductService.isFreshTomatoImportName("Rosii"))
        #expect(ProductService.isFreshTomatoImportName("SOS ROSII") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "MC ROSII CIORCHINE") == "ROSII")
        #expect(ProductService.canonicalProduceName(forImportName: "ROSII RO") == "ROSII")

        #expect(ProductService.isKapiaImportName("ARDEI KAPIA ROSU"))
        #expect(ProductService.isKapiaImportName("ardei kapia"))
        #expect(ProductService.canonicalProduceName(forImportName: "ardei kapia") == "ARDEI KAPIA ROSU")

        #expect(ProductService.isFreshCucumberImportName("CASTRAVETI FABIO"))
        #expect(ProductService.isFreshCucumberImportName("Castraveti"))
        #expect(ProductService.isFreshCucumberImportName("MC CASTRAVETI FABIO 5KG"))
        #expect(ProductService.isFreshCucumberImportName("CASTRAVETI MURATI") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "Castraveti") == "CASTRAVETI FABIO")

        #expect(ProductService.isPickledCucumberImportName("CASTRAVETI MURATI"))
        #expect(ProductService.isPickledCucumberImportName("Castraveti murati 5KG"))
        #expect(ProductService.isPickledCucumberImportName("CASTRAVETI FABIO") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "CASTRAVETI MURATI") == "CASTRAVETI MURATI")
        #expect(ProductService.canonicalProduceName(forImportName: "cornisoane murate") == "CASTRAVETI MURATI")

        #expect(ProductService.isYellowOnionImportName("CEAPA GALBENA"))
        #expect(ProductService.isYellowOnionImportName("CEAPA GALBENA 10KG"))
        #expect(ProductService.isYellowOnionImportName("5KG MC CEAPA GALBENA"))
        #expect(ProductService.isYellowOnionImportName("Ceapa alba"))
        #expect(ProductService.isYellowOnionImportName("CEAPA ROSIE") == false)
        #expect(ProductService.isYellowOnionImportName("CEAPA PRAJITA") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "CEAPA GALBENA 10KG") == "CEAPA GALBENA")

        #expect(ProductService.isRedOnionImportName("CEAPA ROSIE"))
        #expect(ProductService.isRedOnionImportName("MC CEAPA ROSIE 5KG"))
        #expect(ProductService.isRedOnionImportName("red onion"))
        #expect(ProductService.isRedOnionImportName("CEAPA GALBENA") == false)
        #expect(ProductService.isRedOnionImportName("CEAPA PRAJITA") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "CEAPA ROSIE") == "CEAPA ROSIE")

        #expect(ProductService.isFriedOnionImportName("CEAPA PRAJITA"))
        #expect(ProductService.isFriedOnionImportName("270G MC CEAPA PRAJITA FULGI"))
        #expect(ProductService.isFriedOnionImportName("500G MC CEAPA PRAJITA BUC CROC"))
        #expect(ProductService.isFriedOnionImportName("CEAPA GALBENA") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "500G MC CEAPA PRAJITA BUC CROC") == "CEAPA PRAJITA")

        #expect(ProductService.isCekoPizzaImportName("CEKO PIZZA"))
        #expect(ProductService.isCekoPizzaImportName("CEKO PIZZA FIRST 2.3KG 4 BUC/BAX"))
        #expect(ProductService.isCekoPizzaImportName("PIZZA MARGHERITA") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "CEKO PIZZA FIRST 2.3KG 4 BUC/BAX") == "CEKO PIZZA")

        #expect(ProductService.isChifleMariImportName("CHIFLE MARI"))
        #expect(ProductService.isChifleMariImportName("Chifle mari 50 buc"))
        #expect(ProductService.isChifleMariImportName("CHIFLĂ PUI") == false)
        #expect(ProductService.isChifleMariImportName("SANDWICH CHIFLA SNITEL") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "CHIFLE MARI") == "CHIFLE MARI")

        #expect(ProductService.isDonerVitaTocatImportName("DONER VITA TOCAT"))
        #expect(ProductService.isDonerVitaTocatImportName("DONER VITA TOCAT LOT 16092026"))
        #expect(ProductService.isDonerVitaTocatImportName("DONER PUI TOCAT") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "DONER VITA TOCAT LOT 17092026") == "DONER VITA TOCAT")

        #expect(ProductService.isBaitSnitelImportName("BAIT SNITEL"))
        #expect(ProductService.isBaitSnitelImportName("BATTER 300 FS 1/10 KG"))
        #expect(ProductService.isBaitSnitelImportName("SNITEL LA FARFURIE") == false)
        #expect(ProductService.isBaitSnitelImportName("SANDWICH CHIFLA SNITEL") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "BATTER 300 FS 1/10 KG") == "BAIT SNITEL")

        #expect(ProductService.isCondimixImportName("CONDIMIX"))
        #expect(ProductService.isCondimixImportName("CONDIMIX GUSTOS 1/1 KG"))
        #expect(ProductService.canonicalProduceName(forImportName: "CONDIMIX GUSTOS 1/1 KG") == "CONDIMIX")

        #expect(ProductService.isCrustaCrispyImportName("CRUSTA CRISPY"))
        #expect(ProductService.isCrustaCrispyImportName("CRUSTA CRISPY ACG 1/10 KG"))
        #expect(ProductService.isCrustaCrispyImportName("SHAORMA CRISPY") == false)
        #expect(ProductService.isCrustaCrispyImportName("CRISPY LA FARFURIE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "CRUSTA CRISPY ACG 1/10 KG") == "CRUSTA CRISPY")

        #expect(ProductService.isFalafel450ImportName("FALAFEL 450G"))
        #expect(ProductService.isFalafel450ImportName("FALAFEL 450G EDENIA"))
        #expect(ProductService.isFalafel450ImportName("FALAFEL") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "FALAFEL 450G EDENIA") == "FALAFEL 450G")

        #expect(ProductService.isHotMarinadeImportName("HOT MARINADE"))
        #expect(ProductService.isHotMarinadeImportName("HOT MARINADE SEASONING 1/1 KG"))
        #expect(ProductService.canonicalProduceName(forImportName: "HOT MARINADE SEASONING 1/1 KG") == "HOT MARINADE")

        #expect(ProductService.isLemonImportName("LAMAI"))
        #expect(ProductService.isLemonImportName("LAMAI PLASA 500G"))
        #expect(ProductService.isLemonImportName("LIPTON LAMAIE 0.5 L") == false)
        #expect(ProductService.isLemonImportName("500ML FL DETERGENT VASE LAMAIE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "LAMAI PLASA 500G") == "LAMAI")

        #expect(ProductService.isLaysSareImportName("LAY'S SARE"))
        #expect(ProductService.isLaysSareImportName("LAY'S SARE 40G/60 10BUC/BLT 6BLT/BAX"))
        #expect(ProductService.isLaysSareImportName("LAY'S SARE 40G/60 10BUC/BLT 6BLT/BAX DTS"))
        #expect(ProductService.isLaysSareImportName("SARE") == false)
        #expect(ProductService.isSareImportName("LAY'S SARE 40G") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "LAY'S SARE 40G/60 10BUC/BLT 6BLT/BAX DTS") == "LAY'S SARE")

        #expect(ProductService.isZaharImportName("ZAHAR"))
        #expect(ProductService.isZaharImportName("1KG ARO ZAHAR HT"))
        #expect(ProductService.isSareImportName("1KG ARO ZAHAR HT") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "1KG ARO ZAHAR HT") == "ZAHAR")

        #expect(ProductService.isTortillaCurcumaImportName("TORTILLA 27CM CURCUMA"))
        #expect(ProductService.isTortillaCurcumaImportName("TORTILLA CURCUMA 27 CM"))
        #expect(ProductService.isTortillaCurcumaImportName("TORTILLA MENIU") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "TORTILLA 27CM CURCUMA") == "TORTILLA 27CM CURCUMA")

        #expect(ProductService.isVarzaAlbaImportName("VARZA ALBA"))
        #expect(ProductService.isVarzaAlbaImportName("VARZA NOUA"))
        #expect(ProductService.isVarzaAlbaImportName("VARZA ROSIE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "VARZA NOUA") == "VARZA ALBA")

        #expect(ProductService.isVarzaRosieImportName("VARZA ROSIE"))
        #expect(ProductService.isVarzaRosieImportName("RED CABBAGE"))
        #expect(ProductService.isVarzaRosieImportName("VARZA ALBA") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "VARZA ROSIE") == "VARZA ROSIE")

        #expect(ProductService.isLipieTipC750ImportName("LIPIE TIP C 750G"))
        #expect(ProductService.isLipieTipC750ImportName("LIPIE TIP C"))
        #expect(ProductService.isLipieTipC750ImportName("LIPIE TIP 600G") == false)
        #expect(ProductService.isLipieTipC750ImportName("PITA") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "LIPIE TIP C 750G") == "LIPIE TIP C 750G")

        #expect(ProductService.isMiniBagheta120ImportName("MINI BAGHETA 120GR"))
        #expect(ProductService.isMiniBagheta120ImportName("MINI BAGHETA 120 G"))
        #expect(ProductService.isMiniBagheta120ImportName("BAGHETA MARE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "MINI BAGHETA 120GR") == "MINI BAGHETA 120GR")

        #expect(ProductService.isPatrunjelImportName("PATRUNJEL"))
        #expect(ProductService.isPatrunjelImportName("PATRUNJEL VERDE"))
        #expect(ProductService.isPatrunjelImportName("PARSLEY") == true)
        #expect(ProductService.canonicalProduceName(forImportName: "PATRUNJEL VERDE") == "PATRUNJEL")

        #expect(ProductService.isPieptPuiDezImportName("PIEPT DE PUI DEZ CU PIELE"))
        #expect(ProductService.isPieptPuiDezImportName("PIEPT DE PUI DEZOSAT CU PIELE"))
        #expect(ProductService.isPieptPuiDezImportName("PULPE DE PUI DEZOSATE CU PIELE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "PIEPT DE PUI DEZOSAT") == "PIEPT DE PUI DEZ CU PIELE")

        #expect(ProductService.isPulpePuiDezImportName("PULPE DE PUI DEZOSATE CU PIELE"))
        #expect(ProductService.isPulpePuiDezImportName("PULPE PUI DEZOSATE"))
        #expect(ProductService.isPulpePuiDezImportName("PIEPT DE PUI DEZ CU PIELE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "PULPE DE PUI DEZOSATE") == "PULPE DE PUI DEZOSATE CU PIELE")

        #expect(ProductService.isPitaImportName("PITA"))
        #expect(ProductService.isPitaImportName("PITA 10 BUC"))
        #expect(ProductService.isPitaImportName("PITA EXTRA") == false)
        #expect(ProductService.isPitaImportName("LIPIE TIP C 750G") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "PITA") == "PITA")

        #expect(ProductService.isPortocaleImportName("PORTOCALE 3-5 P"))
        #expect(ProductService.isPortocaleImportName("PORTOCALE"))
        #expect(ProductService.isPortocaleImportName("PORTOCALE SUC") == false)
        #expect(ProductService.isPortocaleImportName("MIRINDA ORANGE 0.5 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "PORTOCALE") == "PORTOCALE")
        #expect(ProductService.canonicalProduceName(forImportName: "PORTOCALE 3-5 P") == "PORTOCALE")

        #expect(ProductService.isPortocaleSucImportName("PORTOCALE SUC"))
        #expect(ProductService.isPortocaleSucImportName("PORTOCALE PENTRU SUC"))
        #expect(ProductService.isPortocaleSucImportName("PORTOCALE 3-5 P") == false)
        #expect(ProductService.isPortocaleSucImportName("MIRINDA ORANGE 0.5 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "PORTOCALE SUC") == "PORTOCALE")

        #expect(ProductService.isSalataVerdeImportName("SALATA VERDE"))
        #expect(ProductService.isSalataVerdeImportName("SALATA ICEBERG"))
        #expect(ProductService.isSalataVerdeImportName("SALATA DE VINETE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "SALATA VERDE") == "SALATA VERDE")

        #expect(ProductService.isBoiaDulceImportName("BOIA DULCE"))
        #expect(ProductService.isBoiaDulceImportName("1KG ARO BOIA DULCE"))
        #expect(ProductService.isBoiaDulceImportName("BOIA IUTE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "1KG ARO BOIA DULCE") == "BOIA DULCE")

        #expect(ProductService.isFainaImportName("FAINA"))
        #expect(ProductService.isFainaImportName("1KG ARO FAINA 000"))
        #expect(ProductService.isFainaImportName("FAINA PORUMB") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "1KG ARO FAINA 000") == "FAINA")

        #expect(ProductService.isPiperNegruMacinatImportName("PIPER NEGRU MACINAT"))
        #expect(ProductService.isPiperNegruMacinatImportName("1000G ARO PIPER NEGRU MACINAT"))
        #expect(ProductService.isPiperNegruMacinatImportName("PIPER VERDE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "1000G ARO PIPER NEGRU MACINAT") == "PIPER NEGRU MACINAT")

        #expect(ProductService.isKetchupDulceImportName("KETCHUP DULCE"))
        #expect(ProductService.isKetchupDulceImportName("10KG ARO KETCHUP DULCE"))
        #expect(ProductService.isKetchupDulceImportName("KETCHUP IUTE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "10KG ARO KETCHUP DULCE") == "KETCHUP DULCE")

        #expect(ProductService.isOreganoImportName("OREGANO"))
        #expect(ProductService.isOreganoImportName("110G MC OREGANO MARUNTIT"))
        #expect(ProductService.canonicalProduceName(forImportName: "110G MC OREGANO MARUNTIT") == "OREGANO")

        #expect(ProductService.isSareImportName("SARE"))
        #expect(ProductService.isSareImportName("1KG SALROM SARE IOD RECRIST"))
        #expect(ProductService.isSareImportName("LAY'S SARE 40G") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "1KG SALROM SARE IOD RECRIST") == "SARE")

        #expect(ProductService.isUsturoiImportName("USTUROI"))
        #expect(ProductService.isUsturoiImportName("1KG USTUROI CURATAT"))
        #expect(ProductService.isUsturoiImportName("SOS USTUROI") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "1KG USTUROI CURATAT") == "USTUROI")

        #expect(ProductService.isOtetImportName("OTET"))
        #expect(ProductService.isOtetImportName("1L BISTRITA OT ALC+OT VIN 9G"))
        #expect(ProductService.canonicalProduceName(forImportName: "1L BISTRITA OT ALC+OT VIN 9G") == "OTET")

        #expect(ProductService.isCurryImportName("CURRY"))
        #expect(ProductService.isCurryImportName("200G MC CURRY"))
        #expect(ProductService.isCurryImportName("SOS CURRY") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "200G MC CURRY") == "CURRY")

        #expect(ProductService.isScortisoaraImportName("SCORTISOARA"))
        #expect(ProductService.isScortisoaraImportName("200G MC SCORTISOARA MACINAT"))
        #expect(ProductService.canonicalProduceName(forImportName: "200G MC SCORTISOARA MACINAT") == "SCORTISOARA")

        #expect(ProductService.isDelikatImportName("DELIKAT"))
        #expect(ProductService.isDelikatImportName("2KG DELIK'AT LEGUME"))
        #expect(ProductService.isDelikatImportName("750G DELIKAT GAINA"))
        #expect(ProductService.canonicalProduceName(forImportName: "2KG DELIK'AT LEGUME") == "DELIKAT")
        #expect(ProductService.canonicalProduceName(forImportName: "750G DELIKAT GAINA") == "DELIKAT")

        #expect(ProductService.isBulionImportName("BULION"))
        #expect(ProductService.isBulionImportName("3.3KG SULTAN BULION 18%"))
        #expect(ProductService.canonicalProduceName(forImportName: "3.3KG SULTAN BULION 18%") == "BULION")

        #expect(ProductService.isMaslineVerziGogosariImportName("MASLINE VERZI CU GOGOSARI"))
        #expect(ProductService.isMaslineVerziGogosariImportName("3KG ARO MASL VERZI+GOG181-200"))
        #expect(ProductService.canonicalProduceName(forImportName: "3KG ARO MASL VERZI+GOG181-200") == "MASLINE VERZI CU GOGOSARI")

        #expect(ProductService.isPakmayaDrojdieImportName("PAKMAYA DROJDIE"))
        #expect(ProductService.isPakmayaDrojdieImportName("4X100G PAKMAYA DROJDIE USCATA"))
        #expect(ProductService.canonicalProduceName(forImportName: "4X100G PAKMAYA DROJDIE USCATA") == "PAKMAYA DROJDIE")

        #expect(ProductService.isSolutieAragazImportName("3L TRIUMF SOLUTIE PT ARAGAZ"))
        #expect(ProductService.isSolAragazSprayImportName("500ML TRIUMF SOL ARAGAZ SPRAY"))
        #expect(ProductService.isDetergentVaseImportName("500ML FL DETERGENT VASE LAMAIE"))
        #expect(ProductService.isMaterialeCuratenieImportName("3L TRIUMF SOLUTIE PT ARAGAZ"))
        #expect(ProductService.suggestedImportProductKind(for: "500ML FL DETERGENT VASE LAMAIE") == .materialeCuratenie)
        #expect(ProductService.canonicalProduceName(forImportName: "3L TRIUMF SOLUTIE PT ARAGAZ") == "3L TRIUMF SOLUTIE PT ARAGAZ")
        #expect(ProductService.canonicalProduceName(forImportName: "500ML TRIUMF SOL ARAGAZ SPRAY") == "500ML TRIUMF SOL ARAGAZ SPRAY")
        #expect(ProductService.canonicalProduceName(forImportName: "500ML FL DETERGENT VASE LAMAIE") == "500ML FL DETERGENT VASE LAMAIE")

        #expect(ProductService.isMaionezaImportName("MAIONEZA"))
        #expect(ProductService.isMaionezaImportName("5KG MC SOS MAIONEZA"))
        #expect(ProductService.isMaionezaImportName("Maioneza picanta"))
        #expect(ProductService.isMaionezaImportName("sos maioneză cu usturoi"))
        #expect(ProductService.canonicalProduceName(forImportName: "5KG MC SOS MAIONEZA") == "MAIONEZA")
        #expect(ProductService.canonicalProduceName(forImportName: "Maioneza picanta") == "MAIONEZA")

        #expect(ProductService.isIaurtImportName("IAURT"))
        #expect(ProductService.isIaurtImportName("5KG MC IAURT 10%"))
        #expect(ProductService.canonicalProduceName(forImportName: "5KG MC IAURT 10%") == "IAURT")

        #expect(ProductService.isSosSamuraiImportName("SOS SAMURAI"))
        #expect(ProductService.isSosSamuraiImportName("5KG UNIVER SOS SAMURAI"))
        #expect(ProductService.canonicalProduceName(forImportName: "5KG UNIVER SOS SAMURAI") == "SOS SAMURAI")

        #expect(ProductService.isSosCedarImportName("SOS CEDAR"))
        #expect(ProductService.isSosCedarImportName("SOS CEDAR GAL 5 L"))
        #expect(ProductService.canonicalProduceName(forImportName: "SOS CEDAR GAL 5 L") == "SOS CEDAR")

        #expect(ProductService.isUleiPalmierImportName("ULEI DE PALMIER"))
        #expect(ProductService.isUleiPalmierImportName("ALFA ULEI DE PALMIER (OLEINA) CUTIE 18 L"))
        #expect(ProductService.isSunflowerOilImportName("ULEI FLOAREA SOARELUI"))
        #expect(ProductService.isSunflowerOilImportName("MC ULEI FLOAREA SOARELUI"))
        #expect(ProductService.isSunflowerOilImportName("ULEI FL"))
        #expect(ProductService.isSunflowerOilImportName("ALFA ULEI DE PALMIER (OLEINA) CUTIE 18 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "ULEI FL") == "ULEI FLOAREA SOARELUI")

        #expect(ProductService.isSevenUp05ImportName("7UP LEMON LIME 0.5 L"))
        #expect(ProductService.isSevenUp05ImportName("7UP LEMON LIME 0.5L SGR"))
        #expect(ProductService.isSevenUp05ImportName("7UP 1.5 L") == false)
        #expect(ProductService.isLemonImportName("7UP LEMON LIME 0.5 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "7UP LEMON LIME 0.5 L") == "7UP LEMON LIME 0.5 L")

        #expect(ProductService.isAquaMinerala05ImportName("AQUA MINERALA 0.5 L"))
        #expect(ProductService.isAquaMinerala05ImportName("QAB AQUA CARPATICA CARBO 0.5L PET SGR"))
        #expect(ProductService.isAquaMinerala05ImportName("AQUA PLATA 0.5 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "AQUA MINERALA 0.5 L") == "AQUA MINERALA 0.5 L")

        #expect(ProductService.isAquaPlata05ImportName("AQUA PLATA 0.5 L"))
        #expect(ProductService.isAquaPlata05ImportName("QAB AQUA CARPATICA PLATA 0.5L PET SGR"))
        #expect(ProductService.isAquaPlata05ImportName("AQUA MINERALA 0.5 L") == false)
        #expect(ProductService.isAquaPlata05ImportName("1L AQUA CARPATICA PLATA SGR") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "AQUA PLATA 0.5 L") == "AQUA PLATA 0.5 L")

        #expect(ProductService.isAyranImportName("AYRAN"))
        #expect(ProductService.isAyranImportName("AIRAN"))
        #expect(ProductService.isAyranImportName("IAURT") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "AYRAN") == "AYRAN")

        #expect(ProductService.isBereBucur035ImportName("BERE BUCUR BLONDA 0.35 L"))
        #expect(ProductService.isBereBucur035ImportName("TBG-BUCUR BERE BLONDA 0.35l 20/bax SGR promo"))
        #expect(ProductService.isBereBucur035ImportName("BERE BUCUR 0.5 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "TBG-BUCUR BERE BLONDA 0.35l SGR") == "BERE BUCUR BLONDA 0.35 L")

        #expect(ProductService.isCarlsberg033ImportName("BERE CARLSBERG 0.33 L"))
        #expect(ProductService.isCarlsberg033ImportName("TBG-CARLSBERG 0.33L NRB 12/bx SGR promo"))
        #expect(ProductService.isCarlsberg033ImportName("BERE CARLSBERG DOZA 0.5 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "TBG-CARLSBERG 0.33L SGR") == "BERE CARLSBERG 0.33 L")

        #expect(ProductService.isCarlsberg05DozaImportName("BERE CARLSBERG DOZA 0.5 L"))
        #expect(ProductService.isCarlsberg05DozaImportName("TBG-CARLSBERG can 0.5 L 12/bx SGR promo"))
        #expect(ProductService.isCarlsberg05DozaImportName("BERE CARLSBERG 0.33 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "TBG-CARLSBERG can 0.5 L SGR") == "BERE CARLSBERG DOZA 0.5 L")

        #expect(ProductService.isTuborg05DozaImportName("BERE TUBORG DOZA 0.5 L"))
        #expect(ProductService.isTuborg05DozaImportName("TUBORG 0.5L DOZA SGR"))
        #expect(ProductService.isTuborg05DozaImportName("BERE TUBORG ST. 0.33 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "TUBORG 0.5 DOZA PROMO") == "BERE TUBORG DOZA 0.5 L")

        #expect(ProductService.isTuborg033ImportName("BERE TUBORG ST. 0.33 L"))
        #expect(ProductService.isTuborg033ImportName("TUBORG 0.33L SGR"))
        #expect(ProductService.isTuborg033ImportName("BERE TUBORG DOZA 0.5 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "TUBORG 0.33L NRB") == "BERE TUBORG ST. 0.33 L")

        #expect(ProductService.isGranini033ImportName("GRANINI 0.33 L"))
        #expect(ProductService.isGranini033ImportName("Tbg-Granini piersici 0.33l 12/bax SGR promo"))
        #expect(ProductService.isGranini033ImportName("*2.SGR-Granini 0.33l Visine (1=12buc)pet"))
        #expect(ProductService.isGranini033ImportName("GRANINI 1 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "TBG-GRANINI Limonada + capsuni 0.33L SGR") == "GRANINI 0.33 L")

        #expect(ProductService.isLiptonLamaie05ImportName("LIPTON LAMAIE 0.5 L"))
        #expect(ProductService.isLiptonLamaie05ImportName("LIPTON LEMON 500ML PET 12X DRS NEW"))
        #expect(ProductService.isLiptonLamaie05ImportName("QAB LIPTON ICE TEA LEMON 0.5L 12BUC/BAX SGR"))
        #expect(ProductService.isLiptonLamaie05ImportName("LIPTON PIERSICI 0.5 L") == false)
        #expect(ProductService.isLiptonLamaie05ImportName("LIPTON LAMAIE 250ML CAN") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "LIPTON LEMON 500ML PET") == "LIPTON LAMAIE 0.5 L")

        #expect(ProductService.isLiptonPiersici05ImportName("LIPTON PIERSICI 0.5 L"))
        #expect(ProductService.isLiptonPiersici05ImportName("LIPTON ICE TEA PEACH 500ML PET 12X DRS"))
        #expect(ProductService.isLiptonPiersici05ImportName("QAB LIPTON ICE TEA PIERSICI 0.5L 12/BAX SGR"))
        #expect(ProductService.isLiptonPiersici05ImportName("LIPTON LAMAIE 0.5 L") == false)
        #expect(ProductService.isLiptonPiersici05ImportName("LIPTON PIERSICA 250ML CAN") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "LIPTON ICE TEA PEACH 500ML") == "LIPTON PIERSICI 0.5 L")

        #expect(ProductService.isMirindaOrange05ImportName("MIRINDA ORANGE 0.5 L"))
        #expect(ProductService.isMirindaOrange05ImportName("MIRINDA ORANGE 500ML PET 6X DRS NEW"))
        #expect(ProductService.isMirindaOrange05ImportName("QAB MIRINDA ORANGE 0.5L 6 / BAX SGR"))
        #expect(ProductService.isMirindaOrange05ImportName("MIRINDA ORANGE DOZA 0.33 L") == false)
        #expect(ProductService.isMirindaOrange05ImportName("QAB Mirinda Orange 0.33L doza*6 TT SGR") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "MIRINDA ORANGE 500ML PET") == "MIRINDA ORANGE 0.5 L")

        #expect(ProductService.isMirindaOrange033DozaImportName("MIRINDA ORANGE DOZA 0.33 L"))
        #expect(ProductService.isMirindaOrange033DozaImportName("MIRINDA ORANGE CAN 330ML 6X DRS NEW"))
        #expect(ProductService.isMirindaOrange033DozaImportName("QAB Mirinda Orange 0.33L doza*6 TT SGR"))
        #expect(ProductService.isMirindaOrange033DozaImportName("MIRINDA ORANGE 0.5 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "MIRINDA ORANGE CAN 330ML") == "MIRINDA ORANGE DOZA 0.33 L")

        #expect(ProductService.isMountainDew05ImportName("MOUNTAIN DEW 0.5 L"))
        #expect(ProductService.isMountainDew05ImportName("MOUNTAIN DEW 500ML PET 6X DRS"))
        #expect(ProductService.isMountainDew05ImportName("MTN DEW 0.5L SGR"))
        #expect(ProductService.isMountainDew05ImportName("MOUNTAIN DEW 0.33 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "MOUNTAIN DEW 500ML PET") == "MOUNTAIN DEW 0.5 L")

        #expect(ProductService.isPepsiCola05ImportName("PEPSI COLA 0.5 L"))
        #expect(ProductService.isPepsiCola05ImportName("PEPSI COLA 500ML PET 12X DRS"))
        #expect(ProductService.isPepsiCola05ImportName("QAB Pepsi Cola 0.5L 12/BAX SGR"))
        #expect(ProductService.isPepsiCola05ImportName("PEPSI TWIST 0.5 L") == false)
        #expect(ProductService.isPepsiCola05ImportName("PEPSI ZERO 0.5 L") == false)
        #expect(ProductService.isPepsiCola05ImportName("PEPSI COLA DOZA 0.33 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "PEPSI COLA 500ML PET") == "PEPSI COLA 0.5 L")

        #expect(ProductService.isPepsiCola033DozaImportName("PEPSI COLA DOZA 0.33 L"))
        #expect(ProductService.isPepsiCola033DozaImportName("PEPSI COLA  330ML DTS 60 ANI 12X DRS"))
        #expect(ProductService.isPepsiCola033DozaImportName("QAB PEPSI COLA DOZA 0.33L DTS 12/bax TT SGR"))
        #expect(ProductService.isPepsiCola033DozaImportName("PEPSI COLA 0.5 L") == false)
        #expect(ProductService.isPepsiCola033DozaImportName("PEPSI ZERO CAN 330ML") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "PEPSI COLA 330ML DTS") == "PEPSI COLA DOZA 0.33 L")

        #expect(ProductService.isPepsiTwist05ImportName("PEPSI TWIST 0.5 L"))
        #expect(ProductService.isPepsiTwist05ImportName("PEPSI TWIST 500ML PET 12X DRS"))
        #expect(ProductService.isPepsiTwist05ImportName("QAB PEPSI TWIST 0.5L 12/BAX SGR"))
        #expect(ProductService.isPepsiTwist05ImportName("PEPSI COLA 0.5 L") == false)
        #expect(ProductService.isPepsiTwist05ImportName("PEPSI ZERO 0.5 L") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "PEPSI TWIST 500ML PET") == "PEPSI TWIST 0.5 L")

        #expect(ProductService.isPepsiZero05ImportName("PEPSI ZERO 0.5 L"))
        #expect(ProductService.isPepsiZero05ImportName("PEPSI ZERO 500ML PET 6X DRS"))
        #expect(ProductService.isPepsiZero05ImportName("QAB Pepsi ZERO 0.5L 6/BAX SGR"))
        #expect(ProductService.isPepsiZero05ImportName("PEPSI COLA 0.5 L") == false)
        #expect(ProductService.isPepsiZero05ImportName("PEPSI TWIST 0.5 L") == false)
        #expect(ProductService.isPepsiZero05ImportName("PEPSI ZERO VANILIE 330ML") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "PEPSI ZERO 500ML PET") == "PEPSI ZERO 0.5 L")

        #expect(ProductService.isPepsiZeroVanilie033ImportName("PEPSI ZERO VANILIE 0.33 L"))
        #expect(ProductService.isPepsiZeroVanilie033ImportName("PEPSI ZERO VANILIE 330ML 6X DRS"))
        #expect(ProductService.isPepsiZeroVanilie033ImportName("PEPSI ZERO VANILLA CAN 0.33L"))
        #expect(ProductService.isPepsiZeroVanilie033ImportName("PEPSI ZERO 0.5 L") == false)
        #expect(ProductService.isPepsiZeroVanilie033ImportName("PEPSI ZERO CAN 330ML") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "PEPSI ZERO VANILIE 330ML") == "PEPSI ZERO VANILIE 0.33 L")

        #expect(ProductService.canonicalProduceName(forImportName: "ALFA ULEI DE PALMIER (OLEINA) CUTIE 18 L") == "ULEI DE PALMIER")

        #expect(ProductService.isArdeiIuteImportName("ARDEI IUTE"))
        #expect(ProductService.isArdeiIuteImportName("ardei iute"))
        #expect(ProductService.isArdeiIuteImportName("ARDEI KAPIA ROSU") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "ardei iute") == "ARDEI IUTE")

        #expect(ProductService.isAripiPuiImportName("ARIPI PUI"))
        #expect(ProductService.isAripiPuiImportName("ARIPI MARINATE 1KG ED CHE"))
        #expect(ProductService.isAripiPuiImportName("ARIPIOARE LA FARFURIE") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "ARIPI MARINATE 1KG ED CHE") == "ARIPI PUI")
    }

    @Test func nameSimilarityDetectsCloseProductNames() {
        #expect(ProductService.nameSimilarity("DONER VITA TOCAT", "DONER VITA TOCAT LOT 18082026") == 1)
        #expect(ProductService.nameSimilarity("CASTRAVETI MURATI", "CASTRAVETI MURATI") == 1)
        let similar = ProductService.nameSimilarity("ARDEI KAPIA", "ARDEI KAPIA ROSU")
        #expect(similar >= ProductService.provisionalNameSimilarityThreshold)
        #expect(ProductService.nameSimilarity("PEPSI COLA", "CARTOFI ALBI IMP") < ProductService.provisionalNameSimilarityThreshold)
    }
}
