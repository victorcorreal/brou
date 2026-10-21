import SwiftUI

/// A quiet entry to the existing bookmark tree on an empty tab.
struct StartBookmarks: View {
    @ObservedObject var browser: Browser
    @ObservedObject var bookmarks: Bookmarks
    @State private var showing = false
    @State private var expanded: Set<Bookmark.ID> = []

    var body: some View {
        Button {
            browser.bookmarksOpen = false
            showing.toggle()
        } label: {
            Image(systemName: "bookmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Bookmarks")
        .accessibilityLabel("Bookmarks")
        .accessibilityIdentifier("start-bookmarks-button")
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Bookmarks").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button("Manage…") {
                        showing = false
                        browser.bookmarking = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                if bookmarks.isEmpty {
                    Text("No bookmarks yet. Save a page or import your bookmarks to see them here.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ScrollView {
                        BookmarkOutline(bookmarks: bookmarks, expanded: $expanded) { url in
                            showing = false
                            browser.pickBookmark(url)
                        } openInNewTab: { url in
                            showing = false
                            browser.pickBookmark(url, inNewTab: true)
                        }
                        .padding(4)
                    }
                    .frame(height: min(300, CGFloat(bookmarks.count + 2) * 30))
                }
            }
            .padding(14)
            .frame(width: 280)
            .popoverGround(card: true)
            .onAppear { expanded = BookmarksDropdown.opening(bookmarks.roots) }
        }
        .onChange(of: browser.activeID) { _, _ in showing = false }
    }
}
