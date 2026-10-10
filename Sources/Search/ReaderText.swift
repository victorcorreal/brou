// Reading mode, the words and nothing else. View › Text Only in Reading Mode.
//
// Not in Office Commun's Search: added for this build, in a file of its own so
// a new release merges in without touching it. Reader.script is left as it
// is; this runs after it, on the article it has put in place.

extension Reader {
    /// View › Text Only in Reading Mode. On unless turned off.
    @MainActor static var textOnly = true

    /// Everything in the article that isn't text goes: pictures, video,
    /// sound, embedded frames, drawings. A figure goes with its caption when
    /// a picture was all it held; one holding code or a quotation stays.
    /// Then whatever is left empty — the box a picture was in, the link
    /// around it.
    static let textOnlyScript = """
    (function () {
      var article = document.getElementById('office-reader');
      if (!article) return 'none';
      var pictures = article.querySelectorAll(
        'img,picture,video,audio,iframe,svg,canvas,embed,object,source,track,map'
      );
      for (var i = 0; i < pictures.length; i++) pictures[i].remove();

      var figures = article.querySelectorAll('figure');
      for (var f = 0; f < figures.length; f++) {
        var words = figures[f].cloneNode(true);
        var captions = words.querySelectorAll('figcaption');
        for (var c = 0; c < captions.length; c++) captions[c].remove();
        if (!words.textContent.trim()) figures[f].remove();
      }

      // Reading mode puts the title on top, and the article often carries
      // the same heading as well: once is enough.
      var title = article.firstElementChild;
      var said = title ? title.textContent.trim() : '';
      var heads = article.querySelectorAll('h1,h2');
      for (var h = 0; h < heads.length; h++) {
        if (heads[h] !== title && heads[h].textContent.trim() === said) heads[h].remove();
      }

      var all = article.querySelectorAll('*');
      for (var e = all.length - 1; e >= 0; e--) {
        var el = all[e];
        if (/^(BR|HR|TD|TH)$/.test(el.tagName) || el.closest('pre')) continue;
        if (!el.textContent.trim()) el.remove();
      }
      return 'read';
    })();
    """
}

extension Tab {
    /// Once reading mode has put the article in place.
    func afterReading() {
        if Reader.textOnly { web.evaluateInSearch(Reader.textOnlyScript) }
        // A white page now, whatever the site was: Dark Pages looks again.
        if DarkPages.on { web.evaluateInSearch(DarkPages.recheck) }
    }
}
