# Contributing to Brou

Brou is maintained by Victor Correal. Report bugs and propose changes in [this repository](https://github.com/victorcorreal/brou). For vulnerabilities use [SECURITY.md](SECURITY.md).

For a larger change, open an issue describing the user problem before coding. Keep pull requests small. Prefer native Apple APIs, simple architecture and no new runtime dependencies. Reading, privacy and reliable Mac/iPhone continuity guide scope; roadmap proposals are not implemented features.

1. Build from [Docs/BUILDING.md](Docs/BUILDING.md).
2. Work in a branch and preserve other people's changes.
3. Add a regression for meaningful behavior changes; use disposable accounts and synthetic pages.
4. Run the checks in README.md and explain what passed, what was skipped and what needs manual/device testing.
5. Describe the problem, resulting behavior and validation in the pull request.

Never run a test against someone's real keychain, bookmarks, sessions or browser profile. Mac SEARCH_PROBE worlds and the iPhone synthetic Security adapter are distinct from real iCloud tests. A simulator or mocked keychain does not establish cross-device synchronization.

Include app/OS versions, reproducible steps, expected and actual behavior in bugs. Redact screenshots and logs. Do not send secrets, cookies, browsing history, Apple identifiers or provisioning material. We welcome voluntary feedback without usage telemetry; external adoption is not yet established.

Keep the MIT license, Office Commun attribution, original authors and history. Follow [Brand/README.md](Brand/README.md) for artwork. Retained app/storage and protocol identities are compatibility contracts: changes need a migration plan. Project and target names are Brou. Update both apps and [Docs/SYNC.md](Docs/SYNC.md) when changing shared formats.

For upstream work, keep a read-only remote, review changes in a branch and use cherry-pick -x for selected fixes to retain author/reference. Explain conflicts and excluded features. Re-run affected tests, check entitlements and persistent data, and record the result in Docs/UPSTREAM_INTEGRATION.md. Never merge upstream product changes without reviewing their fit for Brou.
