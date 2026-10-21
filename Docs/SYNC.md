# Bookmarks and credentials between devices

Brou uses two Apple services, not a custom sync backend. Both devices need the same iCloud account and builds signed for the same developer configuration.

| Data | Storage and transport | Scope |
| --- | --- | --- |
| Bookmarks and folders | CKSyncEngine, private CloudKit database | Configured container, zone Search, record type Bookmark |
| Brou credentials | Synchronizable internet-password items | Shared keychain access group, label Search |
| Tabs, history, cookies, sessions | Local files and WebKit storage | This device only |

## Bookmark schema

Each bookmark or folder has a UUID used as its CloudKit record name. Fields: `title` (String), `url` (String or absent for folders), `folder` (Int64, 0/1), `parent` (String, empty at root), `position` (Double) and `modified` (Date). The local tree is `bookmarks.json`; `icloud.json` stores engine serialization and last-agreed records. These files are user data and must never be committed.

Changes are queued after local edits. Remote changes fetch at launch, on foreground activation and every five minutes; there is no push entitlement in the current builds. Delivery is asynchronous, not instant. The server version wins a conflict on the same record; other local changes remain. Missing parents and cycles are recovered at the root. This policy is implemented, but real concurrent/offline conflict journeys have not been verified.

Signing out clears the remembered account/agreement metadata while retaining local bookmarks. Signing into another account can upload the retained local list to that account. Account switching has not been verified in devices: use a separate test install/account and back up first. Do not treat sign-out as a deletion of local data.

## Credential format

Internet-password items use the shared access group, label Search, normalized host, account and protocol. Selection reads only the chosen item's secret. Suggestions are host-scoped, with the historical www/root alias. HTTP and HTTPS entries can retain distinct references and secrets; cleartext pages only offer credentials saved for HTTP. The full vault requires an explicit action.

This is Brou's own group, separate from Apple's Passwords database. The default-browser entitlement does not change that. Mac can migrate a selected legacy login-keychain credential into the shared group; keep the same signing team when updating the existing installation.

## Development versus Production

Maintainer installations use `iCloud.cat.correal.search` in **Development** and group `E653G759EN.cat.correal.search`. These strings identify capabilities; they are not secret keys and do not give another team access.

Development and Production are different CloudKit databases. A public distribution needs the schema deployed to Production, coordinated configuration in both apps, and an explicit plan for existing data. Merely changing the entitlement does not migrate records. This source release does not switch environments or distribute profiles.

For your own team, use your own App IDs/container/group in both repos, as described in BUILDING.md. Your builds cannot access the maintainer's data. CloudKit and keychain errors must not be reported with personal records or identifiers attached.

## Evidence

On 21 October 2026, physical Mac/iPhone checks passed for bookmark create Mac→iPhone and rename/delete iPhone→Mac. Production Vault and real shared keychain checks passed for credential save/read/delete in both directions with synthetic items. The fixture records were removed. This does not establish offline behavior, conflict resolution, account switching, credential editing or visual iPhone form autofill. See VERIFICATION.md.
