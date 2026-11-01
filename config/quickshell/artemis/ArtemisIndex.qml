// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ARTEMIS — the finder. Goddess of the hunt, who is said never to have missed
// what she aimed at: type a few letters and the thing you meant is the thing
// at the top. An index of the tree, an fzf over it, and a frecency count so
// what you actually open climbs.
//
// Since 2026-11-01 she has no panel of her own: what she finds is the Files
// section of Cynosure's list. This is all of her that is left, and all of her
// that ever did the finding — the walk, the search, the frecency and the
// open — as one object in shell.qml that Cynosure asks and plato's Ctrl-P
// reads (`finder`).

import QtQuick
import Quickshell
import Quickshell.Io
import "artemis.js" as Artemis
import "../morpheus"
import "../terminus/terminus.js" as Terminus

Item {
  id: finder

  property string searchRoot: Quickshell.env("HOME")

  // ── the index ────────────────────────────────────────────────────────
  // Where the walk gets written, and when it last happened. The file itself
  // is never read into QML — only fzf opens it — so its size costs the
  // engine nothing.
  readonly property string indexPath: Quickshell.cachePath("artemis-index")
  // kept for artemis.json and status(), not for deciding whether to rebuild
  property double indexedAt: 0
  property bool indexing: false
  property bool searching: false

  // what was last asked, and what came back for it
  property string query: ""
  property var rows: []
  // the query `rows` answer, which is not the one being typed until they land
  property string answered: ""

  // Results can arrive out of order — a search is a process, killing one is
  // asynchronous, and a slow reply could otherwise land on top of a newer
  // one. Only the newest generation is allowed to write rows.
  property int searchGen: 0

  property var freq: ({})

  // nothing opens this file: Cynosure raises terminus' open-with card for it
  signal noHandler(string path)
  // it opened (or a directory went to terminus): Cynosure can close
  signal opened()
  // `qs ipc call Artemis toggle`: the finder is Cynosure's list now
  signal toggleAsked()

  IpcHandler {
    target: "Artemis"
    // Same shape as Picasso's rescan(): the index is a cache, and there has
    // to be a way to rebuild it without waiting for it to go stale.
    function reindex(): string {
      finder.reindex();
      return "indexing";
    }
    function status(): string {
      return "index=" + finder.indexPath
        + " age=" + (finder.indexedAt > 0
            ? Math.round((Date.now() - finder.indexedAt) / 1000) + "s" : "never")
        + " indexing=" + finder.indexing
        + " known=" + Object.keys(finder.freq).length;
    }
    function toggle(): string {
      finder.toggleAsked();
      return "ok";
    }
  }

  Process {
    id: searchProc
    property int generation: 0
    property string nextCmd: ""
    property int nextGen: 0
    property string nextQuery: ""
    property string runQuery: ""
    onExited: if (searchProc.nextCmd !== "") Qt.callLater(finder.startSearch)
    stdout: StdioCollector {
      id: out
      waitForEnd: true
      onStreamFinished: finder.onSearch(out.text, searchProc.generation, searchProc.runQuery)
    }
  }

  Process {
    id: actionProc
    onExited: (code) => finder.onActionDone(code)
  }

  // The walk. Runs detached from anything the user is waiting on: a search
  // answers off whatever index is already on disk and this refreshes it
  // underneath.
  Process {
    id: indexProc
    onExited: {
      finder.indexing = false
      finder.indexedAt = Date.now()
      finder.saveState()
      // the first index of all: nothing could be found until it existed
      if (finder.query !== "") finder.search(finder.query)
      finder.pruneFreq()
    }
  }

  // The frequency map outlives the files in it. Checked after an index walk
  // rather than on every search: that is the moment the answer can have
  // changed, and it costs one process over a few hundred keys.
  Process {
    id: aliveProc
    stdout: StdioCollector {
      id: aliveOut
      waitForEnd: true
      onStreamFinished: {
        const alive = String(aliveOut.text || "").split("\u001e").filter((x) => x !== "")
        const before = Object.keys(finder.freq).length
        finder.freq = Artemis.pruneFreq(finder.freq, alive)
        if (Object.keys(finder.freq).length !== before) finder.saveState()
      }
    }
  }

  function pruneFreq() {
    const keys = Object.keys(finder.freq)
    if (keys.length === 0 || aliveProc.running) return
    aliveProc.command = ["sh", "-c", Strings.aliveCommand(keys)]
    aliveProc.running = true
  }

  // Walked again on every way in (Cynosure's open, plato's Ctrl-P): the walk
  // is 19ms for ~4k entries, so there is nothing to buy by tolerating a stale
  // index — and a staleness window is what made a manual reindex key needed.
  function reindex() {
    if (finder.indexing) return
    finder.indexing = true
    indexProc.command = ["sh", "-c",
      Artemis.indexCommand(finder.searchRoot || Quickshell.env("HOME"), finder.indexPath)]
    indexProc.running = true
  }

  // ── what to find ─────────────────────────────────────────────────────
  // "" asks nothing and clears; anything else is fzf over the index, ranked.
  function search(q) {
    finder.query = String(q || "").trim()
    if (finder.query === "") {
      finder.searchGen++
      searchProc.nextCmd = ""
      searchProc.running = false
      finder.searching = false
      finder.answered = ""
      finder.rows = []
      return
    }
    finder.run(Artemis.filterCommand(finder.indexPath, finder.query, false), finder.query)
  }

  // The most opened, for a line that only says "find" ("f " with nothing
  // after it)
  function frequent(limit) {
    return Artemis.freqRanked(finder.freq, limit || 50)
  }

  // Every result-producing command goes through here so the generation
  // bookkeeping cannot be forgotten at one of the call sites.
  function run(cmd, q) {
    finder.searchGen++
    finder.searching = true
    searchProc.nextCmd = cmd
    searchProc.nextGen = finder.searchGen
    searchProc.nextQuery = q
    // Killing a process is asynchronous, so the old run is stopped and the
    // new one started from its exit. Setting `generation` and `running` on
    // the spot relabeled the OLD run as the new one.
    if (searchProc.running) { searchProc.running = false; return }
    finder.startSearch()
  }

  function startSearch() {
    if (searchProc.running || searchProc.nextCmd === "") return
    searchProc.generation = searchProc.nextGen
    searchProc.runQuery = searchProc.nextQuery
    searchProc.command = ["sh", "-c", searchProc.nextCmd]
    searchProc.nextCmd = ""
    searchProc.running = true
  }

  // fzf --filter has already fuzzy-matched and ranked: nothing to do here
  // but keep what came back, if it is still the newest question's.
  function onSearch(text, gen, q) {
    if (gen !== finder.searchGen) return
    finder.searching = false
    // the question first: whoever hears rowsChanged checks it
    finder.answered = q
    finder.rows = Artemis.parseResults(text)
  }

  // The file an open is out for, while it is — so its exit can be read as
  // "nothing opens this" and not as any other action ending.
  property string opening: ""

  function open(row) {
    if (!row) return
    finder.freq = Artemis.bumpFreq(finder.freq, row.path)
    finder.saveState()
    if (row.isDir) {
      actionProc.command = ["sh", "-c", Artemis.openDirCommand(row.path)]
      actionProc.running = true
      return
    }
    finder.opening = row.path
    actionProc.command = ["sh", "-c", Terminus.openOrAskCommand(row.path)]
    actionProc.running = true
  }

  function onActionDone(code) {
    const path = finder.opening
    finder.opening = ""
    // nothing opens it: the same card terminus raises for the same file
    if (path !== "" && code === Terminus.NO_HANDLER) finder.noHandler(path)
    else finder.opened()
  }

  // ── FOR PLATO ────────────────────────────────────────────────────────
  // Plato's Ctrl-P is this finder, scoped to a project: it reads this index
  // (see `scope` in artemis.js), asks for it to be walked again through
  // reindex() when it opens, and says what it opened through here — so a file
  // opened from either one ranks in both.
  function noteOpened(path) {
    finder.freq = Artemis.bumpFreq(finder.freq, String(path))
    finder.saveState()
  }

  // ── what survives a restart ──────────────────────────────────────────
  FileView {
    id: stateFile
    path: Quickshell.statePath("artemis.json")
    blockLoading: true
    printErrors: false
  }

  Timer {
    id: stateSave
    interval: 400
    onTriggered: stateFile.setText(JSON.stringify({
      freq: finder.freq, indexedAt: finder.indexedAt
    }))
  }

  function saveState() { stateSave.restart() }

  Component.onCompleted: {
    try {
      const j = JSON.parse(stateFile.text() || "{}")
      finder.freq = j.freq ?? ({})
      finder.indexedAt = j.indexedAt ?? 0
    } catch (e) {}
  }
}
