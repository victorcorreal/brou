# Brou

A small WebKit browser for Mac, focused on comfortable reading, privacy and continuity with iPhone. Maintained by Victor Correal. Based on [Search by Office Commun](https://github.com/driceroland/Search), under the MIT license.

<img src="Brand/Brou.png" width="112" alt="Brou: a single white wisp of steam on black">

Brou means **broth** in Catalan. Its minimal icon is a single white wisp of steam on black. Brou 1.1.0 introduces this identity on Mac and iPhone.

## This version

- A minimal start page and new tabs with a small blue bookmark button at the bottom right. Click it to open your existing bookmark folders and links.
- Dark Pages and a text-only reading option.
- Bookmarks shared with the companion iPhone app through CloudKit.
- Passwords shared between our apps through an iCloud Keychain access group.
- Password suggestions and per-page management limited to the exact host, keeping CMS, development and public-site accounts separate. An explicit action opens the full vault.
- Fixes for download completion, resuming and sign-in forms.
- The tabs, spaces, bookmarks, reading mode, content blocker and WebKit extension support inherited from Search.

These are the current capabilities, not promises of a new reading library or session sync. History and open tabs remain local. A cold launch selects an empty start tab while keeping the previous session’s pages available; an existing empty tab is reused. Returning to an already running app leaves the current page in place. An extension-selected custom new-tab page keeps its own behavior. CloudKit currently uses **Development**, with changes fetched on launch, foreground activation and periodically. This is a development distribution, not a public notarized release.

## Build on Mac

Requires macOS 14 or later and Xcode with the Swift 6 toolchain. Extension support requires macOS 15.4 or later.

```sh
swift build
./build.sh release
open build/Brou.app
```

The Swift package and source target retain the internal name `Search` to keep upstream updates manageable. The packaged application and executable are named **Brou**. The icon is generated locally from the checked-in master artwork; no image service is needed to build.

Without a signing identity, the build is ad-hoc signed and does not have our iCloud or shared-keychain capabilities. The developer-signed version uses the existing profile described in [Provisioning/README.md](Provisioning/README.md). Using another Apple Developer account requires your own App ID, CloudKit container, keychain group and profiles in both apps. Our profiles, signing certificates and personal data are not part of the repository.

## Updating an existing installation

Install Brou over your existing variant without deleting its data. The public name changes; the following compatibility identities deliberately do not:

| Purpose | Retained identity |
| --- | --- |
| Bundle identifier | `cat.correal.search` |
| CloudKit container | `iCloud.cat.correal.search` |
| Keychain group | `E653G759EN.cat.correal.search` |
| CloudKit bookmark zone | `Search` |
| Password label | `Search` |
| Local data folder | `~/Library/Application Support/Search/` |

Cookies, sessions, preferences and stored keys keep their existing identities. Test-world names, scripting command codes, script isolation worlds and internal extension identifiers remain compatible as well. A change of name alone does not migrate or delete records. Keep the same signing team to preserve access.

## Updates and distribution

Brou does **not** check or install Office Commun releases. Its inherited updater is disabled outside explicitly configured isolated tests. Automatic update controls are hidden until Brou has its own authenticated release channel.

`./build.sh release dmg` can make a local `Brou.dmg` and `Brou.zip`. It does not generate an appcast unless `SEARCH_DOWNLOAD_URL` is explicitly set; that does not enable the app's updater. The upstream `publish.sh` and `tap.sh` are disabled. A public signed download still needs a Developer ID certificate, a suitable profile, notarization and a Brou release channel. Publishing source is a separate step.

Feedback goes to [this variant's issue tracker](https://github.com/victorcorreal/search/issues), not Office Commun. The repositories remain private while this version is reviewed.

## Verification and contribution

```sh
swift test --skip DownloadLifecycleTests
python3 Tests/dark_pages.py
```

UI probes use `SEARCH_PROBE` and isolated data. The download lifecycle cases must run in separate processes; `python3 Tests/run-ci-tests.py` runs the complete Swift suite with that isolation. `./bench` keeps its existing socket location and protocol; its name is a developer tool, not a separate distribution.

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and [Brand/README.md](Brand/README.md). The upstream `CHANGELOG.md` preserves Search's history; Brou's changes are recorded separately in `NOTES.md` and the 1.1.0 in-app notes.

## Origin and license

Brou is an independently maintained variant of Search by Office Commun. The original Git history, MIT license and copyright notices are preserved. CloudKit sync, shared keychain integration, Dark Pages, text-only reading and the fixes described above were developed in this variant before the Brou rename. Their original commits and pull requests remain in the history.

The Brou name and icon replace Search's product branding. This distribution is not an Office Commun release. See [LICENSE](LICENSE).

[Password host-scope verification](Docs/PASSWORD_HOST_SCOPE.md).

[Start-page bookmarks and verification](Docs/START_BOOKMARKS.md).
