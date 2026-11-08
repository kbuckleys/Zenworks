// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ── change glyph ──────────────────────────────────────────────────
// The glyph a file or directory is drawn with, chosen by hand (user,
// 2026-11-05). Every Nerd Font glyph, searched by its name — the grid is
// Alexandria's own (morpheus/GlyphGrid), and so are the names: the
// manager's glyphnames.json (needNames), fetched once into the cache.
//
// Per path: the choice is that entry's, kept by morpheus/FileGlyphs, which
// Icons.glyphFor asks first. Return uses the glyph under the cursor on
// everything the sheet was opened over; ctrl d puts the default back.
// The bar shows the entry wearing the glyph under the cursor, so what it
// would look like is on screen before it is chosen.

import QtQuick
import "../morpheus"
import "terminus.js" as Terminus
import "../morpheus/icons.js" as Icons
import "../alexandria/alexandria.js" as A

Rectangle {
  id: glyphPick
  // the terminus window (`term`, never `root` — see terminus-split notes)
  property var term: null
  anchors.fill: parent
  z: 13
  visible: opacity > 0.01
  opacity: glyphPick.open ? 1 : 0
  // the scrim stops at the bar, as the tag picker's does
  color: "transparent"
  Rectangle {
    anchors.fill: parent
    anchors.topMargin: term.tabStripRef.height + term.crumbBarRef.height
    color: term.cardScrim
  }
  Rectangle {
    width: term.sideRef.width
    height: term.tabStripRef.height + term.crumbBarRef.height
    color: term.cardScrim
  }
  Behavior on opacity {
    NumberAnimation {
      duration: glyphPick.open ? glyphSheet.slideIn : glyphSheet.slideOut
      easing.type: Zenon.ease
    }
  }

  property bool open: false
  // what it is choosing for, captured on the way in (rows with a path)
  property var targets: []
  readonly property bool many: glyphPick.targets.length > 1
  readonly property var first: glyphPick.targets.length > 0 ? glyphPick.targets[0] : null

  // ── THE GLYPHS AND THEIR NAMES ─────────────────────────────────
  readonly property var book: term && term.mgr ? term.mgr.fontBook : null
  readonly property var nerd: glyphPick.book ? glyphPick.book.nerd : ({})
  // every codepoint glyphnames.json names, in order
  readonly property var all: {
    const cps = Object.keys(glyphPick.nerd).map(Number).filter((c) => !isNaN(c));
    cps.sort((a, b) => a - b);
    return A.indexOfList(cps);
  }
  // names are still on their way: no "nothing found" yet
  readonly property bool waiting: glyphPick.all.count === 0
  property var found: []
  Timer { id: findDelay; interval: 140; onTriggered: glyphPick.runSearch() }
  function runSearch() {
    const q = cells.query.trim();
    glyphPick.found = q === "" ? []
      : A.searchGlyphs(glyphPick.all, q, glyphPick.book ? glyphPick.book.uni : null, glyphPick.nerd);
    cells.sel = 0;
    if (q === "") glyphPick.seat();
  }
  readonly property var ix: cells.query.trim() !== "" ? A.indexOfList(glyphPick.found) : glyphPick.all
  onAllChanged: if (glyphPick.open) { if (cells.query.trim() !== "") findDelay.restart(); else glyphPick.seat(); }

  // what the entry wears now, and whether that is a choice of its own
  readonly property string current: glyphPick.first ? Terminus.glyphOf(glyphPick.first, Icons) : ""
  readonly property bool hasOwn: glyphPick.targets.some((t) => FileGlyphs.of(t.path) !== "")
  // the glyph the bar shows: the one under the cursor, else the current one
  readonly property string shown: cells.cp >= 0 ? A.charOf(cells.cp) : glyphPick.current
  function nameOf(cp) {
    const n = cp >= 0 ? glyphPick.nerd[cp] : null;
    return n && n.length > 0 ? n[0] : "";
  }

  // the cursor on what it wears now, when that is one of them
  function seat() {
    const cur = glyphPick.current;
    const at = cur !== "" ? A.posOf(glyphPick.all, cur.codePointAt(0)) : -1;
    cells.sel = Math.max(0, at);
    Qt.callLater(() => cells.show(cells.sel));
  }

  // over `rows` when given (the Info card's), else what the verbs act on
  function ask(rows) {
    rows = (rows || term.acting() || []).filter((r) => r && r.path);
    if (rows.length === 0) { term.warn("Nothing to change the glyph of"); return; }
    glyphPick.targets = rows;
    if (glyphPick.book) glyphPick.book.needNames();
    glyphPick.found = [];
    cells.query = "";
    glyphPick.open = true;
    glyphPick.seat();
    glyphClaim.begin();
  }
  function dismiss() {
    glyphPick.open = false;
    term.contentRef.forceActiveFocus();
  }
  function use() {
    if (cells.cp < 0 || glyphPick.targets.length === 0) return;
    const g = A.charOf(cells.cp);
    // Return on the rule's own glyph is no choice: it would pin the default
    // and stop following the map (audit 11-05)
    const ts = glyphPick.targets.filter(t => !(g === glyphPick.current && !glyphPick.hasOwn));
    FileGlyphs.setMany(ts.map(t => t.path), g);
    glyphPick.dismiss();
  }
  // the default back, from the menu as well as from ctrl d here
  function reset(rows) {
    const paths = (rows || glyphPick.targets).map((r) => r.path);
    FileGlyphs.clear(paths);
    if (glyphPick.open) glyphPick.dismiss();
  }
  function move(d) {
    if (cells.index.count === 0) return;
    cells.sel = Math.max(0, Math.min(cells.index.count - 1, cells.sel + d));
    cells.show(cells.sel);
  }
  function navKey(e) {
    const k = e.key, ctrl = e.modifiers & Qt.ControlModifier;
    if (k === Qt.Key_Escape) {
      if (cells.query !== "") cells.query = ""; else glyphPick.dismiss();
      return true;
    }
    if (k === Qt.Key_Return || k === Qt.Key_Enter) { glyphPick.use(); return true; }
    if (ctrl && k === Qt.Key_D) { if (glyphPick.hasOwn) glyphPick.reset(); return true; }
    const cols = cells.cols;
    if (k === Qt.Key_Left) { glyphPick.move(-1); return true; }
    if (k === Qt.Key_Right) { glyphPick.move(1); return true; }
    if (k === Qt.Key_Up) { glyphPick.move(-cols); return true; }
    if (k === Qt.Key_Down) { glyphPick.move(cols); return true; }
    if (k === Qt.Key_PageUp) { glyphPick.move(-cols * 6); return true; }
    if (k === Qt.Key_PageDown) { glyphPick.move(cols * 6); return true; }
    return false;
  }

  // ask until it has it: the card is still fading in when the first
  // request goes out, and focus on an item not placed yet is dropped
  FocusRetry {
    id: glyphClaim
    interval: 40
    checkFirst: true
    live: glyphPick.open
    took: cells.field.activeFocus
    onPlace: {
      cells.field.forceActiveFocus();
    }
  }

  InputShield { keepTop: term.tabStripRef.height + term.crumbBarRef.height; onClicked: glyphPick.dismiss() }

  TermSheet {
    id: glyphSheet
    host: term
    note: "s14"
    leftInset: term.sideRef.width
    floating: false
    title: term.sheetTitle
    glyph: term.sheetGlyph
    titleInk: term.sheetTitleInk
    glyphInk: term.sheetGlyphInk
    shown: glyphPick.open
    fromTop: term.tabStripRef.height + term.crumbBarRef.height
    cardW: Math.max(460, Math.min(780, term.width - term.sideRef.width - 48))
    cardH: Math.max(300, Math.min(560, term.height - glyphSheet.fromTop - 48))

    // THE ROWS GO ON UNDER THE SEARCH, frosted (user, 2026-11-05), as on
    // Alexandria's Glyphs page: the chrome is the card's top down to the
    // grid's, a span to measure rather than a bar of its own, and the edge
    // is laid before the grid so the search's translucent wash tints it.
    Item {
      id: searchChrome
      x: cells.x
      y: 0
      width: cells.width
      height: cells.y + cells.grid.y
    }
    ScrollEdge {
      view: cells.grid
      follow: true
      bar: searchChrome
      visible: glyphPick.open
    }

    GlyphGrid {
      id: cells
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: glyphFoot.top
      index: glyphPick.ix
      total: glyphPick.all.count
      cell: 56
      busy: glyphPick.waiting
      placeholder: "Search by name or codepoint — folder, git, U+F07B"
      navKey: glyphPick.navKey
      onQueryChanged: findDelay.restart()
      onUsed: (i) => { cells.sel = i; glyphPick.use(); }
    }
    // the names on their way (fetched once into the cache)
    Text {
      textFormat: Text.PlainText
      anchors.centerIn: cells
      visible: glyphPick.open && glyphPick.waiting
      text: glyphPick.book ? "Reading glyph names…" : "Alexandria is not running"
      color: Zenon.accentMuted
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(15)
    }

    ScrollEdge { view: cells.grid; below: true; follow: true; bar: glyphFoot }
    HintBar {
      id: glyphFoot
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      rows: [["↵", "use"], ["←↑↓→", "move"]]
        .concat(glyphPick.hasOwn ? [["ctrl d", "default"]] : [])
        .concat([["esc", "close"]])
      // the name of the glyph under the cursor
      leading: Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: cells.cp >= 0 ? (glyphPick.nameOf(cells.cp) || A.uplus(cells.cp)) : ""
        color: Zenon.accentMuted
        font.family: Zenon.face
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(14)
      }
    }
  }
}
