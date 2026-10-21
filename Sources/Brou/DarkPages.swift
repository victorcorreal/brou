// Dark pages: every site dark, whatever its own colours. View › Dark Pages.
//
// Not in Office Commun's Search: added for this build, in files of its own so
// a new release merges in without touching it.
//
// A site with a dark look of its own already shows it when the window is dark
// (pages follow the window's appearance, see Tab.swift). Every other page is
// turned over: the whole document inverted, its hues turned back half a
// circle so a red stays a red, and every picture, video and canvas turned
// over a second time so it looks as it should. A page that turns out to be
// dark already is left as it is.
//
// One stylesheet, in before the document has a body, so a light page is never
// seen light first. Main frame only: the filter on the main document turns
// its frames over with it, and each frame is turned back whole, as its site
// made it, since the pictures inside are out of this stylesheet's reach.

enum DarkPages {
    /// View › Dark Pages. Off unless asked for.
    @MainActor static var on = false

    /// For a page already up when it is turned off.
    static let off = "window.__searchDark && window.__searchDark.off();"

    /// For a page whose look has just changed under it: reading mode puts a
    /// white page in place of whatever was there.
    static let recheck = "window.__searchDark && window.__searchDark.check();"

    static let script = #"""
    (() => {
      if (window.__searchDark) { window.__searchDark.on(); return; }

      const turn = 'invert(1) hue-rotate(180deg)';
      const mark = 'data-search-dark-picture';
      const sheet = document.createElement('style');
      sheet.id = 'search-dark-pages';
      // Screen only: a page printed comes out as the site made it.
      sheet.media = 'screen';
      sheet.textContent = [
        `html{filter:${turn} !important}`,
        // Turned over twice: as the site made them. Every frame too — a
        // video player, a map, a post from another site: this stylesheet
        // can't reach the pictures inside, so the frame is shown whole as
        // its site made it rather than with its pictures as negatives.
        `img:not(picture img),picture,video,canvas,svg image,iframe,frame,embed,object,[${mark}]{filter:${turn} !important}`,
        // Inside something already turned over twice, a picture is right as
        // it is: a third time would turn it back into a negative.
        `[${mark}] :is(img,picture,video,canvas,svg image,iframe,frame,embed,object,[${mark}]){filter:none !important}`
      ].join('');
      const place = () => (document.head || document.documentElement).appendChild(sheet);
      place();

      // How light a colour is, 0 to 1 — or null for one you can see through,
      // where whatever is behind it decides.
      const lightness = (css) => {
        const n = (css || '').match(/-?[\d.]+%?/g);
        if (!n || n.length < 3) return null;
        const v = n.map(parseFloat);
        const alpha = n.length > 3 ? v[3] / (n[3].endsWith('%') ? 100 : 1) : 1;
        if (alpha < 0.5) return null;
        if (/^(ok)?l(ab|ch)\(/.test(css)) return n[0].endsWith('%') || v[0] > 1 ? v[0] / 100 : v[0];
        const scale = css.startsWith('color(') ? 1 : 255;
        return (0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]) / scale;
      };

      // What the page itself paints behind its words. The body's colour, or
      // the document's: what a site sets when it has a look of its own, and
      // what scrolling never changes. Only when neither paints anything, what
      // is under a few points of the window — and failing that, the colour
      // scheme the page asked for.
      const ground = () => {
        for (const el of [document.body, document.documentElement]) {
          const found = el && lightness(getComputedStyle(el).backgroundColor);
          if (found !== null && found !== undefined) return found;
        }
        const found = [];
        for (const [x, y] of [[0.5, 0.5], [0.5, 0.2], [0.2, 0.6], [0.8, 0.6]]) {
          for (const el of document.elementsFromPoint(innerWidth * x, innerHeight * y)) {
            if (el.closest(`[${mark}]`) || /^(img|video|canvas|picture|iframe|svg)$/i.test(el.tagName)) continue;
            const light = lightness(getComputedStyle(el).backgroundColor);
            if (light !== null) { found.push(light); break; }
          }
        }
        if (found.length) return found.reduce((a, b) => a + b, 0) / found.length;
        const scheme = getComputedStyle(document.documentElement).colorScheme || '';
        const dark = scheme.includes('dark') && (!scheme.includes('light') || matchMedia('(prefers-color-scheme: dark)').matches);
        return dark ? 0 : 1;
      };

      let wanted = true;
      const check = () => {
        if (!wanted) return;
        sheet.media = ground() < 0.4 ? 'not all' : 'screen';
      };

      // A picture drawn as a background, which the stylesheet can't name by
      // its tag. Gradients stay out: they are colours, and turn with the page.
      // One that has lost its picture since is let go again.
      const look = (el) => {
        if (el === document.documentElement || el === document.body) return;
        const image = getComputedStyle(el).backgroundImage;
        const picture = !!image && image.includes('url(');
        if (picture && !el.hasAttribute(mark) && !(el.parentElement && el.parentElement.closest(`[${mark}]`))) {
          el.setAttribute(mark, '');
        } else if (!picture && el.hasAttribute(mark)) {
          el.removeAttribute(mark);
        }
      };
      const scan = (root, budget) => {
        if (!root || root.nodeType !== 1) return budget;
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT);
        for (let el = root; el && budget > 0; el = walker.nextNode(), budget--) look(el);
        return budget;
      };

      // What arrives later: more of the page; a player that gives an element
      // its picture after putting it in, through its style or a class; or a
      // framework that took the stylesheet out while putting its own
      // document in place.
      let waiting = [];
      const touched = new Set();
      let timer = 0;
      let early = false;
      new MutationObserver((records) => {
        if (!sheet.isConnected) place();
        if (!early && document.body) { early = true; check(); }
        for (const record of records) {
          if (record.type === 'attributes') { touched.add(record.target); continue; }
          for (const node of record.addedNodes) if (node.nodeType === 1) waiting.push(node);
        }
        if (waiting.length > 2000) waiting = waiting.slice(-2000);
        // A page animating hundreds of things through their style: looking
        // at every one would cost more than it finds.
        if (touched.size > 500) touched.clear();
        if (timer || (!waiting.length && !touched.size)) return;
        timer = setTimeout(() => {
          timer = 0;
          let budget = 4000;
          for (const node of waiting.splice(0)) budget = scan(node, budget);
          for (const el of touched) if (el.isConnected) look(el);
          touched.clear();
        }, 250);
      }).observe(document.documentElement, {
        childList: true, subtree: true, attributes: true, attributeFilter: ['style', 'class']
      });

      window.__searchDark = {
        on() { wanted = true; sheet.media = 'screen'; check(); },
        off() { wanted = false; sheet.media = 'not all'; },
        check
      };

      const ready = () => { scan(document.body, 6000); check(); };
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', ready, { once: true });
      } else {
        ready();
      }
      addEventListener('load', () => { check(); setTimeout(check, 1500); }, { once: true });
    })();
    """#
}
