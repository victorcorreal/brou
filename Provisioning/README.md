# Provisioning (Victor's build only)

Victor's Search has an identity of its own, `cat.correal.search`, so it can
use iCloud: CloudKit for bookmarks and the rest, and a keychain group shared
with the iPhone app for passwords. Office Commun's build is
`com.officecommun.search`.

| What | Value |
|---|---|
| Team | Great Heights Systems S.L. (`E653G759EN`) |
| Bundle id (Mac and iOS) | `cat.correal.search` |
| CloudKit container | `iCloud.cat.correal.search`, private database, **Development** environment |
| Keychain access group | `E653G759EN.cat.correal.search` |
| Signing | "Apple Development: Created via API (GLH3XY3XWK)" |
| Profile | "Mac Team Provisioning Profile: cat.correal.search", one year |

## Files

- `project.yml`, `main.swift`, `Search.entitlements`, `SearchProvisioning.xcodeproj`: a helper app that is
  never shipped. Building it with `-allowProvisioningUpdates` makes Xcode register the App ID, the iCloud
  container and this Mac, and fetch the profile.
- `refresh.sh`: builds the helper and copies its profile to `Search.provisionprofile` (git-ignored), only when
  it is missing or ends within 30 days. `actualizar.sh` runs it before every build.
- `App.entitlements`: what `build.sh` signs Search with whenever `Search.provisionprofile` is present: the usual
  camera, microphone and location, plus iCloud and the keychain group.

## Why Development and not Production

CloudKit's Production environment only takes record types already deployed from the CloudKit Console. The
Development environment creates them as the apps use them, and keeps its data. Both apps use Development.
Moving to Production later: deploy the schema in the CloudKit Console, then change
`com.apple.developer.icloud-container-environment` in both apps at once.

## Another Mac

A development profile lists the Macs it runs on. On the Mac mini, `refresh.sh --forzar` registers it with the
same Xcode account and fetches a profile that includes it. A "Developer ID Application" certificate would avoid
the list, but only the account holder can create one.
