# Contributing to Brou

Brou is maintained by Victor Correal and is based on Search by Office Commun. Contributions and reports belong in [this variant's repository](https://github.com/victorcorreal/search). The repositories are private during preparation for public release.

Before a larger change, describe the user problem and proposed scope in an issue. Prefer small pull requests, native Apple APIs, no new dependencies and no unsolicited telemetry. Preserve the MIT license, upstream attribution and existing data identities.

Build with `./build.sh release`. Run `swift test --skip DownloadLifecycleTests` for the unit suite without WebKit download journeys. `python3 Tests/run-ci-tests.py` runs all Swift tests, isolating the download cases in separate processes. UI probes use SEARCH_PROBE and test-only storage; do not run experiments against a person's real bookmarks, passwords or session.

For a bug report include the steps, expected result, actual result, Brou version and macOS version. Review logs and screenshots before sharing them; redact addresses, account names, tokens and private browsing data. See [SECURITY.md](SECURITY.md) for private security reports.

The Swift target, historical storage names and SEARCH_* development variables deliberately retain their names for compatibility. Follow [Brand/README.md](Brand/README.md) when changing product artwork. Record changes in NOTES.md and the in-app notes. CHANGELOG.md and ROADMAP.md retain upstream context; they are not a claim that Office Commun's reports or usage belong to Brou.
