# Brou identity

Brou means broth in Catalan. The current emblem is a single white wisp of steam on black: a quiet exhale, without a bowl or lettering. The same artwork is shared by Mac and iPhone. It replaces the earlier cream-and-orange bowl icon; the original remains in Git history.

`Brou.png` is the checked-in opaque master. It was edited from the earlier Brou icon with OpenAI's built-in image generation tool at Victor's request. The final prompt is in `icon-prompt.txt`. Builds use the local asset and do not call an image service.

The Mac's `Icon/icon.swift` packages the artwork into an iconset and an Icon Composer document with a black background. The iPhone AppIcon catalog uses an opaque 1024-pixel export. Platform masks are applied by the packaging tool or operating system.

The name and icon are display identities. Bundle identifiers, signing teams, CloudKit containers/zones, keychain access groups/labels and data directories retain their existing names to preserve access to data. The current projects, schemes and Swift targets are named Brou. Storage, signing and protocol identifiers retain their historical names for compatibility. See Docs/NAME_MIGRATION.md.

See [VERIFICATION.md](VERIFICATION.md) for the earlier 1.1.0 rename checks and [STEAM_ICON.md](STEAM_ICON.md) for this revision.
