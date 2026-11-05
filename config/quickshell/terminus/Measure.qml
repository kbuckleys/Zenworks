// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// Terminus' how big a directory really is … logic, out of TerminusWindow.qml
// (2026-10-08). The state stays on the window (term); the window keeps a
// one-line forwarder for each function here, so callers are unchanged.

import QtQuick
import Quickshell.Io
import "../morpheus"
import "terminus.js" as Terminus

Item {
  id: measure
  property var term: null
  readonly property alias selMeasure: selMeasure
  readonly property alias usageDelay: usageDelay

  Process {
    id: duProc
    // how long a walk takes here, so a re-measure waits in proportion — see
    // restale
    property real began: 0
    onRunningChanged: if (duProc.running) duProc.began = Date.now();
              else measure.lastWalk = Date.now() - duProc.began
    stdout: StdioCollector {
      id: duOut
      waitForEnd: true
      onStreamFinished: {
        const got = Terminus.parseDirSizes(duOut.text);
        const next = Object.assign({}, term.dirSizes, got);
        // A re-measured directory du had nothing to say about is gone, or
        // can no longer be read: its old total is no answer either.
        for (const p of measure.reasked) if (got[p] === undefined) delete next[p];
        measure.reasked = [];
        term.dirSizes = next;
        // and handed to the manager, so the NEXT window starts measured —
        // see revealWhenReady
        if (term.mgr) term.mgr.noteSizes(got);
        const n = Object.keys(got).length;
        // In the usage view the bars ARE the report, and a line reading
        // "measured 22" left over from the directory before this one is just
        // a wrong caption under a right picture.
        if (term.duQuiet) {
          // measured for the selection's total, which is the report — see
          // measureMarked. Nothing to say in the status line.
          term.duQuiet = false;
          Qt.callLater(term.measureMarked);
          if (term.sizing) Qt.callLater(term.measureAll);
        } else if (term.sizing) {
          term.status = "";
          // whatever this batch could not reach, and anything listed since it
          // started — see measureAll's note about being busy
          Qt.callLater(term.measureAll);
          Qt.callLater(term.measureMarked);
        } else {
          // only the nothing-measured case is bad news; the others are counts
          if (n === 0) term.warn("Could not measure");
          else term.status = (n === 1 ? "measured" : "measured " + n);
          // marks made while this ran are still waiting for their total
          Qt.callLater(term.measureMarked);
        }
      }
    }
  }
  // ── A TOTAL IS ONLY AS OLD AS THE LAST CHANGE UNDER IT ─────────────────
  // dirSizes was kept for as long as the window was open, so a directory
  // measured once said the same number however much was written into it
  // afterwards, and so did every directory above it. The window already
  // hears about changes (DirWatch, and deepProc below for what lies under
  // a measured directory); a change now marks every measured total it sits
  // under as stale.
  //
  // A stale total on screen is MEASURED AGAIN, quietly, and keeps its old
  // number until the new one lands, so the column never blinks to a dash.
  // One that is not on screen is dropped, so it is measured fresh the next
  // time it is wanted rather than served from before the change.
  property var stale: ({})
  property var reasked: []
  property real lastWalk: 0
  // `paths` changed, so every total they sit in is stale; `under` are
  // directories that came or went whole, so totals INSIDE them are too.
  function sizesMoved(paths, under) {
    const sizes = term.dirSizes;
    const st = measure.stale;
    const deep = (under || []).map((u) => u === "/" ? "/" : u + "/");
    let any = false;
    for (const k in sizes) {
      if (st[k]) continue;
      const pre = k === "/" ? "/" : k + "/";
      let hit = false;
      for (const p of paths) if (p === k || p.indexOf(pre) === 0) { hit = true; break; }
      if (!hit) for (const d of deep) if (k.indexOf(d) === 0) { hit = true; break; }
      if (hit) { st[k] = true; any = true; }
    }
    if (any && !restale.running) restale.start();
  }
  // Everything measured, after the window has been hidden and watching
  // nothing — see catchUp.
  function sizesAllMoved() {
    for (const k in term.dirSizes) measure.stale[k] = true;
    if (Object.keys(measure.stale).length > 0 && !restale.running) restale.start();
  }
  // The directories on screen whose TOTAL is drawn: every row of a list
  // (its size column shows any total there is) and every row while the
  // usage view, a size sort or the space map is up; otherwise only the
  // marked ones (the selection's total) and the one under the cursor (the
  // columns view's footer). A total nobody is shown is not worth a walk.
  function shownDirs() {
    const out = ({});
    const cur = term.currentRow();
    const panes = [term.act, term.dual ? term.pas : null];
    for (const pane of panes) {
      if (!pane) continue;
      const all = term.sizing || pane.viewMode === "list";
      const v = pane.view || [];
      for (let i = 0; i < v.length; ++i) {
        const r = v[i];
        if (!r || !r.isDir) continue;
        if (all || (pane === term.act && (term.marked[r.path]
            || (cur && cur.path === r.path)))) out[r.path] = true;
      }
    }
    return out;
  }
  // STARTED, NEVER RESTARTED: the first change of a burst is answered after
  // one interval, however long the writing goes on, and a walk is never
  // asked for more often than five times what the last one took — a busy
  // ~/.cache must not keep du walking it back to back.
  Timer {
    id: restale
    interval: Math.max(1500, 5 * measure.lastWalk)
    onTriggered: {
      if (duProc.running) { restale.start(); return; }
      const keys = Object.keys(measure.stale);
      measure.stale = ({});
      if (keys.length === 0) return;
      const shown = term.shown ? measure.shownDirs() : ({});
      const ask = [], drop = [];
      for (const k of keys) {
        if (term.dirSizes[k] === undefined) continue;
        (shown[k] ? ask : drop).push(k);
      }
      if (drop.length > 0) {
        const next = Object.assign({}, term.dirSizes);
        const tried = Object.assign({}, term.duTried);
        const sel = Object.assign({}, term.selTried);
        for (const k of drop) { delete next[k]; delete tried[k]; delete sel[k]; }
        term.duTried = tried;
        term.selTried = sel;
        term.dirSizes = next;
        if (term.mgr) term.mgr.forgetSizes(drop);
      }
      if (ask.length === 0) return;
      measure.reasked = ask;
      term.duQuiet = true;
      duProc.command = Terminus.shArgv(Terminus.dirSizeCommand(ask));
      duProc.running = true;
    }
  }

  // ── AND WHAT LIES UNDER A MEASURED DIRECTORY ──────────────────────────
  // The listing's watch is one level deep, so a file growing two directories
  // down inside a measured row moves that row's total without a single
  // event reaching the window. One recursive inotifywait over the measured
  // directories on screen hears it.
  //
  // CAPPED, because -r costs a watch per directory underneath: each one is
  // counted first (`find | head`, which stops at the cap rather than walking
  // the whole tree), and one that would take the set past deepCap is left
  // out. A directory that big is still re-measured when something changes
  // at a level the listing watches, and whenever the window is shown again.
  readonly property int deepCap: 8000
  readonly property string deepWant: {
    if (!term || !term.shown) return "";
    const sizes = term.dirSizes;
    const shown = Object.keys(measure.shownDirs()).filter((p) => sizes[p] !== undefined);
    shown.sort();
    // a directory inside one already listed is already covered by it
    const out = [];
    for (const p of shown) {
      const last = out.length > 0 ? out[out.length - 1] : "";
      if (last !== "" && p.indexOf(last === "/" ? "/" : last + "/") === 0) continue;
      out.push(p);
    }
    return out.join("\n");
  }
  onDeepWantChanged: deepAim.restart()
  property string deepArmed: ""
  Timer {
    id: deepAim
    interval: 300
    onTriggered: {
      const key = measure.deepWant;
      if (key === measure.deepArmed && (key === "" || deepProc.running)) return;
      measure.deepArmed = key;
      deepProc.running = false;
      if (key === "") return;
      deepProc.command = Paths.tether(["sh", "-c",
        'left=' + measure.deepCap + '; n=$#; while [ "$n" -gt 0 ]; do d=$1; shift; n=$((n-1)); '
        + 'if [ -d "$d" ] && [ -r "$d" ] && [ -x "$d" ]; then '
        + 'c=$(find "$d" -type d 2>/dev/null | head -n "$left" | wc -l); '
        + 'if [ "$c" -lt "$left" ]; then left=$((left-c)); set -- "$@" "$d"; fi; fi; done; '
        + '[ "$#" -gt 0 ] || exit 0; '
        + 'exec inotifywait -m -q -r --format %w -e create -e delete -e moved_to '
        + '-e moved_from -e close_write -e modify -- "$@"',
        "sh"].concat(key.split("\n")));
      deepProc.running = true;
    }
  }
  property var deepHits: ({})
  Process {
    id: deepProc
    stdout: SplitParser {
      splitMarker: "\n"
      // %w: the directory the change happened in, with its slash
      onRead: (line) => {
        let p = String(line || "");
        if (p.length > 1 && p.charAt(p.length - 1) === "/") p = p.slice(0, -1);
        if (p === "") return;
        measure.deepHits[p] = true;
        if (!deepFlush.running) deepFlush.start();
      }
    }
    // see shutWatchProc in DirWatch: forgotten, so the next aim starts it again
    onExited: (code) => { if (!deepProc.running) measure.deepArmed = ""; }
  }
  // a modify per write() is hundreds of lines a second during a copy; they
  // are gathered here and the totals looked over once per interval
  Timer {
    id: deepFlush
    interval: 250
    onTriggered: {
      const hits = Object.keys(measure.deepHits);
      measure.deepHits = ({});
      if (hits.length > 0) measure.sizesMoved(hits, []);
    }
  }

  Process {
    id: gitProc
    stdout: StdioCollector {
      id: gitOut
      waitForEnd: true
      onStreamFinished: {
        // Asked about the directory we were in when the scan started, not the
        // one we are in now: a reply that arrives after you have walked on
        // would otherwise be rolled up against the wrong base and mark rows it
        // knows nothing about.
        const asked = term.gitAsked;
        term.gitAsked = "";
        // and the directory we are in now is asked about in its turn: its
        // own scan was refused while this one ran (audit 2026-10-28d)
        if (asked !== term.cwd) { Qt.callLater(term.scanGit); return; }
        const g = Terminus.parseGit(gitOut.text);
        term.gitRoot = g.root;
        term.gitBranch = g.branch;
        term.gitMarks = g.root === "" ? ({})
                                      : Terminus.gitRollup(g.entries, term.cwd);
      }
    }
  }
  function scanGit() {
    if (!term.git) return;
    // One at a time. A directory of directories walked quickly would otherwise
    // start a `git status` per keystroke and the answers would land in an order
    // nobody controls.
    if (gitProc.running) return;
    term.gitAsked = term.cwd;
    gitProc.command = ["sh", "-c", Terminus.gitCommand(term.cwd)];
    gitProc.running = true;
  }
  function toggleGit() {
    term.git = !term.git;
    if (term.git) { term.scanGit(); return; }
    term.gitMarks = ({});
    term.gitRoot = "";
    term.gitBranch = "";
  }
  // What a state is worth looking at in. Red for the two that cost you
  // something, green for what is already safely staged, and the rest below
  // the names they sit beside — a gutter that shouted would be a listing you
  // read the gutter of.
  // one definition, in terminus.js, shared with plato's tree
  function gitInk(state) { return Terminus.gitInk(state); }
  // The measured size of a row: a walked directory, or a file, which is
  // already its own whole answer. Undefined until du has been round.
  function usageOf(r) {
    if (!r) return 0;
    if (!r.isDir) return r.size;
    const v = term.dirSizes[r.path];
    return v === undefined ? 0 : v;
  }
  function toggleUsage() {
    term.usage = !term.usage;
    if (term.usage) {
      term.usagePrevSort = term.sortKey;
      term.usagePrevDesc = term.sortDesc;
      term.usagePrevView = term.viewMode;
      term.sortKey = "usage";
      term.sortDesc = true;
      term.duTried = ({});
      // A FRESH ANSWER, because that is what turning the mode on is asking
      // for. Sizes are cached by path and outlive the listing, which is right
      // for navigating — but a directory measured an hour and several downloads
      // ago would be reported here as though it were current.
      term.dirSizes = ({});
      // The column this mode is about only exists in the list. Toggling it in
      // the grid would reorder tiles that show no sizes, which reads as
      // nothing having happened.
      if (term.viewMode !== "list") term.act.viewMode = "list";
      term.measureAll();
    } else {
      term.sortKey = term.usagePrevSort !== "" ? term.usagePrevSort : "name";
      term.sortDesc = term.usagePrevDesc;
      if (term.usagePrevView !== "" && term.usagePrevView !== term.viewMode)
        term.act.viewMode = term.usagePrevView;
      term.status = "";
    }
  }
  // Opening a branch puts directories on screen without re-listing cwd, so
  // nothing else would come back to measure them. Debounced for the reason
  // the empty-directory probe is: expanding changes the rows twice in quick
  // succession, and du is a walk of the whole subtree.
  Timer {
    id: usageDelay
    interval: 150
    onTriggered: term.measureAll()
  }
  function measureAll() {
    if (!term.sizing) return;
    // Busy is not the same as done. This used to just give up, and since the
    // only caller was the listing, nothing ever came back to it: walk into a
    // directory while the previous one is still being measured and its directories
    // kept their dashes for as long as the window stayed open. The retry now
    // lives in duProc's completion, so being busy costs a wait rather than the
    // whole answer.
    if (duProc.running) return;
    const tried = term.duTried;
    const sizes = term.dirSizes;
    // ── EVERY DIRECTORY DRAWN, NOT ONLY THE TOP LEVEL ───────────────
    // This asked about root.rows, which is the listing — so a directory
    // spliced into the tree by opening a branch was never handed to du at
    // all. Its bar stayed an empty track for ever, which the delegate
    // draws to mean "asked, no answer yet" and here meant "never asked":
    // usage had nothing to do with the child rows. `view` is what is on
    // screen, which is also what usageMax is already measured against, so
    // the bars and the yardstick now come from the same set of rows.
    const todo = term.view.filter((r) => r.isDir
      && sizes[r.path] === undefined && tried[r.path] !== true);
    if (todo.length === 0) { term.status = ""; return; }
    const next = Object.assign({}, tried);
    for (const r of todo) next[r.path] = true;
    term.duTried = next;
    term.status = "Measuring " + todo.length
      + (todo.length === 1 ? " directory\u2026" : " directories\u2026");
    duProc.command = Terminus.shArgv(
      Terminus.dirSizeCommand(todo.map((r) => r.path)));
    duProc.running = true;
  }
  Timer {
    id: selMeasure
    interval: 350
    onTriggered: term.measureMarked()
  }
  function measureMarked() {
    if (term.markedCount === 0 || duProc.running) return;
    const tried = term.selTried;
    const todo = term.markedRows().filter((r) => r.isDir
      && term.dirSizes[r.path] === undefined && tried[r.path] !== true);
    if (todo.length === 0) return;
    const next = Object.assign({}, tried);
    for (const r of todo) next[r.path] = true;
    term.selTried = next;
    term.duQuiet = true;
    duProc.command = Terminus.shArgv(
      Terminus.dirSizeCommand(todo.map((r) => r.path)));
    duProc.running = true;
  }
  function measureDirs() {
    const dirs = term.acting().filter((r) => r.isDir);
    if (dirs.length === 0) { term.warn("No directory to measure"); return; }
    if (duProc.running) { term.status = "Still measuring\u2026"; return; }
    term.status = "Measuring " + (dirs.length === 1 ? dirs[0].name
      : dirs.length + " directories") + "\u2026";
    duProc.command = Terminus.shArgv(
      Terminus.dirSizeCommand(dirs.map((r) => r.path)));
    duProc.running = true;
  }
}
