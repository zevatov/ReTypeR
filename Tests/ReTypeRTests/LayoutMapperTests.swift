import XCTest
@testable import ReTypeR

final class LayoutMapperTests: XCTestCase {
    
    override func setUpWithError() throws {
        super.setUp()
        // Ensure ABC and Russian mappings are loaded for the test
        LayoutMapper.shared.refreshAvailableLayouts()
        LayoutMapper.shared.buildBidirectionalMap(
            layoutAID: "com.apple.keylayout.ABC",
            layoutBID: "com.apple.keylayout.Russian"
        )
    }
    
    func testEnglishToRussianConversion() {
        // Standard word translation: ghjdthbv -> проверим
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv"), "проверим")
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv "), "проверим ")
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv!"), "проверим!")
        
        // Capitalization
        XCTAssertEqual(LayoutMapper.shared.convert("Ghjdthbv"), "Проверим")
        
        // Mixed text
        XCTAssertEqual(LayoutMapper.shared.convert("Ghjdthbv - ntcn"), "Проверим - тест")
    }
    
    func testRussianToEnglishConversion() {
        // Standard word translation: ьн уьфшд -> my email
        XCTAssertEqual(LayoutMapper.shared.convert("ьн уьфшд"), "my email")
        XCTAssertEqual(LayoutMapper.shared.convert("ьн уьфшд!"), "my email!")
        
        // Capitalization
        XCTAssertEqual(LayoutMapper.shared.convert("Ьн уьфшд"), "My email")
    }
    
    func testSpecialCharactersMapping() {
        // Test standard punctuation mapping under Russian Mac layout by placing them inside a word to avoid ties.
        
        // Key 0x29: ; in ABC -> ж in RUS
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv;"), "проверимж")
        XCTAssertEqual(LayoutMapper.shared.convert("проверимж"), "ghjdthbv;")
        
        // Key 0x21: [ in ABC -> х in RUS
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv["), "проверимх")
        XCTAssertEqual(LayoutMapper.shared.convert("проверимх"), "ghjdthbv[")
        
        // Key 0x1e: ] in ABC -> ъ in RUS
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv]"), "проверимъ")
        XCTAssertEqual(LayoutMapper.shared.convert("проверимъ"), "ghjdthbv]")
    }
}
