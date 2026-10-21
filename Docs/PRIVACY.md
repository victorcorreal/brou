# Privacy and network behavior

Brou adds no analytics SDK, usage counter or maintainer telemetry endpoint. Bug reports and feedback are voluntary. This describes the current source, not an anonymity guarantee.

## What leaves the device

- Websites receive ordinary browser requests, along with the cookies and information you choose to send. WebKit manages website storage.
- Searches go to the configured search engine on Mac and to Google on iPhone. A search is a network request, even with the blocker enabled.
- In a correctly provisioned sync build, bookmarks and folders go to the private CloudKit database of the configured container. Credentials use the synchronizable iCloud Keychain access group, not CloudKit records.
- On Mac, favicons and enabled extensions can make their own network requests. Review extension permissions and the settings you enable.

There is no Brou account or Brou sync server. Apple operates the iCloud services. No maintainer receives bookmarks or credentials through Brou's implementation.

## Local data

Bookmarks, session, settings and history live in the app's Application Support/Search directory. WebKit also stores website data. Credentials are in the system keychain under the retained Search label. Clearing website data is distinct from deleting a credential or a synchronized bookmark.

Tabs, history, cookies and website sessions are not synchronized by Brou. Mac private browsing is inherited from Search; the iPhone app does not implement a private mode. Reader mode and Dark Pages alter presentation; they do not sanitize a site or prevent all tracking.

## Diagnostics and feedback

CloudKit messages are marked private in the system log. Test worlds can write detailed diagnostics only to their isolated local files. Logs, exported data and screenshots can still contain sensitive material: inspect them before sharing. Use example.com and disposable accounts in reproductions.

Do not include passwords, cookies, Apple IDs, keychain exports, profiles, certificates or raw browsing histories in issues. Report security concerns through SECURITY.md. We do not collect browsing activity to prove adoption. GitHub download counts, if published later, will be called downloads rather than active users.
