# Steam icon revision — 21 October 2026

The current Brou icon is one white steam wisp on black. The earlier bowl/letter/orange background has been replaced at Victor's request. The master and exact built-in image-generation prompt are checked in; earlier artwork remains in Git history.

## Checks

- Same opaque 1254-pixel master in both repositories; iOS AppIcon export is opaque 1024 × 1024. Mac packaging generates the iconset and Icon Composer variants with a black background. The 64-pixel rendition was visually inspected.
- Mac signed Release build and signature verification succeed. The packaged icon resource is named `BrouSteam` so macOS refreshes the cached earlier artwork. The installed app's About panel was visually checked and displays the white wisp on black. Six local JSON files are unchanged across installation; signed entitlements match.
- iPhone Release archive, signature verification and development IPA export succeed (build 1792577997). Entitlements match the previous build. Installed over the existing app on the registered iPhone. The phone is locked, so launch and visual inspection of this revision remain unverified.
- Whitespace and shell syntax checks pass. Application logic was not changed; functional/browser/sync tests were not rerun for the artwork change. The separate WebKit test failure recorded in the rename verification remains unresolved.

Both repositories remain private. No public/store release was made. Docs/PRODUCT_DIRECTION.md is a proposal, not a list of implemented features.
