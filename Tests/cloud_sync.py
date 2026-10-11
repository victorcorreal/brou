#!/usr/bin/env python3
"""Bookmarks through iCloud between hidden probes (see CloudSync.swift).

Build first (`./build.sh`, signed with Victor's profile, so the app has the
iCloud entitlement), then `python3 Tests/cloud_sync.py`. Test worlds
"cloud-a", "cloud-b" and "cloud-c" sync through a zone of their own in the
private database, SearchTest-<random>, never the browser's own zone "Search".
At the end the zone is deleted and the worlds are wiped.
"""
import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import split_view as sv  # noqa: E402

ZONE = f"SearchTest-{uuid.uuid4().hex[:8]}"
ALPHA, WORK, BETA = (str(uuid.uuid4()).upper() for _ in range(3))
TREE = [
    {"id": ALPHA, "title": "Alpha", "url": "https://alpha.example/"},
    {"id": WORK, "title": "Work", "children": [
        {"id": BETA, "title": "Beta", "url": "https://beta.example/"},
    ]},
]

t = sv.T()


def launch(**env):
    if os.path.exists(sv.SOCK):
        os.remove(sv.SOCK)
    before = sv.running()
    args = ["open", "-n", "-g", "-j", "--env", f"SEARCH_PROBE={sv.W}", "--env", f"SEARCH_SYNC_ZONE={ZONE}",
            "--env", "SEARCH_SYNC_POLL=10"]
    for key, value in env.items():
        args += ["--env", f"{key}={value}"]
    subprocess.run(args + [sv.APP])
    for _ in range(150):
        if os.path.exists(sv.SOCK):
            break
        time.sleep(0.1)
    time.sleep(2)
    sv.started.update((sv.running() - before) & sv.holding())


def read(name):
    try:
        return json.load(open(f"{sv.SUPPORT}/{name}"))
    except (OSError, ValueError):
        return None


def wait(test, seconds=120):
    end = time.time() + seconds
    while time.time() < end:
        if test():
            return True
        time.sleep(2)
    return False


def agreed():
    return (read(f"icloud-{ZONE}.json") or {}).get("agreed", {})


def outline(nodes):
    return [(n["id"], n["title"], n.get("url"), outline(n.get("children") or [])) for n in nodes or []]


def world(name, fresh):
    sv.use(name)
    if fresh:
        sv.setup()
        os.makedirs(sv.SUPPORT, exist_ok=True)


try:
    # A has two bookmarks and a folder; they go up.
    world("cloud-a", fresh=True)
    json.dump(TREE, open(f"{sv.SUPPORT}/bookmarks.json", "w"))
    launch()
    t.ok("A: all three records agreed with iCloud", wait(lambda: set(agreed()) == {ALPHA, WORK, BETA}), agreed().keys())
    sv.quit()

    # B starts empty and gets them.
    world("cloud-b", fresh=True)
    launch()
    t.ok("B: the list came down as it was", wait(lambda: outline(read("bookmarks.json")) == outline(TREE)), read("bookmarks.json"))
    sv.quit()

    # B, offline: Alpha renamed, Beta deleted. Then it goes up.
    edited = read("bookmarks.json")
    edited[0]["title"] = "Alpha 2"
    edited[1]["children"] = []
    json.dump(edited, open(f"{sv.SUPPORT}/bookmarks.json", "w"))
    launch()
    t.ok("B: the rename and the deletion were agreed",
         wait(lambda: BETA not in agreed() and agreed().get(ALPHA, {}).get("node", {}).get("title") == "Alpha 2"), agreed())
    if os.environ.get("VERBOSE"):
        for line in open(f"{sv.SUPPORT}/icloud-events.log"):
            if any(word in line for word in ("started", "Fetched", "SentRecord", "AccountChange", "failed")):
                print("   B:", line.rstrip()[:400])
    sv.quit()

    # C, new, gets iCloud's copy whole: B's rename and deletion are in it.
    # (A, already in sync, would not hear of them: iCloud tells a device only
    # of changes made on other devices, and A and B are the same Mac. Between
    # the Mac and the iPhone, they arrive at the next fetch.)
    world("cloud-c", fresh=True)
    launch()
    came = wait(lambda: outline(read("bookmarks.json")) == outline(edited))
    t.ok("C: iCloud holds the rename and the deletion", came, read("bookmarks.json"))
    if not came and os.path.exists(f"{sv.SUPPORT}/icloud-events.log"):
        quiet = ("StateUpdate", "WillFetch", "DidFetch", "WillSend", "DidSend")
        for line in open(f"{sv.SUPPORT}/icloud-events.log"):
            if not any(word in line for word in quiet):
                print(line.rstrip()[:400])
    sv.quit()
    sv.wipe()
finally:
    # The test zone goes from iCloud, then both worlds go.
    world("cloud-a", fresh=False)
    if os.path.isdir(sv.SUPPORT):
        launch(SEARCH_SYNC_DROP="1")
        t.ok("the test zone was deleted from iCloud", wait(lambda: os.path.exists(f"{sv.SUPPORT}/icloud-dropped"), 60))
    sv.quit()
    sv.wipe()
    world("cloud-b", fresh=False)
    sv.wipe()
    t.done()
sys.exit(1 if t.failed else 0)
