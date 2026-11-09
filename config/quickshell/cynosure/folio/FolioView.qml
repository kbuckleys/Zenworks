// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../../morpheus"
import "../../morpheus/gridnav.js" as Nav
import "../../morpheus/runjob.js" as RunJob
import "../../picasso"
import "../../terminus"
import "../../oracle"
import "../../clio"
import "folio.js" as Folio
import "../../morpheus/icons.js" as Icons
import "../../picasso/capture.js" as Cap

// FOLIO — the clipboard and the snippets. Since 2026-11-01 what it holds
// is shown as rows of Cynosure's list (the Clipboard and Snippets sections,
// "cb …" for them alone): Cynosure loads this, unseen, and reads its
// entries, pictures, stamps and snippets, and acts through it (takeClip,
// takeSnippet, dropClip, keepClip, annotateClip, editSnippetAt). The one
// part of it still drawn is the snippet page (`editing`), which takes the
// panel while a snippet is written.

Item {
  id: popup

  // ── THE VIEW CONTRACT ── how Cynosure loads it (cynosure/CynosurePopup.qml):
  // `host` is Cynosure's window (its shown, its collapsing, the window a
  // bubble hangs from); `dismissed` closes the panel, `backed` returns to
  // its list. `closing` latches, so the close is done once however it
  // arrives (Cynosure's grab, a click outside, a copy).
  property var host: null
  readonly property bool shown: !!popup.host && popup.host.shown
  readonly property bool collapsing: !!popup.host && popup.host.collapsing
  property bool nested: true
  readonly property string escWord: "close"
  signal dismissed()
  signal backed()
  property bool closing: false
  // read and acted on by Cynosure's rows, unseen but for the snippet page:
  // it never takes the keyboard but to write a snippet
  property bool embedded: false
  // bumped on each way in: rows that arrive one after another restart
  // their entrance on it, as they did on the layer's own `opened`
  property int opened: 0

  // ── DRAGGING ONE OF THESE SOMEWHERE ELSE ──────────────────────────────
  // Artemis' arrangement, wholesale, because the problem is identical: a
  // layer-shell popup that must let go of the pointer and of its own focus
  // grab for as long as a drag is in flight, without canceling the drag.
  // Cynosure's window reads `dragging` for both: its input region and its
  // grab let go while it is true.
  //
  // Wayland's drag grab is separate from the surface input region, so
  // dropping the region mid-drag does not cancel anything — it only decides
  // who the drop resolves to, which has to be the application underneath.
  property bool dragging: false

  // text · image · snip (snippets, 2026-10-21: kept text, pasted with its
  // placeholders filled — see Folio.expandSnippet)
  property string mode: "text"
  property var snippets: []
  property string query: ""
  property var entries: []
  // the entries as cliphist listed them, before their names (Folio.withNames)
  property var listed: []
  // ── NAMES: a clip renamed, id → name (Folio.namesPath) ──
  property var names: ({})
  FileView {
    id: namesFile
    path: Folio.namesPath()
    blockLoading: true
    printErrors: false
    Component.onCompleted: popup.names = Folio.parseLedger(namesFile.text()) || {}
  }
  // our own write never fires loaded (FileView): the names are set from it
  function setName(id, name) {
    popup.names = Folio.setName(popup.names, id, name);
    namesFile.setText(JSON.stringify(popup.names));
    popup.entries = Folio.withNames(popup.listed, popup.names);
  }
  function nameOf(id) { return popup.names[id] || ""; }
  // ── PINS: clips at the top of "cb" (Folio.pinsPath) ──
  property var pins: []
  FileView {
    id: pinsFile
    path: Folio.pinsPath()
    blockLoading: true
    printErrors: false
    Component.onCompleted: popup.pins = Folio.parsePins(pinsFile.text())
  }
  // pinned with its whole text (cliphist's list line is cut short), read
  // back first; unpinned at once
  function togglePin(id, text) {
    const put = (t) => {
      popup.pins = Folio.togglePin(popup.pins, id, t);
      pinsFile.setText(JSON.stringify(popup.pins));
    };
    if (popup.isPinned(id)) put("");
    else popup.decodeText(id, (t) => put(t !== "" ? t : text));
  }
  function isPinned(id) { return popup.pins.some((p) => p.id === id); }
  // a pin's own words, for one cliphist has let go
  function takeText(t) {
    popup.runAction("printf '%s' " + Strings.shellQuote(String(t || "")) + " | wl-copy", "copy");
  }
  // ── IN TURN: clips marked to paste one after another (Folio.inTurnCommand) ──
  property var turn: []
  function toggleTurn(id) {
    popup.turn = popup.turn.indexOf(id) >= 0 ? popup.turn.filter((x) => x !== id) : popup.turn.concat([id]);
  }
  function pasteInTurn() {
    if (popup.turn.length === 0) return;
    Quickshell.execDetached(["sh", "-c", Folio.inTurnCommand(popup.turn, Paths.runtimeDir())]);
    Quickshell.execDetached(["notify-send", "-a", "folio", "--", "Pasting in turn",
      popup.turn.length + " clips: each paste takes the next"]);
    popup.turn = [];
  }
  property var imageIds: []
  property var rows: []
  property var imgRows: []
  property var thumbsReady: ({})
  property int thumbStamp: 0
  property int sel: 0
  property bool hasText: false
  property bool hasImg: false
  // one kind per command asked: a second asked while the first runs is
  // queued by the Process, and with one shared kind the first's exit read
  // the second's (two quick deletes closed the panel; audit 10-31)

  // ── THE PAGE A SNIPPET IS WRITTEN ON (user, 2026-10-21) ───────────────
  // ctrl n and ctrl e no longer hand the snippet to plato: the panel itself
  // turns into a sticky's page (clio/NoteField, plain text), its name on a
  // line above, Cancel and Save under it. `editPath` is the file being
  // changed, "" for a new one.
  property bool editing: false
  property string editPath: ""
  readonly property int editW: 640
  readonly property int editH: 340

  readonly property color bgColor: Zenon.layerBg
  readonly property color fgColor: Zenon.white
  readonly property color hintColor: Zenon.muted

  // ── THE KEYS, DRAWN AS KEYS ──────────────────────────────────────────
  // The hints were rich text with the key in bold and its word after it in
  // gray, and the colors were hex literals inside folio.js — the palette
  // said twice. A chip says "this is a key you press" the way the rest of
  // this desktop says it, and takes its ink from Zenon like everything else.
  //
  // The recipe is terminus' KeyChip, which is an inline component of that
  // file and so cannot be imported.

  // Two lines a cell: the clip, and under it when it was copied.
  readonly property int textCellH: 52
  readonly property int textRows: 9
  readonly property int imgCell: 200
  // The tile plus its own date line under the picture.
  readonly property int imgCellH: popup.imgCell + 22
  readonly property int imgRowsVisible: 3
  // morpheus/HintBar's strip; Cynosure's strip says its keys when embedded
  readonly property int msgH: popup.embedded ? 0 : Zenon.hintBarH

  // AS MANY AS THERE ARE, up to as many as fit. Five was the answer whether
  // the clipboard held two pictures or twenty, so two pictures sat in the
  // left fifth of a panel that was three fifths empty. The literal 1000 here
  // and not panelWidth: the ceiling is what limits the columns, and reading
  // the width back would be the width deciding itself.
  readonly property int imgPerRow: Math.max(1,
    Math.min(popup.imgRows.length, Math.floor(1000 / popup.imgCell)))

  // ONE COLUMN, ALWAYS (user 2026-10-17). Past twelve entries they used to
  // be dealt across two, each at half the width; an entry now carries its
  // date on a second line, and one entry per line reads top to bottom.
  readonly property int textRowsNeeded:
    Math.min(Math.max(1, popup.rows.length), popup.textRows)

  // ── AS WIDE AS WHAT IS IN IT ──────────────────────────────────────────
  // A thousand pixels was the answer to every clipboard: three short clips
  // got the same panel as thirty lines of HTML, most of it empty. The face
  // is monospaced and cellText already measures in characters against it,
  // so the width the longest entry wants is arithmetic, not a layout pass —
  // the same advanceWidth, the same 32 of cell padding, read backwards.
  //
  // NO NARROWER THAN ITS OWN FOOTER, in either mode. The hint strip is a row
  // of chips centered in the panel and its contents change with the mode, so
  // the floor is measured off the row itself rather than guessed at with a
  // literal that would be wrong the day a hint is reworded.
  //
  // No circle in reading it back: what the row is wide is decided by the
  // chips and their labels, and not one of them looks at the panel.
  readonly property int hintPad: 24
  readonly property int minW:
    Math.ceil(msgBar.hintRow.implicitWidth) + popup.hintPad * 2
  // MEASURED, NOT COUNTED. This was characters times the advance of an
  // "M" — right for a monospaced face, and the shell's is proportional, so
  // every line was cut at roughly two thirds of the room it had (user
  // 2026-10-17: "truncate too early"). Only the first 240 characters are
  // measured: past that the 1000px ceiling has long since won.
  readonly property int textCellW: {
    let w = 0;
    for (let i = 0; i < popup.rows.length; ++i) {
      const p = popup.rows[i].preview;
      if (p) w = Math.max(w, textMetrics.advanceWidth(p.slice(0, 240)));
    }
    return Math.ceil(w) + 32;
  }

  // The bar OVERLAYS the right edge of the grid rather than sitting beside
  // it, so it is not part of a cell's width — it is a strip the panel has to
  // carry in addition, or the tail of the longest line is read through it.
  // No circle: whether the grid scrolls is decided by how many entries there
  // are, never by how wide it is.
  readonly property int textBarW: textBar.visible ? textBar.width : 0
  readonly property int textWant: popup.rows.length === 0 ? popup.minW
    : Math.max(popup.minW, popup.textCellW + popup.textBarW)

  // 1000 is folio's own ceiling, under whatever Zenon.layerMax currently is.
  // Image mode measures in whole tiles, which is the only width a grid of
  // fixed 200px cells can honestly be.
  readonly property int panelWidth: popup.editing ? Math.max(popup.minW, popup.editW)
    : popup.mode === "image"
    ? Math.max(popup.minW, popup.imgPerRow * popup.imgCell)
    : Math.min(1000, popup.textWant)
  readonly property int panelTarget: Zenon.layerWidth(popup.panelWidth)

  readonly property int imgRowsNeeded: Math.min(Math.ceil(popup.imgRows.length / popup.imgPerRow), popup.imgRowsVisible)

  function cellText(preview) {
    // THE TARGET WIDTH, not the live one. panel.width follows the pill while
    // it morphs, so measuring against it re-truncated and re-marked-up every
    // row on every frame of the animation for an answer that is only correct
    // at the end of it.
    // Elided by the face's own metrics, before the markup goes in — rich
    // text cannot elide itself.
    const avail = Math.max(1, popup.panelTarget - popup.textBarW - 32);
    const p = textMetrics.elidedText(preview.slice(0, 2000), Qt.ElideRight, avail);
    return Folio.highlightedPreview(p, popup.query, Zenon.hex(Zenon.pink));
  }
  readonly property real textCellHeight: popup.textCellH

  // Whether the side you are LOOKING AT has anything in it, which is not the
  // same question as whether the clipboard does. Deleting the last image
  // leaves hasText true, and every test here asked about the clipboard.
  readonly property bool modeEmpty:
    popup.mode === "image" ? !popup.hasImg : popup.mode === "snip" ? popup.snippets.length === 0 : !popup.hasText

  // AN EMPTY MODE STILL HAS SOMETHING TO SAY. The text side has always kept
  // a row back for its message — that is what the Math.max(1, ...) in
  // textRowsNeeded is for — and the image side kept none, so deleting the
  // last picture collapsed the panel onto its own hint strip: a bar of keys
  // floating over nothing, with no line saying why.
  //
  // One row's worth either way, and the text row's height for both, so the
  // two empty states are the same object rather than two sizes of nothing.
  readonly property real bodyH: popup.editing ? popup.editH + popup.msgH
    : popup.modeEmpty
    ? popup.textCellHeight + popup.msgH
    : (popup.mode === "image"
        ? popup.imgRowsNeeded * popup.imgCellH + popup.msgH
        : popup.textRowsNeeded * popup.textCellHeight + popup.msgH)

  FontMetrics {
    id: textMetrics
    font.family: Zenon.face
    font.pixelSize: Zenon.px(16)
    font.weight: Zenon.titleWeight
  }




  // a reload asked while one runs is the one that counts (audit 11-09:
  // it was dropped, and the list stayed as the earlier read had it)
  Process {
    id: listProc
    property var job: null
    property var want: null
    onExited: RunJob.next(listProc)
    stdout: StdioCollector {
      id: out
      waitForEnd: true
      onStreamFinished: if (RunJob.current(listProc)) popup.onList(out.text)
    }
  }

  Process {
    id: thumbProc
    onExited: popup.onThumbsDone()
  }

  // one at a time, in turn, each with its kind (audit 2026-11-09): a list
  // of kinds beside a single command lost a second action and read every
  // later exit as the one before
  Process {
    id: actionProc
    property var job: null
    property var queue: []
    onExited: { popup.onActionDone(actionProc.job ? actionProc.job.kind : ""); RunJob.next(actionProc); }
  }

  // ── THE LEDGER: WHEN EACH ENTRY ARRIVED ───────────────────────────────
  // See Folio.reconcile. Kept running while the popup is shut, since that is
  // when nearly everything is copied. Tethered like every -m watcher here.
  property var stamps: ({})
  property bool ledgerRead: false
  // null: nothing re-copied; a number (0 included) is the original's stamp
  property var carryStamp: null
  property bool scanLive: false
  property real openedAt: Date.now()

  FileView {
    id: ledgerFile
    path: Folio.ledgerPath()
    blockLoading: true
    printErrors: false
  }

  Process {
    id: ledgerWatch
    command: Paths.tether(["sh", "-c",
      "mkdir -p \"$1\" && exec inotifywait -m -q -e close_write,delete,moved_to --format %f \"$1\"",
      "folio-ledger", Folio.thumbDir()])
    stdout: SplitParser {
      onRead: (line) => {
        if (line.trim() !== "db") return;
        popup.scanLive = true;
        ledgerDebounce.restart();
      }
    }
    // Ended means inotify-tools went missing or the directory did: try
    // again later rather than spinning.
    onExited: ledgerRetry.restart()
  }

  Timer {
    id: ledgerRetry
    interval: 30000
    onTriggered: ledgerWatch.running = true
  }

  Timer {
    id: ledgerDebounce
    interval: 120
    onTriggered: popup.ledgerScan()
  }

  Process {
    id: ledgerProc
    stdout: StdioCollector {
      id: ledgerOut
      waitForEnd: true
      onStreamFinished: popup.onLedgerList(ledgerOut.text)
    }
  }

  function ledgerScan() {
    if (ledgerProc.running) { ledgerDebounce.restart(); return; }
    ledgerProc.command = ["cliphist", "-preview-width", "1", "list"];
    ledgerProc.running = true;
  }

  function onLedgerList(text) {
    if (!popup.ledgerRead) {
      ledgerFile.reload();
      popup.stamps = Folio.parseLedger(ledgerFile.text()) || {};
      popup.ledgerRead = true;
    }
    const live = popup.scanLive;
    popup.scanLive = false;
    const next = Folio.reconcile(popup.stamps, Folio.listIds(text), live,
                                 Date.now(), live ? popup.carryStamp : null);
    if (live) popup.carryStamp = null;
    if (!next) return;
    popup.stamps = next;
    // setText never fires loaded — the state above is already the truth
    ledgerFile.setText(JSON.stringify(next));
  }

  Component.onCompleted: {
    ledgerWatch.running = true;
    popup.ledgerScan();
  }

  function stampOf(id) {
    return Folio.stampLabel(popup.stamps[id] || 0, popup.openedAt, Oracle.clock24h);
  }

  // Cynosure's way in: a fresh open
  function start() {
    popup.closing = false;
    popup.opened++;
    popup.openedAt = Date.now();
    popup.mode = "text";
    popup.editing = false;
    popup.query = "";
    filter.text = "";
    popup.sel = 0;
    popup.reload();
    popup.loadSnippets();
    if (!popup.embedded) focusRetry.begin();
  }

  // the filter as if typed here ("cb …" in Cynosure)
  function setLine(q) {
    filter.text = q || "";
  }

  // ── SNIPPETS ───────────────────────────────────────────────────────────
  // One .txt each in Folio.snippetDir(), read whole when the panel opens:
  // a handful of small files, not worth watching.
  function loadSnippets() {
    snipList.command = ["python3", "-I", "-c",
      "import json,os,shutil,sys\n"
      + "d=sys.argv[1]; old=sys.argv[2]; out=[]\n"
      // the old place (folio's data directory) emptied into the new once
      + "if os.path.isdir(old):\n"
      + "  os.makedirs(d,exist_ok=True)\n"
      + "  for f in os.listdir(old):\n"
      + "    if not os.path.exists(os.path.join(d,f)): shutil.move(os.path.join(old,f),os.path.join(d,f))\n"
      + "  try: os.rmdir(old)\n"
      + "  except OSError: pass\n"
      + "if os.path.isdir(d):\n"
      + "  for f in sorted(os.listdir(d)):\n"
      + "    p=os.path.join(d,f)\n"
      + "    if f.endswith('.txt') and os.path.isfile(p):\n"
      + "      out.append({'name':f[:-4],'path':p,'text':open(p,encoding='utf-8',errors='replace').read().rstrip('\\n')})\n"
      + "print(json.dumps(out))", Folio.snippetDir(), Folio.oldSnippetDir()];
    snipList.running = true;
  }
  Process {
    id: snipList
    stdout: StdioCollector {
      id: snipOut
      waitForEnd: true
      onStreamFinished: {
        popup.snippets = Folio.parseSnippets(snipOut.text);
        if (popup.mode === "snip") popup.applyFilter();
        if (popup.selectAfterLoad !== "") {
          const at = popup.rows.findIndex((r) => r.snip && r.preview === popup.selectAfterLoad);
          popup.selectAfterLoad = "";
          if (at >= 0) { popup.sel = at; popup.followSelection(); }
        }
      }
    }
  }
  // A CLIP'S OWN TEXT. A row's `content` is cliphist's list preview, which
  // folds every run of spaces and line breaks into one space: kept as a
  // snippet or filled into {clipboard}, a block of lines came out as one
  // (audit 10-31). Decoded, one process per ask.
  Component {
    id: decoder
    Process {
      id: dec
      property var done: null
      running: true
      stdout: StdioCollector {
        id: decOut
        waitForEnd: true
        onStreamFinished: if (dec.done) dec.done(decOut.text)
      }
      onExited: dec.destroy()
    }
  }
  function decodeText(id, fn) {
    decoder.createObject(popup, { done: fn,
      command: ["sh", "-c", "printf '%s' " + Strings.shellQuote(id) + " | cliphist decode"] });
  }
  // what was copied last, for {clipboard}
  function lastClipThen(fn) {
    if (popup.entries.length === 0) { fn(""); return; }
    popup.decodeText(popup.entries[0].id, fn);
  }
  // a file written whole (beside it, then moved over it); `was`, when it is
  // another path, is the old name of a snippet renamed, and goes
  function writeSnippet(name, text, was) {
    const path = Folio.snippetDir() + "/" + name + ".txt";
    Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1.part\""
      + " && mv -f \"$1.part\" \"$1\" && { [ -z \"$3\" ] || [ \"$3\" = \"$1\" ] || rm -f \"$3\"; }",
      "sh", path, text, was || ""]);
    snipReload.restart();
    return path;
  }
  Timer { id: snipReload; interval: 300; onTriggered: popup.loadSnippets() }
  // a word in the hint strip's place for a moment (HintBar's note)
  property string note: ""
  function flash(t) { popup.note = t; noteTimer.restart(); }
  Timer { id: noteTimer; interval: 2400; onTriggered: popup.note = "" }
  function newSnippet() {
    if (popup.editing) return;
    popup.beginEdit("", "", "");
  }
  // the text clip under the cursor, kept
  function keepAsSnippet() {
    if (popup.mode !== "text" || popup.rows.length === 0) return;
    popup.decodeText(popup.rows[popup.sel].id, (text) => {
      if (text === "") return;
      const name = Folio.snippetName(text, popup.snippets.map((s) => s.name));
      popup.writeSnippet(name, text, "");
      popup.flash("Kept as \u201C" + name + "\u201D \u2014 tab to snippets");
    });
  }
  function editSnippet() {
    if (popup.editing || popup.mode !== "snip" || popup.rows.length === 0) return;
    const r = popup.rows[popup.sel];
    popup.beginEdit(r.path, r.preview, r.content);
  }
  // ── THE PAGE ──────────────────────────────────────────────────────────
  // Into the page: the list fades out under it and the panel takes the
  // page's size, as it takes any mode's. The caret goes to the text, or to
  // the name when there is none yet to keep.
  function beginEdit(path, name, text) {
    rowFlash.cancel();
    popup.editPath = path;
    snipName.text = name;
    page.edit.text = text;
    popup.mode = "snip";
    popup.editing = true;
    Qt.callLater(() => {
      page.edit.cursorPosition = page.edit.length;
      page.edit.forceActiveFocus();
    });
  }
  // back to the list, the filter holding the keyboard again
  function endEdit() {
    popup.editing = false;
    popup.editPath = "";
    if (!popup.embedded) filter.forceActiveFocus();
  }
  // Saved under the name typed, or under its first words when none was.
  // A name another snippet already has is refused in the hint strip's
  // place rather than written over it.
  function saveEdit() {
    const text = page.edit.text.replace(/\n+$/, "");
    const was = popup.editPath;
    const others = popup.snippets.filter((x) => x.path !== was).map((x) => x.name);
    const name = Folio.snippetFileName(snipName.text) || Folio.snippetName(text, others);
    if (others.some((n) => n.toLowerCase() === name.toLowerCase())) {
      popup.flash("A snippet is already called \u201C" + name + "\u201D");
      snipName.forceActiveFocus();
      return;
    }
    popup.writeSnippet(name, text, was);
    popup.endEdit();
    popup.flash(was === "" ? "Saved \u201C" + name + "\u201D" : "Saved");
    // the cursor on it once the listing is back
    popup.selectAfterLoad = name;
  }
  function cancelEdit() { popup.endEdit(); }
  property string selectAfterLoad: ""
  // the keys both of the page's fields answer the same way
  function editKey(e) {
    const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
    if (e.key === Qt.Key_Escape) { e.accepted = true; popup.cancelEdit(); }
    else if (ctrl && e.key === Qt.Key_S) { e.accepted = true; popup.saveEdit(); }
  }
  function closePopup() {
    if (popup.closing) return;
    popup.closing = true;
    rowFlash.cancel();
    popup.dismissed();
  }
  function goBack() { popup.backed(); }

  function reload() {
    RunJob.latest(listProc, { command: ["cliphist", "-preview-width", "10000", "list"] });
  }

  function onList(text) {
    const parsed = Folio.parseList(text);
    popup.listed = parsed.entries;
    popup.entries = Folio.withNames(parsed.entries, popup.names);
    popup.imageIds = parsed.imageIds;
    popup.hasText = parsed.entries.length > 0;
    popup.hasImg = parsed.imageIds.length > 0;

    if (popup.mode === "text" && !popup.hasText && popup.hasImg) popup.mode = "image";
    else if (popup.mode === "image" && !popup.hasImg && popup.hasText) popup.mode = "text";
    else if (popup.mode !== "snip" && !popup.hasText && !popup.hasImg && popup.snippets.length > 0) popup.mode = "snip";

    popup.rebuildImageRows();
    popup.applyFilter();
    popup.generateThumbs();
    popup.clampSel();
  }

  function rebuildImageRows() {
    const tdir = Folio.thumbDir();
    const arr = [];
    for (let i = 0; i < popup.imageIds.length; ++i) {
      arr.push({ id: popup.imageIds[i], path: tdir + "/" + popup.imageIds[i] + ".png" });
    }
    popup.imgRows = arr;
  }

  function applyFilter() {
    popup.rows = popup.mode === "snip" ? Folio.snippetRows(popup.snippets, popup.query)
      : Folio.filterEntries(popup.entries, popup.query);
    popup.clampSel();
  }

  function generateThumbs() {
    // asked again mid-run: once it is done, for the pictures that came since
    if (thumbProc.running) { popup.thumbsAgain = true; return; }
    const cmd = Folio.thumbCommand(popup.imageIds, Folio.thumbDir());
    if (!cmd) return;
    thumbProc.command = ["sh", "-c", cmd];
    thumbProc.running = true;
  }

property bool thumbsAgain: false
function onThumbsDone() {
  if (popup.thumbsAgain) { popup.thumbsAgain = false; Qt.callLater(popup.generateThumbs); }

  const ready = {};
  for (const r of popup.imgRows) ready[r.id] = true;
  popup.thumbsReady = ready;
  popup.thumbStamp++;
  popup.followSelection();
}

  function runAction(cmd, kind) {
    RunJob.queued(actionProc, { kind: kind, command: ["sh", "-c", cmd] });
  }

  function onActionDone(kind) {
    // a copy leaves the panel open for the next one (user, 2026-11-08); the
    // list read again, since the copied clip is now the newest
    if (kind === "delete") popup.reload();
    else if (kind === "copy") { popup.flash("Copied"); popup.reload(); }
    else popup.closePopup();
  }

  // ── THE ROW FLASHES, THEN IT PASTES (user, 2026-10-21) ────────────────
  // The suite's two flashes: terminus' RowFlash on the text and snippet
  // rows (a list), ChosenFlash in the picture's own cell (a grid, as
  // icarus' Home cards). The choice is taken now, not read at the tail.
  RowFlash { id: rowFlash }
  function confirm() {
    if (popup.rowCount() === 0 || rowFlash.running) return;
    const i = popup.sel, mode = popup.mode;
    const act = () => { if (popup.mode === mode && popup.sel === i) popup.confirmNow(); };
    if (mode === "image") {
      Nav.fireCell(imgGrid.itemAtIndex(i), act);
      return;
    }
    rowFlash.flashThen(i, act);
  }
  function confirmNow() {
    const len = popup.mode === "image" ? popup.imgRows.length : popup.rows.length;
    if (len === 0) return;
    if (popup.mode === "snip") {
      // filled in now, onto the clipboard as any copy is (and into its
      // history); the panel stays, as it does for every copy
      const snip = String(popup.rows[popup.sel].content || "");
      const put = (clip) => {
        const text = Folio.expandSnippet(snip, new Date(), clip);
        popup.runAction("printf '%s' " + Strings.shellQuote(text) + " | wl-copy", "copy");
      };
      if (snip.indexOf("{clipboard}") >= 0) popup.lastClipThen(put); else put("");
      return;
    }
    const id = popup.mode === "image"
      ? popup.imgRows[popup.sel].id
      : popup.rows[popup.sel].id;
    popup.carryStamp = popup.stamps[id] !== undefined ? popup.stamps[id] : null;
    popup.runAction(Folio.copyCommand(id), "copy");
  }

  // ── WHAT CYNOSURE'S ROWS DO ───────────────────────────────────────────
  // The same actions as this panel's own rows, by id rather than by cursor.
  // A copy leaves the panel open (onActionDone).
  function takeClip(id) {
    popup.carryStamp = popup.stamps[id] !== undefined ? popup.stamps[id] : null;
    popup.runAction(Folio.copyCommand(id), "copy");
  }
  function takeSnippet(content) {
    const snip = String(content || "");
    const put = (clip) => {
      const text = Folio.expandSnippet(snip, new Date(), clip);
      popup.runAction("printf '%s' " + Strings.shellQuote(text) + " | wl-copy", "copy");
    };
    if (snip.indexOf("{clipboard}") >= 0) popup.lastClipThen(put); else put("");
  }
  // typed into the window that had the keyboard, the caret put back at
  // {cursor} (2026-11-01): after the panel has gone, so the keys land there
  function pasteSnippet(content) {
    const snip = String(content || "");
    const put = (clip) => {
      const x = Folio.expandSnippetAt(snip, new Date(), clip);
      popup.closePopup();
      Quickshell.execDetached(["sh", "-c", Folio.pasteSnippetCommand(x.text, x.back)]);
    };
    if (snip.indexOf("{clipboard}") >= 0) popup.lastClipThen(put); else put("");
  }
  function dropClip(id) {
    popup.runAction(Folio.deleteCommand(id, Folio.thumbDir()), "delete");
  }
  function dropSnippet(path) {
    // to the trash, not gone: a snippet is something you wrote
    Quickshell.execDetached(["gio", "trash", path]);
    snipReload.restart();
  }
  function keepClip(id) {
    popup.decodeText(id, (text) => {
      if (text === "") return;
      const name = Folio.snippetName(text, popup.snippets.map((s) => s.name));
      popup.writeSnippet(name, text, "");
      popup.flash("Kept as \u201C" + name + "\u201D");
    });
  }
  // the picture as a file (as a drag writes it), shown in picasso's viewer
  function viewClip(id) {
    popup.dragDecode(id, (f) => {
      if (f === "") return;
      Quickshell.execDetached(["qs", "ipc", "call", "Picasso", "view", f]);
      popup.closePopup();
    });
  }
  // the picture kept in Pictures, under when it was saved
  function saveClip(id) {
    popup.dragDecode(id, (f) => {
      if (f === "") return;
      const d = new Date();
      const two = (n) => (n < 10 ? "0" : "") + n;
      const name = "Clipboard " + d.getFullYear() + "-" + two(d.getMonth() + 1) + "-" + two(d.getDate())
        + " " + two(d.getHours()) + "." + two(d.getMinutes()) + "." + two(d.getSeconds()) + ".png";
      Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && cp -- \"$2\" \"$1/$3\"", "folio",
        UserDirs.pictures, f, name]);
      popup.flash("Saved to Pictures");
    });
  }
  function annotateClip(id) {
    popup.dragDecode(id, (f) => {
      if (f === "") return;
      Picasso.annotate(f);
      popup.closePopup();
    });
  }
  // the page, for a snippet ("" path: a new one)
  function editSnippetAt(path, name, text) {
    popup.beginEdit(path || "", name || "", text || "");
  }
  function stampText(id) { return popup.stampOf(id); }

  // Into picasso's annotation window rather than an image viewer: a clip is
  // most often a screenshot, and what you want next is to mark it up. The
  // original is written out the way a drag writes it — see
  // Folio.dragFileCommand — and handed over once it exists.
  function annotateSelected() {
    if (popup.mode !== "image" || popup.imgRows.length === 0) return;
    popup.dragDecode(popup.imgRows[popup.sel].id, (f) => {
      if (f === "") return;
      Picasso.annotate(f);
      popup.closePopup();
    });
  }

  function deleteSelected() {
    const len = popup.mode === "image" ? popup.imgRows.length : popup.rows.length;
    if (len === 0) return;
    if (popup.mode === "snip") {
      // to the trash, not gone: a snippet is something you wrote
      Quickshell.execDetached(["gio", "trash", popup.rows[popup.sel].path]);
      snipReload.restart();
      return;
    }
    const id = popup.mode === "image"
      ? popup.imgRows[popup.sel].id
      : popup.rows[popup.sel].id;
    popup.runAction(Folio.deleteCommand(id, Folio.thumbDir()), "delete");
  }

  function toggleMode() {
    // text → pictures → snippets, skipping a side with nothing on it;
    // snippets are always there to go to (to make the first one)
    const order = ["text", "image", "snip"].filter((m) => m === "snip" || (m === "text" ? popup.hasText : popup.hasImg));
    const target = order[(order.indexOf(popup.mode) + 1) % order.length];
    if (!target || popup.mode === target) return;
    popup.mode = target;
    popup.query = "";
    filter.text = "";
    popup.sel = 0;
    popup.applyFilter();
    popup.followSelection();
    focusRetry.restart();
  }

  function rowCount() {
    return popup.mode === "image" ? popup.imgRows.length : popup.rows.length;
  }

  function moveVert(delta) {
    const len = popup.rowCount();
    if (len === 0) return;
    popup.sel = Nav.vert(popup.sel, delta, len, popup.mode === "image" ? popup.imgPerRow : 1);
    popup.followSelection();
  }

  function moveHoriz(delta) {
    const len = popup.rowCount();
    if (len === 0) return;
    popup.sel = Nav.horiz(popup.sel, delta, len, popup.mode === "image" ? popup.imgPerRow : 1);
    popup.followSelection();
  }

  function pageMove(delta) {
    const len = popup.rowCount();
    if (len === 0) return;

    const page = popup.mode === "image"
      ? popup.imgPerRow * popup.imgRowsVisible
      : popup.textRowsNeeded;
    popup.sel = Math.max(0, Math.min(len - 1, popup.sel + delta * page));
    popup.followSelection();
  }

  function goHome() {
    if (popup.rowCount() > 0) popup.sel = 0;
    popup.followSelection();
  }

  function goEnd() {
    const len = popup.rowCount();
    if (len > 0) popup.sel = len - 1;
    popup.followSelection();
  }

  function clampSel() {
    popup.sel = Nav.clamp(popup.sel, popup.rowCount());
    popup.followSelection();
  }

  function followSelection() {
    Qt.callLater(() => {
      textGrid.positionViewAtIndex(popup.sel, ListView.Contain);
      imgGrid.positionViewAtIndex(popup.sel, ListView.Contain);
    });
  }

  // ── WHAT YOU ARE CARRYING, DRAWN BESIDE THE CURSOR ────────────────────
  // Without it a drag out of here is an invisible one: the popup gets out of
  // the way the moment the gesture starts, so between picking an entry up and
  // dropping it there is nothing on screen saying which entry it was.
  // The suite's card — terminus/DragCard.qml.
  DragCard { id: dragCard }

  // The picture is made BEFORE the drag is offered: Drag.imageSource is read
  // when Drag.active turns true and grabToImage answers a frame later, so
  // setting them the other way round makes every drag carry the previous
  // one's picture.
  // `thumb`, when given, rides in the glyph's place — a picture of the
  // picture, as picasso's drags carry.
  function dragPicture(label, glyph, ink, then, thumb) {
    dragCard.label = label;
    dragCard.glyph = glyph;
    dragCard.ink = ink;
    dragCard.thumb = thumb || "";
    dragCard.picture(then);
  }

  // The original behind a thumbnail, written out so it can be handed over —
  // see Folio.dragFileCommand. Asynchronous, like the grab above, so the
  // drag is offered from the callback rather than before it.
  // the newest ask wins, its callback carried on its own job: one shared
  // `dragThen` handed the earlier run's file to the newer callback (Save,
  // Annotate, the preview got the wrong picture; audit 2026-11-09)
  Process {
    id: dragProc
    property var job: null
    property var want: null
    onExited: RunJob.next(dragProc)
    stdout: StdioCollector {
      id: dragOut
      waitForEnd: true
      onStreamFinished: {
        if (!RunJob.current(dragProc)) return;
        const f = String(dragOut.text || "").trim();
        const then = dragProc.job.then;
        if (then) then(f);
      }
    }
  }

  function dragDecode(id, then) {
    RunJob.latest(dragProc, { then: then, command: ["sh", "-c", Folio.dragFileCommand(id, Folio.openDir())] });
  }


  // shell.qml sizes the morphed pill from this; without it the pill fell back
  // to a hardcoded 320px and the panel floated free of its own background
  function calcHeight() {
    return popup.bodyH;
  }

  Item {
    id: panel
    anchors.fill: parent

    // ClippingRectangle, not Rectangle + clip: true. Qt's own clip is
    // RECTANGULAR — it clips to the bounding box and knows nothing about the
    // radius — so every square child painted to the panel's edge (the bottom
    // strip most visibly) filled in the rounded corners behind it. This one
    // clips to the rounded shape itself.

    ClippingRectangle {
      id: bg
      anchors.fill: parent
      // Grown by its own border: a ClippingRectangle insets its children by
      // border.width on every side, so the content box came out 2px smaller
      // than the panel and any layout measured against the panel's size fell
      // one row or one column short. This hands the content its full box back.
      anchors.margins: -bg.border.width
      color: popup.bgColor
      radius: Zenon.pillRadius
      topLeftRadius: Zenon.pillRadius
      topRightRadius: Zenon.pillRadius
      bottomLeftRadius: Zenon.pillRadius
      bottomRightRadius: Zenon.pillRadius
      border.color: Zenon.border
      border.width: 1
      // the list's keys, not the page's: a key the page's text did not
      // take climbs up to here, and ctrl n or delete would act on the list
      Keys.enabled: !popup.editing

      // the entries still below rise out of the hint strip, frosted — see
      // morpheus/ScrollEdge. One per pane, sliding and fading with it.
      Repeater {
        model: [{ v: textGrid, pane: textPane }, { v: imgGrid, pane: imgPane }]
        delegate: ScrollEdge {
          required property var modelData
          view: modelData.v
          below: true
          bar: msgBar
          opacity: modelData.pane.opacity
          x: body.x + modelData.pane.x + modelData.v.x
          y: msgBar.y
          width: modelData.v.width
          height: msgBar.height
        }
      }

      Column {
      anchors.fill: parent

      Item {
        id: body
        width: parent.width
        height: parent.height - msgBar.height

          EmptyState {
            id: emptyLabel
            anchors.centerIn: parent
            text: popup.mode === "snip" ? "No snippets yet \u2014 ctrl n writes one, ctrl s keeps a copied text as one"
              : "No clipboard entries"
            // THE MODE ON SCREEN, not the clipboard as a whole. This asked
            // whether BOTH sides were empty, so an image mode emptied down
            // to nothing said nothing at all while text entries existed one
            // Tab away — and the panel that had just answered `delete` went
            // blank rather than telling you it was done.
            visible: popup.shown && popup.modeEmpty && !popup.editing
          }

          EmptyState {
            anchors.centerIn: parent
            filtered: popup.query !== ""
            text: popup.query !== "" ? "Nothing matches \u201C" + popup.query + "\u201D" : "Nothing here"
            visible: popup.shown && popup.rows.length === 0 && !popup.editing
              && ((popup.mode === "text" && popup.hasText) || (popup.mode === "snip" && popup.snippets.length > 0))
          }

        Item {
          id: textPane
          anchors.fill: parent
          visible: opacity > 0.01
          opacity: !popup.editing && (popup.mode === "text" || popup.mode === "snip") ? 1 : 0
          x: popup.editing ? -24 : popup.mode === "text" || popup.mode === "snip" ? 0 : -24
          Behavior on opacity { NumberAnimation { duration: Zenon.normal; easing.type: Zenon.ease } }
          Behavior on x { NumberAnimation { duration: Zenon.normal; easing.type: Zenon.ease } }

          GridView {
            id: textGrid
            // Finder's rubber band and the smooth wheel notch, one rule for
            // the whole shell — see morpheus/Elastic.qml. Inside the view
            // rather than over it: it pins itself to the viewport.
            ElasticScroll { view: textGrid }
            // the chosen one slides (morpheus/CursorBand), rather than each row lighting (user, 2026-10-19: text mode jumped)
            CursorBand { follows: textGrid; index: popup.sel }
            anchors.fill: parent
            clip: true
            flow: GridView.FlowLeftToRight
            cellWidth: textGrid.width
            cellHeight: popup.textCellHeight
            model: popup.rows
            highlightMoveDuration: 120

            delegate: Item {
              id: textRow
              required property var modelData
              required property int index
              width: textGrid.cellWidth
              height: textGrid.cellHeight
              FlashOver { flash: rowFlash; index: textRow.index }

              // ── ARRIVING ONE AFTER ANOTHER ─────────────────────────────
              // When the panel opens, each of the first eight rows fades in
              // and rises a few pixels, Zenon.stagger after the one before.
              property real enter: 1
              opacity: textRow.enter
              transform: Translate { y: (1 - textRow.enter) * 6 }
              Connections {
                target: popup
                function onOpenedChanged() {
                  if (textRow.index > 7 || Zenon.stagger === 0) return;
                  textRow.enter = 0;
                  textRowArrive.restart();
                }
              }
              SequentialAnimation {
                id: textRowArrive
                PauseAnimation { duration: textRow.index * Zenon.stagger }
                NumberAnimation {
                  target: textRow; property: "enter"; to: 1
                  duration: Zenon.normal; easing.type: Zenon.ease
                }
              }

              // The WHOLE entry, not the preview the cell shows — the preview
              // is trimmed and marked up for reading in a narrow cell, and
              // what the other application wants is what was copied.
              //
              // Drag.active is never bound: a binding starts the drag the
              // instant the handler activates, which is a frame before
              // grabToImage can answer, so the card would always be empty.
              Drag.active: false
              Drag.source: textRow
              Drag.keys: ["text/plain"]
              Drag.mimeData: ({ "text/plain": String(textRow.modelData.content || "") })
              Drag.supportedActions: Qt.CopyAction
              Drag.dragType: Drag.Automatic
              Drag.hotSpot.x: 0
              Drag.hotSpot.y: 0
              Drag.onDragFinished: function(dropAction) {
                textRow.Drag.active = false;
                popup.dragging = false;
                if (dropAction === Qt.CopyAction) popup.closePopup();
              }

              DragHandler {
                target: null
                onActiveChanged: {
                  if (!active) return;
                  // region first, so the surface is already transparent by
                  // the time the drag is offered
                  popup.dragging = true;
                  const go = function(text) {
                    textRow.Drag.mimeData = { "text/plain": text };
                    // a clip that is one file's path carries that file's
                    // glyph from the map, as Terminus shows it (2026-11-05)
                    const fp = textRow.modelData.snip ? null : Folio.clipPath(text);
                    popup.dragPicture(Folio.plain(textRow.modelData.preview),
                                      (fp ? Icons.glyphFor({ name: fp.name, isDir: fp.isDir,
                                        path: fp.path.replace(/^~(?=\/|$)/, Quickshell.env("HOME")) }) : "") || "\uF0F6",
                                      Zenon.accent, function(url) {
                      textRow.Drag.imageSource = url;
                      textRow.Drag.active = true;
                    });
                  };
                  // a clip's row is cliphist's folded preview: what is carried
                  // is the clip itself, decoded first (audit 10-31); a
                  // snippet's text is its file's already
                  if (textRow.modelData.snip) go(String(textRow.modelData.content || ""));
                  else popup.decodeText(textRow.modelData.id, function(t) {
                    if (!popup.dragging) return;
                    go(t !== "" ? t : String(textRow.modelData.content || ""));
                  });
                }
              }


              // A clip that is a color wears it (2026-10-22): every color
              // copied, the picker's included, is a palette to take again
              readonly property string swatch: textRow.modelData.snip ? ""
                : Cap.colorOfText(textRow.modelData.content)
              Rectangle {
                id: swatchChip
                visible: textRow.swatch !== ""
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: Zenon.radiusControl
                color: textRow.swatch !== "" ? textRow.swatch : "transparent"
                border.width: 1
                border.color: Zenon.wash(0.14)
              }

              Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: swatchChip.visible ? 16 + swatchChip.width + 12 : 16
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                  width: parent.width
                  text: popup.cellText(modelData.name || modelData.preview)
                  color: popup.fgColor
                  textFormat: Text.RichText
                  font.family: Zenon.face
                  font.weight: Zenon.titleWeight
                  font.pixelSize: Zenon.px(16)
                  clip: true
                  wrapMode: Text.NoWrap
                }

                Text {
                  width: parent.width
                  // a snippet's own text under its name; a clip's time
                  text: modelData.snip ? modelData.sub : popup.stampOf(modelData.id)
                  textFormat: Text.PlainText
                  color: popup.hintColor
                  font.family: Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(12)
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                // ONE CLICK PICKS, TWO COMMIT. A single click used to paste
                // and close, which cannot coexist with dragging an entry out
                // — every drag begins with a press on the thing being
                // dragged, and the release that ends it read as a click. It
                // also made the most destructive gesture here the cheapest
                // one: a mis-click pasted into whatever had focus.
                onClicked: popup.sel = index
                onDoubleClicked: {
                  popup.sel = index;
                  popup.confirm();
                }
              }
            }
          }

          // A SIBLING OF THE VIEW, never a child of it — inside, it becomes
          // part of the scrolling content: it travels with the cells and its
          // anchors resolve against the content item, which is as tall as the
          // whole list. It hides itself when everything fits.
          Scrollbar {
            id: textBar
            flick: textGrid
            anchors.right: textGrid.right
            anchors.top: textGrid.top
            anchors.bottom: textGrid.bottom
          }
        }

        Item {
          id: imgPane
          anchors.fill: parent
          visible: opacity > 0.01
          opacity: !popup.editing && popup.mode === "image" ? 1 : 0
          x: !popup.editing && popup.mode === "image" ? 0 : 24
          Behavior on opacity { NumberAnimation { duration: Zenon.normal; easing.type: Zenon.ease } }
          Behavior on x { NumberAnimation { duration: Zenon.normal; easing.type: Zenon.ease } }

          GridView {
            id: imgGrid
            // Finder's rubber band and the smooth wheel notch, one rule for
            // the whole shell — see morpheus/Elastic.qml. Inside the view
            // rather than over it: it pins itself to the viewport.
            ElasticScroll { view: imgGrid }
            // CENTERED AT ITS OWN WIDTH, not filling the pane. The panel is a
            // whole number of tiles wide except when the minimum floor is
            // holding it open — one or two pictures — and then the leftover
            // belongs on both sides of them rather than all of it on the
            // right. Plain x, because anchors.horizontalCenter here would be
            // a third opinion on a pane that already sets its own x.
            width: popup.imgPerRow * popup.imgCell
            x: Math.round((imgPane.width - imgGrid.width) / 2)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true
            flow: GridView.FlowLeftToRight
            cellWidth: popup.imgCell
            cellHeight: popup.imgCellH
            model: popup.imgRows
            highlightMoveDuration: 120

            delegate: Item {
              id: imgRow
              required property var modelData
              required property int index
              width: imgGrid.cellWidth
              height: imgGrid.cellHeight
              // inside SelectCell's 4px inset, so it lights the cursor's box
              readonly property alias flash: cellFlash
              ChosenFlash { id: cellFlash; anchors.margins: 4 }

              // ── ARRIVING ONE AFTER ANOTHER ─────────────────────────────
              // When the panel opens, each of the first eight rows fades in
              // and rises a few pixels, Zenon.stagger after the one before.
              property real enter: 1
              opacity: imgRow.enter
              transform: Translate { y: (1 - imgRow.enter) * 6 }
              Connections {
                target: popup
                function onOpenedChanged() {
                  if (imgRow.index > 7 || Zenon.stagger === 0) return;
                  imgRow.enter = 0;
                  imgRowArrive.restart();
                }
              }
              SequentialAnimation {
                id: imgRowArrive
                PauseAnimation { duration: imgRow.index * Zenon.stagger }
                NumberAnimation {
                  target: imgRow; property: "enter"; to: 1
                  duration: Zenon.normal; easing.type: Zenon.ease
                }
              }

              // A FILE, and the real one rather than the thumbnail this cell
              // is drawing — see Folio.dragFileCommand. The mime data cannot
              // be written until that file exists, so unlike the text rows
              // above it is filled in from the decode's callback.
              Drag.active: false
              Drag.source: imgRow
              Drag.keys: ["text/uri-list"]
              Drag.supportedActions: Qt.CopyAction
              Drag.dragType: Drag.Automatic
              // on the card's leading edge, as terminus' rows hold it
              Drag.hotSpot.x: 16
              Drag.hotSpot.y: 19
              Drag.onDragFinished: function(dropAction) {
                imgRow.Drag.active = false;
                popup.dragging = false;
                if (dropAction === Qt.CopyAction) popup.closePopup();
              }

              DragHandler {
                target: null
                onActiveChanged: {
                  if (!active) return;
                  popup.dragging = true;
                  popup.dragDecode(imgRow.modelData.id, function(file) {
                    // Nothing decoded means nothing to carry: let go of the
                    // surface again rather than offering an empty drag.
                    if (file === "") { popup.dragging = false; return; }
                    imgRow.Drag.mimeData = {
                      "text/uri-list": Strings.fileUrl(file) + "\r\n"
                    };
                    popup.dragPicture(Folio.baseName(file), "\uF03E",
                                      Zenon.accent, function(url) {
                      imgRow.Drag.imageSource = url;
                      imgRow.Drag.active = true;
                    }, popup.thumbsReady[imgRow.modelData.id]
                       ? "file://" + imgRow.modelData.path : "");
                  });
                }
              }

              // NO PER-CELL OUTLINE: the cursor is terminus' SelectCell,
              // one box behind the tiles that slides between them (below).
              // The picture sits inside that box's 4px inset with room to
              // spare, so the box shows as a frame around it.
              Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: imgStamp.top
                anchors.margins: 10
                anchors.bottomMargin: 2

                Image {
                  anchors.fill: parent
                  source: popup.thumbsReady[modelData.id]
                    ? "file://" + modelData.path + "?v=" + popup.thumbStamp
                    : ""
                  asynchronous: true
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: popup.imgCell
                  sourceSize.height: popup.imgCell
                }
              }

              Text {
                id: imgStamp
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                horizontalAlignment: Text.AlignHCenter
                text: popup.stampOf(imgRow.modelData.id)
                color: popup.hintColor
                font.family: Zenon.face
                font.weight: Zenon.weight
                font.pixelSize: Zenon.px(12)
                elide: Text.ElideRight
              }

              MouseArea {
                anchors.fill: parent
                // ONE CLICK PICKS, TWO COMMIT. A single click used to paste
                // and close, which cannot coexist with dragging an entry out
                // — every drag begins with a press on the thing being
                // dragged, and the release that ends it read as a click. It
                // also made the most destructive gesture here the cheapest
                // one: a mis-click pasted into whatever had focus.
                onClicked: popup.sel = index
                onDoubleClicked: {
                  popup.sel = index;
                  popup.confirm();
                }
              }
            }
          }

          // Terminus' grid cursor — see terminus/SelectCell.qml. It parents
          // itself to the view and works out the columns from its width.
          SelectCell {
            view: imgGrid
            index: popup.sel
            on: popup.mode === "image"
            // the menu cursor, in the theme's accent (Zenon.menuHi)
            fill: Zenon.menuHi
          }

          // A SIBLING OF THE VIEW, never a child of it — inside, it becomes
          // part of the scrolling content: it travels with the cells and its
          // anchors resolve against the content item, which is as tall as the
          // whole list. It hides itself when everything fits.
          Scrollbar {
            flick: imgGrid
            // the pane's edge: the grid is centered at its own width
            anchors.right: parent.right
            anchors.top: imgGrid.top
            anchors.bottom: imgGrid.bottom
          }
        }

        // ── THE PAGE (see beginEdit) ──────────────────────────────────
        // The name on a line of its own, the sticky's page under it, and
        // Cancel and Save at the bottom right, Cancel left of the verb.
        Item {
          id: editPane
          anchors.fill: parent
          visible: opacity > 0.01
          opacity: popup.editing ? 1 : 0
          x: popup.editing ? 0 : 24
          Behavior on opacity { NumberAnimation { duration: Zenon.normal; easing.type: Zenon.ease } }
          Behavior on x { NumberAnimation { duration: Zenon.normal; easing.type: Zenon.ease } }

          TextInput {
            id: snipName
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 28
            verticalAlignment: TextInput.AlignVCenter
            enabled: popup.editing
            color: popup.fgColor
            selectionColor: Zenon.textSel
            selectByMouse: true
            clip: true
            font.family: Zenon.face
            font.weight: Zenon.titleWeight
            font.pixelSize: Zenon.px(16)
            cursorDelegate: Caret { field: snipName }
            Keys.onPressed: (e) => {
              popup.editKey(e);
              if (e.accepted) return;
              if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Tab
                  || e.key === Qt.Key_Down) {
                e.accepted = true;
                page.edit.forceActiveFocus();
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: snipName.text === ""
              text: "Name \u2014 its first words if left blank"
              color: Zenon.wash(0.35)
              font: snipName.font
            }
          }

          Rectangle {
            id: nameRule
            anchors.top: snipName.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Zenon.border
          }

          Item {
            anchors.top: nameRule.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: editButtons.top
            anchors.bottomMargin: 6

            NoteField {
              id: page
              rich: false
              ground: popup.bgColor
              inset: 16
              ghostFocused: true
              placeholder: "Text to paste again \u2014 {date} {time} {weekday} {clipboard} {uuid} {cursor} are filled in; {date +3d} moves the day"
              mgr: Clio.app
              spelling: popup.editing
              onKeyPressed: (e) => {
                popup.editKey(e);
                if (e.accepted) return;
                // up out of the first line, to the name
                if (e.key === Qt.Key_Backtab) {
                  e.accepted = true;
                  snipName.forceActiveFocus();
                }
              }
            }
          }

          // spelling, on or off: Clio's switch, so one answer everywhere (on
          // by default — user, 2026-10-25)
          ClioTool {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: editButtons.verticalCenter
            word: "\u{F04C6}  Spelling"
            wordPx: Zenon.px(13)
            wordWeight: Zenon.titleWeight
            pad: 16
            lit: !!Clio.app && Clio.app.spellOn
            litInk: Zenon.accent
            enabled: !!Clio.app && popup.editing
            onPressed: Clio.app.setSpellOn(!Clio.app.spellOn)
          }
          Row {
            id: editButtons
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 16
            anchors.bottomMargin: 12
            spacing: Zenon.buttonGap
            DialogButton { label: "Cancel"; onClicked: popup.cancelEdit() }
            DialogButton { label: "Save"; primary: true; onClicked: popup.saveEdit() }
          }
        }
      }

      // morpheus/HintBar, as every strip (ceres' height, ground and rule)
      HintBar {
        id: msgBar
        visible: !popup.embedded
        height: popup.msgH
        width: parent.width
        rows: Folio.hintText(popup.editing ? "edit" : popup.mode)
        note: popup.note
      }
    }

    TextInput {
      id: filter

      cursorDelegate: Caret { field: filter }
      width: 1
      height: 1
      x: -1
      y: -1
      opacity: 0
      focus: true
      color: "transparent"
      Keys.forwardTo: bg
      onTextChanged: {
        if (popup.mode === "text" || popup.mode === "snip") {
          popup.query = filter.text;
          popup.sel = 0;
          popup.applyFilter();
        }
      }
    }

    Keys.onEscapePressed: (event) => {
      // Cynosure's one rule (2026-11-01): esc clears the line, then closes
      event.accepted = true;
      if (filter.text !== "") {
        filter.text = "";
        popup.query = "";
      } else {
        popup.closePopup();
      }
    }

    Keys.onReturnPressed: (event) => {
      event.accepted = true;
      if (event.modifiers & Qt.ShiftModifier) popup.annotateSelected();
      else popup.confirm();
    }

    Keys.onTabPressed: (event) => {
      event.accepted = true;
      popup.toggleMode();
    }

    Keys.onBacktabPressed: (event) => {
      event.accepted = true;
      popup.toggleMode();
    }

    Keys.onLeftPressed: (event) => { event.accepted = true; popup.moveHoriz(-1); }
    Keys.onRightPressed: (event) => { event.accepted = true; popup.moveHoriz(1); }
    Keys.onUpPressed: (event) => { event.accepted = true; popup.moveVert(-1); }
    Keys.onDownPressed: (event) => { event.accepted = true; popup.moveVert(1); }

    Keys.onPressed: (event) => {
      const ctrl = event.modifiers & Qt.ControlModifier;
      if (ctrl && event.key === Qt.Key_N) { event.accepted = true; popup.newSnippet(); return; }
      if (ctrl && event.key === Qt.Key_S) { event.accepted = true; popup.keepAsSnippet(); return; }
      if (ctrl && event.key === Qt.Key_E) { event.accepted = true; popup.editSnippet(); return; }
      if (event.key === Qt.Key_Delete) {
        event.accepted = true;
        popup.deleteSelected();
      } else if (event.key === Qt.Key_Backspace) {
        event.accepted = true;
        if (filter.text.length > 0) {
          const chars = Array.from(filter.text);
          chars.pop();
          filter.text = chars.join("");
        } else {
          // an empty line: back to Cynosure's list
          popup.goBack();
        }
      } else if (event.key === Qt.Key_Home) {
        event.accepted = true;
        popup.goHome();
      } else if (event.key === Qt.Key_End) {
        event.accepted = true;
        popup.goEnd();
      } else if (event.key === Qt.Key_PageUp) {
        event.accepted = true;
        popup.pageMove(-1);
      } else if (event.key === Qt.Key_PageDown) {
        event.accepted = true;
        popup.pageMove(1);
      }
    }
    }
    }

  FocusRetry {
    id: focusRetry
    live: popup.shown && !popup.embedded
    took: filter.activeFocus
    onPlace: filter.forceActiveFocus()
  }
}
