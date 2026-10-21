# Password host scope — 21 October 2026

Suggestions and the page-specific password view use the exact stored host. A CMS, development server, root domain and child subdomain do not share automatic suggestions. The existing www/root alias is preserved; URL paths are not separate credential scopes. An unknown host has no fallback accounts. The full vault remains available through an explicit action.

The keychain lookup now narrows by server before reading secrets. Storage identifiers, password values and CloudKit records are not migrated by this change. HTTP pages still only receive credentials saved for HTTP.

## Verification

- The pre-fix Mac test reproduced domain grouping in the page-specific password panel with synthetic accounts.
- `python3 Tests/passwords_site.py`: 21 passed, zero failures. Covers exact-host selection from real test keychain items, root/sibling separation, unknown and lookalike hosts, the www alias, text-search scope, form suggestions, filling and Manage passwords. Uses an isolated world and nonsynchronizing synthetic keychain items, removed afterwards.
- `python3 Tests/cloud_keychain.py`: 16 passed, zero failures. Checks reading, use timestamps, HTTP/HTTPS separation and deleting one of two same-host/user records without damaging the other. This is a local keychain test, not an end-to-end iCloud sync test.
- Mac signed Release build and signature verification succeed. Installed with matching entitlements and six local JSON files unchanged immediately after installation.
- Manual Mac check on the reported CMS login: the dropdown contains only its one saved CMS account, with no root-domain or development-server entry. No account was selected and no sign-in was submitted. The temporary check tab was closed.
- iPhone Release archive, signature verification and development IPA export succeed (build 1792577033). Signed entitlements match the preceding 1.1.0. Installed over the existing app; device launch succeeds. The host-specific iPhone UI and cross-device sync were not manually rechecked.
- Whitespace and Python syntax checks pass. The full Swift suite was not rerun for this change; the separately documented WebKit file-permission test from the rename remains unresolved.

The repositories remain private. Builds and personal diagnostics are ignored; no public release or store submission was made.
