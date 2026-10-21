# Start-page bookmark access

21 October 2026 — development build, repositories private.

## Behavior

The start page and each ordinary new tab keep the address field ready to type and a small blue control at the bottom right. On Mac, the bookmark button opens a popover with the existing folder tree. On iPhone, the general «…» menu occupies that corner and includes Bookmarks, Tabs and New Tab, alongside the existing actions. Bookmarks opens the existing manager, including folder navigation and edit actions. The iPhone keyboard opens automatically; returning to an empty page from the background restores focus. Empty bookmark collections have an empty state.

A cold launch selects an empty start tab and retains the previous session’s pages. An existing empty tab is reused at launch. Returning from the background does not replace the current page. Mac extensions with a custom new-tab page retain that choice.

The UI reads the existing bookmark model. There is no second collection, migration or new sync protocol. Bundle identifiers, CloudKit records, keychain groups and local data paths remain unchanged. Passwords, downloads and iCloud conflict handling are outside this change.

## Verification

- Signed Mac Release build and iPhone Release archive completed. iPhone bundle ID remains `cat.correal.search`; final menu revision build: `1792582963`.
- Mac: `Tests/start_bookmarks.py` checks cold launch, retention of previous pages, reuse of the start tab, bookmark navigation, relaunch, and unchanged bookmark bytes, folder tree and order. All 12 checks passed on the final Mac build. It runs with synthetic data in an isolated test world.
- Mac UI: confirmed the minimal start page, focused address field, blue button at the bottom right and bookmark popover. Bookmark navigation passed the model probe; a manual destination click from the final popover remains to be checked.
- iPhone: physical UI confirmation of the final automatic-focus and bottom-right menu revision remains pending.

The simulator did not provide a conclusive behavioral check. Its test fixtures were restored. iCloud synchronization needs a signed physical-device test and was not revalidated here.

This is focused verification, not a claim that the entire inherited test suite passes. The previously recorded WebKit prerequisite failure in `ExtensionFileAccessTests` remains outside this change.

## Reproduce on Mac

```sh
./build.sh release
ditto build/Brou.app build/StartBookmarksProbe.app
SEARCH_TEST_APP="$PWD/build/StartBookmarksProbe.app" python3 Tests/start_bookmarks.py
```

The test helper refuses to use an app bundle that is running outside its isolated probe world. Do not bypass that guard. To inspect the interface, open a normal new tab, press the blue bookmark button, expand a folder and open a saved page. Close and relaunch Brou to confirm the start page appears and earlier tabs remain available. On iPhone, repeat using the installed development build and check that the cursor starts in the address field, the keyboard is ready, the bottom-right menu opens, and Bookmarks opens the folder list.
