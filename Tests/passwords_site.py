#!/usr/bin/env python3
"""The foot of the accounts list opens the passwords of the page's site alone.

Build first (`./build.sh`, signed with Victor's profile, so the app has the
keychain group), then `python3 Tests/passwords_site.py`. As in
cloud_keychain.py, the probe's passwords go to the shared group, labelled
with its own test world and kept on this Mac; everything is removed at the
end.

The panel's site is matched by registrable domain: example.com takes in
dev.example.com, and an account on another site whose name holds the domain
(eve@example.com on other.org) stays out. The text search still matches
names, as before. The menu and ⌥⌘L open every site.
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


class Pages(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(LOGIN)))
        self.end_headers()
        self.wfile.write(LOGIN)

    def log_message(self, *a):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Pages)
threading.Thread(target=server.serve_forever, daemon=True).start()
PORT = server.server_port
BASE = f"http://127.0.0.1:{PORT}"

# Who is kept where. admin@127.0.0.1 is on another host whose name is not the
# page's: searching "127.0.0.1" finds it by its name, the page's site doesn't.
KEPT = [
    (f"{BASE}/", "ana"),
    (f"{BASE}/", "bob"),
    (f"http://localhost:{PORT}/", "admin@127.0.0.1"),
    ("https://example.com/", "cris"),
    ("https://dev.example.com/", "dora"),
    ("https://other.org/", "eve@example.com"),
]

t = sv.T()
sv.use("site")


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
        for url, user in rows:
            f.write(f"site,{url},{user},pw-{user}\n")
    try:
        return sv.cmd({"do": "import-file", "path": f.name})
    finally:
        os.remove(f.name)


def login_page():
    """The test page in front, the caret in its name box."""
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


def panel(**request):
    """The panel's site and its rows' users, sorted (see Bench's "passwords")."""
    out = sv.cmd({"do": "passwords", **request})
    return out.get("site"), sorted(r["user"] for r in out.get("rows", []))


try:
    sv.setup()
    launch(SEARCH_SYNC_KEYCHAIN_DROP="1")
    took = take(KEPT)
    t.ok("six passwords kept", took.get("kept") == len(KEPT), took)

    # The text search matches names: "127.0.0.1" also finds admin@127.0.0.1
    # on localhost. That is what mixed other sites in before.
    site, users = panel(site="", hunt="127.0.0.1")
    t.ok("the text search still finds an account by its name",
         site == "" and users == ["admin@127.0.0.1", "ana", "bob"], users)

    # The site goes by registrable domain: dev.example.com is example.com's,
    # eve@example.com on other.org is not.
    site, users = panel(site="example.com", hunt="")
    t.ok("a site takes in its subdomains and nothing matched by name",
         site == "example.com" and users == ["cris", "dora"], users)
    site, users = panel(site="example.com", hunt="dora")
    t.ok("the text search narrows within the site", users == ["dora"], users)
    site, users = panel(site="", hunt="")
    t.ok("without a site, every password", site == "" and len(users) == len(KEPT), users)

    # The foot of the list under the sign-in box.
    login_page()
    shown = sv.cmd({"do": "accounts"})
    t.ok("the list under the box offers this site's accounts",
         sorted(r.get("login") for r in shown.get("rows", [])) == ["ana", "bob"], shown)
    sv.cmd({"do": "accounts", "manage": True})
    time.sleep(1)
    state = sv.cmd({"do": "probe"})
    t.ok("its foot opens the passwords panel and takes the list down",
         state.get("passwords") is True and state.get("suggesting") is False, state)
    t.ok("kept to the page's site", state.get("passwordSite") == "127.0.0.1", state.get("passwordSite"))
    site, users = panel()
    t.ok("showing only this site's accounts, not admin@127.0.0.1 from localhost",
         site == "127.0.0.1" and users == ["ana", "bob"], users)

    # Closed, it forgets the site: the menu and ⌥⌘L open the whole list.
    sv.cmd({"do": "ui", "passwords": False})
    time.sleep(0.5)
    t.ok("closing the panel forgets the site", sv.cmd({"do": "probe"}).get("passwordSite") == "", "")
    sv.cmd({"do": "ui", "passwords": True})
    time.sleep(0.5)
    site, users = panel()
    t.ok("opened as the menu opens it, every password", site == "" and len(users) == len(KEPT), users)
    sv.cmd({"do": "ui", "passwords": False})
    sv.quit()
finally:
    launch(SEARCH_SYNC_KEYCHAIN_DROP="1")
    site, users = panel(site="", hunt="")
    t.ok("cleared from the shared group", users == [], users)
    sv.quit()
    sv.wipe()
    server.shutdown()
    t.done()
sys.exit(1 if t.failed else 0)
