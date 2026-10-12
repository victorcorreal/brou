#!/usr/bin/env python3
"""Passwords in the shared keychain group, in a hidden probe (see VaultCloud.swift).

Build first (`./build.sh`, signed with Victor's profile, so the app has the
keychain group), then `python3 Tests/cloud_keychain.py`. The probe is given
SEARCH_SYNC_KEYCHAIN, so its passwords go to the shared group — labelled with
its own test world and kept on this Mac, never synced. Everything is removed
at the end.

Two items can share a site and an account: one kept over http and one over
https, each saved on a different device before iCloud brought the other
across. The probe makes the second one the way the iPhone app would, then
checks that each is read, noted as used and removed on its own.

With LEGACY=1, one made-up password is also put in the login keychain the way
Search kept them before, to see it copied across the first time it is read.
macOS then asks for the login keychain password in a dialog: only run it with
someone at the Mac who expects that dialog.
"""
import os
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import split_view as sv  # noqa: E402

LOGIN = (b"<!doctype html><title>login</title><form action=/in method=post>"
         b"<input id=user name=username autocomplete=username>"
         b"<input id=pass type=password name=password autocomplete=current-password>"
         b"<button>Sign in</button></form>")
SIGNED_IN = b"<!doctype html><title>in</title><p>Signed in."


class Pages(BaseHTTPRequestHandler):
    def do_GET(self):
        self.answer(LOGIN)

    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length") or 0))
        self.answer(SIGNED_IN)

    def answer(self, body):
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Pages)
threading.Thread(target=server.serve_forever, daemon=True).start()
BASE = f"http://127.0.0.1:{server.server_port}"

t = sv.T()
sv.use("keys")
LABEL = f"Search ({sv.W})"


def launch(**env):
    if os.path.exists(sv.SOCK):
        os.remove(sv.SOCK)
    before = sv.running()
    args = ["open", "-n", "-g", "-j", "--env", f"SEARCH_PROBE={sv.W}", "--env", "SEARCH_SYNC_KEYCHAIN=1"]
    for key, value in env.items():
        args += ["--env", f"{key}={value}"]
    subprocess.run(args + [sv.APP])
    for _ in range(150):
        if os.path.exists(sv.SOCK):
            break
        time.sleep(0.1)
    time.sleep(2)
    sv.started.update((sv.running() - before) & sv.holding())


def take(rows):
    """Passwords through the same import the Bring Things Over sheet uses."""
    with tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False) as f:
        f.write("name,url,username,password\n")
        for user, password in rows:
            f.write(f"site,{BASE}/,{user},{password}\n")
    try:
        return sv.cmd({"do": "import-file", "path": f.name})
    finally:
        os.remove(f.name)


def login_page():
    """The test page in front, the caret in its name box. Its tab."""
    tab = sv.cmd({"do": "open", "url": f"{BASE}/"})["id"]
    sv.cmd({"do": "wait", "id": tab})
    sv.cmd({"do": "select", "id": tab})
    time.sleep(1)
    try:
        sv.cmd({"do": "eval", "id": tab, "js": "document.getElementById('user').focus(); true"})
    except Exception:
        pass
    time.sleep(2)
    return tab


def offered():
    """The logins under the sign-in box of the test page, by user."""
    login_page()
    shown = sv.cmd({"do": "accounts"})
    return sorted(r["login"] for r in shown.get("rows", []) if "login" in r)


def passwords(**request):
    """The passwords panel's rows, each with its own secret (see Bench's "passwords")."""
    return sv.cmd({"do": "passwords", **request}).get("rows", [])


def cris():
    """Cris's rows, the one kept over http first."""
    return sorted((r for r in passwords() if r["user"] == "cris"), key=lambda r: not r["clear"])


def in_login_keychain(user):
    """Whether the login keychain still holds it: where Search kept passwords before."""
    return subprocess.run(["security", "find-internet-password", "-l", LABEL, "-a", user],
                          capture_output=True).returncode == 0


try:
    sv.setup()
    launch(SEARCH_SYNC_KEYCHAIN_DROP="1")
    took = take([("ana", "uno"), ("bob", "dos")])
    t.ok("two passwords kept", took.get("kept") == 2, took)
    t.ok("they went to the shared group, not the login keychain",
         not in_login_keychain("ana") and not in_login_keychain("bob"))
    sv.quit()

    launch()
    users = offered()
    t.ok("after a restart, both offered from the shared group", users == ["ana", "bob"], users)

    # Cris twice for the same site: kept here over http, and over https by
    # the iPhone app before iCloud brought this one across.
    took = take([("cris", "tres")])
    t.ok("cris kept over http", took.get("kept") == 1, took)
    passwords(plant={"host": "127.0.0.1", "user": "cris", "password": "cuatro", "clear": False})
    both = cris()
    t.ok("both of cris's listed, each a row of its own",
         len(both) == 2 and both[0]["id"] != both[1]["id"] and [r["clear"] for r in both] == [True, False], both)
    t.ok("each row reads its own password", [r["password"] for r in both] == ["tres", "cuatro"], both)
    t.ok("each row says when it was saved", all(r["saved"] > 0 for r in both), both)

    # Picked from the list on this http page: only the http one is offered,
    # and its use is noted on it alone.
    login_page()
    rows = sv.cmd({"do": "accounts"}).get("rows", [])
    at = next((i for i, r in enumerate(rows) if r.get("login") == "cris"), None)
    t.ok("the http one offered on the http page", at is not None, rows)
    if at is not None:
        sv.cmd({"do": "accounts", "pick": at})
    time.sleep(1)
    both = cris()
    t.ok("a use noted on the one picked, not on the other",
         len(both) == 2 and both[0]["used"] > 0 and both[1]["used"] == 0, both)
    t.ok("neither password written over the other", [r["password"] for r in both] == ["tres", "cuatro"], both)

    # Signed in on this http page with the https one's password: its use is
    # noted, and it stays https, since moving it to http would make it the
    # same item as the other.
    tab = login_page()
    sv.cmd({"do": "type", "id": tab, "selector": "#user", "text": "cris"})
    sv.cmd({"do": "type", "id": tab, "selector": "#pass", "text": "cuatro"})
    sv.cmd({"do": "submit", "id": tab, "selector": "#pass"})
    time.sleep(3)
    both = cris()
    t.ok("a sign-in notes the use on the item whose password it was",
         len(both) == 2 and both[1]["used"] > 0 and not both[1]["clear"], both)
    t.ok("and neither password is written over the other", [r["password"] for r in both] == ["tres", "cuatro"], both)

    # Removing one leaves the other.
    https = next((r for r in both if not r["clear"]), None)
    left = [r for r in passwords(forget=https["id"]) if r["user"] == "cris"] if https else []
    t.ok("removing the https one leaves the http one",
         len(left) == 1 and left[0]["clear"] and left[0]["password"] == "tres", left)
    sv.quit()

    launch()
    users = offered()
    t.ok("after a restart, the one left is still offered", users == ["ana", "bob", "cris"], users)

    # The last of cris's goes too, and nothing else with it.
    last = next((r for r in passwords() if r["user"] == "cris"), None)
    rows = passwords(forget=last["id"]) if last else []
    t.ok("removing the last one leaves no cris and everyone else",
         sorted(r["user"] for r in rows) == ["ana", "bob"], rows)
    sv.quit()

    if os.environ.get("LEGACY"):
        # One kept the old way, in the login keychain.
        subprocess.run(["security", "add-internet-password", "-l", LABEL, "-a", "lena", "-s", "127.0.0.1",
                        "-w", "tres", "-r", "http", "-t", "form", "-A"], check=True)
        launch()
        users = offered()
        t.ok("the old one is offered with the new ones", users == ["ana", "bob", "lena"], users)
        sv.quit()

        # Without the old one, the copy it left in the shared group is what's offered.
        while in_login_keychain("lena"):
            subprocess.run(["security", "delete-internet-password", "-l", LABEL, "-a", "lena"], capture_output=True)
        launch()
        users = offered()
        t.ok("once read, the old one has a copy in the shared group", users == ["ana", "bob", "lena"], users)
        sv.quit()
finally:
    # The test world's items go from the shared group, and any left behind.
    launch(SEARCH_SYNC_KEYCHAIN_DROP="1")
    users = offered()
    t.ok("cleared from the shared group", users == [], users)
    sv.quit()
    if os.path.exists(f"{sv.SUPPORT}/keychain-events.log"):
        print(open(f"{sv.SUPPORT}/keychain-events.log").read()[-4000:])
    while in_login_keychain("lena"):
        subprocess.run(["security", "delete-internet-password", "-l", LABEL, "-a", "lena"], capture_output=True)
    sv.wipe()
    server.shutdown()
    t.done()
sys.exit(1 if t.failed else 0)
