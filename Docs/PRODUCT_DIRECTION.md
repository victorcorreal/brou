# Proposed direction for Brou

Status: product proposal for review; these capabilities are not implemented by the icon change.

Brou is a small browser for reading at your own pace and continuing between Mac and iPhone. The audience is people who collect articles, news and documentation during the day and want to finish them later. The current baseline is an inherited reader, this variant's Dark Pages/text-only mode, synced bookmarks and shared keychain credentials. History and open tabs are local.

## 1. A reading library

Save an article into one small library: To read, Reading and Finished. Offer a comfortable reader with text size/width controls and a locally downloaded text copy for offline use where extraction works. Preserve a paragraph-based reading position rather than a screen-pixel offset.

The difference from the current reader is persistence: a saved reading has a state and a place to resume, separate from ordinary bookmarks. Start with articles whose text is available to the browser; retain the source link and show extraction failures clearly.

## 2. Continue on the other device

The saved library and reading position follow the person between Mac and iPhone. Offer a deliberate action to hand over the current page. Synchronize only the reading items the person chooses to save/send, without adding automatic history or cookie synchronization.

First make sync understandable: pending/complete/error states, last successful sync and retry. Verify offline edits, two-device conflicts, deletions and Apple-account changes. Keep reading records separate from the existing bookmark schema. A local article copy is offline only on devices where it has been downloaded; synchronized metadata must not imply an article is downloaded everywhere.

## 3. Temporary reading

Provide a clear temporary mode on both platforms: web data kept in an ephemeral store, no entry in browsing history, and no automatic reading/progress record sent to iCloud. Mac already has private tabs; this work brings the behavior to iPhone and verifies consistent cleanup. An intentional save is a separate visible action.

The saved text reader should render sanitized local content without remote scripts or automatic external resources. An extracted article view is not by itself a guarantee of privacy; test the outgoing network requests and data written to disk.

## Suggested order and first release

Verify and expose the reliability of current bookmark/password sync first. Then ship a small reading-library loop: save an accessible article, download its text locally, close the app, resume it, and continue at the same paragraph on the other device. Complete the temporary-mode behavior before describing the new workflow as private on both platforms.

Use the existing native UI, WebKit, local storage and CloudKit. Reuse sync mechanisms rather than adding an account service or another database dependency. Keep original Search history/attribution and document Brou's additions separately.

Technical references: [Apple's CKSyncEngine sample](https://github.com/apple/sample-cloudkit-sync-engine), [WKWebsiteDataStore](https://developer.apple.com/documentation/webkit/wkwebsitedatastore), [WebKit tracking prevention](https://webkit.org/tracking-prevention/).
