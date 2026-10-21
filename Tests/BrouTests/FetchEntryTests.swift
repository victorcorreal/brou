import AppKit
import Foundation
import WebKit
import XCTest
@testable import Brou

@MainActor
final class FetchEntryTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
    }

    func testFailedResumeDataAllowsResumeWithoutOriginalRequest() async throws {
        let webView = makeWebView()
        let entry = FetchEntry(name: "archive.zip", request: nil, webView: webView)
        entry.failed(NSError(domain: "DownloadFixture", code: 1), resumeData: Data([1, 2, 3]))

        XCTAssertEqual(entry.state, .failed)
        XCTAssertTrue(entry.canResume)
        XCTAssertFalse(entry.canRetry)
        XCTAssertEqual(try XCTUnwrap(Fetches().beginResume(entry)?.resumeData), Data([1, 2, 3]))
    }

    func testPauseWithoutResumeDataBecomesRetryableWithVisibleReason() async throws {
        let webView = makeWebView()
        let request = URLRequest(url: URL(string: "https://example.test/archive.zip")!)
        let entry = FetchEntry(name: "archive.zip", request: request, webView: webView)

        entry.stopped(.pause, data: nil)

        XCTAssertEqual(entry.state, .failed)
        XCTAssertFalse(entry.canResume)
        XCTAssertTrue(entry.canRetry)
        XCTAssertTrue(try XCTUnwrap(entry.errorDescription).contains("doesn't let this download pause"))
    }

    func testBeginResumeRejectsDuplicateActionWhileWebKitStarts() async throws {
        let webView = makeWebView()
        let entry = FetchEntry(name: "archive.zip", request: nil, webView: webView)
        entry.failed(NSError(domain: "DownloadFixture", code: 1), resumeData: Data([1]))
        let fetches = Fetches()

        let first = try XCTUnwrap(fetches.beginResume(entry))

        XCTAssertTrue(fetches.accepts(first))
        XCTAssertNil(fetches.beginResume(entry))
    }

    func testRemovingPendingStartInvalidatesItsCallback() async throws {
        let webView = makeWebView()
        let request = URLRequest(url: URL(string: "https://example.test/archive.zip")!)
        let entry = FetchEntry(name: "archive.zip", request: request, webView: webView)
        entry.failed(NSError(domain: "DownloadFixture", code: 1), resumeData: nil)
        let fetches = Fetches()
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("retry.zip")
        let start = try XCTUnwrap(fetches.beginRetry(entry, destination: { target }))

        XCTAssertTrue(fetches.accepts(start))
        fetches.removeStarting(entry)

        XCTAssertFalse(fetches.accepts(start))
        XCTAssertNil(entry.request)
        XCTAssertNil(entry.webView)
    }

    func testALostConnectionIsResumedOnItsOwnOnceAndNotAgainFromAResumedAttempt() async throws {
        let webView = makeWebView()
        let entry = FetchEntry(name: "archive.zip", request: nil, webView: webView)
        let lost = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
        let timedOut = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

        entry.failed(timedOut, resumeData: Data([1]))
        XCTAssertFalse(entry.resumesOnItsOwn(after: timedOut))
        entry.failed(lost, resumeData: Data([1]))
        XCTAssertTrue(entry.resumesOnItsOwn(after: lost))
        XCTAssertNotNil(Fetches().beginResume(entry))

        // The resumed attempt is cut off too: its resume data is let go.
        entry.failed(lost, resumeData: Data([2]))
        XCTAssertNil(entry.resumeData)
        XCTAssertFalse(entry.canResume)
        XCTAssertFalse(entry.resumesOnItsOwn(after: lost))
    }

    func testLandingNumbersPastAFileOrAnotherDownloadUnderTheName() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Search-landing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("report.pdf")
        let partial = FetchEntry.partial(for: file)
        XCTAssertEqual(partial.lastPathComponent, "report.pdf.download")

        try Data("first".utf8).write(to: partial)
        XCTAssertEqual(Fetches.land(partial, as: file), file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))

        // "report.pdf" is there now, and "report 2.pdf" is another download's.
        try Data("second".utf8).write(to: partial)
        let theirs = FetchEntry.partial(for: folder.appendingPathComponent("report 2.pdf"))
        try Data("theirs".utf8).write(to: theirs)
        let landed = Fetches.land(partial, as: file)

        XCTAssertEqual(landed.lastPathComponent, "report 3.pdf")
        XCTAssertEqual(try Data(contentsOf: landed), Data("second".utf8))
        XCTAssertEqual(try Data(contentsOf: file), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: theirs), Data("theirs".utf8))
        XCTAssertTrue(FetchEntry.taken(folder.appendingPathComponent("report 2.pdf")))
        XCTAssertFalse(FetchEntry.taken(folder.appendingPathComponent("report 4.pdf")))
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        return WKWebView(frame: .zero, configuration: configuration)
    }
}
