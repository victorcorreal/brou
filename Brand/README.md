# Brou identity

Brou means broth in Catalan. The emblem combines a bowl, rising steam and a lowercase b. The cream and warm orange artwork is shared by Mac and iPhone; it does not reuse Search's name mark or icon.

`Brou.png` is the checked-in opaque master. It was created with OpenAI's built-in image generation tool for this project. The final prompt is in `icon-prompt.txt`. Builds use this file locally and do not call an image service.

The Mac's `Icon/icon.swift` packages the artwork into an iconset and an Icon Composer document. The iPhone's AppIcon catalog uses an opaque 1024-pixel export from the same master. Platform-specific masks are applied by the packaging tool or the operating system.

The name is a display identity. Bundle identifiers, signing teams, CloudKit containers/zones, keychain access groups/labels and data directories retain their existing names to preserve access to existing data. Source projects and targets keep their internal Search names to reduce upstream merge conflicts.

See [VERIFICATION.md](VERIFICATION.md) for the checks and limits of the 1.1.0 identity change.
