# Build Brou for Mac

## Local build, no Apple account

Install full Xcode, open it once to accept Apple's tools agreement, and select its command line tools. The current source is checked with Xcode 27 / Swift 6.4. macOS 14 is the deployment target; extensions need macOS 15.4.

```sh
xcode-select -p
swift --version
swift build
./build.sh release
open build/Brou.app
```

A clean clone contains no provisioning profile or signing key. The script uses a Developer ID identity if it finds one; otherwise it signs ad-hoc for local use. It does not install the result in Applications. Without the shared entitlements, CloudKit stays off and Mac credentials use the local keychain. Do not rename or overwrite a real user's app to test a different identity.

`SEARCH_ARCH=x86_64 ./build.sh release` builds Intel; the default is the host architecture. Intel compilation is not proof of testing on Intel hardware. The checked-in master icon builds locally through AppKit/iconutil and, when available, actool.

## Your own Apple Developer team

Full continuity requires a paid Apple Developer team, certificates/profiles managed by Xcode and the same configuration in the iPhone repo. Apple controls capability approval. Never use or request the maintainer's profiles or private keys.

Choose an App ID, e.g. `com.example.brou`, an iCloud container `iCloud.com.example.brou` and a group `<AppIdentifierPrefix>com.example.brou`. Use the actual App Identifier Prefix from your profile; it usually matches the team ID but legacy accounts may differ.

In a separate development checkout, configure these exact locations:

| File | Change |
| --- | --- |
| `build.sh` | BUNDLE_ID to your App ID |
| `Sources/Brou/CloudSync.swift` | container constant to your container |
| `Sources/Brou/VaultCloud.swift` | group constant to the full keychain group |
| `Provisioning/project.yml` | DEVELOPMENT_TEAM, PRODUCT_BUNDLE_IDENTIFIER and iCloud/group capabilities |
| `Provisioning/Brou.entitlements` | container and keychain group of the helper |
| `Provisioning/App.entitlements` | application identifier, team, container and full group allowed by your profile |

Then regenerate the helper project with XcodeGen in Provisioning, sign into your Apple account in Xcode, enable iCloud/CloudKit and Keychain Sharing for the App ID, and let Xcode register the test Mac and create a development profile:

```sh
cd Provisioning
xcodegen generate
cd ..
Provisioning/refresh.sh --forzar
SEARCH_SIGN_IDENTITY='Apple Development: Your Name (CERTIFICATE-ID)' ./build.sh release
codesign --verify --deep --strict build/Brou.app
codesign -d --entitlements :- build/Brou.app
```

The helper is never installed. `refresh.sh` writes the git-ignored profile to Provisioning/Brou.provisionprofile; build.sh embeds it and signs with App.entitlements. Check the helper's product path if you change its PRODUCT_NAME. Do not commit generated personal configuration, profiles or credentials. Use ignored LocalSigning/ for private copies and review git diff before pushing.

In the iPhone repo configure the matching team, App ID, container and group. [Companion guide](https://github.com/victorcorreal/brou-ios/blob/main/Docs/BUILDING.md). The group and container must match on both platforms. Use a disposable Apple account/data set for testing. Your App ID is a separate app with separate data; it is not a migration of Victor's install.

## Existing Brou installations

Keep `cat.correal.search`, its signing team, container, group and data paths when updating the maintainer build. Install over the existing app. Do not uninstall the iPhone app to update. Do not change CloudKit Development to Production as a build cleanup. [SYNC.md](SYNC.md) describes persistence and account boundaries.

## Distribution

Publishing source needs no signing secret. `./build.sh release dmg` packages a local disk image/zip, not a general notarized download. A public binary needs Developer ID, an appropriate profile, hardened runtime, notarization, stapling and Gatekeeper verification on another Mac. iPhone distribution requires its own TestFlight/App Store work and a deliberate CloudKit Production deployment.

The upstream publish/tap scripts are disabled, and Brou's updater stays disabled outside isolated tests. No Office Commun appcast is used in normal runs. A future updater must use Brou-owned metadata and signature verification. Do not enable the old feed as a shortcut.
