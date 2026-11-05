// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// FILEGLYPHS — the glyphs you chose yourself, for one file or directory.
//
// Terminus' "Change glyph…" writes here; Icons.glyphFor asks here FIRST,
// before any of its tables, for every entry that comes with a path. So the
// listing, the sidebar, the crumbs, the pickers and Cynosure all draw the
// one you chose, from one answer.
//
// PER PATH (user, 2026-11-05): a glyph belongs to that one entry, not to
// every entry with its name. It follows the entry where Terminus renames or
// moves it (moved), and goes when Terminus deletes or trashes it (forget) —
// both called from the same places as Terminus' tag index.
//
// Kept in Terminus' state, terminus-glyphs.json, written whole through
// AtomicWriter: { "paths": { "/abs/path": "<glyph>" } }.
//
//   of(path)            the chosen glyph, or ""  (a binding that asks
//                       updates when the choice changes: it reads `map`)
//   set(path, glyph)    choose; "" puts the default back
//   clear(paths)        the default back for each
//   moved(pairs)        [[from, to], …], descendants of a directory too
//   forget(paths)       gone from disk, descendants too
//   edited()            after any change, for the views that copied a
//                       glyph into their rows (terminus' enrich)

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var map: ({})
  property var written: []
  readonly property string file: Quickshell.statePath("terminus-glyphs.json")
  signal edited()

  function of(path) {
    let p = String(path || "");
    if (p === "") return "";
    // a directory as "dir/" (artemis' paths) is the same directory
    if (p.length > 1 && p.charAt(p.length - 1) === "/") p = p.replace(/\/+$/, "") || "/";
    const g = root.map[p];
    return typeof g === "string" ? g : "";
  }

  function set(path, glyph) {
    const p = root.clean_(path);
    if (p === "") return;
    const g = String(glyph || "");
    if (root.of(p) === g) return;
    const m = Object.assign({}, root.map);
    if (g === "") delete m[p]; else m[p] = g;
    root.commit_(m);
  }
  // many at once, one write (a choice for 500 marked files was 500 writes
  // and 500 relists in every window; audit 11-05)
  function setMany(paths, glyph) {
    const g = String(glyph || "");
    const m = Object.assign({}, root.map);
    let hit = false;
    for (const raw of paths || []) {
      const p = root.clean_(raw);
      if (p === "" || root.of(p) === g) continue;
      if (g === "") delete m[p]; else m[p] = g;
      hit = true;
    }
    if (hit) root.commit_(m);
  }
  function clear(paths) {
    const m = Object.assign({}, root.map);
    let hit = false;
    for (const p of paths || []) {
      const c = root.clean_(p);
      if (m[c] !== undefined) { delete m[c]; hit = true; }
    }
    if (hit) root.commit_(m);
  }

  // A directory's choices move with it: everything under `from/` too.
  function moved(pairs) {
    if (!pairs || pairs.length === 0) return;
    const keys = Object.keys(root.map);
    if (keys.length === 0) return;
    // FROM THE SNAPSHOT (audit 11-05): bulk rename swaps and shifts
    // (a→b, b→a), so every source is cleared first and then written from
    // the OLD map — moving in place lost one of a swapped pair. A target
    // that was overwritten loses its own choice (a file over a file).
    const m = Object.assign({}, root.map);
    const src = [];
    for (const q of pairs) {
      const from = root.clean_(q && q[0]), to = root.clean_(q && q[1]);
      if (from === "" || to === "" || from === to) continue;
      src.push([from, to]);
    }
    if (src.length === 0) return;
    const inside = (k, p) => k === p || k.indexOf(p + "/") === 0;
    for (const [from] of src)
      for (const k of keys) if (inside(k, from)) delete m[k];
    for (const [from, to] of src) {
      if (src.every(s => s[0] !== to)) delete m[to];
      for (const k of keys)
        if (inside(k, from)) m[to + k.slice(from.length)] = root.map[k];
    }
    const before = root.map;
    root.commit_(m);
    root.check_({ kind: "move", pairs: src, before: before });
  }
  function forget(paths) {
    if (!paths || paths.length === 0) return;
    const keys = Object.keys(root.map);
    if (keys.length === 0) return;
    const m = Object.assign({}, root.map);
    let hit = false;
    for (const raw of paths) {
      const p = root.clean_(raw);
      if (p === "") continue;
      const under = p + "/";
      for (const k of keys) {
        if ((k === p || k.indexOf(under) === 0) && m[k] !== undefined) { delete m[k]; hit = true; }
      }
    }
    if (!hit) return;
    const before = root.map;
    root.commit_(m);
    root.check_({ kind: "forget", paths: paths.map(root.clean_).filter((p) => p !== ""), before: before });
  }

  // an absolute path, without a trailing slash ("/" stays "/")
  function clean_(path) {
    const p = String(path || "").replace(/(.)\/+$/, "$1");
    return p.charAt(0) === "/" ? p : "";
  }
  function commit_(m) {
    root.map = m;
    const text = JSON.stringify({ paths: m }, null, 1) + "\n";
    // our own writes, so the file watch can tell them from an import's
    root.written = root.written.slice(-7).concat([text]);
    writer.write(root.file, text);
    root.edited();
  }

  FileView {
    id: store
    path: root.file
    blockLoading: true
    printErrors: false
    // an import (Oracle's settings) writes it under us: read it again, or
    // the next choice would write the old list back over it (audit 11-05)
    watchChanges: true
    onFileChanged: {
      store.reload();
      if (root.written.indexOf(store.text()) >= 0) return;
      root.load_();
      root.edited();
    }
  }
  Component.onCompleted: root.load_()
  function load_() {
    try {
      const st = JSON.parse(store.text() || "{}");
      const m = ({});
      const ps = st && st.paths && typeof st.paths === "object" ? st.paths : {};
      for (const k in ps) {
        const p = root.clean_(k);
        if (p !== "" && typeof ps[k] === "string" && ps[k] !== "") m[p] = ps[k];
      }
      root.map = m;
    } catch (e) {}
  }
  AtomicWriter { id: writer; tag: "fileglyphs" }

  // ── DID THE JOB LAND? (audit 11-05) ─────────────────────────────────────
  // Choices move (and go) when the verb is ASKED, as the tag index does;
  // a rename that failed, or a trash refused, would leave the file without
  // its glyph. So the disk is looked at twice, 2 s and 10 s on: a move whose
  // source is still there and target is not, or a forgotten path still
  // there, both times, gets its choices back from before.
  property var checks: []
  property var pending_: null
  function check_(c) {
    root.checks = root.checks.concat([Object.assign({ round: 0 }, c)]);
    if (!checkTimer.running && !probe.running) checkTimer.restart();
  }
  function paths_(c) {
    if (c.kind === "forget") return c.paths;
    const out = [];
    for (const q of c.pairs) out.push(q[0], q[1]);
    return out;
  }
  function failed_(c, here) {
    if (c.kind === "forget") return c.paths.filter((p) => here[p]);
    return c.pairs.filter((q) => here[q[0]] && !here[q[1]]);
  }
  function undo_(c, bad) {
    const inside = (k, p) => k === p || k.indexOf(p + "/") === 0;
    const m = Object.assign({}, root.map);
    const old = c.before;
    for (const b of bad) {
      const from = c.kind === "forget" ? b : b[0];
      if (c.kind === "move") {
        // what this move wrote under `to`, back to what was there
        for (const k of Object.keys(m)) if (inside(k, b[1])) delete m[k];
        for (const k of Object.keys(old)) if (inside(k, b[1])) m[k] = old[k];
      }
      for (const k of Object.keys(old)) if (inside(k, from)) m[k] = old[k];
    }
    root.commit_(m);
  }
  Timer {
    id: checkTimer
    interval: root.checks.length > 0 && root.checks[0].round > 0 ? 8000 : 2000
    onTriggered: {
      if (root.checks.length === 0) return;
      const c = root.checks[0];
      root.pending_ = c;
      probe.command = ["sh", "-c", 'for p; do [ -e "$p" ] && printf "%s\\n" "$p"; done; exit 0', "fileglyphs"]
        .concat(root.paths_(c));
      probe.running = true;
    }
  }
  Process {
    id: probe
    stdout: StdioCollector {
      onStreamFinished: {
        const c = root.pending_;
        if (!c) return;
        const here = {};
        for (const l of text.split("\n")) if (l !== "") here[l] = true;
        const bad = root.failed_(c, here);
        if (bad.length > 0 && c.round === 0) {
          // once more, later: the job may still be running
          const again = Object.assign({}, c, { round: 1 });
          if (c.kind === "move") again.pairs = bad; else again.paths = bad;
          root.checks = [again].concat(root.checks.slice(1));
        } else {
          if (bad.length > 0) root.undo_(c, bad);
          root.checks = root.checks.slice(1);
        }
      }
    }
    // the queue goes on after the exit (streamFinished comes first)
    onExited: { root.pending_ = null; if (root.checks.length > 0) checkTimer.restart(); }
  }
}
