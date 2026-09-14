import XCTest
@testable import ReTypeR

/// Unit tests for the v1.3 frequency layer that can run headless.
final class FrequencyAndCaptureTests: XCTestCase {

    // MARK: - BundleFrequencyStore (v1.3 §1.1.1)

    func testBundleFrequencyStoreRankLookup() {
        let store = BundleFrequencyStore()

        // Top Russian word from OpenSubtitles 2018.
        let ya = store.rank(of: "я", language: "ru")
        XCTAssertNotNil(ya, "«я» must be present in frequency_ru.txt")
        XCTAssertLessThanOrEqual(ya!, 5, "«я» is a top-5 Russian word")

        let privet = store.rank(of: "привет", language: "ru")
        XCTAssertNotNil(privet)
        XCTAssertLessThan(privet!, 1000)

        let hello = store.rank(of: "hello", language: "en")
        XCTAssertNotNil(hello)
        XCTAssertLessThanOrEqual(hello!, 500, "«hello» is a common English word")

        // Unknown words miss.
        XCTAssertNil(store.rank(of: "qqzzxxww", language: "en"))
        XCTAssertNil(store.rank(of: "ппрриветт", language: "ru"))

        // Case-insensitive.
        XCTAssertEqual(store.rank(of: "ПРИВЕТ", language: "ru"), privet)
    }

    func testSmartScorerUsesBundleStoreByDefault() {
        // The production default must be the bundle-backed store, not the
        // empty fixture.
        XCTAssertTrue(SmartScorer.shared.frequencyStore is BundleFrequencyStore)
    }
}
