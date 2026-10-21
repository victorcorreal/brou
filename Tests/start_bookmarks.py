#!/usr/bin/env python3
"""Start-page session preservation and bookmark navigation, in an isolated world."""
import json
import sys
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import split_view as sv

class Pages(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"<!doctype html><title>Fixture</title><p>Local bookmark fixture</p>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *args): pass

server = ThreadingHTTPServer(("127.0.0.1", 0), Pages)
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f"http://127.0.0.1:{server.server_port}"
sv.use("start-bookmarks")
t = sv.T()

def tabs(): return sv.cmd({"do": "tabs"})["tabs"]
def active(): return next(row for row in tabs() if row["active"])

try:
    sv.setup()
    root = Path(sv.SUPPORT)
    root.mkdir(parents=True, exist_ok=True)
    marks = [{"id": str(uuid.uuid4()), "title": "Work", "url": None, "children": [
        {"id": str(uuid.uuid4()), "title": "Saved page", "url": base + "/saved", "children": None}]}]
    encoded = json.dumps(marks).encode()
    (root / "bookmarks.json").write_bytes(encoded)
    old_urls = [base + "/one", base + "/two"]
    (root / "session.json").write_text(json.dumps({
        "tabs": [{"url": url, "title": "Existing page"} for url in old_urls],
        "active": 1, "groups": None, "splits": []}))
    sv.launch()
    t.ok("cold start selects the minimal start page", active()["url"] == "", tabs())
    t.ok("previous session pages remain available", all(url in [r["url"] for r in tabs()] for url in old_urls), tabs())
    t.ok("local bookmarks loaded at startup", sv.cmd({"do": "probe"})["bookmarkCount"] == 1)
    t.ok("startup does not rewrite bookmarks", (root / "bookmarks.json").read_bytes() == encoded)
    before = len(tabs())
    sv.cmd({"do": "split", "action": "newTab"})
    sv.cmd({"do": "split", "action": "newTab"})
    t.ok("new-tab requests reuse the empty start page", len(tabs()) == before and active()["url"] == "", tabs())
    result = sv.cmd({"do": "bookmark", "url": base + "/saved"})
    t.ok("picking a bookmark uses the start tab", result.get("sameTab") is True, result)
    t.ok("picking a bookmark opens its destination", active()["url"] == base + "/saved", active())
    t.ok("bookmark navigation preserves older tabs", all(url in [r["url"] for r in tabs()] for url in old_urls), tabs())
    sv.quit()
    sv.launch()
    t.ok("relaunch selects the start page again", active()["url"] == "", tabs())
    t.ok("relaunch preserves the page opened from a bookmark", base + "/saved" in [r["url"] for r in tabs()], tabs())
    t.ok("relaunch keeps exactly one start tab", sum(r["url"] == "" for r in tabs()) == 1, tabs())
    t.ok("folder tree and bookmark order are unchanged", (root / "bookmarks.json").read_bytes() == encoded)
finally:
    sv.quit()
    sv.wipe()
    server.shutdown()
    t.done()
sys.exit(1 if t.failed else 0)
