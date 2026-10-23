import Foundation
import XCTest
@testable import Brou

/// Every XCTest run is a test run, with or without SEARCH_PROBE, so whatever
/// a test reaches — settings, the folder, the passwords' keychain label —
/// belongs to a test world, never to the browser somebody is using. Nothing
/// here touches the keychain, the settings or the disk.
final class StoreTests: XCTestCase {
    func testXCTestAloneMakesATestRun() {
        let probe = ProcessInfo.processInfo.environment["SEARCH_PROBE"]
        unsetenv("SEARCH_PROBE")
        defer { if let probe { setenv("SEARCH_PROBE", probe, 1) } }

        XCTAssertTrue(Store.underXCTest)
        XCTAssertFalse(Bundle.main.executablePath?.contains("/.build/") == true,
                       "xctest runs from Xcode, not from the build folder: only the XCTest check can catch it")
        XCTAssertTrue(Store.testing)
        // A world, so the passwords use "Search (<world>)", never "Search".
        XCTAssertNotNil(Store.world)
    }
}
