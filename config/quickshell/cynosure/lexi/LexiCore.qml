// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/

import QtQuick
import Quickshell
import Quickshell.Io
import "lexi.js" as Lexicon
import "../../morpheus"

// LEXI — the dictionary and the translator. Since 2026-11-01 (user: "both
// lexi's modes in base panel just like metis") they are cards under
// Cynosure's line, which reads the line and draws them; this is all of Lexi
// that is left, and all of it that ever did the asking: Wiktionary and
// Google, the caches that spare asking twice, the histories and the
// language use the cards' chips come from, and the voice. No page, no
// field, no focus — the way Artemis became ArtemisIndex.

Item {
  id: popup

  // Cynosure: an answer that lands after it closed is not shown
  property var host: null
  readonly property bool shown: !!popup.host && popup.host.shown

  // ── what was asked, and what came back ─────────────────────────────
  property string dictQuery: ""
  property string dictAskedAs: ""
  property bool dictLoading: false
  property int lookupSeq: 0
  property var dictResult: null
  property string dictError: ""
  property string dictErrorWord: ""
  property var dictRows: []
  property var dictHist: []
  property var transHist: []
  property var usageMap: ({})
  // the languages, most used first: the translate card's chips
  property var langRows: Lexicon.rankedLangs({})
  // A new map, not the old one written into: a var property only notifies
  // on assignment, so bumping it in place left the picker's ranking and the
  // dictionary's star as they were until the next open.
  function bumpUsage(code) {
    const m = Object.assign({}, popup.usageMap);
    m[code] = (m[code] || 0) + 1;
    popup.usageMap = m;
    writer.write(Lexicon.usagePath(), Lexicon.serializeUsage(m));
  }

  // shared list state

  // the audio player, found once
  property string playerCmd: ""

  property bool cachesRead: false

  function cacheReadDone() {
    popup.cachesRead = true;
    if (popup.cardPending) { const c = popup.cardPending; popup.cardPending = null; popup.cardDefine(c.word, c.lang); }
  }

  // ------------------------------------------------------------- procs --

  Process {
    id: rDictHist
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: popup.onRead("dicthist", text)
    }
  }

  Process {
    id: rTransHist
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: popup.onRead("transhist", text)
    }
  }

  Process {
    id: rUsage
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: popup.onRead("usage", text)
    }
  }

  Process {
    id: rDictCache
    // The stream is what carries the content; the exit is what guarantees
    // an answer. Both release the pending look-up, whichever arrives.
    onExited: popup.cacheReadDone()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: popup.onRead("dictcache", text)
    }
  }

  Process {
    id: rTransCache
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: popup.onRead("transcache", text)
    }
  }

  AtomicWriter { id: writer; tag: "lexi-write" }

  Process {
    id: probeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Split on the marker LINE, and before any trimming: with no audio
        // player found the output starts "\n---", and trim() would eat it
        const ls = String(text).split("\n");
        const at = ls.indexOf("---");
        if (at >= 0) {
          popup.playerCmd = ls.slice(0, at).join("\n").trim();
        }
      }
    }
  }

  function readCaches() {
    // THROUGH A SHELL, and swallowing the error. A missing file makes cat
    // exit non-zero, and a look-up seeded from IPC waits on this read
    // before it will go to the network — so a cache that has never been
    // written must still ANSWER, with nothing, rather than not answer.
    rDictCache.command = ["sh", "-c",
      "cat " + Strings.shellQuote(Lexicon.dictCachePath()) + " 2>/dev/null"];
    rDictCache.running = true;
    rTransCache.command = ["sh", "-c",
      "cat " + Strings.shellQuote(Lexicon.transCachePath()) + " 2>/dev/null"];
    rTransCache.running = true;
    rDictHist.command = ["cat", Lexicon.dictHistoryPath()];
    rDictHist.running = true;
    rTransHist.command = ["cat", Lexicon.transHistoryPath()];
    rTransHist.running = true;
    rUsage.command = ["cat", Lexicon.usagePath()];
    rUsage.running = true;
  }

  function onRead(purpose, text) {
    if (purpose === "dicthist") {
      popup.dictHist = Lexicon.parseDictHistory(text);
    } else if (purpose === "transhist") {
      popup.transHist = Lexicon.parseTransHistory(text);
    } else if (purpose === "usage") {
      popup.usageMap = Lexicon.parseUsage(text);
      popup.langRows = Lexicon.rankedLangs(popup.usageMap);
    } else if (purpose === "dictcache") {
      popup.dictCache = Lexicon.parseCache(text);
      popup.cacheReadDone();
    } else if (purpose === "transcache") {
      popup.transCache = Lexicon.parseCache(text);
    }
  }

  // The head of the look-up history, for the line under the empty field.
  // Four: enough to be a reminder, few enough to stay one line on a panel
  // that is now only as wide as what is in it.
  // Answers already in hand. See the note in lexi.js — these are read at
  // open like the histories are, so a look-up never waits on a file.
  property var dictCache: Lexicon.emptyCache()
  property var transCache: Lexicon.emptyCache()

  function saveDictCache() {
    writer.write(Lexicon.dictCachePath(),
      Lexicon.serializeCache(popup.dictCache));
  }
  function saveTransCache() {
    writer.write(Lexicon.transCachePath(),
      Lexicon.serializeCache(popup.transCache));
  }

  function detach(script) {
    if (script) Quickshell.execDetached(["bash", "-c", script]);
  }

  // ---------------------------------------------------- dictionary --

  // keys its cache by: the chosen one, or the one Cynosure's card asked for
  property string lookLangEn: "English"
  property string lookLangKey: "en"
  // a look-up, with no page and no focus moved: startLookup's, and the card's
  function lookWord(word, langEn, langKey) {
    popup.lookLangEn = langEn;
    popup.lookLangKey = langKey;
    popup.dictQuery = word;
    popup.dictAskedAs = word;
    popup.dictError = "";
    popup.dictErrorWord = "";
    popup.dictResult = null;
    popup.dictSuggest = [];
    popup.dictAlso = [];
    popup.expanded = false;

    // A word already read comes back in this frame: no request, and no
    // loading state either, because there is nothing to wait for and a
    // spinner that never spins is a flicker.
    const key = Lexicon.dictCacheKey(word, popup.lookLangKey);
    const hit = Lexicon.cacheGet(popup.dictCache, key);
    if (hit) {
      popup.lookupSeq++;   // anything still in flight is answering an old question
      popup.dictLoading = false;
      popup.showDictResult(hit);
      return;
    }

    popup.dictLoading = true;
    const seq = ++popup.lookupSeq;
    Lexicon.resolveWord(word, popup.lookLangEn).then(
      (res) => popup.onDictResolved(seq, res),
      (err) => popup.onDictFailed(seq, err)
    );
  }

  // Everything that happens once a result exists, however it was come by.
  function showDictResult(result) {
    popup.dictResult = result;
    popup.dictRows = popup.buildDictRows(result);
    if (result.corrected) popup.dictQuery = result.title;

    popup.dictHist = Lexicon.addDictHistory(popup.dictHist, result.title);
    writer.write(Lexicon.dictHistoryPath(),
      Lexicon.serializeDictHistory(popup.dictHist));

    if (result.audio && popup.playerCmd !== "")
      popup.prefetchDictAudio(result.audio.file);
  }

  function onDictResolved(seq, res) {
    if (seq !== popup.lookupSeq || !popup.shown) return;
    popup.dictLoading = false;

    const result = Lexicon.entryToResult(res);

    // Under BOTH names. A typo that Wiktionary's own search rescued —
    // "helo" to "hello" — is the look-up most worth not repeating, and it
    // is the one a title-only key would miss every time.
    const lc = popup.lookLangKey;
    popup.dictCache = Lexicon.cachePut(popup.dictCache,
      Lexicon.dictCacheKey(result.title, lc), result);
    const asked = Lexicon.dictCacheKey(popup.dictQuery, lc);
    if (asked !== "" && asked !== Lexicon.dictCacheKey(result.title, lc))
      popup.dictCache = Lexicon.cachePut(popup.dictCache, asked, result);
    popup.saveDictCache();

    popup.showDictResult(result);

    // Only when it corrected: an exact hit has no runners-up worth the
    // request, and this is one more round trip on a path that just made
    // a guess on your behalf.
    if (result.corrected) {
      const asked = popup.dictQuery;
      const got = String(result.title).toLowerCase();
      Lexicon.suggest(asked, 6).then((list) => {
        if (seq !== popup.lookupSeq || !popup.shown) return;
        const out = [];
        for (const c of list)
          if (String(c).toLowerCase() !== got && out.length < 3) out.push(String(c));
        popup.dictAlso = out;
      });
    }
  }

  // ── WHAT IT NEARLY FOUND ──────────────────────────────────────────────
  // resolveWord already asks Wiktionary's own search when the word as
  // typed is not a page, and tries the top three — so a typo usually
  // rescues itself. When none of the three has an English section you got
  // "Check spelling?" and nothing else, while the search had a list of
  // near misses sitting right there.
  //
  // Eight now rather than three, because the three it already tried are
  // the ones that failed: the useful ones are the five underneath them.
  property var dictSuggest: []

  // THE RUNNERS-UP, when the word you typed was not the word you got.
  // "kick the buckit" resolves to "kick the bucket" and says CORRECTED,
  // which is the right answer nine times in ten — and in the tenth there
  // was no way to see what else the search had offered, or to take it.
  // Not a list with a caret in it: the definition on screen is still the
  // answer, and this is a footnote to it.
  property var dictAlso: []

  // What the offers under an error ARE. Two kinds, one caret: a near-miss
  // word to look up instead, or a language the page does have a section
  // for — because when "faire" misses while reading English, the fix is
  // not a different spelling, it is a different language, and the answer
  // was on the page all along.
  property string offerLabel: "did you mean"

  function onDictFailed(seq, err) {
    if (seq !== popup.lookupSeq || !popup.shown) return;
    popup.dictLoading = false;

    // the page exists, just not in this language
    if (err && typeof err === "object" && err.kind === "lang") {
      // EVERY SECTION THE PAGE CAN BE READ IN, code or no code. Filtering
      // these by codeForEnName is what made the list wrong: it kept only
      // the languages that are translation targets, which on "faire" meant
      // keeping the two that parse to nothing and dropping the eight that
      // work.
      const offers = [];
      for (const name of err.has)
        offers.push({ kind: "lang", code: Lexicon.codeForEnName(name) || "",
                      en: name, text: name });
      popup.offerLabel = "\"" + popup.dictQuery + "\" is not "
        + popup.lookLangEn + ". This page has";
      // EMPTY, not a space. It was a space so the error branch of the
      // height would fire; that branch now measures the column like every
      // other, and the space was rendering as a blank line of 17px text
      // with its padding — forty pixels of nothing above the sentence.
      popup.dictError = offers.length > 0 ? ""
        : "no " + popup.lookLangEn + " entry for";
      popup.dictErrorWord = offers.length > 0 ? "" : popup.dictQuery;
      popup.dictSuggest = offers;
      return;
    }

    // A MONTH-OLD DEFINITION BEATS AN ERROR. The cache is only read fresh
    // on the way in, which is right — but once the network has actually
    // failed, an entry too old to trust is still the answer to the
    // question, and the alternative on offer is nothing at all.
    if (err === "network") {
      const stale = Lexicon.cacheGetStale(popup.dictCache,
        Lexicon.dictCacheKey(popup.dictQuery, popup.lookLangKey));
      if (stale) { popup.showDictResult(stale); return; }
    }

    // THE WORD IS THE SUBJECT, and the header that used to carry it is
    // hidden in this state — so the message names it, and is the only
    // thing on the panel. Lower case and no full stop: the same voice the
    // rest of the shell answers in — "no match", "no backgrounds in …".
    popup.dictError = err === "network"
      ? "no answer from Wiktionary — check the connection"
      : "no entry for";
    popup.dictErrorWord = err === "network" ? "" : popup.dictQuery;

    if (err !== "network") {
      popup.offerLabel = "did you mean";
      const asked = popup.dictQuery;
      Lexicon.suggest(asked, 8).then((list) => {
        if (seq !== popup.lookupSeq || !popup.shown) return;
        const out = [];
        for (const c of list)
          if (String(c).toLowerCase() !== String(asked).toLowerCase())
            out.push({ kind: "word", text: String(c) });
        popup.dictSuggest = out;
        });
    }
  }

  // Whether the whole entry is on show. Resets with every look-up: it is
  // a thing you ask of one word, not a setting.
  property bool expanded: false

  function buildDictRows(res) {
    const rows = [];
    const maxDefs = popup.expanded ? 99 : Lexicon.showDefs();
    const maxSyn = popup.expanded ? 99 : Lexicon.showSynonyms();
    for (const group of res.pos) {
      rows.push({ kind: "pos", text: Strings.escapeHtml(group.name) });
      for (const d of group.defs.slice(0, maxDefs)) {
        const label = d.label ? "(" + d.label + ") " : "";
        const lab = label
          ? "<span style=\"color:" + Zenon.muted + ";font-style:italic;\">" +
            Strings.escapeHtml(label) + "</span>"
          : "";
        rows.push({ kind: "def", text: lab + Strings.escapeHtml(d.def) });
        if (d.example)
          rows.push({ kind: "ex", text: Strings.escapeHtml(d.example) });
      }
    }
    if (res.synonyms && res.synonyms.length > 0) {
      rows.push({ kind: "syn", text: "<b>Synonyms:</b> " +
        Strings.escapeHtml(res.synonyms.slice(0, maxSyn).join(", ")) });
    }
    return rows;
  }

  readonly property string dictAudioPath: Paths.runtimeDir() + "/qslexicon-dict.audio"

  function prefetchDictAudio(file) {
    const url = Lexicon.WIKT_AUDIO_BASE + encodeURIComponent(file);
    popup.detach("rm -f " + Strings.shellQuote(popup.dictAudioPath) +
      " " + Strings.shellQuote(popup.dictAudioPath + ".part") + " && " +
      "curl -sL --max-time 10 -A " + Strings.shellQuote(Lexicon.UA) + " " +
      Strings.shellQuote(url) + " -o " +
      Strings.shellQuote(popup.dictAudioPath + ".part") + " && mv -f " +
      Strings.shellQuote(popup.dictAudioPath + ".part") + " " +
      Strings.shellQuote(popup.dictAudioPath));
  }

  function playDictAudio() {
    if (popup.playerCmd === "" || !popup.dictResult || !popup.dictResult.audio) return;
    popup.detach(Lexicon.audioPlayScript(popup.dictAudioPath, popup.playerCmd));
  }

  // ── CYNOSURE'S CARDS (2026-11-01) ─────────────────────────────────────
  // The dictionary and the translator as cards under Cynosure's own line,
  // the way the calculator is (user: "both lexi's modes in base panel just
  // like metis", in stylized cards): Cynosure reads the line and draws the
  // card; this does the asking, through the same look-up, caches and
  // histories as the pages. Nothing here moves the focus or the view.
  property bool cardInit: false
  property var cardPending: null
  function cardWake() {
    if (popup.cardInit) return;
    popup.cardInit = true;
    popup.readCaches();
  }
  // a word, in English or the language named ({ code, en })
  function cardDefine(word, lang) {
    popup.cardWake();
    const w = String(word || "").trim();
    if (w === "") {
      popup.lookupSeq++;
      popup.dictQuery = "";
      popup.dictResult = null;
      popup.dictRows = [];
      popup.dictError = "";
      popup.dictLoading = false;
      popup.dictSuggest = [];
      popup.dictAlso = [];
      return;
    }
    if (!popup.cachesRead) { popup.cardPending = { word: w, lang }; return; }
    const en = lang ? lang.en : "English";
    const key = lang ? lang.code || lang.en : "en";
    // the same word asked again (the line re-read): nothing new to fetch
    if (w === popup.dictAskedAs && key === popup.lookLangKey && (popup.dictResult || popup.dictLoading)) return;
    popup.dictAskedAs = w;
    popup.lookWord(w, en, key);
  }
  // all of the entry, or the first few senses again
  function cardMore() {
    if (!popup.dictResult) return;
    popup.expanded = !popup.expanded;
    popup.dictRows = popup.buildDictRows(popup.dictResult);
  }
  // { text, to, from, pending } then { …, translation, roman, source } or
  // { …, error }: the translation the card shows
  property var cardTr: null
  property int cardTrSeq: 0
  function cardTranslate(text, to, from) {
    popup.cardWake();
    const t = String(text || "").trim();
    const seq = ++popup.cardTrSeq;
    if (t === "") { popup.cardTr = null; return; }
    const code = to || "en";
    const was = popup.cardTr;
    if (was && was.text === t && was.to === code && was.from === (from || null) && !was.error) return;
    const key = Lexicon.transCacheKey(code, from || null, t);
    const hit = Lexicon.cacheGet(popup.transCache, key);
    const base = { text: t, to: code, from: from || null };
    if (hit) { popup.cardTr = Object.assign(base, hit); return; }
    // the last answer stays up, dimmed, while this one is out
    popup.cardTr = Object.assign({}, was && !was.error ? was : {}, base, { pending: true });
    Lexicon.postForm(Lexicon.translateRequest(t, code, from || null), (status, body) => {
      if (seq !== popup.cardTrSeq) return;
      const parsed = status === 200 ? Lexicon.parseTranslateResponse(body) : null;
      if (!parsed) {
        const stale = Lexicon.cacheGetStale(popup.transCache, key);
        popup.cardTr = Object.assign(base, stale || { error: true });
        return;
      }
      popup.transCache = Lexicon.cachePut(popup.transCache, key, parsed);
      popup.saveTransCache();
      popup.cardTr = Object.assign(base, parsed);
    });
  }
  // kept once the line is left with it (Cynosure closes or copies)
  function cardKeep() {
    const c = popup.cardTr;
    if (c && !c.error && !c.pending && c.translation) {
      popup.bumpUsage(c.to);
      popup.transHist = Lexicon.addTransHistory(popup.transHist, c.to, c.from, c.text, c.translation);
      writer.write(Lexicon.transHistoryPath(), Lexicon.serializeTransHistory(popup.transHist));
    }
  }
  // the word said (Wiktionary's recording), or the translation read out
  function cardSpeak(mode) {
    if (mode === "dict") { popup.playDictAudio(); return; }
    popup.stopAudio();
    const c = popup.cardTr;
    if (!c || !c.translation || popup.playerCmd === "") return;
    const prefix = "qslexicon-" + Date.now();
    popup.activePrefix = prefix;
    popup.detach(Lexicon.ttsScript(prefix, c.translation, c.to, popup.playerCmd));
  }
  // what return copies off a card
  function cardText(mode) {
    if (mode === "dict") return popup.dictResult ? Lexicon.dictPlain(popup.dictResult.title, popup.dictRows) : "";
    return popup.cardTr && popup.cardTr.translation ? popup.cardTr.translation : "";
  }

  // ---------------------------------------------------------- voice --

  property string activePrefix: ""

  function stopAudio() {
    // Kill only the running playback's own prefix; a broad "qslexicon-"
    // pattern races against freshly spawned scripts and kills them instead.
    if (popup.activePrefix !== "") {
      popup.detach("pkill -f " + Strings.shellQuote(popup.activePrefix) +
        " >/dev/null 2>&1");
    }
    popup.activePrefix = "";
  }

  Component.onCompleted: {
    probeProc.command = ["sh", "-c", Lexicon.playerProbeCommand() + "; echo ---"];
    probeProc.running = true;
  }
}
