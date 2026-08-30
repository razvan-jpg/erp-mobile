import Testing
@testable import ERPMobile

struct NameFormatterTests {
    @Test func capitalizesFirstLetter() {
        #expect(NameFormatter.formatName("ion") == "Ion")
        #expect(NameFormatter.formatName("MARIA") == "Maria")
    }

    @Test func capitalizesAfterSpace() {
        #expect(NameFormatter.formatName("ion popescu") == "Ion Popescu")
        #expect(NameFormatter.formatName("ana maria ionescu") == "Ana Maria Ionescu")
    }

    @Test func capitalizesAfterHyphen() {
        #expect(NameFormatter.formatName("ion-popescu") == "Ion-Popescu")
        #expect(NameFormatter.formatName("ana-maria") == "Ana-Maria")
    }
}
