# Project naming: Search → Brou

21 October 2026. Product and development names now agree: Brou.

| Item | Current name |
| --- | --- |
| Mac repository / checkout | victorcorreal/brou / ~/work/brou |
| iPhone repository / checkout | victorcorreal/brou-ios / ~/work/brou-ios |
| Operational folder | ~/Vcode/Mac/Brou |
| Swift package, executable target and module | Brou |
| Mac test target | BrouTests |
| iPhone Xcode project / scheme / target | Brou.xcodeproj / Brou / Brou |
| Mac provisioning helper | BrouProvisioning.xcodeproj / BrouProvisioning |
| App, entry point and signing input files | Brou.app, BrouApp, Brou.entitlements |

## Compatibility remains deliberate

The bundle ID cat.correal.search, Apple team, iCloud.cat.correal.search container, Development environment, Search bookmark zone, keychain access group/label and Application Support/Search paths are unchanged. Existing Apple-event codes, JavaScript message/world names, settings keys and SEARCH_* developer variables also remain stable. “Search” as a normal browsing action is not product branding.

These identifiers give existing installations access to their bookmarks, credentials, sessions and website data. Renaming them would require a tested data migration and, for signing capabilities, separate Apple configuration. Source organization does not require that migration.

Original Search/Office Commun attribution, copyright, upstream URLs and historical release records remain. Published v1.1.0 archives keep their original source layout; use that version's instructions when building the tag. Current main uses the Brou commands in BUILDING.md.

GitHub redirects the old victorcorreal/search and search-ios URLs, including the links already submitted to OpenAI. Do not create new repositories under those old names: doing so would break those redirects. Local Git origins now use the new URLs; the Mac upstream remote still points to driceroland/Search and is read-only.

The operational updater installs reviewed Brou main. Upstream integration is reviewed separately in branches/PRs; it must not silently merge tags into a personal installation. Folder renaming does not update an installed app or alter its data.

## Validation of this rename

- Mac: signed Release build and strict signature verification; all 122 Swift cases completed with zero failures (one existing WebKit capability skip), including ten downloads in isolated processes.
- Mac: address, popup, history and 62 page-find regressions passed; the isolated startup/bookmark/session probe passed all 12 checks.
- iPhone: the regenerated Brou project built for the simulator without signing; six Vault, 13 WebKit form/blocker and seven page-colour checks passed.
- Renamed entitlements match their previous values. The newly built Mac app's entitlements match the installed app. License bytes and Apple-event codes are unchanged.
- Old repository, PR, release and verification-document URLs redirect successfully for both repositories.

These checks cover source/build compatibility. This rename does not install a new version on either device or establish new evidence of iCloud synchronization. See [VERIFICATION.md](VERIFICATION.md) for device tests and remaining limitations.
