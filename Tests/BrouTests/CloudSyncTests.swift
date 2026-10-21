import XCTest
@testable import Brou

/// The list as records and back (see CloudSync.swift): nothing lost, nothing
/// out of order, whatever two devices did at once.
final class CloudSyncTests: XCTestCase {
    private func site(_ title: String) -> Bookmark {
        .site(title, URL(string: "https://\(title.lowercased()).example/")!)
    }

    func testRoundTripKeepsTreeAndOrder() {
        let tree: [Bookmark] = [
            site("A"),
            .folder("Work", [site("B"), .folder("Deep", [site("C")]), site("D")]),
            .folder("Empty", []),
            site("E"),
        ]
        let back = CloudSync.tree(CloudSync.flatten(tree))
        XCTAssertEqual(back, tree)
    }

    func testFoldersHaveNoAddress() {
        let flat = CloudSync.flatten([.folder("Work", [site("B")])])
        XCTAssertEqual(flat.values.filter(\.folder).count, 1)
        XCTAssertNil(flat.values.first(where: \.folder)?.url)
    }

    func testOrphanGoesToTopLevel() {
        let folder = Bookmark.folder("Gone", [site("Kept")])
        var flat = CloudSync.flatten([site("A"), folder])
        flat[folder.id.uuidString] = nil
        let back = CloudSync.tree(flat)
        XCTAssertEqual(back.map(\.title).sorted(), ["A", "Kept"])
    }

    @MainActor func testCycleFromTwoMovesStaysVisible() {
        let one = Bookmark.folder("One", [])
        let two = Bookmark.folder("Two", [])
        var flat = CloudSync.flatten([one, two])
        flat[one.id.uuidString]?.parent = two.id.uuidString
        flat[two.id.uuidString]?.parent = one.id.uuidString
        let back = CloudSync.tree(flat)
        XCTAssertEqual(Bookmarks.folders(back).count, 2)
    }

    func testPositionThenIdOrdersSiblings() {
        let a = site("A"), b = site("B"), c = site("C")
        var flat = CloudSync.flatten([a, b, c])
        flat[c.id.uuidString]?.position = -1
        XCTAssertEqual(CloudSync.tree(flat).map(\.title), ["C", "A", "B"])
    }
}
