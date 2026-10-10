#!/usr/bin/env python3
"""Dark Pages and Text Only in Reading Mode, in a hidden probe.

Build first (`./build.sh`), then `python3 Tests/dark_pages.py`. It runs in
split_view.py's test world, with its harness: started hidden, everything
removed afterwards. The pages come from a server of its own on 127.0.0.1.
Screenshots go to the folder named by SHOTS, when it is set.
"""
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import split_view as sv  # noqa: E402

PIC = b'<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><rect width="40" height="40" fill="#e33"/></svg>'
PROSE = " ".join(["A long sentence about something worth reading slowly and with care."] * 10)
PAGES = {
    "/light": (
        "<!doctype html><title>light</title>"
        "<header style='position:fixed;top:0;left:0;right:0;height:40px;background:#eee'>header</header>"
        f"<div style='height:3000px;padding-top:60px'><p>{PROSE}</p><img id=pic src=/pic.svg>"
        "<div id=bg style='background-image:url(/pic.svg);width:80px;height:80px'><img id=inner src=/pic.svg></div>"
        "<div id=gradient style='background-image:linear-gradient(#fff,#ddd);height:20px'></div>"
        # A player from another site, in a frame; pictures given out late.
        "<iframe id=player src=/player width=300 height=120></iframe>"
        "<style>.poster{background-image:url(/pic.svg)}</style>"
        "<div id=late style='width:60px;height:60px'></div><div id=classed style='width:60px;height:60px'></div>"
        "<div id=lost style='background-image:url(/pic.svg);width:60px;height:60px'></div>"
        "<script>setTimeout(() => {"
        "document.getElementById('late').style.backgroundImage = 'url(/pic.svg)';"
        "document.getElementById('classed').className = 'poster';"
        "document.getElementById('lost').style.backgroundImage = 'none';"
        "}, 300)</script></div>"
    ),
    "/player": "<!doctype html><body style='background:#fff;margin:0'><img src=/pic.svg width=120 height=120> player",
    "/dark": "<!doctype html><title>dark</title><body style='background:#111;color:#eee'><p>already dark</p>",
    "/article": (
        "<!doctype html><title>article</title><body><nav><a href=/>home</a></nav><article><h1>The headline</h1>"
        f"<p>{PROSE}</p><img src=/pic.svg><p>{PROSE}</p>"
        "<figure><img src=/pic.svg><figcaption>Caption of the picture</figcaption></figure>"
        "<figure><pre>let code = 1</pre><figcaption>Listing one</figcaption></figure>"
        "<p><a href=/x><img src=/pic.svg></a></p>"
        "<iframe src='/youtube-embed'></iframe><video src=/v.mp4></video>"
        "<svg width=10 height=10><rect width=10 height=10 /></svg>"
        f"<p>{PROSE}</p><p>The last paragraph.</p></article>"
    ),
}


class Pages(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/pic.svg":
            body, kind = PIC, "image/svg+xml"
        else:
            body, kind = PAGES.get(self.path, "<!doctype html><p>nothing").encode(), "text/html"
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Pages)
threading.Thread(target=server.serve_forever, daemon=True).start()
BASE = f"http://127.0.0.1:{server.server_port}"
SHOTS = os.environ.get("SHOTS")

t = sv.T()


def ev(tab, js):
    return sv.cmd({"do": "eval", "id": tab, "js": js, "world": "search"}).get("value")


def open_page(name):
    tab = sv.cmd({"do": "open", "url": f"{BASE}/{name}"})["id"]
    sv.cmd({"do": "wait", "id": tab})
    time.sleep(0.8)
    return tab


def press(code, chars, mods):
    sv.cmd({"do": "press", "code": code, "chars": chars, "mods": mods})
    time.sleep(0.6)


def media(tab):
    return ev(tab, "(document.getElementById('search-dark-pages') || {}).media || 'missing'")


def shot(tab, name):
    if SHOTS:
        sv.cmd({"do": "shot", "id": tab, "path": f"{SHOTS}/{name}.png"})


try:
    sv.setup(**{"pages.dark": True})
    sv.launch()

    light = open_page("light")
    t.ok("light page: turned dark", media(light) == "screen", media(light))
    t.ok("light page: the document is inverted",
         "invert" in ev(light, "getComputedStyle(document.documentElement).filter"))
    t.ok("a picture is turned back", "invert" in ev(light, "getComputedStyle(document.getElementById('pic')).filter"))
    t.ok("a background picture is found",
         ev(light, "document.getElementById('bg').hasAttribute('data-search-dark-picture')") is True)
    t.ok("a picture inside it is left as it is",
         ev(light, "getComputedStyle(document.getElementById('inner')).filter") == "none")
    t.ok("a gradient turns with the page",
         ev(light, "document.getElementById('gradient').hasAttribute('data-search-dark-picture')") is False)
    t.ok("a frame is shown as its site made it",
         "invert" in ev(light, "getComputedStyle(document.getElementById('player')).filter"))
    time.sleep(1)
    marked = lambda id: ev(light, f"document.getElementById('{id}').hasAttribute('data-search-dark-picture')")
    t.ok("a picture given through the style later is found", marked("late") is True)
    t.ok("a picture given through a class later is found", marked("classed") is True)
    t.ok("a picture taken away later is let go", marked("lost") is False)
    top = ev(light, "scrollTo(0, 1500); document.querySelector('header').getBoundingClientRect().top")
    t.ok("a fixed header stays fixed", top == 0, top)
    ev(light, "scrollTo(0, 0)")
    shot(light, "light-dark")

    dark = open_page("dark")
    t.ok("a dark page is left alone", media(dark) == "not all", media(dark))

    sv.cmd({"do": "select", "id": light})
    press(2, "D", ["cmd", "shift"])
    t.ok("⇧⌘D: off on the page that is up", media(light) == "not all", media(light))
    sv.cmd({"do": "go", "id": light, "url": f"{BASE}/light"})
    sv.cmd({"do": "wait", "id": light})
    time.sleep(0.8)
    t.ok("⇧⌘D: off on the next page", media(light) == "missing", media(light))
    press(2, "D", ["cmd", "shift"])
    t.ok("⇧⌘D: on again", media(light) == "screen", media(light))

    article = open_page("article")
    sv.cmd({"do": "select", "id": article})
    press(15, "R", ["cmd", "shift"])
    time.sleep(0.6)
    t.ok("reading mode is up", ev(article, "!!document.getElementById('office-reader')") is True)
    left = ev(article, "document.querySelectorAll('#office-reader :is(img,picture,video,audio,iframe,svg,canvas)').length")
    t.ok("text only: no pictures, video or frames", left == 0, left)
    words = ev(article, "document.getElementById('office-reader').innerText")
    t.ok("text only: the words are all there",
         "The headline" in words and PROSE[:40] in words and "The last paragraph." in words)
    t.ok("text only: the title once", words.count("The headline") == 1, words.count("The headline"))
    t.ok("text only: a picture's caption goes with it", "Caption of the picture" not in words)
    t.ok("text only: code in a figure stays", "let code = 1" in words and "Listing one" in words)
    empty = ev(article, "[...document.querySelectorAll('#office-reader a')].filter(a => !a.textContent.trim()).length")
    t.ok("text only: no empty link left where a picture was", empty == 0, empty)
    t.ok("reading mode under Dark Pages is dark", media(article) == "screen", media(article))
    shot(article, "reader-text-only")
finally:
    t.done()
    sv.finish()
    server.shutdown()
sys.exit(1 if t.failed else 0)
