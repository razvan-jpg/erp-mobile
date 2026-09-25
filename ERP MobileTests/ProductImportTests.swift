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
        #expect(ProductService.isFreshTomatoImportName("ROSII RO"))
        #expect(ProductService.isFreshTomatoImportName("ROSII P"))
        #expect(ProductService.isFreshTomatoImportName("MC ROSII CIORCHINE"))
        #expect(ProductService.isFreshTomatoImportName("Rosii"))
        #expect(ProductService.isFreshTomatoImportName("SOS ROSII") == false)
        #expect(ProductService.canonicalProduceName(forImportName: "MC ROSII CIORCHINE") == "ROSII RO")

        #expect(ProductService.isKapiaImportName("ARDEI KAPIA ROSU"))
        #expect(ProductService.isKapiaImportName("ardei kapia"))
        #expect(ProductService.canonicalProduceName(forImportName: "ardei kapia") == "ARDEI KAPIA ROSU")
    }

    @Test func nameSimilarityDetectsCloseProductNames() {
        #expect(ProductService.nameSimilarity("DONER VITA TOCAT", "DONER VITA TOCAT LOT 18082026") == 1)
        #expect(ProductService.nameSimilarity("CASTRAVETI MURATI", "CASTRAVETI MURATI") == 1)
        let similar = ProductService.nameSimilarity("ARDEI KAPIA", "ARDEI KAPIA ROSU")
        #expect(similar >= ProductService.provisionalNameSimilarityThreshold)
        #expect(ProductService.nameSimilarity("PEPSI COLA", "CARTOFI ALBI IMP") < ProductService.provisionalNameSimilarityThreshold)
    }
}
