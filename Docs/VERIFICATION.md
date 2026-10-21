# Verification — 21 October 2026

Results recorded by the maintainer on Apple Silicon, macOS 27.0.1 and Xcode 27 / Swift 6.4. These are bounded checks, not a claim that a browser is bug-free. CI re-runs the source build and regressions without private signing files.

| Check | Result | Scope |
| --- | --- | --- |
| Full Mac Swift suite | 122 executed: 121 pass, 1 skipped | Ten WebKit download cases isolated in separate processes; file-permission prerequisite skipped when WebKit denies it itself |
| Mac address and popup listener harnesses | Pass | Local production logic and synthetic script cases |
| iPhone Vault regression harness | 6 pass | Production Vault with a synthetic Security adapter; no real secrets |
| iPhone forms/blocker WebKit harness | 13 pass | Production scripts and actual WebKit on Mac |
| iPhone upper-page colour harness | 7 pass | Local rendered pages on Mac, not iPhone safe-area geometry |
| Clean Mac Release | Builds with ad-hoc signing | No provisioning profiles or private certificates in the source copy |
| Clean iPhone simulator Debug | Builds unsigned | CODE_SIGNING_ALLOWED=NO; not a physical iCloud test |

## Physical devices and installed Release

Earlier today, Mac Release 1.1.0 build 202610211452 and iPhone Release 1.1.0 build 1792585822 were installed over the previous apps. Initial JSON comparisons were identical (seven Mac files, four iPhone files). Signatures, current IDs/groups/container and app launch were verified. The Dock's old icon cache was corrected; Victor confirmed the white steam on black.

With a disposable bookmark, we verified Mac creation arriving on iPhone and iPhone rename/deletion arriving on Mac, with the same UUID. The pre-existing bookmark remained. Victor performed the iPhone edit and deletion in the actual app.

With synthetic credentials in the real synchronizable keychain, the production Vault code verified save/read in both directions and deletion from each device. Three native XCTest cases on the physical iPhone passed: test01ReceiveMacAndCreatePhone, test02DeleteMacOnly, test03ReceiveMacDeletion. A signed Mac harness used the production Vault files with adapters for non-keychain dependencies. Only the two synthetic identities were read/deleted. The final iPhone Release was restored after the test host. All fixture records were removed.

The device harnesses/results are retained locally with private signing context; raw logs/backups are not release assets. This section is a maintainer-recorded device report, separate from the reproducible synthetic tests and CI. No third-party adoption is implied. See [SYNC.md](SYNC.md) to reproduce the manual journeys with disposable data and a correctly provisioned pair.

The public-source cleanup changes log privacy and packaging metadata; it does not change the sync algorithm. Device sync was tested on the parent revisions (Mac 3a61c797, iPhone 0c6bc6bb), not re-run as a new pair after those cleanup changes.

## Honest limits

- The local HTTP fixture did not load on the physical iPhone. No visual form-autofill pass is claimed for that run; the credential check was native.
- Credential editing, offline changes, simultaneous conflicts, account switching and provisioning under another developer account remain unverified.
- CloudKit Production, notarized Mac distribution, TestFlight/App Store distribution and Intel hardware are not validated by these checks.
- Long-open popup menus, physical security keys and individual real extensions need additional manual coverage. The iPhone private-mode and download-manager parity do not exist.
- External adoption has not been established. Upstream Search's metrics belong to upstream.

## Reproduce without personal data

Use the commands in README.md and BUILDING.md from a clean clone. Run probes sequentially in their isolated worlds. For real iCloud, create a uniquely named example.com bookmark on one device, rename on the other and delete it; confirm the same record and existing data. Use disposable credentials in a local fixture under your control for native/form checks. Never test with or publish personal saved passwords, profiles, account IDs or browsing history.
