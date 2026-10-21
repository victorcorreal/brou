# Brou 1.1.0 verification — 21 October 2026

Scope: name, shared icon, product text and distribution safeguards. The storage and synchronization engines are unchanged. This is a signed development build, not a notarized public release.

## Mac

- Release build succeeds on macOS 27.0.1 (26A434), Apple Silicon. `codesign --verify --deep --strict` succeeds.
- Installed as `/Applications/Brou.app`; launches with the previous session and pins. Settings, About, app menu and default-browser status show Brou and the new icon.
- Signing team, bundle ID, CloudKit container/environment and keychain group match the previous installed build. All six top-level JSON data files were identical immediately after installation, before launch. Backups stay in ignored local build output.
- `swift test --skip DownloadLifecycleTests`: 62 tests, 61 pass, one failure in the unchanged `ExtensionFileAccessTests.testFilesAreNeverGrantedButSitesAre`. WebKit does not grant the file URL at the test's prerequisite assertion (line 40); the initial assertions denying files and allowing the named HTTPS site pass. The same failure reproduces when that test class runs alone. A baseline build was not run, so this is not claimed as a proven pre-existing failure. Do not weaken the file fence to make this test pass.
- The new test verifies that an unconfigured updater completes without starting a fetch. CloudKit and vault unit tests pass.
- `python3 Tests/dark_pages.py`: 23 checks pass, zero failures, using an isolated test world.
- Shell syntax and `git diff --check` pass. No download lifecycle journeys were rerun for this identity change.

## iPhone

- Release archive and development IPA export succeed for version 1.1.0, build 1792575304. Signed app and profile retain `cat.correal.search`, the browser entitlement, team, iCloud container/environment and keychain group.
- Installed over the previous version on the registered iPhone 16 Pro. All three local data files were identical immediately after installation. After the phone was unlocked, the launch command succeeds and the Brou executable remains running.
- App and IPA metadata name the app and executable Brou; the icon catalog contains an opaque 1024-pixel export of the shared artwork.
- The preceding 1.0.1 build's default-browser listing and Add to Home Screen sheet were checked by Victor. These two flows were not repeated for 1.1.0.

## Limits and next checks

This rename does not prove end-to-end CloudKit or password synchronization, validate existing password values, or recheck all download and session journeys. CloudKit remains in Development on both apps. No records, passwords, container names or keychain labels were migrated. Another Apple team cannot access these data merely by compiling the source.

Before a public binary release: resolve the WebKit test, verify cross-device sync with synthetic records, complete targeted download and credential checks, deploy a deliberate CloudKit Production setup, and configure signing, notarization and a Brou update channel. The GitHub repositories remain private; no TestFlight upload, App Store submission or OSS application was sent.
