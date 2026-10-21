# Provisioning helper

This folder supports the maintainer's development identity. A clean source build does not need it. For your own Apple account follow [Docs/BUILDING.md](../Docs/BUILDING.md); change the helper configuration before asking Xcode to register anything.

The current app ID is cat.correal.search, team E653G759EN, container iCloud.cat.correal.search (private database, Development), group E653G759EN.cat.correal.search. These public identifiers do not grant access to data. Keep them for existing maintainer installations.

- project.yml and Search.entitlements define the small helper; regenerate its project with XcodeGen after configuration changes.
- refresh.sh builds it with Xcode's signed-in account and copies its development profile to git-ignored Search.provisionprofile, only when missing/near expiry or with --forzar.
- App.entitlements is used by build.sh when that profile exists. Pass SEARCH_SIGN_IDENTITY explicitly for a development certificate.

The helper is not installed or distributed. No certificate, profile or private key is included. Development profiles list devices and expire; they are not a public distribution mechanism. Never switch the two apps to Production without planning the separate database and existing data.
