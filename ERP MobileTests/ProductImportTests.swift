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
}
