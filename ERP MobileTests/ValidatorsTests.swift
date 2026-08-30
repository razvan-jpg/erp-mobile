import Testing
@testable import ERPMobile

struct ValidatorsTests {
    @Test func validEmail() {
        #expect(Validators.isValidEmail("user@dateconta.ro"))
        #expect(!Validators.isValidEmail("invalid-email"))
    }

    @Test func validCNPFormat() {
        #expect(Validators.isValidCNP("0000000000000"))
        #expect(Validators.isGDPRCNPPlaceholder("0000000000000"))
        #expect(!Validators.isGDPRCNPPlaceholder("1234567890123"))
        #expect(!Validators.isValidCNP("123"))
        #expect(!Validators.isValidCNP("abcdefghijklm"))
    }

    @Test func validPhone() {
        #expect(Validators.isValidPhone("0721234567"))
        #expect(!Validators.isValidPhone("123"))
    }
}
