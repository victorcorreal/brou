# Brou 1.1.0 — first public source preview

21 October 2026. A small native browser with a clearer identity and a practical link between Mac and iPhone.

## In this version

- Independent Brou name and white-steam-on-black icon on both apps.
- Dark Pages and text-only reading refinements.
- CloudKit bookmark folders and a shared iCloud Keychain group for Brou credentials.
- Host-scoped password suggestions and per-site management, keeping CMS/development/root accounts separate; www/root remains an explicit alias.
- Minimal start/new-tab experiences, with existing sessions preserved. iPhone opens with focus and keyboard ready; its menu stays at the bottom right.
- iPhone background continuity behind the status bar, default-browser entitlement and Add to Home Screen in the approved maintainer build.
- Selected upstream security/reliability maintenance, plus form and download regressions. Original authors, references and MIT notices remain.
- Public build, sync and privacy documentation, contribution/security reporting, isolated regression runners and CI without signing secrets. CloudKit diagnostics are marked private.

## Try it

This release publishes **source code**. GitHub supplies source archives; it includes no notarized Mac app, general-purpose IPA, certificate, profile or user data. Build instructions are in [BUILDING.md](BUILDING.md). The Mac app can be built for local use without an Apple account. Physical cross-device continuity requires your own matching Apple configuration.

The current maintainer installs use CloudKit Development and retain their old compatibility identities. There is no automatic update channel. A future public signed distribution needs separate Apple signing/review, Production schema/data planning and validation.

## Verification and remaining work

See [VERIFICATION.md](VERIFICATION.md) for the exact test counts and scope. Basic physical-device bookmark and credential sync passed with synthetic data. Offline/conflicts, account switching, visual iPhone form autofill and a different team's provisioning still need coverage. No external adoption is claimed.

## Feedback

Open an issue with version, OS, steps and expected/actual behavior. Use a disposable example and redacted screenshots. Security reports follow SECURITY.md. No analytics or browsing histories are collected for feedback. Downloads, if offered later, will not be presented as unique or active users.

## Credit

Brou is maintained by Victor Correal and derives from Search by Office Commun, MIT. Search's original history and notices remain; this is not an Office Commun release. See UPSTREAM_INTEGRATION.md, LICENSE and the repository's attribution documents.
