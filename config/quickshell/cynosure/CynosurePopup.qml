// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// CYNOSURE — the launcher. Ursa Minor, and the star at the end of its tail
// that everything else in the sky turns around: what you look up to find
// your bearings. Super+Space, one field, and you are pointed at the thing you
// meant to open.
//
// EVERY QUICK PANEL, IN ONE (2026-11-01). It was a one-line strip that was
// the pill itself, with a popup of its own for each of the others; it is
// one panel now, out of the pill like every layer, with a field over a list
// in sections and the keys in a strip at its foot — and the others are in
// it, as Raycast has them:
//
//   Applications · Commands · Files · Clipboard · Snippets · Emoji ·
//   History · Run       the list; files from artemis' index (ArtemisIndex),
//                       clips and snippets from folio, emoji from ideo, each
//                       loaded unseen the first time the line could want it
//   a sum, "calc …"     metis takes the field: its own line, answer, chips
//                       and tape (MetisView)
//   "def …", "tr …"     lexi takes the field: the dictionary or translator
//   "pw …"              calypso's Quick Access takes the field
//   "f …", "cb …",      the list as only files, clips, emoji or glyphs
//   "em …", "nf …"
//
// What takes the field is drawn from the top of the panel, its keys its own
// and its hints in this strip; backspace at its empty line gives the field
// back. Esc clears the line, and on an empty one closes (user, 2026-11-01).
// Each app's part is still written once, in its own directory.
//
// A steady size while the list is up: a panel that changes shape as you
// type is one you cannot read while it is doing it.

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
// a library; its markup escaping is morpheus Strings'
import "cynosure.js" as Cynosure
import "folio/folio.js" as Folio
import "metis/metis.js" as Metis
import "answers.js" as Answers
import "../chronos/weather.js" as Wx
import "../chronos/chronos.js" as Chr
import "../morpheus/hypr.js" as Hypr
import "../morpheus/runjob.js" as RunJob
import "../oracle/oracle.js" as Ora
import "../morpheus/offspecial.js" as Off
import "../terminus/terminus.js" as Terminus
import "../terminus/network.js" as TermNet
import "../artemis/artemis.js" as Artemis
import "../hermes/hermes.js" as HermesJs
import "../morpheus/icons.js" as Icons
import "../morpheus"
import "../morpheus/gridnav.js" as Nav
import "../chronos"
import "../oracle"
import "../ceres"
import "../ceres/ceres.js" as Cer
import "../clio"
import "../hermes"
import "../howler"
import "../kairos"
import "../kairos/kairos.js" as KairosJs
import "../alexandria/alexandria.js" as Alex
import "../morpheus/thumbs.js" as Thumbs
// terminus' open-with card, for a file nothing opens
import "../terminus" as Term
// The directories of what this loads by Loader (metis, lexi, folio, ideo,
// calypso), imported by name: under quickshell's own scheme a directory's
// types are made only when something imports it, and a file loaded by URL
// out of one that nothing imports cannot find its siblings ("MetisTip is
// not a type", 2026-11-01). Qualified, so none of their names reach here.
// qmllint disable unused-imports
import "metis" as MetisDir
import "lexi" as LexiDir
import "lexi/lexi.js" as Lexicon
import "folio" as FolioDir
import "ideo" as IdeoDir
import "../calypso" as CalypsoDir
// qmllint enable unused-imports

LayerPopup {
  id: popup

  focusable: true
  // where it opens (Oracle's Opens, morpheus/place.js): placed by its usual
  // full height, so the field stays put while the list fills in
  steadyH: popup.fieldH + popup.listH + Zenon.hintBarH

  // the quick panels, which are the list: their word typed is all it takes ("f
  // report", "calc 2^10", "def serendipity"), so their command row only
  // types it
  readonly property var inList: ({ artemis: "f", metis: "calc", "lexi:dict": "def", "lexi:trans": "tr",
    folio: "cb", "ideo:emoji": "em", "ideo:nerd": "nf", calypso: "pw" })

  // calypso's manager (shell.qml): Quick Access is drawn from it
  property var passwords: null

  // artemis' index (shell.qml): the Files section asks it, and opens through it
  property var finder: null

  property string mode: "search"
  property string query: ""
  // ── THE CHIP (2026-11-04) ─────────────────────────────────────────────
  // a word Tab took out of the line ("def", "win", "quit": Cynosure.chipFor),
  // shown in the field as a chip; the query is still read with it first, so
  // every scoped list works as it did. Backspace on an empty line takes it
  // away, and so does any line set from outside (setLine).
  property var chip: null
  onChipChanged: if (!popup.editing) popup.query = popup.chipLine(input.text)
  function chipLine(t) { return popup.chip ? popup.chip.word + " " + t : t; }
  function setLine(t) {
    popup.chip = null;
    input.text = t;
  }
  // a line that starts with a chip's word comes in as that chip (a panel's
  // row handing over, "Search files" among the other ways)
  function lineAt(t) {
    const m = /^\s*(\S+)\s+([\s\S]*)$/.exec(String(t || ""));
    const c = m ? Cynosure.chipFor(m[1], popup.links, popup.scripts) : null;
    if (!c) { popup.setLine(t); return; }
    popup.chip = c;
    input.text = m[2];
  }
  // what Tab would make a chip of now, and what of the line is left: the
  // hint bar names it and the field shows the rest of a begun word, so it
  // is seen before Tab is pressed (2026-11-04)
  readonly property var chipOffer: {
    if (popup.mode !== "search" || popup.chip || popup.taken || popup.editing) return null;
    const m = /^\s*(\S+)(?:\s+([\s\S]*))?$/.exec(popup.query);
    if (!m) return null;
    let c = Cynosure.chipFor(m[1], popup.links, popup.scripts);
    if (!c && m[2] === undefined) {
      // a begun word, unless the chosen row is an app it begins
      const row = popup.filtered[popup.sel];
      if (row && row.kind === "app" && String(row.label || "").toLowerCase().startsWith(m[1].toLowerCase())) return null;
      c = Cynosure.chipComplete(m[1], popup.links, popup.scripts);
    }
    if (!c) return null;
    // the rest of the word, when the word typed is its start
    const typed = m[1].toLowerCase();
    const ghost = m[2] === undefined && c.word.startsWith(typed) && c.word !== typed ? c.word.slice(typed.length) : "";
    return { chip: c, rest: m[2] || "", ghost };
  }
  // the chip in place, moved on to its next of kin (Windows → Snap …)
  readonly property var chipNext: popup.chip && popup.mode === "search" && !popup.editing
    ? Cynosure.chipNext(popup.chip.word, false) : null
  function chipTurn(back) {
    const c = back && popup.chipNext ? Cynosure.chipNext(popup.chip.word, true) : popup.chipNext;
    if (!c) return false;
    popup.chip = c;
    popup.sel = 0;
    return true;
  }
  // tab: the word typed made a chip, whole ("def") or begun ("lay"), the
  // rest of the line kept as what is looked for; false when it is not one
  function chipTab() {
    const o = popup.chipOffer;
    if (!o) return false;
    popup.chip = o.chip;
    input.text = o.rest;
    return true;
  }
  property var histLines: []
  property var freqMap: ({})
  property var appsSnapshot: []
  property var rows: []
  property var filtered: []
  property string filteredSig: ""
  property int sel: 0
  // the calculator's answer to the line, or null: { question, answer }
  property var calc: null

  // The session verb waiting on "Reboot?" — see Cynosure.SHELL_ACTIONS. The
  // picker is the confirm: the list turns into its two answers and the field
  // into the question, rather than a dialog over the panel.
  property var pending: null
  // A session verb asking "Reboot?" sets the question on red — one rule for
  // every `confirm` verb, keyed off the flag, never a color per verb.
  readonly property bool alarm: popup.mode === "picker" && !popup.choices
    && !!popup.pending && !!popup.pending.confirm
  // socordia's switch, handed in by shell.qml so the Caffeinate row can say
  // which way it is — rebuilt the moment it flips.
  property bool keepAwake: false
  onKeepAwakeChanged: popup.rebuild()
  // A verb that has to ask WHICH (see `choose` in Cynosure.SHELL_ACTIONS)
  // puts its answers here, and the picker offers them ahead of Back.
  property var choices: null
  readonly property var pickerRows: (popup.choices ? popup.choices.concat([
    { key: "Back", label: Cynosure.ICON_B + "  Back" },
  ]) : [
    { key: "Confirm", label: "  Confirm" },
    { key: "Back", label: Cynosure.ICON_B + "  Back" },
  ]).map((r) => Object.assign({ kind: "pick" }, r, Cynosure.splitGlyph(r.label)))

  readonly property var current: popup.mode === "picker"
    ? (popup.pickerRows[popup.sel] || null) : (popup.filtered[popup.sel] || null)

  // ── ITS SIZE ──────────────────────────────────────────────────────────
  // the hint strip's height (user, 2026-11-01): the panel's top and foot match
  readonly property int fieldH: Zenon.hintBarH
  // what the typed line is set in, before Zenon.px; Lexi's senses read at
  // it too (user, 2026-11-05: "word definitions font size the same as my
  // own input's")
  readonly property int linePx: 18
  // the field's side room (user, 2026-11-04): what sits at either end as
  // far from the side as from the top and bottom, and a little more
  readonly property int fieldInset: 3
  // a chip, or what is being set ("Alias for …"), in a pill ahead of the line
  readonly property bool pillShown: popup.editing || popup.mode === "search" && !!popup.chip
  // the field's and the strip's height too (user, 2026-11-01): one line height
  readonly property int rowH: Zenon.hintBarH
  readonly property int sectionH: Zenon.px(30)
  readonly property int listH: popup.rowH * Oracle.cynosureRows
  // the calculator's card (its heading and itself) when it is up
  readonly property int metisH: popup.metis ? popup.metis.calcHeight() : 0
  // the calculator's card under the field: its heading, then metis
  readonly property int calcBoxH: (popup.calcShown ? popup.cardTop + popup.metisH : 0) + popup.answerBoxH
    + popup.lexiBoxH
  // the dictionary's or the translator's card: its heading, then itself
  readonly property int lexiBoxH: popup.lexiShown ? popup.cardTop + lexiCard.want : 0
  // a card's heading is in the field now (fieldTag): a breath of space over
  // the card is all that is left of the row it had
  readonly property int cardTop: Zenon.px(6)
  // WHAT THE LINE IS BEING READ AS, in the field (user, 2026-11-01: "inline
  // inside the search bar … for all keywords", as metis' line shows the
  // measure): its glyph in place of the magnifier and its name at the right,
  // where a heading over the card or the list used to say it. Null for a
  // plain search.
  readonly property var fieldTag: popup.mode !== "search" || popup.editing || popup.taken ? null
    : popup.lexiShown ? (popup.lexiMode === "dict" ? { glyph: "\uF02D", text: "Dictionary" } : { glyph: "\uF1AB", text: "Translate" })
    : popup.calcShown ? { glyph: Metis.glyphFor(popup.metis.resultShown && !popup.metis.shownBad ? popup.metis.shownKind : "Calc",
        popup.metis.shownResult), text: "Calculator" }
    : popup.answerShown ? { glyph: "", text: popup.wxAsk ? "Weather" : Answers.titleOf(popup.answer ? popup.answer.kind : "") }
    : popup.filesScoped ? { glyph: "\uF114", text: "Files" }
    : popup.clipsScoped ? { glyph: "\uF0EA", text: "Clipboard" }
    : popup.glyphsScoped ? (popup.glyphNerd ? { glyph: "\uF031", text: "Nerd glyphs" } : { glyph: "\uF118", text: "Emoji" })
    : popup.winsScoped ? { glyph: "\uF2D2", text: "Windows" }
    : popup.quitScoped ? { glyph: "\uF00D", text: "Quit" }
    : popup.historyScoped ? { glyph: "\uF1DA", text: "History" }
    : popup.snapScoped ? { glyph: "\uF2D0", text: "Snap" }
    : popup.themesScoped ? { glyph: "\uF1FC", text: "Themes" }
    : popup.layoutsScoped ? { glyph: "\uF009", text: "Layouts" }
    : popup.settingsScoped ? { glyph: "\uF013", text: "Settings" }
    : popup.storeScoped ? { glyph: "\uF07A", text: "Store" }
    : popup.pkgScoped ? { glyph: "\uF187", text: "Packages" }
    : popup.eventScoped ? { glyph: "\uF073", text: "New event" }
    : popup.notesScoped ? { glyph: "\uE678", text: "Notes" }
    : popup.newNoteScoped ? { glyph: "\uE678", text: "New note" }
    : popup.newTaskScoped ? { glyph: "\uF14A", text: "New task" }
    : popup.remindScoped ? { glyph: "\u{F009F}", text: "Reminder" }
    : popup.tasksScoped ? { glyph: "\uF14A", text: "Tasks" }
    : popup.booksScoped ? { glyph: "\uF02D", text: "Books" }
    : popup.outputsScoped ? { glyph: "\u{F04C3}", text: "Sound output" }
    : popup.colorsScoped ? { glyph: "\u{F03D8}", text: "Colors you picked" }
    : popup.placesScoped ? { glyph: "\uF07B", text: "Places" }
    : popup.procsScoped ? { glyph: "\uF085", text: "Processes" }
    : popup.portScoped ? { glyph: "\u{F0317}", text: "Port" }
    : popup.btScoped ? { glyph: "\uF293", text: "Bluetooth" }
    : popup.wifiScoped ? { glyph: "\uF1EB", text: "Wi-Fi" }
    : popup.reposScoped ? { glyph: "\uF1D3", text: "Repositories" }
    : popup.servicesScoped ? { glyph: "\u{F08D6}", text: "Services" }
    : popup.notifsScoped ? { glyph: "\uF0F3", text: "Notifications" }
    : popup.helpScoped ? { glyph: "\uF059", text: "Help" }
    : popup.scriptList ? { glyph: popup.scriptList.script.glyph, text: popup.scriptList.script.title }
    : popup.hitsScoped ? { glyph: "\uF15C", text: "Inside files" }
    : popup.fontsScoped ? { glyph: "\uF031", text: "Fonts" }
    : popup.shotsScoped ? { glyph: "\u{F0E51}", text: "Screenshots" }
    : popup.recsScoped ? { glyph: "\u{F044B}", text: "Recordings" }
    : lookups.tag
  // a smart answer's card: its heading, then the weather's taller card or
  // an answer's two lines
  readonly property int answerBoxH: !popup.answerShown ? 0
    : popup.cardTop + (popup.wxAsk ? Zenon.px(168) : Zenon.px(92) + popup.answerGaugeH)
  // what a live answer draws under its two lines: cpu and memory their
  // graph, the disk and the battery how full
  readonly property bool answerGraph: !!popup.answer && (popup.answer.kind === "cpu" || popup.answer.kind === "memory")
  readonly property bool answerMeter: !!popup.answer && popup.answer.level !== undefined
  readonly property bool answerQr: !!popup.answer && !!popup.answer.qr
  // facts under an answer's two lines (the uptime's load, processes, cores)
  readonly property bool answerFacts: !!popup.answer && !!popup.answer.facts && popup.answer.facts.length > 0
  readonly property int answerGaugeH: popup.answerFacts ? Zenon.px(22) + 14
    : popup.answerQr ? Zenon.px(200) + 14
    : popup.answerGraph ? Zenon.px(64) + 14
    : popup.answerMeter ? Zenon.px(8) + 14 : 0
  readonly property int topH: popup.folioEditing ? popup.folioH
    : popup.pwMode ? popup.pwH : popup.fieldH
  // something has the field (the calculator, the dictionary, a snippet
  // being written)
  readonly property bool taken: popup.folioEditing
    || popup.pwMode
  onTakenChanged: popup.applyFilter()
  // the whole panel: the list's nine rows under the field, or what took the
  // field with two rows of list under it, whichever is taller — and with
  // nothing in the list under what took the field, that alone
  // A SESSION VERB'S CONFIRM, ON ONE LINE (user, 2026-11-01): "Shutdown?"
  // on its red with Confirm and Back beside it, and the panel only as wide
  // and as tall as that — no list under it, no strip of keys
  readonly property bool confirmLine: popup.mode === "picker" && !popup.choices
    && !!popup.pending && !!popup.pending.confirm
  // where the question's red ends: its glyph, its words, and the same room
  // after the words as before the glyph (user, 2026-11-05: the old sum
  // reserved more than the glyph's real place, so the red ran long)
  readonly property int questionW: Math.ceil(question.x + question.implicitWidth) + fieldGlyph.x + 4
  // the pill's own height: the strip is a line, not a panel
  readonly property int confirmH: Zenon.slot
  // COMPACT (Oracle, 2026-11-04, Raycast's): the field alone on an empty
  // line, the list and the keys only once something is typed
  readonly property bool compactNow: Oracle.cynosureCompact && popup.mode === "search" && !popup.taken
    && popup.query.trim() === "" && !popup.answer && popup.calcBoxH === 0 && !popup.compactOpen
  // down on the empty compact field opens it on your favorites and
  // suggestions (2026-11-04); esc, a key typed or the next opening folds it
  property bool compactOpen: false
  onQueryChanged: { popup.compactOpen = false; popup.lastPick = null; }
  // the row return last ran, for history (closeCynosure)
  property var lastPick: null
  readonly property int rootH: popup.confirmLine ? popup.confirmH
    : popup.compactNow ? popup.fieldH
    : popup.editing ? popup.fieldH + Zenon.hintBarH
    : popup.taken && popup.filtered.length === 0
    ? popup.topH + Zenon.hintBarH
    : popup.topH + popup.calcBoxH + popup.listFit + Zenon.hintBarH
  // AUTOFIT (user, 2026-11-01: "autofit is really important"): the list is
  // only as tall as its rows and headings, up to the nine rows' room under
  // the field — less what the cards above it take, but never under two rows
  // while it has any. A list of one kind with its detail pane keeps the full
  // room, which the preview needs.
  readonly property int listNeed: {
    const rows = popup.mode === "picker" ? popup.pickerRows : popup.filtered;
    let h = 0, sec = "";
    for (const r of rows || []) {
      if (r.section && r.section !== sec && !(popup.fieldTag && r.section === popup.fieldTag.text)) h += popup.sectionH;
      sec = r.section || "";
      h += r.kind === "clipimg" ? popup.rowH * 2 : r.kind === "glyphs" ? popup.glyphRowH
        : r.kind === "pics" || r.kind === "shots" || r.kind === "fonts" ? popup.picRowH : popup.rowH;
      if (h > popup.listH) break;
    }
    return h;
  }
  readonly property int listFit: {
    const room = Math.max(popup.rowH * 2, popup.fieldH + popup.listH - popup.topH - popup.calcBoxH);
    if (popup.paneOn) return room;
    return Math.min(popup.listNeed, room);
  }
  // A view is shown at its own size, the one it had as a panel of its own
  // (metis shrink-wraps its line): the pill carries the panel from the
  // list's shape to the view's and back.
  readonly property int panelWidth: popup.confirmLine
    ? popup.questionW + Math.ceil(answers.implicitWidth)
    : Math.round(Oracle.cynosureWidth * (popup.paneOn ? (popup.glyphsScoped ? 880 : 1000) / 760 : 1))
  readonly property int panelTarget: Zenon.layerWidth(popup.panelWidth)
  function calcHeight() {
    return popup.rootH;
  }

  // WHAT IS ON SCREEN, which is not the target while the pill is moving.
  // Morphed, the pill's own animated width IS the value; standalone there is
  // no pill to follow, so the ease lives here (ideo, folio and artemis do
  // the same).
  property real liveWidth: (popup.morphMode && popup.statusbar
      && popup.statusbar.pillWidth > 0)
    ? popup.statusbar.pillWidth : popup.panelTarget
  Behavior on liveWidth {
    enabled: !popup.morphMode
    NumberAnimation { duration: Zenon.slow; easing.type: Zenon.ease }
  }

  HyprlandFocusGrab {
    id: grab
    // the actions card is its own surface: a press on it is not a press away
    windows: actionsMenu.visible ? [ popup, actionsMenu ] : [ popup ]
    // let go the moment the close begins: a quick panel this one handed the
    // pill to is taking its own grab in the same frame
    // nor while something is being dragged out to another app
    active: popup.shown && !popup.collapsing && !popup.dragging
    onCleared: popup.closeCynosure()
  }

  IpcHandler {
    target: "Cynosure"
    function toggle() {
      popup.toggle();
    }
    // a hotkey of yours (binds.lua, from hotkeys.lua): the row it was given to
    function hotkey(chord: string): string {
      return popup.runHotkey(chord);
    }
    // what is highlighted anywhere (else copied), typed into the line
    // (Super+Shift+Space)
    function selection(): string {
      if (selectionProc.running) return "busy";
      selectionProc.running = true;
      return "ok";
    }
  }
  // The names the quick panels answered to before they moved in here, kept
  // so a bind or a script that calls them still lands: each one is now a
  // view of this panel.
  IpcHandler {
    target: "Metis"
    function toggle(): string { return popup.toggleLine("calc "); }
  }
  IpcHandler {
    target: "Lexi"
    function toggle(): string { return popup.toggleLine("def "); }
    function translate(): string { return popup.toggleLine("tr "); }
    // the translator, onto words already chosen (minerva's look-up card)
    function translateText(text: string): string {
      const t = String(text || "").trim();
      popup.lookUp("trans", t);
      return t === "" ? "empty" : "translating";
    }
    // open onto a word without typing it — for a script, a menu entry, or
    // anything else that already knows what it wants defined
    function define(word: string): string {
      const w = String(word || "").trim();
      if (w === "") return "empty";
      popup.lookUp("dict", w);
      return "defining " + w;
    }
  }
  IpcHandler {
    target: "Folio"
    function toggle(): string { return popup.toggleLine("cb "); }
  }
  IpcHandler {
    target: "Ideo"
    function toggle(): string { return popup.toggleLine("em "); }
    function emoji(): string { return popup.toggleLine("em "); }
    function nerd(): string { return popup.toggleLine("nf "); }
  }
  // open with a word already typed ("calc ", "f "): the list as that word
  // makes it; closes if it is already what is up
  function toggleLine(line) {
    if (popup.shown && !popup.collapsing && popup.query === line) {
      popup.closeCynosure();
      return "closed";
    }
    popup.openCynosure();
    popup.untake();
    popup.setLine(line);
    input.cursorPosition = input.text.length;
    return "ok";
  }

  Repeater {
    id: appLoader
    model: DesktopEntries.applications
    delegate: Item { required property var modelData }
  }

  Confetti { id: confetti }
  // "camera": the webcam, mirrored, in its own window, while it is open
  Loader {
    id: cameraLoader
    active: false
    source: "CameraMirror.qml"
  }
  Connections {
    target: cameraLoader.item
    function onClosed() { cameraLoader.active = false; }
  }

  // Oracle's Forget buttons (Cynosure › Search, Windows & layouts)
  Connections {
    target: Oracle
    function onCynosureForgetAsked(what) {
      if (what === "places") { popup.snapWas = {}; return; }
      if (what === "layouts") { popup.writeLayouts({}); return; }
      if (what !== "learned") return;
      popup.freqMap = ({});
      popup.picks = ({});
      writer.write(Cynosure.picksPath(), Cynosure.serializePicks({}));
      popup.histLines = [];
      popup.queries = [];
      writer.write(Cynosure.freqPath(), Cynosure.serializeFreq({}));
      writer.write(Cynosure.histPath(), Cynosure.serializeHistory([]));
      writer.write(Cynosure.queriesPath(), Cynosure.serializeQueries([]));
      popup.rebuild();
    }
  }

  Cat {
    id: histCat
    path: Cynosure.histPath()
    onDone: (text) => {
      popup.histLines = Cynosure.parseHistory(text);
      popup.loadTick();
    }
  }

  // what you picked for what you typed (Cynosure.notePick)
  property var picks: ({})
  Cat {
    id: picksCat
    path: Cynosure.picksPath()
    onDone: (text) => { popup.picks = Cynosure.parsePicks(text); }
  }
  Cat {
    id: freqCat
    path: Cynosure.freqPath()
    onDone: (text) => {
      popup.freqMap = Cynosure.parseFreq(text);
      popup.loadTick();
    }
  }

  // your own words for things (Cynosure.aliasPath): a missing file is none
  property var aliases: ({})
  Cat {
    id: aliasCat
    path: Cynosure.aliasPath()
    onDone: (text) => {
      popup.aliases = Cynosure.parseAliases(text);
      popup.loadTick();
    }
  }
  // ── HOTKEYS (2026-11-01) ─────────────────────────────────────────────
  // A chord for a row (Raycast's), set from its actions: the line becomes
  // "Hotkey for X" and waits for the keys, hyprland held in oracle's empty
  // "oracle-keys" submap meanwhile so Super+anything reaches here (Oracle's
  // Shortcuts does the same). A chord something else answers is refused,
  // saying whose. Kept in cynosure-hotkeys.json and written to hotkeys.lua.
  property var hotkeys: []
  Cat {
    id: hotkeysCat
    path: Cynosure.hotkeysPath()
    onDone: (text) => {
      popup.hotkeys = Cynosure.parseHotkeys(text);
      // a list that came by Oracle's Import reaches hyprland too: the
      // binds are written again when they are not what the list says
      hotkeysLuaFile.reload();
      const had = String(hotkeysLuaFile.text() || "");
      const lua = Cynosure.renderHotkeysLua(popup.hotkeys);
      if (had !== lua && !(popup.hotkeys.length === 0 && had === ""))
        writer.write(Cynosure.hotkeysLuaPath(), lua, () => hyprReload.restart());
    }
  }
  FileView { id: hotkeysLuaFile; path: Cynosure.hotkeysLuaPath(); blockLoading: true; printErrors: false }
  property var hotkeyRow: null
  property var liveBinds: []
  Process {
    id: liveBindsProc
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector {
      id: liveBindsOut
      onStreamFinished: {
        try { popup.liveBinds = JSON.parse(liveBindsOut.text); } catch (e) { popup.liveBinds = []; }
      }
    }
  }
  function askHotkey(row) {
    popup.hotkeyRow = row;
    popup.aliasNote = "";
    popup.aliasWas = popup.query;
    popup.mode = "hotkey";
    popup.setLine("");
    input.readOnly = true;
    if (!liveBindsProc.running) liveBindsProc.running = true;
    Hyprland.dispatch(Hypr.submap("oracle-keys"));
    hotkeyTimeout.restart();
    Qt.callLater(() => input.forceActiveFocus());
  }
  Timer {
    id: hotkeyTimeout
    interval: 10000
    onTriggered: popup.endHotkey()
  }
  function hotkeyKey(event) {
    event.accepted = true;
    if (event.key === Qt.Key_Escape && !(event.modifiers & (Qt.MetaModifier | Qt.ControlModifier | Qt.AltModifier))) {
      popup.endHotkey();
      return;
    }
    const chord = Ora.chordFromKey(event.key, event.modifiers, event.text);
    if (chord === "") return;
    hotkeyTimeout.restart();
    // a key alone, or with only Shift, would be taken from every app
    if (!/\b(SUPER|CONTROL|ALT)\b/.test(chord)) {
      popup.aliasNote = "Hold Super, Ctrl or Alt with the key";
      return;
    }
    // this row's own chord is free to give it again
    const mine = Cynosure.hotkeyOf(popup.hotkeys, popup.hotkeyRow) !== ""
      ? Cynosure.hotkeyLabel({ row: popup.hotkeyRow }) : "";
    const live = popup.liveBinds.filter((b) => mine === "" || b.description !== mine);
    const taken = Ora.chordTaken(chord, "", [], ({}), live);
    if (taken !== "") { popup.aliasNote = "Taken by " + taken; return; }
    popup.hotkeys = Cynosure.setHotkey(popup.hotkeys, chord, popup.hotkeyRow);
    popup.writeHotkeys();
    popup.endHotkey();
  }
  // a chord as the hints write keys: "super shift f", on one cap
  function chordWords(chord) {
    return Ora.chordCaps(chord).join(" ").toLowerCase();
  }
  function dropHotkey(row) {
    popup.hotkeys = Cynosure.dropHotkey(popup.hotkeys, row);
    popup.writeHotkeys();
  }
  function writeHotkeys() {
    writer.write(Cynosure.hotkeysPath(), Cynosure.serializeHotkeys(popup.hotkeys));
    writer.write(Cynosure.hotkeysLuaPath(), Cynosure.renderHotkeysLua(popup.hotkeys), () => hyprReload.restart());
  }
  Timer {
    id: hyprReload
    interval: 150
    onTriggered: Quickshell.execDetached(["hyprctl", "reload"])
  }
  function endHotkey() {
    if (popup.mode !== "hotkey") return;
    hotkeyTimeout.stop();
    Hyprland.dispatch(Hypr.submap("reset"));
    popup.hotkeyRow = null;
    popup.aliasNote = "";
    input.readOnly = false;
    popup.mode = "search";
    popup.setLine(popup.aliasWas);
    input.cursorPosition = input.text.length;
    popup.rebuild();
  }
  // the chord pressed: its row, as fresh as the list has it, else as kept
  function runHotkey(chord) {
    const n = Ora.normChord(chord);
    const h = popup.hotkeys.find((x) => Ora.normChord(x.chord) === n);
    if (!h) return "unknown";
    const t = Cynosure.hotkeyTarget(h.row);
    const row = h.row.kind === "file" ? h.row
      : popup.rows.find((r) => Cynosure.hotkeyTarget(r) === t) || h.row;
    // a verb that asks first, or opens a view, does it in the panel
    if (row.kind === "shell" && row.action && (row.action.confirm || row.action.choose
        || row.action.view || row.action.line || row.action.inline)) {
      if (!popup.shown) popup.toggle();
      Qt.callLater(() => popup.runRow(row));
      return "asked";
    }
    popup.runRow(row);
    return "ran";
  }

  function writeAliases() {
    writer.write(Cynosure.aliasPath(), Cynosure.serializeAliases(popup.aliases));
  }

  // your scripts (Cynosure.scriptsDir), read again on every open: a file
  // added or changed since is there the next time
  property var scripts: []
  Process {
    id: scriptsProc
    command: ["sh", "-c", Cynosure.scriptsListCommand(), "cynosure", Cynosure.scriptsDir()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        popup.scripts = Cynosure.parseScripts(text);
        popup.rebuild();
        popup.runInlineScripts(true);
      }
    }
  }
  // run by its @mode: in the background, in your terminal, or what it
  // prints said as a notification. Run with sh when it is not executable.
  function runScript(sc, arg) {
    // an inline script's row already says it: return copies what it said
    if (sc.mode === "inline") {
      popup.copyText(popup.scriptSaid[sc.path] || "");
      return;
    }
    const args = arg ? [arg] : [];
    if (sc.mode === "terminal") {
      Quickshell.execDetached(["sh", "-c", Cynosure.terminalCommand(
        Strings.shellQuote(sc.path) + (arg ? " " + Strings.shellQuote(arg) : ""), Oracle.terminal)]);
    } else if (sc.mode === "output") {
      Quickshell.execDetached(["sh", "-c",
        "out=$( (if [ -x \"$1\" ]; then \"$@\"; else sh \"$@\"; fi) 2>&1 | head -c 2000 ); "
        + "notify-send -a Cynosure -- \"$0\" \"${out:-Done}\"", sc.title, sc.path].concat(args));
    } else {
      Quickshell.execDetached(["setsid", "-f", "sh", "-c",
        "if [ -x \"$1\" ]; then exec \"$@\"; else exec sh \"$@\"; fi", "cynosure", sc.path].concat(args));
    }
    popup.closeCynosure();
  }

  // your quick links (Cynosure.linksPath), the built-ins under them
  property var ownLinks: []
  readonly property var links: Cynosure.allLinks(popup.ownLinks, Oracle.cynosureWebEngine)
  Cat {
    id: linkCat
    path: Cynosure.linksPath()
    onDone: (text) => {
      popup.ownLinks = Cynosure.parseLinks(text);
      popup.loadTick();
    }
  }
  function writeLinks() {
    writer.write(Cynosure.linksPath(), Cynosure.serializeLinks(popup.ownLinks));
  }

  // what you searched, newest first (Cynosure.queriesPath): "history"
  // lists it, and an empty chip leads with its own
  property var queries: []
  Cat {
    id: queriesCat
    path: Cynosure.queriesPath()
    onDone: (text) => {
      popup.queries = Cynosure.parseQueries(text);
      popup.loadTick();
    }
  }
  // Alt held: the first nine rows say their number (alt 1–9 opens them)
  property bool altHeld: false

  property int pendingLoad: 5

  // The first load waits for both files; every re-read after it (the
  // history is read again on each open) rebuilds on its own. It only ever
  // rebuilt at exactly zero, so after startup the count just went negative
  // and a re-read changed nothing on screen.
  function loadTick() {
    if (popup.pendingLoad > 0 && --popup.pendingLoad > 0) return;
    popup.rebuild();
  }

  AtomicWriter { id: writer; tag: "cynosure-write" }

  function writeHistory() {
    if (!Oracle.cynosureRemember) return;
    writer.write(Cynosure.histPath(), Cynosure.serializeHistory(popup.histLines));
  }

  function writeFreq() {
    writer.write(Cynosure.freqPath(), Cynosure.serializeFreq(popup.freqMap));
  }

  function refreshApps() {
    const vals = DesktopEntries.applications.values;
    const snapshot = [];
    for (let i = 0; i < vals.length; ++i) {
      const e = vals[i];
      // its generic name and keywords too, so "font" finds Alexandria and
      // "editor" finds Plato; the generic name is also the row's second line
      if (e) snapshot.push({ name: e.name, exec: e.execString, id: e.id, icon: e.icon,
                             generic: e.genericName || "",
                             words: [e.genericName || ""].concat(Array.from(e.keywords || [])).join(" ") });
    }
    popup.appsSnapshot = snapshot;
    popup.rebuild();
  }

  // the live flags the verbs read: `state` picks a row's face, `needs`
  // whether it is offered at all (control hub's switches)
  readonly property var actionStates: ({
    awake: popup.keepAwake,
    night: Hermes.nightWanted, nightReady: Hermes.probe.display.hyprsunset,
    wifiOff: !Hermes.wifiOn, wifiReady: Hermes.wifiReady,
    btOff: !Hermes.btOn, btReady: Hermes.btReady
  })
  onActionStatesChanged: if (popup.shown) popup.rebuild()
  function rebuild() {
    const apps = Cynosure.getApps(popup.appsSnapshot);
    popup.rows = Cynosure.withAliases(Cynosure.buildRows(apps, popup.histLines || [], popup.freqMap || {},
      Cynosure.SHELL_ACTIONS.concat(Cynosure.linkActions(popup.links), Cynosure.scriptActions(popup.scripts, popup.scriptSaid)),
      popup.actionStates, Strings.appGlyph),
      popup.aliases);
    popup.applyFilter();
  }

  // SNAPPIER (user, 2026-11-02: "can we make it snappier?"): every source
  // that changes the list asks for it again — a key asked three times, each
  // a rebuild and every row drawn anew. Asked any number of times in one
  // turn of the event loop, it is built once (Qt.callLater keeps one call),
  // and a list that came out the same is not handed to the view again.
  function applyFilter() { Qt.callLater(popup.filterNow); }
  function filterNow() {
    // what has taken the field has the panel: no list under it
    const next = popup.taken ? [] : Cynosure.rootRows(popup.rows, popup.query, popup.freqMap || {},
      Cynosure.SHELL_ACTIONS, { files: popup.filesScoped || Oracle.cynosureRootFiles ? popup.fileRows : [], filesOnly: popup.filesScoped,
        suggested: Oracle.cynosureSuggested, history: Oracle.cynosureRemember, fallbacks: Oracle.cynosureFallbacks,
        hidden: Cynosure.hiddenSet(Oracle.cynosureHidden), fallbackList: Oracle.cynosureFallbackList,
        picks: Oracle.cynosureRemember ? popup.picks : null,
        links: popup.links,
        scripts: popup.scripts,
        windows: popup.winsScoped || Oracle.cynosureRootWindows ? Cynosure.windowRows(popup.openWindows(), popup.winLine, popup.winsScoped, Strings.appGlyph) : [],
        windowsOnly: popup.winsScoped,
        command: popup.cmdRow,
        aliasFiles: Cynosure.aliasFiles(popup.aliases, popup.query, Quickshell.env("HOME"), Icons.glyphFor),
        fileFreq: popup.finder ? popup.finder.freq : ({}),
        clips: popup.clipsScoped || Oracle.cynosureRootClips ? popup.clipRows : [], clipsOnly: popup.clipsScoped,
        glyphs: popup.glyphsScoped || Oracle.cynosureRootEmoji ? popup.glyphRows : [], glyphsOnly: popup.glyphsScoped,
        settings: popup.settingsWanted && (popup.settingsScoped || Oracle.cynosureRootSettings) ? Cynosure.settingsRows(Oracle.schema, Oracle.sections, popup.settingsLine, popup.settingsScoped) : [],
        settingsOnly: popup.settingsScoped,
        store: popup.storeScoped ? Cynosure.storeRows(popup.storeApps, popup.storeLine, Strings.appGlyph) : [],
        storeOnly: popup.storeScoped,
        notes: popup.notesWanted && (popup.notesScoped || Oracle.cynosureRootNotes) ? Cynosure.noteRows(popup.clioNotes, popup.notesLine, popup.notesScoped) : [],
        newNote: popup.newNoteScoped ? Cynosure.newNoteRow(popup.notesLine) : null,
        notesOnly: popup.notesScoped || popup.newNoteScoped,
        packages: popup.pkgScoped ? Cynosure.packageRows(popup.pkgFound) : [],
        packagesOnly: popup.pkgScoped,
        event: popup.eventScoped ? Cynosure.eventRow(popup.eventLine, Chr.isoOf(new Date()), new Date()) : null,
        eventOnly: popup.eventScoped,
        newTask: popup.newTaskScoped || popup.remindScoped ? Cynosure.newTaskRow(popup.taskLine, popup.remindScoped, new Date()) : null,
        tasks: popup.tasksScoped ? Cynosure.taskRows(popup.clioNotes, popup.taskLine, new Date()) : [],
        tasksOnly: popup.newTaskScoped || popup.remindScoped || popup.tasksScoped,
        books: popup.booksScoped ? Cynosure.bookRows(popup.books, popup.bookLine) : [],
        booksOnly: popup.booksScoped,
        outputs: popup.outputRows, outputsOnly: popup.outputsScoped,
        colors: popup.colorsScoped ? Cynosure.colorRows(popup.palette, popup.colorLine) : [],
        colorsOnly: popup.colorsScoped,
        favorites: popup.query.trim() === "" ? Cynosure.favoriteRows(popup.favorites, popup.rows) : [],
        places: popup.placeRows, placesOnly: popup.placesScoped,
        procs: popup.procRows, procsOnly: popup.procsScoped || popup.portScoped,
        radios: popup.radioRows, radiosOnly: popup.btScoped || popup.wifiScoped,
        repos: popup.reposScoped ? Cynosure.repoRows(popup.repoRecents, popup.repoState, popup.repoLine, Quickshell.env("HOME")) : [],
        reposOnly: popup.reposScoped,
        services: popup.servicesScoped ? Cynosure.serviceRows(popup.units, popup.serviceLine) : [],
        servicesOnly: popup.servicesScoped,
        notifs: popup.notifsScoped ? Cynosure.notifRows(Howler.history, popup.notifLine, new Date()) : [],
        notifsOnly: popup.notifsScoped,
        listItems: popup.listRows, listOnly: !!popup.scriptList,
        hits: popup.hitRows, hitsOnly: popup.hitsScoped,
        fonts: popup.fontsScoped ? Cynosure.fontRows(popup.fontFamilies, popup.fontLine, popup.picsPer) : [],
        fontsOnly: popup.fontsScoped,
        captures: popup.captureRows, capturesOnly: popup.shotsScoped || popup.recsScoped,
        help: popup.helpScoped ? Cynosure.helpRows(popup.helpLine, { aliases: popup.aliases, links: popup.ownLinks,
          scripts: popup.scripts }) : [],
        helpOnly: popup.helpScoped,
        only: popup.snapScoped ? Cynosure.snapRows(popup.scopeRest, popup.lastWindowName())
          : popup.themesScoped ? popup.themeList()
          : popup.historyScoped ? Cynosure.searchRows(popup.queries, popup.scopeRest, popup.links, popup.scripts)
          : popup.quitScoped ? popup.quitList() : popup.layoutsScoped ? Cynosure.layoutRows(popup.layouts, popup.scopeRest)
          : lookups.scoped ? lookups.rows : null });
    // a chip with nothing after it: what you last looked for under it, first
    if (popup.chip && !popup.taken && input.text.trim() === "" && Oracle.cynosureRemember)
      next.unshift(...Cynosure.chipRecentRows(popup.queries, popup.chip.word, popup.links, popup.scripts));
    // the same rows as now: the view keeps the ones it drew
    const sig = JSON.stringify(next);
    if (sig !== popup.filteredSig) {
      popup.filteredSig = sig;
      popup.filtered = next;
    }
    if (popup.sel >= 0 || !popup.cardUp) popup.sel = Nav.clamp(popup.sel, popup.filtered.length);
    popup.followSelection();
  }

  // ── SETTINGS, IN THE LIST ─────────────────────────────────────────────
  // Oracle's pages and rows (Cynosure.settingsRows): the few whose name the
  // line starts for any line, every match for "settings …"; return opens
  // Oracle there (its own IPC, show <key> / at <page>)
  readonly property bool settingsScoped: /^\s*settings\s/i.test(popup.query)
  readonly property string settingsLine: popup.settingsScoped
    ? popup.query.replace(/^\s*settings\s+/i, "") : popup.query
  readonly property bool settingsWanted: popup.mode === "search" && !popup.taken && !popup.calcShown
    && !popup.lexiAsk && (popup.settingsScoped || popup.settingsLine.trim().length >= 3)
  function openSetting(row) {
    popup.closeThen(() => Quickshell.execDetached(["qs", "ipc", "call", "Oracle", row.spec ? "setting" : "at", row.spec || row.page]));
  }

  // ── A WINDOW OPENED FROM HERE, AFTER HERE HAS GONE ────────────────────
  // Oracle, Ceres, Clio, the calendar asked to open while this panel still
  // held the keyboard: one already open was only raised, and the raise was
  // refused under the grab — "Layout and Tiling layout don't do anything"
  // (user, 2026-11-01). The ask now waits for the panel to finish closing
  // (sequence, not race), or runs at once with the panel already shut (a
  // hotkey). A beat past the close at most, should it never say it ended.
  property var afterClose: []
  function closeThen(fn) {
    if (!popup.shown) { fn(); return; }
    popup.afterClose = popup.afterClose.concat([fn]);
    afterCloseLate.restart();
    popup.closeCynosure();
  }
  function runAfterClose() {
    afterCloseLate.stop();
    const q = popup.afterClose;
    popup.afterClose = [];
    for (const f of q) f();
  }
  Timer { id: afterCloseLate; interval: 900; onTriggered: popup.runAfterClose() }

  // ── THE STORE, IN THE LIST ────────────────────────────────────────────
  // "store …" / "install …": Ceres' catalog (its own ceres-store list, read
  // once a shell session, the first time it is asked for), ranked by Ceres'
  // search; return opens the app's page in Ceres (Ceres.openApp)
  readonly property bool storeScoped: /^\s*(store|install)\s/i.test(popup.query)
  readonly property string storeLine: popup.storeScoped ? popup.query.replace(/^\s*(store|install)\s+/i, "") : ""
  property var storeApps: []
  onStoreScopedChanged: if (popup.storeScoped && popup.storeApps.length === 0 && !storeProc.running) storeProc.running = true
  Process {
    id: storeProc
    command: [Quickshell.shellDir + "/ceres/bin/ceres-store", "list"]
    stdout: StdioCollector {
      id: storeOut
      onStreamFinished: {
        try { popup.storeApps = JSON.parse(storeOut.text).apps || []; } catch (e) { popup.storeApps = []; }
        popup.applyFilter();
      }
    }
  }
  function openStoreApp(row) {
    popup.closeThen(() => Ceres.openApp(row.app));
  }

  // a scope word of its own (settings, store, notes): no files under it
  readonly property bool otherScoped: popup.settingsScoped || popup.storeScoped || popup.notesScoped || popup.newNoteScoped
    || popup.pkgScoped || popup.eventScoped || popup.newTaskScoped || popup.remindScoped || popup.tasksScoped
    || popup.booksScoped || popup.outputsScoped || popup.colorsScoped || popup.placesScoped || popup.procsScoped
    || popup.portScoped || popup.btScoped || popup.wifiScoped || popup.reposScoped || popup.servicesScoped || popup.notifsScoped
    || !!popup.scriptList || popup.hitsScoped || popup.fontsScoped || popup.shotsScoped || popup.recsScoped
    || popup.helpScoped || lookups.scoped

  // ── PACKAGES, IN THE LIST ─────────────────────────────────────────────
  // "pkg …": every repo package and the AUR, by Ceres' own search (its
  // ceres.sh search, the Packages tab's), asked a beat after the last key;
  // return hands the change to Ceres' confirm sheet (Ceres.changePackage)
  readonly property bool pkgScoped: /^\s*pkg\s/i.test(popup.query)
  readonly property string pkgLine: popup.pkgScoped ? popup.query.replace(/^\s*pkg\s+/i, "").trim() : ""
  property var pkgFound: []
  onPkgLineChanged: { if (popup.pkgLine === "") { popup.pkgFound = []; popup.applyFilter(); } else pkgLater.restart(); }
  Timer { id: pkgLater; interval: 220; onTriggered: popup.askPackages() }
  function askPackages() {
    if (pkgProc.running) { pkgProc.again = true; return; }
    pkgProc.asked = popup.pkgLine;
    pkgProc.command = ["sh", "-c", Cer.searchCommand(Quickshell.shellDir + "/scripts/ceres.sh", false, popup.pkgLine)];
    pkgProc.running = true;
  }
  Process {
    id: pkgProc
    property string asked: ""
    property bool again: false
    onExited: if (pkgProc.again) { pkgProc.again = false; Qt.callLater(popup.askPackages); }
    stdout: StdioCollector {
      id: pkgOut
      onStreamFinished: {
        if (pkgProc.asked !== popup.pkgLine) return;
        popup.pkgFound = Cer.parseRows(pkgOut.text);
        popup.applyFilter();
      }
    }
  }
  function changePackage(row) {
    popup.closeThen(() => Ceres.changePackage(row.pkg));
  }

  // ── A CALENDAR EVENT, FROM THE LINE ───────────────────────────────────
  // "event lunch friday 1pm": one row saying how Chronos reads it; return
  // adds it (Chronos.addQuick), and says so in a toast once it is kept
  readonly property bool eventScoped: /^\s*event\s/i.test(popup.query)
  readonly property string eventLine: popup.eventScoped ? popup.query.replace(/^\s*event\s+/i, "") : ""
  function addEvent(row, show) {
    if (row.bad) return;
    Chronos.addQuick(row.text, Chr.isoOf(new Date()), (ok, words) => {
      Quickshell.execDetached(["notify-send", "-a", "chronos", "-i", "x-office-calendar", "--",
        ok ? words : "The event was not added", ok ? "" : words]);
    });
    const q = Chr.parseNatural(row.text, Chr.isoOf(new Date()));
    popup.closeThen(() => { if (show) Quickshell.execDetached(["qs", "ipc", "call", "Calendar", "day", q.iso || ""]); });
  }

  // ── TASKS AND REMINDERS (2026-11-02) ──────────────────────────────────
  // "todo pay rent friday" and "remind me in 20 min to call mom": one row
  // saying how it will be kept (Cynosure.newTaskRow); return adds it to
  // Clio's Tasks note, the time its reminder. "todos …" / "tasks …" lists
  // the open ones; return ticks one (Clio's own tickTask).
  readonly property bool newTaskScoped: /^\s*todo\s/i.test(popup.query)
  readonly property bool remindScoped: /^\s*remind me\s/i.test(popup.query)
  readonly property bool tasksScoped: /^\s*(todos|tasks)\s/i.test(popup.query)
  readonly property string taskLine: popup.newTaskScoped ? popup.query.replace(/^\s*todo\s+/i, "")
    : popup.remindScoped ? popup.query.replace(/^\s*remind me\s+/i, "")
    : popup.tasksScoped ? popup.query.replace(/^\s*(todos|tasks)\s+/i, "") : ""
  onTasksScopedChanged: if (popup.tasksScoped && Clio.app && !Clio.app.loaded) Clio.app.whenLoaded(() => popup.applyFilter())
  function addTask(row, show) {
    if (row.bad) return;
    popup.closeThen(() => {
      if (!Clio.app) return;
      Clio.app.addTask(row.title, row.due, (id) => { if (show) Clio.app.openAt(id, row.title); });
      Quickshell.execDetached(["notify-send", "-a", "clio", "--", row.remind ? "Reminder set" : "Task added",
        row.title + (row.due ? " · " + Cynosure.dueWords(row.due, new Date()) : "")]);
    });
  }
  function tickTask(row) {
    if (Clio.app && Clio.app.tickTask(row.task)) popup.applyFilter();
  }

  // ── BOOKS (2026-11-02) ────────────────────────────────────────────────
  // "book …": Minerva's library, read from its own file each time the word
  // is typed; return opens the book where it was left
  readonly property bool booksScoped: /^\s*books?\s/i.test(popup.query)
  readonly property string bookLine: popup.booksScoped ? popup.query.replace(/^\s*books?\s+/i, "") : ""
  property var books: []
  onBooksScopedChanged: if (popup.booksScoped) { booksCat.running = false; booksCat.running = true; }
  Cat {
    id: booksCat
    path: Quickshell.statePath("minerva.json")
    onDone: (text) => {
      let j = null;
      try { j = JSON.parse(text); } catch (e) {}
      // minerva.js' cleanBook, by hand: a path, a title, the rest as kept
      popup.books = (j && Array.isArray(j.books) ? j.books : []).filter((b) => b && b.path)
        .map((b) => ({ path: String(b.path), kind: String(b.kind || ""), title: String(b.title || "") || Terminus.basename(b.path),
          author: String(b.author || ""), cover: String(b.cover || ""), opened: Number(b.opened) || 0,
          added: Number(b.added) || 0, progress: Math.max(0, Math.min(1, Number(b.progress) || 0)),
          finished: Number(b.finished) || 0 }));
      popup.applyFilter();
    }
  }
  function openBook(row) {
    popup.closeThen(() => Quickshell.execDetached(["qs", "ipc", "call", "Minerva", "open", row.path]));
  }

  // ── SOUND OUTPUT (2026-11-02) ─────────────────────────────────────────
  // "output …": Pipewire's sinks (zeus' Sound reads them the same way);
  // return makes one the default, as zeus' mixer does
  readonly property bool outputsScoped: /^\s*output\s/i.test(popup.query)
  readonly property string outputLine: popup.outputsScoped ? popup.query.replace(/^\s*output\s+/i, "") : ""
  function sinkNodes() {
    const out = [];
    const all = Pipewire.nodes.values;
    for (let i = 0; i < all.length; ++i) {
      const n = all[i];
      if (n && n.audio && n.isSink && !n.isStream && String(n.name || "") !== "quickshell") out.push(n);
    }
    return out;
  }
  readonly property var outputRows: popup.outputsScoped
    ? Cynosure.outputRows(popup.sinkNodes().map((n) => ({ id: n.id, name: String(n.name || ""),
        label: String(n.nickname || "").trim() || String(n.description || "").trim() || String(n.name || "") })),
      Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.id : -1, popup.outputLine)
    : []
  onOutputRowsChanged: if (popup.outputsScoped) popup.applyFilter()
  function useOutput(row) {
    const n = popup.sinkNodes().find((x) => x.id === row.id);
    if (n) Pipewire.preferredDefaultAudioSink = n;
    popup.closeCynosure();
  }

  // ── COLORS YOU PICKED (2026-11-02) ────────────────────────────────────
  // "colors …": Picasso's picker palette (picker-palette.json); return
  // copies the hex, its actions rgb() and hsl()
  readonly property bool colorsScoped: /^\s*colors\s/i.test(popup.query)
  readonly property string colorLine: popup.colorsScoped ? popup.query.replace(/^\s*colors\s+/i, "") : ""
  property var palette: []
  onColorsScopedChanged: if (popup.colorsScoped) { paletteCat.running = false; paletteCat.running = true; }
  Cat {
    id: paletteCat
    path: Quickshell.statePath("picker-palette.json")
    onDone: (text) => {
      let j = null;
      try { j = JSON.parse(text); } catch (e) {}
      popup.palette = Array.isArray(j) ? j.filter((x) => typeof x === "string" && /^#[0-9a-f]{6}$/i.test(x)) : [];
      popup.applyFilter();
    }
  }

  // ── FAVORITES (2026-11-02) ────────────────────────────────────────────
  // rows you keep at the top of the empty line (Cynosure.favoriteRows), set
  // from shift return's menu
  property var favorites: []
  Cat {
    id: favoritesCat
    path: Cynosure.favoritesPath()
    onDone: (text) => { popup.favorites = Cynosure.parseFavorites(text); popup.applyFilter(); }
  }
  function setFavorites(list) {
    popup.favorites = list;
    writer.write(Cynosure.favoritesPath(), Cynosure.serializeFavorites(list));
    popup.applyFilter();
  }

  // ── WHAT IS HIGHLIGHTED, AS THE LINE (2026-11-02) ─────────────────────
  // Super+Shift+Space: the text highlighted anywhere (the primary
  // selection) typed into the field, so the calculator, the dictionary, a
  // color or a conversion answer it at once. With no primary selection —
  // misc:middle_click_paste off takes it away entirely — the text last
  // copied instead (user, 2026-11-02); a copied picture is not text, and
  // the panel opens empty.
  Process {
    id: selectionProc
    command: ["sh", "-c", "wl-paste --primary --no-newline --type text 2>/dev/null || wl-paste --no-newline --type text 2>/dev/null"]
    stdout: StdioCollector {
      id: selectionOut
      waitForEnd: true
      onStreamFinished: {
        // one line, and not a page of it
        const t = selectionOut.text.replace(/\s+/g, " ").trim().slice(0, 300);
        popup.openCynosure();
        popup.untake();
        popup.setLine(t);
        input.cursorPosition = input.text.length;
      }
    }
  }

  // ── PLACES (2026-11-02) ───────────────────────────────────────────────
  // "go …": terminus' bookmarks and network places and the directories
  // artemis has opened most (Cynosure.placeRows), read each time the word is
  // typed; return opens Terminus there, a place not connected connects
  // first (Terminus place)
  readonly property bool placesScoped: /^\s*go\s/i.test(popup.query)
  readonly property string placeLine: popup.placesScoped ? popup.query.replace(/^\s*go\s+/i, "") : ""
  property var termBookmarks: []
  property var netPlaces: []
  property var netMounts: []
  onPlacesScopedChanged: if (popup.placesScoped) {
    bookmarksCat.running = false; bookmarksCat.running = true;
    netPlacesCat.running = false; netPlacesCat.running = true;
    if (!mountsProc.running) mountsProc.running = true;
  }
  Cat {
    id: bookmarksCat
    path: Quickshell.statePath("terminus-bookmarks")
    onDone: (text) => {
      popup.termBookmarks = text.split("\n").map((l) => l.trim()).filter((l) => l !== "");
      popup.applyFilter();
    }
  }
  Cat {
    id: netPlacesCat
    path: Quickshell.statePath("terminus-network.json")
    onDone: (text) => { popup.netPlaces = TermNet.parsePlaces(text); popup.applyFilter(); }
  }
  Process {
    id: mountsProc
    command: ["python3", "-I", Quickshell.shellDir + "/terminus/net/netplaces.py", "list"]
    stdout: StdioCollector {
      id: mountsOut
      waitForEnd: true
      onStreamFinished: {
        let j = null;
        try { j = JSON.parse(mountsOut.text); } catch (e) {}
        popup.netMounts = j && j.ok ? j.mounts || [] : [];
        popup.applyFilter();
      }
    }
  }
  readonly property var placeRows: popup.placesScoped
    ? Cynosure.placeRows(popup.termBookmarks, TermNet.rows(popup.netPlaces, popup.netMounts),
        popup.finder ? Artemis.freqRanked(popup.finder.freq, 300).filter((f) => f.isDir).slice(0, 12).map((f) => f.path) : [],
        popup.placeLine, Quickshell.env("HOME"), Icons.glyphFor)
    : []
  function openPlace(row) {
    popup.closeThen(() => Quickshell.execDetached(row.path !== ""
      ? ["qs", "ipc", "call", "Terminus", "open", row.path] : ["qs", "ipc", "call", "Terminus", "place", row.uri]));
  }

  // ── WINDOWS, PUT SOMEWHERE (2026-11-02) ───────────────────────────────
  // "left half", "maximize", "next screen", "size 1280x720" for the window
  // you were in, and the same from a window row's actions: floated, then
  // sized and moved to the screen it is on (Cynosure.snapRect), in one ask
  // so the order holds (a floating resize grows about the middle; the
  // move after it puts it right)
  Process {
    id: snapProc
    property var job: null
    property var queue: []
    readonly property var snapCmd: ["sh", "-c", "hyprctl monitors -j; printf '\\036'; hyprctl clients -j; printf '\\036'; hyprctl getoption general:gaps_out -j"]
    onExited: RunJob.next(snapProc)
    stdout: StdioCollector {
      id: snapOut
      waitForEnd: true
      onStreamFinished: {
        const parts = snapOut.text.split("\u001e");
        let mons = [], clients = [];
        try { mons = JSON.parse(parts[0]); clients = JSON.parse(parts[1]); } catch (e) { return; }
        const job = snapProc.job;
        if (!job) return;
        const addr = job.address;
        // quickshell's address has no 0x, hyprctl's has
        const bare = (a) => String(a || "").replace(/^0x/, "");
        const c = addr !== "" ? clients.find((x) => bare(x.address) === bare(addr))
          : clients.slice().sort((a, b) => a.focusHistoryID - b.focusHistoryID)[0];
        if (!c) return;
        const mon = mons.find((m) => m.id === c.monitor) || mons.find((m) => m.focused);
        if (!mon) return;
        const sel = Hypr.byAddress(c.address);
        const lead = [Hypr.focusWindow(sel), Hypr.raiseWindow(sel)];
        // "restore": as it was before the first time it was put somewhere
        if (job.where === "restore") {
          const was = popup.snapWas[c.address];
          if (!was) return;
          delete popup.snapWas[c.address];
          popup.dispatchLater(lead.concat(was.floating
            ? [Hypr.floatOn(), Hypr.resizeTo(was.w, was.h), Hypr.moveTo(was.x, was.y)] : [Hypr.floatOff()]));
          return;
        }
        // "center" keeps the size it has; larger, smaller and the widths go
        // from where it is
        const own = { x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1] };
        const size = ["center", "grow", "shrink", "maxW", "maxH"].indexOf(job.where) >= 0 ? own : job.size;
        const r = Cynosure.snapRect(mon, Cynosure.gapsOf(parts[2]), job.where, size);
        if (!r) return;
        if (!popup.snapWas[c.address] && Oracle.cynosureRememberPlaces)
          popup.snapWas[c.address] = { floating: !!c.floating, x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1] };
        popup.dispatchLater(lead.concat([Hypr.floatOn(), Hypr.resizeTo(r.w, r.h), Hypr.moveTo(r.x, r.y)]));
      }
    }
  }
  // the theme "dark mode" / "light mode" moves to: Follow Background keeps
  // following, its tone pinned; Follow Daytime gives way to its own day or
  // night theme; any other its other side (Cynosure.themeSide). Null when
  // already there.
  function appearanceTarget(light) {
    if (Zenon.light === light) return null;
    if (Oracle.theme === "follow") return "follow";
    if (Oracle.theme === "sun") return light ? Oracle.themeDay : Oracle.themeNight;
    return Cynosure.themeSide(Oracle.theme, light, Oracle.themeOptions);
  }
  // every window but the suite's own, closed as its close button would
  function quitAll() { popup.closeWindowsOf((app) => app !== "org.quickshell"); }
  // the windows whose app id `want(appId)` takes, each closed as its close
  // button would
  function closeWindowsOf(want) {
    for (const t of Hyprland.toplevels.values)
      if (t.wayland && want(String(t.wayland.appId || ""))) Hyprland.dispatch(Hypr.closeWindow(Hypr.byAddress(t.address)));
  }
  // every removable drive's partitions unmounted, then the drive powered
  // off; what it did said in a toast
  readonly property string ejectScript: "n=0; for d in $(lsblk -dnpo NAME,RM,TYPE | awk '$2==1 && $3==\"disk\" {print $1}'); do "
    + "for p in $(lsblk -lnpo NAME,MOUNTPOINT \"$d\" | awk 'NF==2 {print $1}'); do udisksctl unmount -b \"$p\" >/dev/null 2>&1; done; "
    + "udisksctl power-off -b \"$d\" >/dev/null 2>&1 && n=$((n+1)); done; "
    + "if [ $n -gt 0 ]; then notify-send -a stylus -- 'Safe to unplug' \"$n removable drive(s) ejected\"; "
    + "else notify-send -a stylus -- 'Nothing to eject' 'no removable drive is plugged in'; fi"
  // the next meeting: the first event from now to tomorrow, not yet over,
  // with a link where a video call's would be (Answers.meetingLink)
  Process {
    id: meetProc
    command: ["sh", "-c", "python3 -I \"$1\" list \"$(date +%F)\" \"$(date -d tomorrow +%F)\"", "cynosure", Chronos.calCore]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        let evs = [];
        try { evs = JSON.parse(text).events || []; } catch (e) {}
        const hit = Answers.nextMeeting(evs, new Date());
        if (hit) Strings.openLink(hit.url);
        else Quickshell.execDetached(["notify-send", "-a", "chronos", "--", "No meeting to join",
          "nothing on your calendar today or tomorrow has a call link"]);
      }
    }
  }
  readonly property string restartScript: "pid=$(pgrep -i -x -o -- \"$1\") || exit 1\n"
    + "mapfile -d '' args < /proc/$pid/cmdline; cwd=$(readlink /proc/$pid/cwd)\n"
    + "pkill -i -x -- \"$1\"\n"
    + "for i in $(seq 100); do pgrep -i -x -- \"$1\" >/dev/null || break; sleep 0.1; done\n"
    + "cd \"${cwd:-$HOME}\" 2>/dev/null || cd\n"
    + "setsid -f \"${args[@]}\" >/dev/null 2>&1 </dev/null\n"
  // a quick link opened: `{clipboard}` / `{selection}` read first (the
  // clipboard and the primary selection, as text)
  function openQuickLink(url, app) {
    if (!Cynosure.wantsDesk(url)) { popup.openLinkIn(url, app); return; }
    // in turn, each with its own link (audit 11-09: a second one while the
    // first read the clipboard was lost)
    RunJob.queued(deskProc, { url: url, app: app || "", command: popup.deskCmd });
  }
  // in the browser the link was set to (2026-11-04), else the default one;
  // only a web address goes to the app
  function openLinkIn(url, app) {
    if (app && /^https?:\/\//i.test(url) && /^[\w.-]+$/.test(app))
      Quickshell.execDetached(["gtk-launch", app, url]);
    else Strings.openLink(url);
  }
  // the apps that open https, for a quick link's "Always open in …"
  property var browsers: []
  Process {
    id: browsersProc
    running: true
    command: ["sh", "-c", "for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" $(printf '%s' \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr ':' ' '); do "
      + "grep -l 'x-scheme-handler/https' \"$d\"/applications/*.desktop 2>/dev/null | while read -r f; do grep -m1 -H '^Name=' \"$f\"; done; done"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: popup.browsers = Cynosure.parseBrowsers(text)
    }
  }
  function setLinkApp(r, app, appName) {
    popup.ownLinks = Cynosure.withLinkApp(popup.ownLinks, r.word, app, appName);
    popup.writeLinks();
    popup.rebuild();
  }
  readonly property var deskCmd: ["sh", "-c", "wl-paste -n -t text 2>/dev/null | head -c 2000; printf '\\036'; wl-paste -p -n -t text 2>/dev/null | head -c 2000"]
  Process {
    id: deskProc
    property var job: null
    property var queue: []
    onExited: RunJob.next(deskProc)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const j = deskProc.job;
        if (!j) return;
        const parts = String(text).split("\u001e");
        popup.openLinkIn(Cynosure.fillLinkFrom(j.url, parts[0], parts[1] || ""), j.app);
      }
    }
  }
  // ── WINDOW LAYOUTS (2026-11-03) ──────────────────────────────────────
  // "save layout coding": every window's app, workspace and (floating) place,
  // kept in cynosure-layouts.json; "layout coding" puts the open ones back,
  // each app's windows matched in turn (the same title first), opens the
  // apps that are missing and, a few seconds later, places those too. Tiled
  // windows go to their workspace; the tiling arranges them there.
  property var layouts: ({})
  FileView {
    id: layoutsFile
    path: Paths.dataDir() + "/cynosure-layouts.json"
    blockLoading: true
    printErrors: false
    Component.onCompleted: { try { popup.layouts = JSON.parse(layoutsFile.text()) || {}; } catch (e) { popup.layouts = {}; } }
  }
  function writeLayouts(l) {
    popup.layouts = l;
    layoutsFile.setText(JSON.stringify(l, null, 2) + "\n");
  }
  function dropLayout(name) {
    const l = Object.assign({}, popup.layouts);
    delete l[name];
    popup.writeLayouts(l);
  }
  // each run with its own job, in turn (audit 2026-11-09): the flags were
  // the process's, and a save asked while a place ran (or its re-run after
  // the launches) turned one into the other, and the new ask was dropped
  readonly property var layoutCmd: ["sh", "-c", "hyprctl clients -j; printf '\\036'; hyprctl activeworkspace -j"]
  function saveLayout(name) { RunJob.queued(layoutProc, { saving: name, using: "", launch: false, command: popup.layoutCmd }); }
  function useLayout(name, launch) {
    RunJob.queued(layoutProc, { saving: "", using: name, launch: launch !== false, command: popup.layoutCmd });
  }
  Process {
    id: layoutProc
    property var job: null
    property var queue: []
    onExited: RunJob.next(layoutProc)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const job = layoutProc.job;
        if (!job) return;
        const parts = String(text).split("\u001e");
        let clients = [], here = null;
        try { clients = JSON.parse(parts[0]); here = JSON.parse(parts[1]); } catch (e) { return; }
        clients = clients.filter((c) => c.mapped && c.workspace && !String(c.workspace.name).startsWith("special"));
        if (job.saving !== "") {
          const l = Object.assign({}, popup.layouts);
          l[job.saving] = clients.map((c) => ({ cls: c.class, title: c.title, ws: String(c.workspace.name),
            floating: !!c.floating, x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1] }));
          popup.writeLayouts(l);
          return;
        }
        const want = popup.layouts[job.using] || [];
        const used = {};
        const steps = [];
        const missing = [];
        for (const w of want) {
          const free = clients.filter((c) => c.class === w.cls && !used[c.address]);
          const c = free.find((x) => x.title === w.title) || free[0];
          if (!c) { missing.push(w.cls); continue; }
          used[c.address] = true;
          const sel = Hypr.byAddress(c.address);
          steps.push(Hypr.focusWindow(sel), Hypr.moveToWorkspace(w.ws));
          if (w.floating) steps.push(Hypr.floatOn(), Hypr.resizeTo(w.w, w.h), Hypr.moveTo(w.x, w.y));
          else if (c.floating) steps.push(Hypr.floatOff());
        }
        if (here) steps.push(Hypr.focusWorkspace(String(here.name)));
        if (steps.length > 0) Quickshell.execDetached(Off.wanted(steps));
        // the apps not open: opened once, then placed when they have come up
        if (job.launch && missing.length > 0) {
          const seen = {};
          for (const cls of missing) {
            if (seen[cls]) continue;
            seen[cls] = true;
            const e = DesktopEntries.heuristicLookup(cls);
            if (e) e.execute();
          }
          layoutAgain.name = job.using;
          layoutAgain.restart();
        }
      }
    }
  }
  // placed again once the launched apps are up: no launching this time
  Timer { id: layoutAgain; property string name: ""; interval: Oracle.cynosureLayoutWait * 1000; onTriggered: popup.useLayout(layoutAgain.name, false) }
  // ── SNIPPET KEYWORDS, TYPED ANYWHERE (2026-11-03) ──────────────────────
  // keyword → snippet file (folio-keywords.json). While there is one,
  // expand.py reads the keyboards and says each keyword as it is typed;
  // here it is erased and the snippet typed in its place (wtype), its
  // placeholders filled as Folio fills them. Never while the screen is
  // locked.
  property var snipKeys: ({})
  FileView {
    id: snipKeysFile
    path: Folio.keywordsPath()
    blockLoading: true
    printErrors: false
    Component.onCompleted: popup.snipKeys = Folio.parseKeywords(snipKeysFile.text())
  }
  readonly property var snipWords: Object.keys(popup.snipKeys).sort()
  // a new list of words is a new run of the reader
  readonly property bool expanding: popup.snipWords.length > 0 && Oracle.cynosureExpand
  // ONE writer of `running`: it was a binding as well, and the first
  // assignment here (at startup, when the words load) cut it, so turning
  // Expand snippets off in Oracle left the reader typing (audit 2026-11-09)
  function restartExpander() { expander.running = false; Qt.callLater(() => expander.running = popup.expanding); }
  onSnipWordsChanged: popup.restartExpander()
  onExpandingChanged: popup.restartExpander()
  Process {
    id: expander
    command: Paths.tether(["python3", "-I", Quickshell.shellDir + "/cynosure/bin/expand.py"].concat(popup.snipWords))
    stdout: SplitParser { onRead: (kw) => popup.expandKeyword(String(kw).trim()) }
  }
  function expandKeyword(kw) {
    const path = popup.snipKeys[kw];
    if (!path || Kairos.locked) return;
    RunJob.queued(expandProc, { word: kw, fromFile: true,
      command: ["sh", "-c", "cat -- \"$1\"; printf '\\036'; wl-paste -n -t text 2>/dev/null | head -c 100000", "cynosure", path] });
  }
  Process {
    id: expandProc
    // job: { word, fromFile — read from the snippet's file (a keyword
    // typed), not handed in filled }; one at a time, so two keywords typed
    // fast each take back their own word
    property var job: null
    property var queue: []
    onExited: RunJob.next(expandProc)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const job = expandProc.job;
        const t = String(text);
        const cut = t.indexOf("\u001e");
        if (cut < 0 || !job) return;
        // values to ask for first: the panel opens for them (askSnipArgs),
        // and types it all once they are given
        if (job.fromFile && Folio.snippetArgs(t.slice(0, cut)).length > 0) {
          popup.askSnipArgs(t.slice(0, cut), "type", job.word);
          return;
        }
        const x = Folio.expandSnippetAt(t.slice(0, cut), new Date(), t.slice(cut + 1));
        for (const argv of Folio.expandKeys(Array.from(job.word).length, x.text, x.back))
          Quickshell.execDetached(argv);
      }
    }
  }
  // ── LOOKUPS (2026-11-03): bm, browsed, github, music, videos, menu ──
  Lookups {
    id: lookups
    query: popup.mode === "search" && !popup.taken ? popup.query : ""
    shown: popup.shown
    onChanged: popup.applyFilter()
  }
  // where a window was before it was first put somewhere, by address, for
  // "restore" (for as long as the shell runs)
  property var snapWas: ({})
  // the window "left half" will move: the one you were in
  function lastWindowName() {
    const t = Hyprland.activeToplevel;
    return t ? String(t.title || "") : "No window";
  }
  function snapWindow(address, where, size) {
    if (where === "next" || where === "prev") {
      const steps = address !== "" ? [Hypr.focusWindow(Hypr.byAddress(address)), Hypr.raiseWindow(Hypr.byAddress(address))] : [];
      popup.closeCynosure();
      popup.dispatchLater(steps.concat([Hypr.moveToMonitor(where === "next" ? "+1" : "-1")]));
      return;
    }
    RunJob.queued(snapProc, { command: snapProc.snapCmd, address, where, size: size || null });
    popup.closeCynosure();
  }

  // ── PROCESSES AND PORTS (2026-11-02) ──────────────────────────────────
  // "ps …": what runs, the busiest first, read again a beat after each key;
  // "port 8080": what listens there. Return ends it on the one-line confirm.
  readonly property bool procsScoped: /^\s*ps\s/i.test(popup.query)
  readonly property bool portScoped: /^\s*port\s+\d{1,5}\s*$/i.test(popup.query)
  readonly property string procLine: popup.procsScoped ? popup.query.replace(/^\s*ps\s+/i, "")
    : popup.portScoped ? popup.query.replace(/^\s*port\s+/i, "").trim() : ""
  property var procRows: []
  onProcLineChanged: if (popup.procsScoped || popup.portScoped) procLater.restart()
  onProcsScopedChanged: if (popup.procsScoped) procLater.restart()
  Timer { id: procLater; interval: 150; onTriggered: popup.askProcs() }
  function askProcs() {
    if (procProc.running) { procProc.again = true; return; }
    procProc.port = popup.portScoped;
    procProc.asked = popup.procLine;
    procProc.command = popup.portScoped ? ["ss", "-ltnupH"]
      : ["ps", "-eo", "pid=,pcpu=,rss=,comm=,args=", "--sort=-pcpu"];
    procProc.running = true;
  }
  Process {
    id: procProc
    property bool port: false
    property string asked: ""
    property bool again: false
    onExited: if (procProc.again) { procProc.again = false; Qt.callLater(popup.askProcs); }
    stdout: StdioCollector {
      id: procOut
      waitForEnd: true
      onStreamFinished: {
        // "ps 8080" and "port 8080" ask the same line: the kind too (11-09)
        if (procProc.asked !== popup.procLine || procProc.port !== popup.portScoped) return;
        popup.procRows = procProc.port ? Cynosure.portRows(procOut.text, procProc.asked)
          : Cynosure.processRows(procOut.text, procProc.asked, 0);
        popup.applyFilter();
      }
    }
  }
  function endProcess(row, force) {
    // noBump: a name with a pid in it is a new key every time, and each
    // quit grew the frequency file for good (audit 2026-11-09)
    popup.pending = { name: (force ? "Force quit " : "Quit ") + row.name + " (" + row.pid + ")", glyph: row.glyph, confirm: true, noBump: true,
      sh: "kill " + (force ? "-KILL " : "") + "-- " + row.pid };
    popup.showPicker();
    popup.sel = popup.pickerRows.length - 1;
  }

  // ── BLUETOOTH AND WI-FI (2026-11-02) ──────────────────────────────────
  // "bt …" and "wifi …": the control hub's devices and networks; return
  // connects or leaves. A network that needs a password Hermes has not got
  // is asked for in the control hub, where the password field is.
  readonly property bool btScoped: /^\s*bt\s/i.test(popup.query)
  readonly property bool wifiScoped: /^\s*wifi\s/i.test(popup.query)
  readonly property string radioLine: popup.btScoped ? popup.query.replace(/^\s*bt\s+/i, "")
    : popup.wifiScoped ? popup.query.replace(/^\s*wifi\s+/i, "") : ""
  // "wifi off" is the switch, not a network called "off"
  readonly property string radioFind: popup.cmd ? "" : popup.radioLine
  readonly property var radioRows: popup.btScoped
    ? Cynosure.deviceRows(Hermes.devices.map((d) => Object.assign({}, d, { glyph: HermesJs.btGlyph(d.icon) })), popup.radioFind)
    : popup.wifiScoped
    ? Cynosure.networkRows(Hermes.networks.map((n) => Object.assign({}, n, { glyph: HermesJs.wifiGlyph(n.strength),
        secure: !HermesJs.securityOpen(n.security) })), popup.radioFind)
    : []
  onRadioRowsChanged: if (popup.btScoped || popup.wifiScoped) popup.applyFilter()
  function radioDo(row) {
    if (row.kind === "btdev") {
      Hermes.toggleDevice(row.dev);
      popup.closeCynosure();
      return;
    }
    const r = Hermes.join(row.net, "");
    if (r === "ask") popup.closeThen(() => Hermes.open("network"));
    else popup.closeCynosure();
  }

  // ── REPOSITORIES (2026-11-02) ─────────────────────────────────────────
  // "repo …": Delphi's recent repositories, with git's word on each
  readonly property bool reposScoped: /^\s*repo\s/i.test(popup.query)
  readonly property string repoLine: popup.reposScoped ? popup.query.replace(/^\s*repo\s+/i, "") : ""
  property var repoRecents: []
  property var repoState: ({})
  onReposScopedChanged: if (popup.reposScoped) { delphiCat.running = false; delphiCat.running = true; }
  Cat {
    id: delphiCat
    path: Quickshell.statePath("delphi.json")
    onDone: (text) => {
      let j = null;
      try { j = JSON.parse(text); } catch (e) {}
      popup.repoRecents = j && Array.isArray(j.recents)
        ? j.recents.filter((r) => r && typeof r.root === "string").map((r) => ({ root: r.root, name: String(r.name || Terminus.basename(r.root)) }))
        : [];
      popup.applyFilter();
      if (popup.repoRecents.length > 0 && !repoProc.running) {
        repoProc.command = ["sh", "-c", Cynosure.repoStatusCommand(), "cynosure"].concat(popup.repoRecents.map((r) => r.root));
        repoProc.running = true;
      }
    }
  }
  Process {
    id: repoProc
    stdout: StdioCollector {
      id: repoOut
      waitForEnd: true
      onStreamFinished: { popup.repoState = Cynosure.repoStatus(repoOut.text); popup.applyFilter(); }
    }
  }
  function openRepo(row) {
    popup.closeThen(() => Quickshell.execDetached(["qs", "ipc", "call", "Delphi", "open", row.path]));
  }

  // ── SERVICES (2026-11-02) ─────────────────────────────────────────────
  // "svc …": Hestia's reading of systemd (hestia.py units, the system's and
  // yours); return opens it in Hestia, start/stop/restart go through
  // Hestia's own act (polkit, or Ceres' password card)
  readonly property bool servicesScoped: /^\s*svc\s/i.test(popup.query)
  readonly property string serviceLine: popup.servicesScoped ? popup.query.replace(/^\s*svc\s+/i, "") : ""
  property var units: []
  onServicesScopedChanged: if (popup.servicesScoped && !unitsProc.running) unitsProc.running = true
  Process {
    id: unitsProc
    command: ["sh", "-c", "python3 -I \"$1\" units system; printf '\\036'; python3 -I \"$1\" units user", "cynosure",
      Quickshell.shellDir + "/hestia/core/hestia.py"]
    stdout: StdioCollector {
      id: unitsOut
      waitForEnd: true
      onStreamFinished: {
        let all = [];
        for (const part of unitsOut.text.split("\u001e")) {
          try { const j = JSON.parse(part); if (Array.isArray(j)) all = all.concat(j); } catch (e) {}
        }
        popup.units = all;
        popup.applyFilter();
      }
    }
  }
  function serviceDo(row, verb) {
    Quickshell.execDetached(["qs", "ipc", "call", "Hestia", "act", row.scope, verb, row.unit]);
    popup.closeCynosure();
  }

  // ── NOTIFICATIONS (2026-11-02) ────────────────────────────────────────
  // "notif …": Howler's history; return does what its toast did
  readonly property bool notifsScoped: /^\s*notif\s/i.test(popup.query)
  readonly property string notifLine: popup.notifsScoped ? popup.query.replace(/^\s*notif\s+/i, "") : ""

  // ── A CLIP, PASTED OTHERWISE (2026-11-02) ─────────────────────────────
  // shift return's "Paste as …" on a text clip: decoded, changed
  // (Cynosure.transformText), typed into the window you were in as a
  // snippet is (folio.js pasteSnippetCommand)
  function pasteAs(row, id) {
    popup.folio.decodeText(row.id, (t) => {
      const out = Cynosure.transformText(id, t);
      if (out === null) {
        Quickshell.execDetached(["notify-send", "-a", "Cynosure", "--", "Not pasted", "That clip is not JSON"]);
        return;
      }
      popup.closeCynosure();
      Quickshell.execDetached(["sh", "-c", Folio.pasteSnippetCommand(out, 0)]);
    });
  }

  // ── HELP (2026-11-02) ─────────────────────────────────────────────────
  // "?" or "help", alone or with words to find among: every word and phrase
  // Cynosure reads (Cynosure.helpRows), yours too; return types it in
  readonly property bool helpScoped: popup.mode === "search" && /^\s*(\?|help)(\s|$)/i.test(popup.query)
  readonly property string helpLine: popup.helpScoped ? popup.query.replace(/^\s*(\?|help)\s*/i, "") : ""

  // ── SCRIPTS THAT LIST, SCRIPTS THAT SAY (2026-11-02) ──────────────────
  // @mode list: its word and a space run it (the words after as $1), a beat
  // after each key, and what it prints is the list (Cynosure.parseListItems).
  // @mode inline: run on every open, what it prints its row's second line;
  // @refresh runs it again while the panel is up.
  readonly property var scriptList: popup.mode === "search" ? Cynosure.scriptListFor(popup.scripts, popup.query) : null
  readonly property string scriptListKey: popup.scriptList ? popup.scriptList.script.path + "\u0000" + popup.scriptList.arg : ""
  property var listRows: []
  onScriptListKeyChanged: {
    if (popup.scriptListKey === "") { popup.listRows = []; return; }
    listLater.restart();
  }
  Timer { id: listLater; interval: 200; onTriggered: popup.runListScript() }
  function runListScript() {
    const sl = popup.scriptList;
    if (!sl) return;
    // the newest query replaces a run still going (audit 11-09: it waited
    // behind it, up to the 10 s timeout for a slow script)
    RunJob.latest(listProc, { asked: popup.scriptListKey, script: sl.script,
      command: ["timeout", "10", "sh", "-c", "if [ -x \"$1\" ]; then exec \"$@\"; else exec sh \"$@\"; fi",
        "cynosure", sl.script.path].concat(sl.arg !== "" ? [sl.arg] : []) });
  }
  Process {
    id: listProc
    property var job: null
    property var want: null
    onExited: RunJob.next(listProc)
    stdout: StdioCollector {
      id: listOut
      waitForEnd: true
      onStreamFinished: {
        const j = listProc.job;
        if (!RunJob.current(listProc) || j.asked !== popup.scriptListKey) return;
        popup.listRows = Cynosure.listItemRows(j.script, Cynosure.parseListItems(listOut.text));
        popup.applyFilter();
      }
    }
  }
  function runListItem(row) {
    const it = row.item;
    popup.closeCynosure();
    if (it.open !== "") {
      if (/^[a-z][\w+.-]*:/i.test(it.open)) Strings.openLink(it.open);
      else Quickshell.execDetached(["gio", "open", it.open.replace(/^~(?=\/|$)/, Quickshell.env("HOME"))]);
    } else if (it.paste !== "") {
      Quickshell.execDetached(["sh", "-c", Folio.pasteSnippetCommand(it.paste, 0)]);
    } else if (it.run !== "") {
      Quickshell.execDetached(["setsid", "-f", "sh", "-c", it.run]);
    } else {
      popup.copyText(it.copy !== "" ? it.copy : it.title);
    }
  }
  // what each inline script last printed, by path
  property var scriptSaid: ({})
  readonly property var inlineScripts: popup.scripts.filter((sc) => sc.mode === "inline")
  function runInlineScripts(all) {
    const now = Date.now();
    for (const sc of popup.inlineScripts) {
      if (!all && !(sc.refresh > 0 && now - (popup.inlineAt[sc.path] || 0) >= sc.refresh)) continue;
      // one run per script: a slow one is not stacked up behind itself
      if (popup.inlineLive[sc.path]) continue;
      popup.inlineAt[sc.path] = now;
      popup.inlineLive[sc.path] = true;
      const p = inlineComp.createObject(popup, { path: sc.path });
      p.running = true;
    }
  }
  // run when the scripts are read (scriptsProc), not again on the list
  // changing: that is the same reading, and each ran twice an open
  property var inlineAt: ({})
  property var inlineLive: ({})
  Component {
    id: inlineComp
    Process {
      id: ip
      property string path: ""
      command: ["timeout", "10", "sh", "-c", "if [ -x \"$1\" ]; then exec \"$@\"; else exec sh \"$@\"; fi", "cynosure", ip.path]
      stdout: StdioCollector {
        id: ipOut
        waitForEnd: true
        onStreamFinished: {
          const said = Object.assign({}, popup.scriptSaid);
          said[ip.path] = ipOut.text.trim();
          popup.scriptSaid = said;
          popup.rebuild();
        }
      }
      onExited: { delete popup.inlineLive[ip.path]; ip.destroy(); }
    }
  }
  // the shortest @refresh asked for, while the panel is up
  Timer {
    interval: Math.max(1000, Math.min.apply(null, [3600000].concat(popup.inlineScripts.filter((sc) => sc.refresh > 0).map((sc) => sc.refresh))))
    repeat: true
    running: popup.shown && popup.inlineScripts.some((sc) => sc.refresh > 0)
    onTriggered: popup.runInlineScripts(false)
  }

  // ── WORDS INSIDE FILES (2026-11-02) ───────────────────────────────────
  // "in …": ripgrep through home (Cynosure.contentCommand), a beat after the
  // last key, a run in flight stopped for the newer one; return opens the
  // file at the line in Plato
  readonly property bool hitsScoped: /^\s*in\s/i.test(popup.query)
  readonly property string hitLine: popup.hitsScoped ? popup.query.replace(/^\s*in\s+/i, "").trim() : ""
  property var hitRows: []
  onHitLineChanged: {
    if (popup.hitLine.length < 3) { hitLater.stop(); RunJob.drop(hitProc); popup.hitRows = []; popup.applyFilter(); return; }
    hitLater.restart();
  }
  Timer { id: hitLater; interval: 300; onTriggered: popup.askHits() }
  function askHits() {
    RunJob.latest(hitProc, { asked: popup.hitLine,
      command: ["sh", "-c", Cynosure.contentCommand(popup.hitLine, Quickshell.env("HOME"))] });
  }
  Process {
    id: hitProc
    property var job: null
    property var want: null
    onExited: RunJob.next(hitProc)
    stdout: StdioCollector {
      id: hitOut
      waitForEnd: true
      onStreamFinished: {
        if (!hitProc.job || hitProc.job.asked !== popup.hitLine) return;
        popup.hitRows = Cynosure.contentRows(hitOut.text, Quickshell.env("HOME"), Icons.glyphFor);
        popup.applyFilter();
      }
    }
  }
  function openHit(row) {
    popup.closeThen(() => Quickshell.execDetached(["qs", "ipc", "call", "Plato", "openAt", row.path, String(row.line)]));
  }

  // ── FONTS (2026-11-02) ────────────────────────────────────────────────
  // "font …": the installed families by Alexandria's reading of fc-list,
  // read the first time the word is typed in a session
  readonly property bool fontsScoped: /^\s*font\s/i.test(popup.query)
  readonly property string fontLine: popup.fontsScoped ? popup.query.replace(/^\s*font\s+/i, "") : ""
  property var fontFamilies: []
  onFontsScopedChanged: if (popup.fontsScoped && popup.fontFamilies.length === 0 && !fontsProc.running) fontsProc.running = true
  Process {
    id: fontsProc
    command: ["sh", "-c", Alex.listCommand()]
    stdout: StdioCollector {
      id: fontsOut
      waitForEnd: true
      onStreamFinished: {
        popup.fontFamilies = Alex.parseList(fontsOut.text, Quickshell.env("HOME"), Ora.familyOf);
        popup.applyFilter();
      }
    }
  }
  function openFont(row) {
    popup.closeThen(() => Quickshell.execDetached(["qs", "ipc", "call", "Alexandria", "open", row.files.join("\n")]));
  }

  // ── SCREENSHOTS AND RECORDINGS (2026-11-02) ───────────────────────────
  // "shots …" and "rec …": the newest captures as a grid of thumbnails
  // (the shell's one pool, morpheus/thumbs.js); return opens a picture in
  // Picasso, a recording in Argus to cut
  readonly property bool shotsScoped: /^\s*shots\s/i.test(popup.query)
  readonly property bool recsScoped: /^\s*rec\s/i.test(popup.query)
  readonly property string captureLine: popup.shotsScoped ? popup.query.replace(/^\s*shots\s+/i, "")
    : popup.recsScoped ? popup.query.replace(/^\s*rec\s+/i, "") : ""
  property string capturesFound: ""
  property var captureThumbs: ({})
  readonly property bool capturesVideo: popup.recsScoped
  onShotsScopedChanged: if (popup.shotsScoped) popup.askCaptures()
  onRecsScopedChanged: if (popup.recsScoped) popup.askCaptures()
  function askCaptures() {
    popup.capturesFound = "";
    // `video` on the run's own job: set on the process, a shots run still
    // out when Tab went to rec passed the check as the recordings (audit
    // 2026-11-09)
    RunJob.latest(capturesProc, { video: popup.capturesVideo,
      command: ["sh", "-c", Cynosure.capturesCommand(popup.capturesVideo)] });
  }
  Process {
    id: capturesProc
    property var job: null
    property var want: null
    onExited: RunJob.next(capturesProc)
    stdout: StdioCollector {
      id: capturesOut
      waitForEnd: true
      onStreamFinished: {
        if (!RunJob.current(capturesProc)) return;
        const video = capturesProc.job.video;
        if (video !== popup.capturesVideo) return;
        popup.capturesFound = capturesOut.text;
        popup.applyFilter();
        const jobs = capturesOut.text.split("\n").filter((l) => l.indexOf("\t") > 0)
          .map((l) => ({ kind: video ? "v" : "i", src: l.slice(l.indexOf("\t") + 1) }));
        if (jobs.length === 0) return;
        // in turn: a batch asked while one is made is made after it
        RunJob.queued(thumbsProc, { command: ["sh", "-c", Thumbs.generate(jobs, false)] });
      }
    }
  }
  Process {
    id: thumbsProc
    property var job: null
    property var queue: []
    onExited: RunJob.next(thumbsProc)
    stdout: StdioCollector {
      id: thumbsOut
      waitForEnd: true
      onStreamFinished: {
        popup.captureThumbs = Object.assign({}, popup.captureThumbs, Thumbs.parseMade(thumbsOut.text));
        popup.applyFilter();
      }
    }
  }
  readonly property var captureRows: popup.shotsScoped || popup.recsScoped
    ? Cynosure.captureRows(popup.capturesFound, popup.captureLine, popup.captureThumbs, popup.picsPer, popup.capturesVideo)
    : []
  function openCapture(c) {
    popup.closeThen(() => Quickshell.execDetached(c.video ? ["qs", "ipc", "call", "Argus", "edit", c.path]
      : ["qs", "ipc", "call", "Picasso", "view", c.path]));
  }

  // ── CLIO'S NOTES, IN THE LIST ─────────────────────────────────────────
  // "notes …" searches the notebook (Cynosure.noteRows), "note …" makes one
  // of the words; once the notebook is read (the first "notes"), any line
  // shows the few whose title it starts. Return opens the note in Clio.
  readonly property bool notesScoped: /^\s*notes\s/i.test(popup.query)
  readonly property bool newNoteScoped: /^\s*note\s/i.test(popup.query)
  readonly property string notesLine: popup.notesScoped || popup.newNoteScoped
    ? popup.query.replace(/^\s*notes?\s+/i, "") : popup.query
  readonly property var clioNotes: Clio.app ? Clio.app.notes : []
  readonly property bool notesWanted: popup.mode === "search" && !popup.taken && !popup.calcShown && !popup.lexiAsk
    && !popup.newNoteScoped && !!Clio.app && (popup.notesScoped || (Clio.app.loaded && popup.notesLine.trim().length >= 3))
  onNotesScopedChanged: if (popup.notesScoped && Clio.app && !Clio.app.loaded) Clio.app.whenLoaded(() => popup.applyFilter())
  onClioNotesChanged: if (popup.shown && (popup.notesWanted || popup.tasksScoped)) popup.applyFilter()
  function openNote(row) {
    popup.closeThen(() => { if (Clio.app) Clio.app.openAt(row.id, ""); });
  }
  function saveNote(words, show) {
    popup.closeThen(() => { if (Clio.app) Clio.app.quickNote(words, show); });
  }

  // ── FILES, IN THE LIST ────────────────────────────────────────────────
  // artemis' index, asked a beat after the last key: a few under the
  // others for any line of two letters or more, all of them for "f …"
  // (and, with nothing after it, the files most opened).
  readonly property bool filesScoped: /^\s*f\s/i.test(popup.query)
  readonly property string fileLine: popup.filesScoped
    ? popup.query.replace(/^\s*f\s+/i, "").trim() : popup.query.trim()
  readonly property bool filesWanted: !!popup.finder && popup.mode === "search" && !popup.taken
    && !popup.calcShown && !popup.otherScoped && !popup.lexiAsk && (popup.filesScoped
      || (popup.fileLine.length >= 2 && !Cynosure.scopedRow(Cynosure.SHELL_ACTIONS, popup.query)))
  property var fileRows: []
  Timer {
    id: fileAsk
    interval: 120
    onTriggered: if (popup.finder) popup.finder.search(popup.filesWanted ? popup.fileLine : "")
  }
  onFileLineChanged: fileAsk.restart()
  onFilesWantedChanged: { fileAsk.restart(); popup.takeFiles(); }
  Connections {
    target: popup.finder
    function onRowsChanged() { popup.takeFiles(); }
    function onNoHandler(path) { popup.opening = false; openWith.ask(path); }
    function onOpened() { if (popup.opening) { popup.opening = false; popup.closeCynosure(); } }
  }
  // ── THE CLIPBOARD, IN THE LIST ────────────────────────────────────────
  // folio (folio/FolioView.qml, `embedded`), loaded unseen the first time
  // the line could want a clip and kept while the panel is up: its
  // entries, pictures, stamps and snippets are the Clipboard and Snippets
  // sections, and the rows act through it. Its snippet page alone is drawn
  // (from the top, like the dictionary) while a snippet is written.
  readonly property bool clipsScoped: /^\s*cb\s/i.test(popup.query)
  readonly property string clipLine: popup.clipsScoped
    ? popup.query.replace(/^\s*cb\s+/i, "") : popup.query
  readonly property bool clipsWanted: popup.mode === "search" && !popup.taken
    && (popup.clipsScoped || popup.clipLine.trim().length >= 2)
  property bool folioLatched: false
  onClipsWantedChanged: { if (popup.clipsWanted) popup.folioLatched = true; popup.takeClips(); }
  onClipLineChanged: popup.takeClips()
  readonly property var folio: folioLoader.item
  readonly property bool folioEditing: !!popup.folio && popup.folio.editing
  readonly property int folioH: popup.folioEditing ? popup.folio.calcHeight() : 0
  onFolioEditingChanged: if (!popup.folioEditing) Qt.callLater(() => input.forceActiveFocus())
  property var clipRows: []
  function takeClips() {
    const f = popup.folio;
    popup.clipRows = f && popup.clipsWanted
      ? Cynosure.clipRows(f.entries, f.imageIds, f.snippets, popup.clipLine, popup.clipsScoped,
          (id) => f.stampText(id),
          (id) => f.thumbsReady[id] ? Folio.thumbDir() + "/" + id + ".png" : "", popup.picsPer,
          { pins: f.pins, turn: f.turn, keywords: Folio.keywordsByPath(popup.snipKeys),
            glyphOf: Icons.glyphFor, home: Quickshell.env("HOME") })
      : [];
    popup.applyFilter();
  }
  // THE WORDS IN COPIED PICTURES (bin/clipocr.py, tesseract over each one)
  // were scrapped the day they came, 2026-11-04: reading the history's
  // pictures cost too much CPU (user). Don't bring them back.
  Connections {
    target: Oracle
    function onCynosureHiddenChanged() { popup.applyFilter(); }
    function onCynosureFallbackListChanged() { popup.applyFilter(); }
    function onCynosureSkinToneChanged() { popup.takeGlyphs(); }
  }
  Connections {
    target: popup.folio
    function onEntriesChanged() { popup.takeClips(); }
    function onPinsChanged() { popup.takeClips(); }
    function onTurnChanged() { popup.takeClips(); }
    function onSnippetsChanged() { popup.takeClips(); }
    function onThumbsReadyChanged() { popup.takeClips(); }
  }

  // ── EMOJI AND NERD GLYPHS, IN THE LIST ────────────────────────────────
  // ideo (ideo/IdeoCore.qml), loaded unseen like folio: its two
  // sets are strips of cells in the list (an Emoji strip for any line, "em
  // …" / "nf …" for them alone). The chosen strip's cell is `cellSel`,
  // moved with left and right; return pastes an emoji, copies a glyph.
  // ":heart" is "em heart" (2026-11-03), the way chat apps take emoji
  readonly property bool glyphsScoped: /^\s*(em|nf)\s/i.test(popup.query) || /^:[a-z+]/i.test(popup.query)
  readonly property bool glyphNerd: /^\s*nf\s/i.test(popup.query)
  readonly property string glyphLine: popup.glyphsScoped
    ? popup.query.replace(/^\s*(em|nf)\s+/i, "").replace(/^:/, "") : popup.query
  readonly property bool glyphsWanted: popup.mode === "search" && !popup.taken
    && (popup.glyphsScoped || popup.glyphLine.trim().length >= 2)
  readonly property int glyphsPer: 11
  // the pictures' grid: four to a row, tall enough to see what each is
  readonly property int picsPer: 4
  readonly property int picRowH: Zenon.px(150)
  readonly property int glyphRowH: Math.round(popup.rowH * 1.3)
  property bool ideoLatched: false
  onGlyphsWantedChanged: { if (popup.glyphsWanted) popup.ideoLatched = true; popup.takeGlyphs(); }
  onGlyphLineChanged: popup.takeGlyphs()
  onGlyphNerdChanged: popup.takeGlyphs()
  readonly property var ideo: ideoLoader.item
  property var glyphRows: []
  property int cellSel: 0
  function takeGlyphs() {
    const g = popup.ideo;
    if (g && popup.glyphsWanted) g.load(popup.glyphNerd ? "nerd" : "emoji");
    popup.glyphRows = g && popup.glyphsWanted
      ? Cynosure.glyphRows(popup.glyphNerd ? g.nerdCache : g.emojiCache, popup.glyphLine,
          popup.glyphNerd, popup.glyphsScoped, popup.glyphsPer,
          popup.glyphNerd ? popup.recentGlyphs.nerd : popup.recentGlyphs.emoji, Oracle.cynosureSkinTone)
      : [];
    popup.applyFilter();
  }
  // the emoji and glyphs last used (Cynosure.glyphsPath), leading the strips
  property var recentGlyphs: ({ emoji: [], nerd: [] })
  Cat {
    id: glyphsCat
    path: Cynosure.glyphsPath()
    onDone: (text) => { popup.recentGlyphs = Cynosure.parseGlyphs(text); popup.takeGlyphs(); }
  }
  function noteGlyph(ch, nerd) {
    popup.recentGlyphs = Cynosure.addGlyph(popup.recentGlyphs, ch, nerd);
    writer.write(Cynosure.glyphsPath(), JSON.stringify(popup.recentGlyphs));
  }
  Connections {
    target: popup.ideo
    function onEmojiCacheChanged() { popup.takeGlyphs(); }
    function onNerdCacheChanged() { popup.takeGlyphs(); }
  }
  onSelChanged: {
    Qt.callLater(popup.placeCellCursor);
    const c = popup.current;
    if (c && c.cells) popup.cellSel = Math.min(popup.cellSel, c.cells.length - 1);
  }
  // left and right along a strip, on into the strip before or after it
  function moveCell(d) {
    const c = popup.current;
    const i = popup.cellSel + d;
    if (i >= 0 && i < c.cells.length) { popup.cellSel = i; return; }
    const next = popup.filtered[popup.sel + d];
    if (!next || !next.cells) return;
    popup.sel += d;
    popup.cellSel = d > 0 ? 0 : next.cells.length - 1;
    popup.followSelection();
  }

  function takeFiles() {
    const f = popup.finder;
    let paths = [];
    if (popup.filesWanted && f) {
      if (popup.filesScoped && popup.fileLine === "")
        paths = f.frequent(30).map((r) => r.path);
      else if (f.answered === popup.fileLine)
        paths = f.rows.map((r) => r.path);
    }
    popup.fileRows = Cynosure.fileRows(paths.slice(0, popup.filesScoped ? 50 : 5),
      Quickshell.env("HOME"), Icons.glyphFor);
    popup.applyFilter();
  }
  // an open is out: the panel waits to hear whether anything opened it
  property bool opening: false
  // terminus' open-with card, for a file nothing opens — over the panel,
  // which dims under it; what is chosen on it is registered for the type
  Term.OpenWithLayer {
    id: openWith
    z: 50
    dim: panel
    onOpened: popup.closeCynosure()
    onCancelled: if (popup.shown) input.forceActiveFocus()
  }

  function followSelection() {
    Qt.callLater(() => {
      // the first row's heading is above it: Beginning, not Contain, keeps
      // it in sight when the cursor goes back to the top
      if (popup.sel === 0) list.positionViewAtBeginning();
      else list.positionViewAtIndex(popup.sel, ListView.Contain);
    });
  }

  function bump(key) {
    // Learn what you open off (Oracle): nothing new is kept
    if (!Oracle.cynosureRemember) return;
    popup.freqMap = Cynosure.bumpFreq(popup.freqMap, key);
    popup.writeFreq();
    if (popup.query.trim() !== "") {
      popup.picks = Cynosure.notePick(popup.picks, popup.query, key);
      writer.write(Cynosure.picksPath(), Cynosure.serializePicks(popup.picks));
    }
    // the new order and the new history row belong in the list itself, not
    // only in the files — nothing else was going to rebuild it
    popup.rebuild();
  }

  // ── THE CALCULATOR, IN THE LIST ───────────────────────────────────────
  // Metis whole (metis/MetisView.qml, `embedded`): made the first time the
  // line looks like a sum (or "calc …", "=…"), kept while the panel is up,
  // dropped when it closes. It works out THIS field's line as it is typed and
  // answers under a "Calculator" heading with its own answer block — the
  // reading, the answer large, its chips and strips (the user kept this over
  // a Raycast two-box card, 2026-11-01). The answer is the chosen row (sel
  // -1) whenever it is up, and while it is, return, ctrl+return, tab (its
  // chips), ctrl+e, ctrl+h and ctrl+r are the calculator's; down goes on
  // into the list.
  readonly property string calcLine: {
    const m = /^\s*calc\s+(.*)$/i.exec(popup.query);
    return m ? m[1].trim() : Cynosure.calcQuestion(popup.query);
  }
  // asked on purpose: "calc …" or a leading =; then even a line it cannot
  // read, or none (its recents and examples), is shown
  readonly property bool calcAsked: /^\s*(calc\s|=)/i.test(popup.query)
  // what metis' own front end makes of the line (pure: no process), for
  // the questions without a digit in them ("time in syd", "usd to eur")
  readonly property string calcKind: popup.calcLine.trim() === "" ? ""
    : Metis.prepare(popup.calcLine, { ans: "", vars: {} }).kind || ""
  // a question in plain words is answered by name, not by the calculator
  // ("#ff8800" is a color before it is a hex number)
  readonly property bool calcWanted: popup.mode === "search" && !popup.ask && !popup.cmd && !popup.lexiAsk
    && (popup.calcAsked || Cynosure.wantsCalc(popup.query, popup.calcKind))
  property bool calcLatched: false
  onCalcWantedChanged: {
    if (popup.calcWanted) popup.calcLatched = true;
    // the line, both ways: a calculator kept from the last open has no
    // onLoaded to hand it over (and the line changed before this did)
    if (popup.metis) popup.metis.setLine(popup.calcWanted ? popup.calcLine : "");
  }
  readonly property var metis: metisLoader.item
  // up while the line wants it and there is an answer (the last one stays,
  // dimmed, while the next is worked out) — or always, asked for by name
  readonly property bool calcShown: !!popup.metis && popup.calcWanted && !popup.taken
    && (popup.calcAsked || popup.metis.tapeMode || popup.metis.shownResult !== "")
  // a card is up over the list — the calculator's, or a smart answer's —
  // and while it is, it is the chosen row (sel -1) until the list is moved to
  readonly property bool cardUp: popup.calcShown || popup.answerShown || popup.lexiShown
  readonly property bool cardSel: popup.cardUp && popup.sel === -1
  onCardUpChanged: {
    if (popup.cardUp) popup.sel = -1;
    else if (popup.sel < 0) popup.sel = 0;
  }

  // ── COMMANDS THAT TAKE AN ARGUMENT ────────────────────────────────────
  // "volume 30", "brightness up", "timer 25m tea", "wifi off", "kill
  // firefox", "workspace 3", "next", an address (answers.js parseCommand):
  // a row first in the list saying what it will do and how things are now;
  // return does it through the app that owns it (Volume, Hermes, Chronos,
  // Howler's quiet, the player, Hyprland). Ending processes asks first.
  readonly property var cmd: popup.mode === "search" && !popup.taken ? Answers.parseCommand(popup.query) : null
  readonly property var cmdRow: popup.describeCmd(popup.cmd)
  // a command as its row: what it does, and how things stand now
  function describeCmd(c) {
    if (!c) return null;
    const onOff = (on) => on ? "On now" : "Off now";
    let label = "", glyph = "\uF0AD", sub = "";
    switch (c.kind) {
    case "volume":
      label = c.pct !== undefined ? "Set the volume to " + c.pct + "%" : c.step > 0 ? "Turn the volume up" : "Turn the volume down";
      glyph = "\uF028"; sub = Volume.ready ? (Volume.muted ? "Muted now" : "Now " + Volume.percent + "%") : "No sound device";
      break;
    case "mute":
      label = c.on ? "Mute" : "Unmute"; glyph = c.on ? "\uF6A9" : "\uF028";
      sub = Volume.ready ? (Volume.muted ? "Muted now" : "Now " + Volume.percent + "%") : "No sound device";
      break;
    case "brightness":
      label = c.pct !== undefined ? "Set the brightness to " + c.pct + "%" : c.step > 0 ? "Brighter" : "Dimmer";
      glyph = "\uF185"; sub = Hermes.screens.length > 0 ? "Now " + Hermes.screens[0].pct + "%" : "No screen that dims";
      break;
    case "wifi":
      label = "Turn Wi-Fi " + (c.on ? "on" : "off"); glyph = "\uF1EB";
      sub = Hermes.wifiReady ? onOff(Hermes.wifiOn) : "No Wi-Fi here";
      break;
    case "bluetooth":
      label = "Turn Bluetooth " + (c.on ? "on" : "off"); glyph = "\uF293";
      sub = Hermes.btReady ? onOff(Hermes.btOn) : "No Bluetooth here";
      break;
    case "night":
      label = "Turn the night light " + (c.on ? "on" : "off"); glyph = "\u{F0594}"; sub = onOff(Hermes.nightWanted);
      break;
    case "dnd":
      label = "Turn do not disturb " + (c.on ? "on" : "off"); glyph = "\uF1F6"; sub = onOff(Oracle.notifSilent);
      break;
    case "media":
      label = { play: "Play", pause: "Pause", next: "Next track", previous: "Previous track" }[c.act];
      glyph = { play: "\uF04B", pause: "\uF04C", next: "\uF051", previous: "\uF048" }[c.act];
      sub = NowPlaying.active && NowPlaying.title !== "" ? NowPlaying.title : "Nothing playing";
      break;
    case "workspace":
      label = "Go to workspace " + c.n; glyph = "\uF2D2";
      break;
    case "moveWs":
      label = "Move the window to workspace " + c.n; glyph = "\uF2D2"; sub = "The window you were in, and you with it";
      break;
    case "camera":
      label = "Camera"; glyph = "\uEADA"; sub = "Your camera, mirrored, in a window of its own. Nothing is kept";
      break;
    case "kill":
      label = (c.force ? "Force quit " : "Quit ") + c.name; glyph = "\uF00D";
      sub = c.force ? "Ends every process by that name, at once" : "Asks every process by that name to end";
      break;
    case "focus":
      label = (Kairos.focus ? "Restart focus for " : "Focus for ") + Answers.minutesText(c.minutes)
        + (c.label !== "Focus" ? " on " + c.label.toLowerCase() : "");
      glyph = "\u{F0E0F}";
      sub = Kairos.focus ? "On now, " + KairosJs.leftWords(Kairos.focus.until - Date.now()).toLowerCase()
        : Kairos.rules.block.length > 0 ? "Do not disturb on, " + Kairos.rules.block.map((k) => Kairos.nameOf(k)).join(", ") + " set aside"
        : "Do not disturb on; \u201Cfocus block <app>\u201D sets an app aside";
      break;
    case "focusEnd":
      label = "End the focus session"; glyph = "\u{F0E0F}";
      sub = Kairos.focus ? KairosJs.leftWords(Kairos.focus.until - Date.now()) : "No session running";
      break;
    case "focusBlock": {
      const key = KairosJs.keyOfName(c.name);
      label = (c.on ? "Set " : "Stop setting ") + Kairos.nameOf(key) + (c.on ? " aside during focus" : " aside");
      glyph = c.on ? "\uF05E" : "\uF00C";
      sub = Kairos.rules.block.length > 0 ? "Set aside now: " + Kairos.rules.block.map((k) => Kairos.nameOf(k)).join(", ") : "Nothing set aside yet";
      break;
    }
    case "autoQuit": {
      const key = KairosJs.keyOfName(c.name);
      label = c.minutes > 0 ? "Quit " + Kairos.nameOf(key) + " after " + KairosJs.limitWords(c.minutes) + " unused"
        : "Stop quitting " + Kairos.nameOf(key) + " when unused";
      glyph = "\uF017";
      const had = Kairos.rules.autoQuit[key];
      sub = had ? "Now after " + KairosJs.limitWords(had) : "Its windows are closed, as their close button would";
      break;
    }
    case "layoutSave":
      label = "Save the windows as \u201C" + c.name + "\u201D"; glyph = "\uF009";
      sub = popup.layouts[c.name] ? "Replaces the one saved by that name" : "Where each window is, on every workspace";
      break;
    case "layoutUse": {
      const l = popup.layouts[c.name];
      label = "Put the windows as \u201C" + c.name + "\u201D"; glyph = "\uF009";
      sub = l ? l.length + (l.length === 1 ? " window" : " windows") + "; missing apps are opened"
        : Object.keys(popup.layouts).length ? "No layout by that name: " + Object.keys(popup.layouts).join(", ") : "No layouts saved yet";
      break;
    }
    case "layoutsClear": {
      const n = Object.keys(popup.layouts).length;
      label = "Forget every window layout"; glyph = "\uF009";
      sub = n ? n + (n === 1 ? " layout: " : " layouts: ") + Object.keys(popup.layouts).join(", ") : "No layouts saved";
      break;
    }
    case "placesClear": {
      const n = Object.keys(popup.snapWas).length;
      label = "Forget where windows were"; glyph = "\uF0E2";
      sub = n ? "\u201CRestore\u201D then has nothing to put back for " + n + (n === 1 ? " window" : " windows")
        : "No window has been put anywhere yet";
      break;
    }
    case "layoutDrop":
      label = "Forget the layout \u201C" + c.name + "\u201D"; glyph = "\uF009";
      sub = popup.layouts[c.name] ? "" : "No layout by that name";
      break;
    case "appearance": {
      const light = c.toggle ? !Zenon.light : c.light;
      const to = popup.appearanceTarget(light);
      label = light ? "Light mode" : "Dark mode"; glyph = light ? "\uF185" : "\uF186";
      sub = to === null ? "Already " + (light ? "light" : "dark")
        : Oracle.theme === "follow" ? "Follow Background, always " + (light ? "light" : "dark")
        : "Theme: " + ((Oracle.themeOptions.find((o) => o.value === to) || { label: to }).label);
      break;
    }
    case "newContact":
      label = "New contact \u201C" + c.name + "\u201D"; glyph = "\uF2BB";
      sub = [c.email, c.phone].filter((x) => x).join(" \u00B7 ") || "In ~/Documents/Contacts";
      break;
    case "confetti":
      label = "Confetti"; glyph = "\uF06B"; sub = "For whatever just went right";
      break;
    case "quitAll":
      label = "Quit every app"; glyph = "\uF00D"; sub = "Closes every window, as its close button would";
      break;
    case "emptyTrash":
      label = "Empty the trash"; glyph = "\uF1F8"; sub = "What is in it is deleted for good";
      break;
    case "eject":
      label = "Eject every removable drive"; glyph = "\uF052"; sub = "Unmounted and powered off, safe to unplug";
      break;
    case "desktop":
      label = "Show the desktop"; glyph = "\uF108"; sub = "An empty workspace";
      break;
    case "screensOff":
      label = "Turn the screens off"; glyph = "\u{F0379}"; sub = "Any key turns them on";
      break;
    case "clearClips":
      label = "Clear the clipboard history"; glyph = "\uF0EA"; sub = "Pinned clips stay";
      break;
    case "joinMeeting":
      label = "Join the next meeting"; glyph = "\uF03D"; sub = "Its link, from your calendar";
      break;
    case "fullscreen":
      label = "Window full screen, or back"; glyph = "\uF065"; sub = popup.lastWindowName();
      break;
    case "ocr":
      label = "Copy text from a region of the screen"; glyph = "\uF15C"; sub = "Picasso reads it with tesseract";
      break;
    case "scanqr":
      label = "Read a QR code on the screen"; glyph = "\uF029"; sub = "What it says goes on the clipboard";
      break;
    case "restart":
      label = "Restart " + c.name; glyph = "\uF021";
      sub = "Ends it, then opens it again the way it was started";
      break;
    case "timer": {
      const m = c.minutes > 0 ? c.minutes : Chronos.defaultMinutes;
      label = "Start a " + Answers.minutesText(m) + " timer"; glyph = "\uF017"; sub = c.label;
      break;
    }
    case "url":
      label = "Open " + c.url.replace(/^https?:\/\//i, ""); glyph = "\uF0AC"; sub = "In the browser";
      break;
    case "snap":
      label = c.where === "size" ? "Resize the window to " + c.w + " \u00D7 " + c.h
        : { left: "Window to the left half", right: "Window to the right half", top: "Window to the top half",
            bottom: "Window to the bottom half", max: "Window to fill the screen", next: "Window to the next screen",
            left3: "Window to the left third", center3: "Window to the center third", right3: "Window to the right third",
            left23: "Window to the left two thirds", right23: "Window to the right two thirds",
            tl: "Window to the top left quarter", tr: "Window to the top right quarter",
            bl: "Window to the bottom left quarter", br: "Window to the bottom right quarter",
            centerHalf: "Window to the center half", almost: "Window to almost fill the screen",
            center: "Window to the center", restore: "Window back where it was",
            grow: "Window a little larger", shrink: "Window a little smaller", maxW: "Window as wide as the screen",
            maxH: "Window as tall as the screen", prev: "Window to the previous screen" }[c.where];
      glyph = { left: "\u{F10AA}", right: "\u{F10AB}", next: "\u{F037A}", restore: "\uF0E2" }[c.where] || "\u{F0293}";
      sub = popup.lastWindowName();
      break;
    case "shot":
      label = { screen: "Screenshot the screen", window: "Screenshot a window", region: "Screenshot a region" }[c.mode]
        + " in " + c.delay + " s";
      glyph = "\u{F0109}"; sub = "Picasso";
      break;
    }
    return { kind: "argcmd", key: "cmd:" + c.kind, cmd: c, text: label, label, sub, glyph, section: "Command" };
  }
  function runCmd(c) {
    switch (c.kind) {
    case "theme": Oracle.set("theme", c.value); break;
    case "volume":
      if (!Volume.ready) return;
      Volume.audio.muted = false;
      Volume.audio.volume = c.pct !== undefined ? c.pct / 100 : Math.max(0, Math.min(1, Volume.level + c.step / 100));
      break;
    case "mute": if (Volume.ready) Volume.audio.muted = c.on; break;
    case "brightness":
      if (c.pct !== undefined) for (const s of Hermes.screens) Hermes.setBrightness(s, c.pct);
      else Hermes.stepBrightness(c.step);
      break;
    case "wifi": if (Hermes.wifiReady && Hermes.wifiOn !== c.on) Hermes.setWifi(c.on); break;
    case "bluetooth": if (Hermes.btReady && Hermes.btOn !== c.on) Hermes.setBluetooth(c.on); break;
    case "night": Hermes.setNight(c.on); break;
    case "dnd": Oracle.set("notifSilent", c.on); break;
    case "media": {
      const p = NowPlaying.player;
      if (!p) break;
      if (c.act === "play") p.play(); else if (c.act === "pause") p.pause();
      else if (c.act === "next") p.next(); else p.previous();
      break;
    }
    case "workspace": Hyprland.dispatch(Hypr.focusWorkspace(String(c.n))); break;
    case "timer": {
      const m = c.minutes > 0 ? c.minutes : Chronos.defaultMinutes;
      if (Chronos.add(c.label, m)) Chronos.toggle(Chronos.timers.length - 1);
      break;
    }
    case "url": Strings.openLink(c.url); break;
    case "snap":
      popup.snapWindow("", c.where, c.where === "size" ? { w: c.w, h: c.h } : null);
      return;
    case "focus": Kairos.startFocus(c.minutes, c.label); break;
    case "focusEnd": Kairos.endFocus(false); break;
    case "focusBlock": Kairos.setBlocked(KairosJs.keyOfName(c.name), c.on); break;
    case "autoQuit": Kairos.setAutoQuit(KairosJs.keyOfName(c.name), c.minutes); break;
    case "layoutSave": popup.saveLayout(c.name); break;
    case "layoutUse": if (popup.layouts[c.name]) popup.useLayout(c.name); break;
    case "layoutDrop": popup.dropLayout(c.name); break;
    case "placesClear": popup.snapWas = {}; break;
    case "appearance": {
      const light = c.toggle ? !Zenon.light : c.light;
      const to = popup.appearanceTarget(light);
      if (to === null) break;
      if (Oracle.theme === "follow") Oracle.set("followMode", light ? "light" : "dark");
      else Oracle.set("theme", to);
      break;
    }
    case "desktop": Hyprland.dispatch(Hypr.focusWorkspace("empty")); break;
    case "newContact":
      Quickshell.execDetached(["sh", "-c", "python3 -I \"$1\" add \"$2\" \"$3\" \"$4\" >/dev/null && notify-send -a Cynosure -- 'Contact saved' \"$2\"",
        "cynosure", Quickshell.shellDir + "/cynosure/bin/contacts.py", c.name, c.email, c.phone]);
      break;
    case "confetti": confetti.burst(); break;
    case "camera": cameraLoader.active = true; break;
    // a tray app with no window: its process ended, as quitting it would
    case "quitTray":
      if (c.pid > 1) Quickshell.execDetached(["kill", "-TERM", String(c.pid)]);
      break;
    // every window of it closed, as its close buttons would
    case "quitApp":
      popup.closeWindowsOf((app) => app === c.app);
      // and its tray process, a beat later, or it stays on in the tray
      if ((c.pids || []).length > 0)
        Quickshell.execDetached(["sh", "-c", "sleep 1; kill -TERM \"$@\" 2>/dev/null", "cynosure"].concat(c.pids.map(String)));
      break;
    // once the panel has gone, so the window it moves is yours
    case "moveWs":
      popup.dispatchLater([Hypr.moveToWorkspace(String(c.n))]);
      break;
    case "fullscreen":
      popup.dispatchLater([Hypr.fullscreen()]);
      break;
    // after the key that asked is let go, or its release wakes them again
    case "screensOff":
      popup.dispatchLater([Hypr.dpms(false)], 0.8);
      break;
    case "eject":
      Quickshell.execDetached(["sh", "-c", popup.ejectScript]);
      break;
    case "joinMeeting": meetProc.running = true; break;
    case "ocr": case "scanqr":
      // once the panel has left the screen
      Quickshell.execDetached(["sh", "-c", "sleep 0.35 && qs ipc call Picasso shot \"$1\"", "cynosure",
        c.kind === "ocr" ? "text" : "qr"]);
      break;
    case "shot":
      Quickshell.execDetached(["sh", "-c", "sleep \"$1\" && qs ipc call Picasso shot \"$2\"", "cynosure",
        String(c.delay), c.mode]);
      break;
    }
    popup.closeCynosure();
  }

  // ── OPEN WINDOWS ──────────────────────────────────────────────────────
  // Hyprland's toplevels as rows to go to (cynosure.js windowRows): a few
  // for a line that names them, every one for "win …". Return focuses and
  // raises it, the window switcher's way (through offspecial, so one on the
  // special workspace comes out to be gone to).
  readonly property bool winsScoped: /^\s*win\s/i.test(popup.query)
  // "quit …": the open apps; "layout …": the saved layouts (2026-11-04)
  readonly property bool quitScoped: /^\s*quit\s/i.test(popup.query)
  // "history …": what you searched before, newest first
  readonly property bool historyScoped: /^\s*history\s/i.test(popup.query)
  // "snap …": every window place, for the window you were in (Cynosure.SNAPS)
  readonly property bool snapScoped: /^\s*snaps?\s/i.test(popup.query)
  readonly property bool layoutsScoped: /^\s*layouts?\s/i.test(popup.query)
  // "theme …": dark and light mode, then every theme (Cynosure.themeRows)
  readonly property bool themesScoped: /^\s*themes?\s/i.test(popup.query)
  readonly property string scopeRest: popup.query.replace(/^\s*\S+\s+/, "")
  // what runs in the tray, by process (bin/trayapps.py asks the bus), read
  // as "quit" is typed and again when the tray changes
  property var trayApps: []
  // the newest read counts: a tray change mid-read was dropped (11-09)
  function askTray() { RunJob.latest(trayProc, { command: ["python3", "-I", Quickshell.shellDir + "/cynosure/bin/trayapps.py"] }); }
  onQuitScopedChanged: if (popup.quitScoped) popup.askTray()
  Connections {
    target: SystemTray.items
    function onValuesChanged() { if (popup.quitScoped) popup.askTray(); }
  }
  Process {
    id: trayProc
    property var job: null
    property var want: null
    onExited: RunJob.next(trayProc)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!RunJob.current(trayProc)) return;
        try { popup.trayApps = JSON.parse(text) || []; } catch (e) { popup.trayApps = []; }
        popup.applyFilter();
      }
    }
  }
  function themeList() {
    const q = popup.scopeRest.trim().toLowerCase();
    const modes = [false, true].map((light) => popup.describeCmd({ kind: "appearance", light }))
      .filter((r) => q === "" || r.label.toLowerCase().indexOf(q) >= 0)
      .map((r) => Object.assign({}, r, { key: "theme:mode:" + r.label, section: "Themes" }));
    return modes.concat(Cynosure.themeRows(Oracle.themeOptions, Oracle.theme, q,
      (o) => Ora.themeInksFor(o, Zenon.zenon, Zenon.followTheme && Zenon.followTheme.colors)));
  }
  function quitList() {
    const apps = Cynosure.quitRows(popup.openWindows(), popup.scopeRest, Strings.appGlyph, (id) => {
      const e = typeof DesktopEntries.heuristicLookup === "function" ? DesktopEntries.heuristicLookup(id) : DesktopEntries.byId(id);
      return e ? e.name : "";
    }, popup.trayApps);
    // "quit all", "quit focus": the command, over the apps
    const c = popup.cmdRow;
    return c && (c.cmd.kind !== "kill" || apps.length === 0) ? [c].concat(apps) : apps;
  }
  readonly property string winLine: popup.winsScoped ? popup.query.replace(/^\s*win\s+/i, "") : popup.query
  function openWindows() {
    const active = Hyprland.activeToplevel;
    const hereWs = popup.hereWorkspace();
    return Hyprland.toplevels.values.filter((t) => t.wayland).map((t) => {
      const app = String(t.wayland.appId || "");
      return { address: t.address, title: String(t.title || ""), app,
        // the suite's own windows share quickshell's app id
        name: app === "org.quickshell" ? "Zenworks" : app,
        ws: t.workspace ? String(t.workspace.name) : "", focused: t === active,
        here: !!t.workspace && String(t.workspace.name) === hereWs };
    });
  }
  Connections {
    target: Hyprland.toplevels
    function onValuesChanged() { if (popup.shown) popup.applyFilter(); }
  }
  function hereWorkspace() {
    const m = Hyprland.focusedMonitor;
    return m && m.activeWorkspace ? String(m.activeWorkspace.name) : "";
  }
  // the window actions (float, center, fullscreen, move here) act on the
  // active window, so the one meant is focused first; "move here" is read
  // before that focus can take the workspace with it
  function windowDo(address, what) {
    const sel = Hypr.byAddress(address);
    const ws = popup.hereWorkspace();
    const then = what === "here" ? (ws !== "" ? Hypr.moveToWorkspace(ws) : "")
      : what === "float" ? Hypr.floatToggle()
      : what === "center" ? Hypr.center() : Hypr.fullscreen();
    if (then === "") return;
    const steps = [Hypr.focusWindow(sel), Hypr.raiseWindow(sel)];
    popup.closeCynosure();
    popup.dispatchLater(steps.concat([then]));
  }
  // dispatches for a window, once the panel has let the keyboard go: run
  // while it still held it, the window was never focused and the rest went
  // nowhere (user, 2026-11-04: "don't do anything")
  function dispatchLater(steps, seconds) {
    Quickshell.execDetached(["sh", "-c", "sleep " + (seconds || 0.25) + "; exec \"$@\"", "cynosure"].concat(Off.wanted(steps)));
  }
  function goToWindow(address) {
    Quickshell.execDetached(Off.wanted([Hypr.focusWindow(Hypr.byAddress(address)),
                                        Hypr.raiseWindow(Hypr.byAddress(address))]));
    popup.closeCynosure();
  }

  // ── THE DETAIL PANE ───────────────────────────────────────────────────
  // In a list of one kind ("f …", "cb …", "em …", "nf …") the chosen row is
  // shown beside the list, Raycast's way: a preview over the facts about it.
  // Read a beat after the cursor stops, newest asking only.
  readonly property bool paneOn: popup.mode === "search" && !popup.taken
    && (popup.filesScoped || popup.clipsScoped || popup.glyphsScoped || popup.booksScoped
      || popup.shotsScoped || popup.recsScoped || popup.hitsScoped || popup.colorsScoped)
  // { kind, image, glyph, nerd, rich, text, mono, icon, busy, facts: [[k, v]] }
  // and for "in …" `hitAt`: [start, end] of the matching line in the text
  property var detail: null
  property int detailSeq: 0
  property string picSize: ""
  Timer { id: detailLater; interval: 120; onTriggered: popup.loadDetail() }
  onCurrentChanged: if (popup.paneOn) detailLater.restart()
  onCellSelChanged: {
    if (popup.paneOn) detailLater.restart();
    Qt.callLater(popup.placeCellCursor);
  }
  onPaneOnChanged: if (popup.paneOn) detailLater.restart(); else popup.detail = null
  function setDetail(seq, more) {
    if (seq !== popup.detailSeq) return;
    popup.detail = Object.assign({}, popup.detail || {}, more);
  }
  function loadDetail() {
    const seq = ++popup.detailSeq;
    const r = popup.current;
    popup.picSize = "";
    if (!r) { popup.detail = null; return; }
    if (r.kind === "file") {
      popup.detail = { kind: "file", icon: r.glyph || "\uF15B", busy: true,
        facts: [["Where", r.sub !== "" ? r.sub : "/"]] };
      RunJob.latest(statProc, { seq, row: r, command: Terminus.statArgv([r.path.replace(/\/$/, "")]) });
      const name = Terminus.basename(r.path);
      if (r.isDir) {
        RunJob.latest(lookProc, { seq, shows: "list",
          command: ["sh", "-c", "ls -1Ap -- \"$1\" 2>/dev/null | head -40", "cynosure", r.path] });
      } else if (Terminus.isImage(name)) {
        popup.setDetail(seq, { image: "file://" + r.path, busy: false });
      } else if (Terminus.kindOf(name) === "text" || Terminus.isText(name)) {
        RunJob.latest(lookProc, { seq, shows: "code", command: ["sh", "-c", Terminus.previewCommand(r.path, null)] });
      } else popup.setDetail(seq, { busy: false });
      return;
    }
    if (r.kind === "clip") {
      popup.detail = { kind: "clip", busy: true, facts: [["Copied", r.sub || ""]] };
      popup.folio.decodeText(r.id, (t) => {
        const words = t.trim() === "" ? 0 : t.trim().split(/\s+/).length;
        popup.setDetail(seq, { text: t, busy: false, facts: [["Copied", r.sub || ""],
          ["Lines", String(t.split("\n").length)], ["Words", String(words)],
          ["Characters", String(Array.from(t).length)]] });
      });
      return;
    }
    if (r.kind === "pics") {
      const c = popup.chosenCell(r);
      if (!c) { popup.detail = null; return; }
      popup.detail = { kind: "pics", image: c.thumb ? "file://" + c.thumb : "", busy: !c.thumb,
        facts: [["Copied", c.stamp || ""]] };
      // the picture whole, written out as a drag writes it, over its thumbnail
      popup.folio.dragDecode(c.id, (f) => { if (f !== "") popup.setDetail(seq, { image: "file://" + f, busy: false }); });
      return;
    }
    if (r.kind === "shots") {
      const c = popup.chosenCell(r);
      if (!c) { popup.detail = null; return; }
      // a picture whole; a recording its frame
      popup.detail = { kind: "pics", icon: c.video ? "\u{F0567}" : "\uF03E",
        image: c.video ? (c.thumb ? "file://" + c.thumb : "") : "file://" + c.path,
        facts: [["Name", c.name], [c.video ? "Recorded" : "Taken", c.stamp]] };
      return;
    }
    if (r.kind === "book") {
      const b = r.book;
      popup.detail = { kind: "book", icon: r.glyph, image: b.cover.startsWith("/") ? "file://" + b.cover : "",
        facts: [["Author", b.author || "\u2014"], ["Read", b.finished > 0 ? "Finished" : Math.round(b.progress * 100) + "%"],
          ["Last opened", b.opened > 0 ? Qt.formatDate(new Date(b.opened), "d MMM yyyy") : "Never"],
          ["File", Terminus.basename(b.path)]] };
      return;
    }
    if (r.kind === "snip") {
      popup.detail = { kind: "snip", text: r.content || "", facts: [["Name", r.label], ["File", r.path]] };
      return;
    }
    // a picked color: itself, large, and every form of it under
    if (r.kind === "pcolor") {
      popup.detail = { kind: "color", swatch: r.hex, facts: r.forms || [] };
      return;
    }
    // "in …": the file from a few lines over the match, the match lit
    // (hitBand) — Raycast's file search preview
    if (r.kind === "hit") {
      const from = Math.max(1, r.line - 3);
      popup.detail = { kind: "file", icon: r.glyph || "\uF15C", busy: true, hit: r.line - from,
        facts: [["Line", String(r.line)]] };
      RunJob.latest(statProc, { seq, command: Terminus.statArgv([r.path]),
        row: { path: r.path, line: r.line, sub: Artemis.shownPath(Terminus.dirname(r.path), Quickshell.env("HOME")) } });
      RunJob.latest(lookProc, { seq, shows: "code", command: ["sh", "-c", Terminus.previewCommand(r.path, null, from)] });
      return;
    }
    if (r.kind === "glyphs") {
      const c = popup.chosenCell(r);
      if (!c) { popup.detail = null; return; }
      // by code point, not by UTF-16 unit: an emoji is two of those
      const cps = [];
      for (let i = 0; i < c.char.length;) {
        const cp = c.char.codePointAt(i);
        i += cp > 0xFFFF ? 2 : 1;
        if (cp !== 0xFE0F) cps.push("U+" + cp.toString(16).toUpperCase().padStart(4, "0"));
      }
      const code = cps.join(" ");
      popup.detail = { kind: "glyphs", glyph: c.char, nerd: r.nerd,
        facts: [[r.nerd ? "Class" : "Name", c.name], ["Codepoint", code]] };
      return;
    }
    popup.detail = null;
  }
  Process {
    id: statProc
    property var job: null
    property var want: null
    onExited: RunJob.next(statProc)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const f = Terminus.parseStat(text)[0];
        const job = statProc.job;
        const r = job ? job.row : null;
        if (!f || !r) return;
        const kind = r.isDir ? "Directory" : Terminus.kindOf(f.name);
        const facts = [["Kind", kind.charAt(0).toUpperCase() + kind.slice(1)]];
        if (!r.isDir) facts.push(["Size", Terminus.formatSize(f.size)]);
        const when = new Date(f.mtime * 1000);
        facts.push(["Modified", Terminus.formatTime(f.mtime) + " · " + when.toLocaleDateString(Qt.locale(), Locale.ShortFormat)]);
        if (r.line) facts.push(["Line", String(r.line)]);
        facts.push(["Where", r.sub !== "" ? r.sub : "/"]);
        popup.setDetail(job.seq, { facts });
      }
    }
  }
  Process {
    id: lookProc
    property var job: null
    property var want: null
    onExited: RunJob.next(lookProc)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const job = lookProc.job;
        if (!job) return;
        if (job.shows === "code") {
          const more = { rich: String(text).trim() === "" ? "" : Terminus.ansiToRich(text, Zenon.faceCode), busy: false };
          // where the matching line is in what the pane shows, by character
          const hit = popup.detail ? popup.detail.hit : undefined;
          if (hit !== undefined) {
            const lines = Terminus.capPreview(text).replace(/\u001b\[[0-9;]*m/g, "").split("\n");
            let at = 0;
            for (let i = 0; i < hit && i < lines.length; ++i) at += lines[i].length + 1;
            more.hitAt = hit < lines.length ? [at, at + lines[hit].length] : null;
          }
          popup.setDetail(job.seq, more);
        }
        else popup.setDetail(job.seq, { text: String(text).trim() === "" ? "Empty" : text, mono: true, busy: false });
      }
    }
  }

  // ── SMART ANSWERS ─────────────────────────────────────────────────────
  // A line in plain words answered in a card over the list (answers.js reads
  // it): the weather here or anywhere ("cairo weather", "will it rain
  // tomorrow", "sunset"), the time and date, the battery, the addresses,
  // the uptime, a coin, dice, a number, a uuid. Arithmetic is answered on
  // the spot; the machine and the weather a beat after the last key.
  readonly property bool answering: popup.mode === "search" && !popup.taken
  // Answers as you type off (Oracle): only the ones asked for by their word
  readonly property var ask: {
    const a = popup.answering && !popup.calcAsked ? Answers.parseAsk(popup.query) : null;
    return a && (Oracle.cynosureAnswers || a.kind === "qr" || a.kind === "speed") ? a : null;
  }
  readonly property var wxAsk: popup.answering && Oracle.cynosureAnswers && !popup.ask && !popup.calcShown ? Answers.parseWeather(popup.query) : null
  // { kind, big, small } for every answer but the weather's
  property var answer: null
  // the weather's: { name, current, days, offset, focus, here }
  property var wx: null
  readonly property bool answerShown: (!!popup.ask && !!popup.answer) || (!!popup.wxAsk && !!popup.wx)
  property int askSeq: 0
  onAskChanged: popup.takeAsk()
  onWxAskChanged: popup.takeAsk()
  Timer { id: askLater; interval: 300; onTriggered: popup.askWorld() }
  function takeAsk() {
    popup.askSeq++;
    const a = popup.ask;
    if (a && a.kind === "define") { popup.answer = null; return; }   // lexi's card has it (lexiAsk)
    const now = a ? Answers.answerOf(a, new Date(), Oracle.clock24h) : null;
    if (now) { popup.answer = Object.assign({ kind: a.kind }, now); popup.wx = null; return; }
    if (!a) popup.answer = null;
    if (!popup.wxAsk) popup.wx = null;
    if (a || popup.wxAsk) askLater.restart();
  }
  // "screen time this week", "how long on firefox": Kairos' days summed,
  // the biggest few named under the total
  function screenTime(a) {
    if (!Kairos.enabled) return { big: "Screen time is off", small: "Turn it on in Settings, under Screen time" };
    const now = new Date();
    const end = a.span === "yesterday" ? KairosJs.addDays(now, -1) : now;
    const day = a.span === "week" ? Kairos.weekSum(now) : Kairos.day(KairosJs.dayKey(end));
    const when = { today: "Today", yesterday: "Yesterday", week: "The last seven days" }[a.span];
    const top = KairosJs.topApps(day, 0);
    if (a.app !== "") {
      const want = a.app.toLowerCase();
      const hit = top.find((t) => Kairos.nameOf(t.key).toLowerCase().indexOf(want) >= 0 || t.key.indexOf(want) >= 0);
      return hit ? { big: KairosJs.fmt(hit.secs), small: when + " in " + Kairos.nameOf(hit.key) }
        : { big: "0m", small: when + ", nothing called \u201C" + a.app + "\u201D" };
    }
    return { big: KairosJs.fmt(KairosJs.total(day)),
      small: [when].concat(top.slice(0, 3).map((t) => Kairos.nameOf(t.key) + " " + KairosJs.fmt(t.secs))).join(" \u00B7 ") };
  }
  // the machine and the weather, asked once the line has settled
  function askWorld() {
    const seq = popup.askSeq;
    const a = popup.ask;
    if (a) {
      // what is playing is the shell's own to say (morpheus/NowPlaying)
      if (a.kind === "playing") {
        popup.answer = NowPlaying.active && NowPlaying.title !== ""
          ? { kind: "playing", big: NowPlaying.title, small: (NowPlaying.artist || "")
              + (NowPlaying.playing ? "" : (NowPlaying.artist ? " · " : "") + "Paused") }
          : { kind: "playing", big: "Nothing playing", small: "No player has anything on" };
        return;
      }
      // screen time: Kairos' own count (its months, kept by the shell)
      if (a.kind === "screentime") {
        popup.answer = Object.assign({ kind: "screentime", kairos: a.span === "week" ? "week" : "day" }, popup.screenTime(a));
        return;
      }
      // the calendar: chronos' cal.py, over the days asked about
      if (a.kind === "cal") {
        const r = Answers.calRange(a, new Date());
        RunJob.latest(askProc, { seq, kind: "cal", command: ["python3", "-I", Chronos.calCore, "list", r.from, r.to] });
        return;
      }
      // how busy, how full: Sysmon's own readings, live (liveFill)
      if (a.kind === "cpu" || a.kind === "memory") { popup.liveFill(); return; }
      // a speed test says it is on its way first: it takes a while
      if (a.kind === "speed") {
        popup.answer = speedProc.got || { kind: "speed", big: "Testing\u2026", small: "Downloading, then uploading, for up to 20 s" };
        if (!speedProc.running && !speedProc.got) speedProc.running = true;
        return;
      }
      const cmd = a.kind === "battery"
        ? "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && echo \"$(cat \"$b/capacity\") $(cat \"$b/status\")\" && break; done"
        : a.kind === "ip" ? "ip -4 -o addr show scope global"
        : a.kind === "uptime" ? "cut -d' ' -f1 /proc/uptime; cut -d' ' -f1-4 /proc/loadavg; nproc"
        : a.kind === "disk" ? "df -kP \"$HOME\""
        : a.kind === "kernel" ? "uname -sr"
        : a.kind === "hostname" ? "cat /etc/hostname 2>/dev/null || uname -n"
        : a.kind === "wifi" ? "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2-"
        // the words to hash go as an argument, never into the script
        : a.kind === "hash" ? "printf '%s' \"$1\" | " + a.algo + "sum | cut -d' ' -f1"
        // the code to a png in the runtime directory (the last one only),
        // its path printed back; dark on light so any camera reads it
        : a.kind === "qr" ? "command -v qrencode >/dev/null || exit 127; d=\"${XDG_RUNTIME_DIR:-/tmp}\"; "
          + "rm -f \"$d\"/cynosure-qr-*.png; f=\"$d/cynosure-qr-$$.png\"; "
          + "qrencode -s 8 -m 2 --foreground=000000 --background=ffffff -o \"$f\" -- \"$1\" && printf '%s' \"$f\""
 : "";
      if (cmd === "") return;
      RunJob.latest(askProc, { seq, kind: a.kind, command: ["sh", "-c", cmd, "cynosure", a.text || ""] });
      return;
    }
    const w = popup.wxAsk;
    if (!w) return;
    const offset = Answers.dayOffset(w.day, new Date());
    // here: chronos' own forecast, already fetched
    if (w.place === "") {
      if (!Weather.ready) { Weather.refreshIfStale(); return; }
      popup.wx = { name: Weather.place !== "" ? Weather.place : "Here", current: Weather.current,
        days: Weather.days, offset, focus: w.focus, here: true };
      return;
    }
    const hit = popup.wxCache[w.place];
    if (hit) { popup.wx = Object.assign({}, hit, { offset, focus: w.focus, here: false }); return; }
    Net.request("GET", Answers.geocodeUrl(w.place), { timeout: 8 }, (st, body) => {
      if (seq !== popup.askSeq) return;
      const g = st === 200 ? Answers.parseGeocode(body) : null;
      if (!g) { popup.wx = null; return; }
      Net.request("GET", Wx.forecastUrl(g.lat, g.lon), { timeout: 10 }, (st2, body2) => {
        if (seq !== popup.askSeq || st2 !== 200) return;
        try {
          const f = Wx.parseForecast(body2);
          const got = { name: g.name, current: f.current, days: f.days };
          popup.wxCache[w.place] = got;
          popup.wx = Object.assign({}, got, { offset, focus: w.focus, here: false });
        } catch (e) { popup.wx = null; }
      });
    });
  }
  // cpu and memory: Sysmon's readings, so the card moves with them and its
  // graph is the history the bar already keeps
  function liveFill() {
    const a = popup.ask;
    if (!a) return;
    const r = a.kind === "cpu" ? Answers.cpuAnswer(Sysmon.cpuUsage, Sysmon.cpuLoad, Sysmon.cpuThreads)
      : a.kind === "memory" ? Answers.memAnswer(Sysmon.memTotal, Sysmon.memAvail) : null;
    if (r) popup.answer = Object.assign({ kind: a.kind }, r);
  }
  Connections {
    target: Sysmon
    enabled: popup.shown && !!popup.ask && (popup.ask.kind === "cpu" || popup.ask.kind === "memory")
    function onCpuHistoryChanged() { popup.liveFill(); }
    function onMemHistoryChanged() { popup.liveFill(); }
  }
  // disk, battery, uptime: asked again while the card is up
  Timer {
    interval: popup.ask && popup.ask.kind === "uptime" ? 30000 : 5000
    repeat: true
    running: popup.shown && popup.answerShown && !!popup.ask
      && ["disk", "battery", "uptime"].indexOf(popup.ask.kind) >= 0
    onTriggered: if (!askProc.running) popup.askWorld()
  }
  // a speed test: Cloudflare's endpoints through curl, ten seconds each
  // way, kept for the while the panel is open (asking again would be another
  // 20 s); on its own so other answers never wait behind it
  Process {
    id: speedProc
    property var got: null
    command: ["sh", "-c", "c='curl -s -o /dev/null --max-time 10'; "
      + "d=$($c -w '%{speed_download} %{time_connect} %{time_namelookup}' 'https://speed.cloudflare.com/__down?bytes=50000000'); "
      + "u=$(head -c 20000000 /dev/zero | $c -w '%{speed_upload}' --data-binary @- 'https://speed.cloudflare.com/__up'); "
      + "echo \"$d $u\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        speedProc.got = Object.assign({ kind: "speed" }, Answers.parseSpeed(text)
          || { big: "Offline", small: "Cloudflare's speed test could not be reached" });
        if (popup.ask && popup.ask.kind === "speed") popup.answer = speedProc.got;
      }
    }
  }
  onShownChanged: if (!popup.shown) speedProc.got = null
  // places already asked about, for as long as the shell runs
  property var wxCache: ({})
  Connections {
    target: Weather
    function onCurrentChanged() { if (popup.wxAsk && popup.wxAsk.place === "") popup.askWorld(); }
  }
  Process {
    id: askProc
    property var job: null
    property var want: null
    onExited: RunJob.next(askProc)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!askProc.job || askProc.job.seq !== popup.askSeq) return;
        const k = askProc.job.kind;
        let a = null;
        if (k === "cal") a = popup.ask ? Answers.calAnswer(text, popup.ask, new Date()) : null;
        else if (k === "battery") a = Answers.parseBattery(text) || { big: "No battery", small: "On mains power" };
        else if (k === "ip") {
          const addrs = Answers.parseAddrs(text);
          a = addrs.length ? { big: addrs.map((x) => x.addr).join("  ·  "), small: addrs.map((x) => x.dev).join(" · "), glyph: "\uF0AC" }
            : { big: "Offline", small: "No address on any network" };
        } else if (k === "uptime") a = Answers.uptimeCard(text, new Date(), Oracle.clock24h);
        else if (k === "disk") a = Answers.parseDf(text);
        else if (k === "kernel") a = { big: text.trim(), small: "The kernel running now", glyph: "\uF17C" };
        else if (k === "qr") a = text.trim() !== "" ? { big: popup.ask ? popup.ask.text : "", small: "Return copies the picture",
            qr: text.trim() } : { big: "No QR code", small: "Making one needs qrencode" };
        else if (k === "hostname") a = { big: text.trim(), small: "This computer's name", glyph: "\uF108" };
        else if (k === "wifi") a = text.trim() !== "" ? { big: text.trim(), small: "The Wi-Fi network you are on", glyph: "\uF1EB" }
          : { big: "Not on Wi-Fi", small: "No wireless network joined" };
        else if (k === "hash") a = { big: text.trim(), small: popup.ask ? popup.ask.algo.toUpperCase() + " of \u201C"
          + (popup.ask.text.length > 30 ? popup.ask.text.slice(0, 29) + "\u2026" : popup.ask.text) + "\u201D" : "" };
        popup.answer = a ? Object.assign({ kind: k }, a) : null;
      }
    }
  }
  // the day the weather card is about, and the line it is copied as
  readonly property var wxDay: popup.wx && popup.wx.days ? (popup.wx.days[popup.wx.offset] || null) : null
  function wxSummary() {
    const w = popup.wx;
    if (!w) return "";
    const d = popup.wxDay;
    const t = (c) => Weather.fmt(c) + Weather.unit;
    if (w.offset === 0 && w.current)
      return w.name + ": " + t(w.current.temp) + ", " + Wx.label(w.current.code)
        + (d ? " (high " + t(d.hi) + ", low " + t(d.lo) + ")" : "");
    return d ? w.name + ", " + popup.dayName(w.offset) + ": " + Wx.label(d.code) + ", " + t(d.hi) + " / " + t(d.lo) : w.name;
  }
  function dayName(offset) {
    if (offset === 0) return "Today";
    if (offset === 1) return "Tomorrow";
    const d = new Date(); d.setDate(d.getDate() + offset);
    return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][d.getDay()];
  }
  // return on the card: its words copied, a QR code's picture
  function takeAnswer() {
    const a = popup.answer;
    if (a && a.kind === "qr" && a.qr)
      Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\"", "cynosure", a.qr]);
    else popup.copyText(popup.answerText());
  }
  function answerText() {
    return popup.wxAsk && popup.wx ? popup.wxSummary() : popup.answer ? popup.answer.big : "";
  }
  onCalcLineChanged: if (popup.metis && popup.calcWanted) popup.metis.setLine(popup.calcLine)
  // this field's text set without it counting as typing; a line that
  // starts with a chip's word ("def …", "tr …", the card's words) keeps
  // it as the chip (2026-11-04: the chip was lost to the card's lines)
  property bool feedingLine: false
  function feedLine(t) {
    popup.feedingLine = true;
    popup.lineAt(t);
    popup.feedingLine = false;
  }

  // ── THE DICTIONARY AND THE TRANSLATOR, AS CARDS ────────────────────
  // Lexi under the field the way the calculator is (user, 2026-11-01: "both
  // lexi's modes in base panel just like metis", stylized cards): the line
  // keeps its own field, and "define …", "… meaning", "tr …", "hello in
  // spanish" (Cynosure.parseLexi) put a Dictionary or a Translate card over
  // the list. Lexi (lexi/LexiCore.qml, loaded unseen) does the asking, with
  // its caches and histories; this draws the card. Its pages are not shown.
  readonly property var lexiAsk: popup.mode === "search" && !popup.taken ? Cynosure.parseLexi(popup.query) : null
  property bool lexiLatched: false
  readonly property var lexi: lexiLoader.item
  onLexiAskChanged: {
    if (popup.lexiAsk) popup.lexiLatched = true;
    popup.lexiChip = -1;
    lexiAskLater.restart();
  }
  // asked once the line rests: both answers come off the network
  Timer { id: lexiAskLater; interval: 350; onTriggered: popup.askLexi() }
  function askLexi() {
    const a = popup.lexiAsk, x = popup.lexi;
    if (!a || !x) return;
    if (a.mode === "dict") x.cardDefine(a.word, a.lang);
    else x.cardTranslate(a.text, a.to ? a.to.code : "en", a.from ? a.from.code : null);
  }
  readonly property bool lexiShown: !!popup.lexi && !!popup.lexiAsk && popup.lexi.cardInit
  readonly property string lexiMode: popup.lexiShown && popup.lexiAsk ? popup.lexiAsk.mode : ""
  // nothing after "def" or "tr": the card is the recents, as chips
  readonly property bool lexiBare: popup.lexiShown && !!popup.lexiAsk
    && (popup.lexiAsk.mode === "dict" ? popup.lexiAsk.word.trim() === "" : popup.lexiAsk.text.trim() === "")
  readonly property var lexiTr: popup.lexiMode === "trans" && popup.lexi ? popup.lexi.cardTr : null
  // the chips under the card: { label, sub, glyph, line } — the line they set
  readonly property var lexiChips: {
    const x = popup.lexi, a = popup.lexiAsk;
    if (!popup.lexiShown || !a || !x) return [];
    const out = [];
    if (a.mode === "dict") {
      if (popup.lexiBare) {
        for (const w of x.dictHist.slice(0, popup.lexiChipMax)) out.push({ label: w, glyph: "\uF1DA", line: "def " + w });
        return out;
      }
      for (const o of x.dictSuggest.slice(0, popup.lexiChipMax))
        out.push(o.kind === "lang"
          ? { label: o.text, glyph: "\uF1AB", line: "def " + x.dictQuery + " in " + o.en }
          : { label: o.text, glyph: "\uF002", line: "def " + o.text });
      if (out.length) return out;
      for (const w of x.dictAlso) out.push({ label: w, glyph: "\uF002", line: "def " + w });
      const r = x.dictResult;
      if (r && r.synonyms) for (const w of r.synonyms.slice(0, Math.max(0, popup.lexiChipMax - out.length))) out.push({ label: w, glyph: "", line: "def " + w });
      return out;
    }
    if (popup.lexiBare) {
      for (const e of x.transHist.slice(0, popup.lexiChipMax))
        out.push({ label: e.translation || e.text, sub: e.text, glyph: "\uF1AB",
          line: "tr " + e.text + " in " + Lexicon.langEnName(e.code) });
      return out;
    }
    // the languages, most used first: a chip translates into that one
    const to = popup.lexiTr ? popup.lexiTr.to : "";
    for (const l of x.langRows) {
      if (l.code === to) continue;
      out.push({ label: Lexicon.langEnName(l.code), sub: "",
        glyph: "", line: "tr " + a.text + (a.from ? " from " + a.from.en : "") + " in " + Lexicon.langEnName(l.code) });
      // few enough to sit centered under the answer, as the card's every
      // line does (user, 2026-11-01); any other is "… in <language>"
      if (out.length >= popup.lexiChipMax) break;
    }
    return out;
  }
  readonly property int lexiChipMax: 6
  // the chip tab has moved onto, or -1
  property int lexiChip: -1
  function lexiTakeChip(i) {
    const c = popup.lexiChips[i];
    if (!c) return;
    popup.feedLine(c.line);
    popup.sel = -1;
  }
  // what return copies, and the translation kept in Lexi's history with it
  function lexiCopy() {
    const x = popup.lexi;
    if (!x) return;
    const t = x.cardText(popup.lexiMode);
    if (t === "") return;
    x.cardKeep();
    popup.copyText(t);
  }
  // the other way round: the translation becomes the words, into what they
  // were written in
  function lexiSwap() {
    const c = popup.lexiTr;
    if (!c || !c.translation || !c.source) return;
    popup.feedLine("tr " + c.translation + " in " + Lexicon.langEnName(c.source));
  }
  // the card's own keys while it is the chosen row; true when one was used
  function lexiKey(event) {
    const k = event.key, alt = event.modifiers & Qt.AltModifier;
    const n = popup.lexiChips.length;
    if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
      // "def" / "define" typed: tab makes it the chip first (the card's
      // recents took it, 2026-11-04), its recents on the next
      if (n === 0 || (k === Qt.Key_Tab && popup.chipOffer)) return false;
      event.accepted = true;
      const d = k === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1;
      // round the chips and back off them (-1, the card itself)
      popup.lexiChip = (popup.lexiChip + 1 + d + n + 1) % (n + 1) - 1;
      popup.revealLexiChip();
      return true;
    }
    if ((k === Qt.Key_Left || k === Qt.Key_Right) && popup.lexiChip >= 0) {
      event.accepted = true;
      popup.lexiChip = Math.max(0, Math.min(n - 1, popup.lexiChip + (k === Qt.Key_Left ? -1 : 1)));
      popup.revealLexiChip();
      return true;
    }
    if ((k === Qt.Key_Return || k === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
      event.accepted = true;
      if (popup.lexiChip >= 0) popup.lexiTakeChip(popup.lexiChip);
      else popup.lexiCopy();
      return true;
    }
    if (alt && k === Qt.Key_P) { event.accepted = true; if (popup.lexiCanSay) popup.lexi.cardSpeak(popup.lexiMode); return true; }
    if (alt && k === Qt.Key_E && popup.lexiMode === "dict") { event.accepted = true; popup.lexi.cardMore(); return true; }
    if (alt && k === Qt.Key_S && popup.lexiMode === "trans") { event.accepted = true; popup.lexiSwap(); return true; }
    return false;
  }
  // the chosen chip scrolled into sight, as metis' are
  function revealLexiChip() {
    const i = popup.lexiChip;
    if (i >= 0) Qt.callLater(() => lexiStrip.reveal(lexiChipRep.itemAt(i)));
  }
  // opened onto words already chosen (Lexi's IPC: minerva's look-up card)
  function lookUp(mode, words) {
    popup.toggleLine((mode === "trans" ? "tr " : "def ") + words);
  }

  // ── PASSWORDS, IN THE LIST ────────────────────────────────────────────
  // Calypso's Quick Access whole (calypso/CalypsoView.qml, `embedded`): "pw
  // …" hands it the field, and its pages (the logins, a login's actions, the
  // unlock) are drawn from the top with the words as its filter; backspace
  // at its empty filter gives the field back. The manager knows it as
  // `quickAccess` (shown only while it is up).
  property bool pwMode: false
  property bool pwLatched: false
  property var pwPending: null
  readonly property var calypso: calypsoLoader.item
  readonly property int pwH: popup.calypso && popup.pwMode ? popup.calypso.calcHeight() : 0
  readonly property QtObject quickAccess: QtObject {
    readonly property bool shown: popup.shown && !popup.collapsing && popup.pwMode
    function closePopup() { if (popup.pwMode) popup.closeCynosure(); }
    function toggle() { popup.toggleLine("pw "); }
  }
  function maybeEnterPw() {
    if (popup.pwMode || popup.taken || popup.mode !== "search") return;
    const m = /^\s*pw\s(.*)$/i.exec(popup.query);
    if (!m) return;
    popup.pwPending = m[1];
    popup.pwMode = true;
    if (popup.calypso) popup.startPw();
    else popup.pwLatched = true;
  }
  function startPw() {
    if (popup.pwPending === null || !popup.calypso) return;
    const rest = popup.pwPending;
    popup.pwPending = null;
    popup.calypso.start();
    popup.calypso.setLine(rest);
  }
  function exitPw() {
    popup.pwMode = false;
    popup.feedLine("");
    Qt.callLater(() => input.forceActiveFocus());
  }


  // ── A QUICK PANEL'S ROW ───────────────────────────────────────────────
  // `view` is a verb's ("folio", "lexi:trans", "ideo:emoji"), `q` what goes
  // after its word: the word typed into the field, which makes the list (or
  // hands the field) as that panel has it.
  // a verb of Cynosure's own: a line typed for you, or a page of a panel
  // that lives in the list (folio's snippet page, made first if need be)
  property bool snippetAsked: false
  function runInline(a) {
    if (a.line) {
      popup.untake();
      popup.lineAt(a.line);
      input.cursorPosition = input.text.length;
      return;
    }
    if (a.inline === "newLink") { popup.askLink(); return; }
    if (a.inline === "script") { popup.runScript(a.script, ""); return; }
    if (a.inline === "newScript") {
      // a starter written under the next free name, opened in plato
      Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && f=\"$1/new-script.sh\" && n=1 && "
        + "while [ -e \"$f\" ]; do n=$((n+1)); f=\"$1/new-script-$n.sh\"; done && "
        + "printf '%s' \"$2\" > \"$f\" && chmod +x \"$f\" && qs ipc call Plato open \"$f\"",
        "cynosure", Cynosure.scriptsDir(), Cynosure.scriptTemplate()]);
      popup.closeCynosure();
      return;
    }
    if (a.inline === "scriptsDir") {
      Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && qs ipc call Terminus open \"$1\"", "cynosure",
        Cynosure.scriptsDir()]);
      popup.closeCynosure();
      return;
    }
    if (a.inline === "newSnippet") {
      if (popup.folio) popup.folio.editSnippetAt("", "", "");
      else { popup.snippetAsked = true; popup.folioLatched = true; }
    }
  }

  // whatever has the field gives it back, for a line set from outside
  function untake() {
    popup.pwMode = false;
    if (popup.folio && popup.folio.editing) popup.folio.cancelEdit();
  }
  function handOff(view, q, action) {
    const parts = String(view).split(":");
    const word = popup.inList[view] !== undefined ? popup.inList[view] : popup.inList[parts[0]];
    if (word === undefined) { if (action) popup.runAction(action); return; }
    popup.untake();
    popup.lineAt(word + " " + (q || ""));
    input.cursorPosition = input.text.length;
  }

  function runCommand(cmd, mode) {
    const icon = mode === "Terminal" ? Cynosure.ICON_T : Cynosure.ICON_P;
    if (Oracle.cynosureRemember) popup.histLines = Cynosure.addHistory(popup.histLines, cmd, mode, icon);
    popup.bump(cmd);
    popup.writeHistory();
    if (mode === "Terminal") {
      Quickshell.execDetached(["sh", "-c", Cynosure.terminalCommand(cmd, Oracle.terminal)]);
    } else {
      Quickshell.execDetached(["sh", "-c", Cynosure.processCommand(cmd)]);
    }
    popup.closeCynosure();
  }

  // THE ROW FLASHES, THEN IT RUNS (user, 2026-10-21) — the suite's list
  // flash, RowFlash. Not for a row that only opens the picker: nothing has
  // happened yet.
  RowFlash { id: rowFlash }
  function confirm() {
    const idx = popup.sel;
    if (rowFlash.running) return;
    if (idx < 0) return;
    if (!popup.acts(idx)) { popup.confirmAt(idx); return; }
    rowFlash.flashThen(idx, () => popup.confirmAt(idx), () => popup.sel);
  }
  function acts(idx) {
    if (popup.mode === "picker") {
      const r = popup.pickerRows[idx];
      return !!r && (r.key.startsWith("timer:") || r.key === "Confirm");
    }
    const row = popup.filtered[idx];
    if (!row) return false;
    if (row.kind === "argcmd") return row.cmd.kind !== "kill";
    if (row.kind === "more") return false;
    if (row.kind !== "shell") return true;
    if (row.action.confirm) return false;
    return !(row.action.choose === "timer" && Cynosure.timerChoices(Chronos.timers).length > 1);
  }
  function confirmAt(idx) {
    if (popup.mode === "picker") {
      const choice = popup.pickerRows[idx].key;
      if (choice.startsWith("timer:")) popup.runAction(popup.pending, "Chronos startAt " + choice.slice(6));
      // a confirm that is the shell's own to do (`run`), not a command line
      else if (choice === "Confirm" && popup.pending.run) { const f = popup.pending.run; popup.closeCynosure(); f(); }
      else if (choice === "Confirm") popup.runAction(popup.pending);
      else popup.backToSearch();
      return;
    }
    popup.runRow(popup.filtered[idx]);
  }
  // what return does to a row, chosen or (a hotkey's) kept
  function runRow(row) {
    if (!row) return;
    popup.lastPick = row;
    if (row.kind === "app") {
      popup.bump(row.key);
      Quickshell.execDetached(["sh", "-c", Cynosure.launchAppCommand(row.id)]);
      popup.closeCynosure();
    } else if (row.kind === "clip" || row.kind === "clipimg") {
      if (row.gone) popup.folio.takeText(row.pinText); else popup.folio.takeClip(row.id);
    } else if (row.kind === "snip") {
      popup.askSnipArgs(row.content, "copy");
    } else if (row.kind === "pics") {
      const pic = popup.chosenCell(row);
      if (pic) popup.folio.takeClip(pic.id);
    } else if (row.kind === "glyphs") {
      const cell = row.cells[Math.min(popup.cellSel, row.cells.length - 1)];
      if (cell) {
        popup.noteGlyph(cell.char, row.nerd);
        row.nerd ? popup.ideo.copyGlyph(cell.char) : popup.ideo.pasteGlyph(cell.char);
      }
    } else if (row.kind === "file") {
      popup.opening = true;
      popup.finder.open(row);
    } else if (row.kind === "more") {
      // the whole section: its word as the chip, the line after it
      popup.lineAt(row.line);
      input.cursorPosition = input.text.length;
    } else if (row.kind === "search") {
      // the line searched again, its word back as its chip
      popup.lineAt(row.text);
      input.cursorPosition = input.text.length;
    } else if (row.kind === "scoped") {
      popup.bump(row.key);
      popup.handOff(row.view, row.rest, row.action);
    } else if (row.kind === "script") {
      popup.runScript(row.script, row.arg);
    } else if (row.kind === "window") {
      popup.goToWindow(row.address);
    } else if (row.kind === "setting") {
      popup.openSetting(row);
    } else if (row.kind === "storeapp") {
      popup.openStoreApp(row);
    } else if (row.kind === "note") {
      popup.openNote(row);
    } else if (row.kind === "package") {
      popup.changePackage(row);
    } else if (row.kind === "newevent") {
      popup.addEvent(row, false);
    } else if (row.kind === "newnote") {
      popup.saveNote(row.text, false);
    } else if (row.kind === "newtask") {
      popup.addTask(row, false);
    } else if (row.kind === "task") {
      popup.tickTask(row);
    } else if (row.kind === "book") {
      popup.openBook(row);
    } else if (row.kind === "output") {
      popup.useOutput(row);
    } else if (row.kind === "pcolor") {
      popup.copyText(row.hex);
    } else if (row.kind === "place") {
      popup.openPlace(row);
    } else if (row.kind === "proc") {
      if (row.pid > 0) popup.endProcess(row, false);
    } else if (row.kind === "btdev" || row.kind === "wifinet") {
      popup.radioDo(row);
    } else if (row.kind === "repo") {
      popup.openRepo(row);
    } else if (row.kind === "svc") {
      popup.closeThen(() => Quickshell.execDetached(["qs", "ipc", "call", "Hestia", "unit", row.unit]));
    } else if (row.kind === "notif") {
      Howler.openRow(row.row);
      popup.closeCynosure();
    } else if (row.kind === "help") {
      if (row.fill !== "") popup.runInline({ line: row.fill });
    } else if (row.kind === "sitem") {
      popup.runListItem(row);
    } else if (row.kind === "hit") {
      popup.openHit(row);
    } else if (row.kind === "fonts") {
      const f = popup.chosenCell(row);
      if (f) popup.openFont(f);
    } else if (row.kind === "shots") {
      const c = popup.chosenCell(row);
      if (c) popup.openCapture(c);
    } else if (row.kind === "argcmd") {
      // ending processes asks first, on the one-line confirm
      if (row.cmd.kind === "kill") {
        popup.pending = { name: row.label, glyph: row.glyph, confirm: true,
          sh: "pkill " + (row.cmd.force ? "-KILL " : "") + "-i -x -- " + Strings.shellQuote(row.cmd.name) };
        popup.showPicker();
        popup.sel = popup.pickerRows.length - 1;
        return;
      }
      // and the ones that cannot be taken back
      // the trash emptied as Terminus empties it: gio's needs gvfs, which
      // is not always there ("Operation not supported", 2026-11-04)
      const sure = { emptyTrash: Terminus.emptyTrashCommand() + "; notify-send -a Terminus -- 'Trash emptied'",
        clearClips: "cliphist wipe && notify-send -a folio -- 'Clipboard cleared' 'pinned clips stay'" }[row.cmd.kind];
      // every layout gone asks too
      const runs = { quitAll: popup.quitAll, layoutsClear: () => popup.writeLayouts({}) }[row.cmd.kind];
      if (sure || (runs && !(row.cmd.kind === "layoutsClear" && Object.keys(popup.layouts).length === 0))) {
        popup.pending = sure ? { name: row.label, glyph: row.glyph, confirm: true, sh: sure }
          : { name: row.label, glyph: row.glyph, confirm: true, run: runs };
        popup.showPicker();
        popup.sel = popup.pickerRows.length - 1;
        return;
      }
      // a restart too: the oldest process by that name (an app's own, not a
      // helper it started) read for its command line and directory, ended,
      // waited for, then started again from them
      if (row.cmd.kind === "restart") {
        popup.pending = { name: row.label, glyph: row.glyph, confirm: true,
          sh: "bash -c " + Strings.shellQuote(popup.restartScript) + " restart " + Strings.shellQuote(row.cmd.name) };
        popup.showPicker();
        popup.sel = popup.pickerRows.length - 1;
        return;
      }
      popup.runCmd(row.cmd);
    } else if (row.kind === "web") {
      Strings.openLink(row.url);
      popup.closeCynosure();
    } else if (row.kind === "contact") {
      // mail opens elsewhere; a number is only copied, so Cynosure stays
      if (row.email) { Strings.openLink("mailto:" + row.email); popup.closeCynosure(); }
      else popup.copyText(row.phone || row.label);
    } else if (row.kind === "traymenu") {
      lookups.trigger(row.at);
      popup.closeCynosure();
    } else if (row.kind === "info") {
      return;
    } else if (row.kind === "link") {
      popup.openQuickLink(row.url, row.app);
      popup.closeCynosure();
    } else if (row.kind === "fallback") {
      popup.runInline(row.action);
    } else if (row.kind === "run") {
      popup.runCommand(row.text, row.mode);
    } else if (row.kind === "shell") {
      if (row.action.line || row.action.inline) {
        popup.bump(row.key);
        popup.runInline(row.action);
        return;
      }
      if (row.action.view) {
        popup.bump(row.key);
        popup.handOff(row.action.view, "", row.action);
        return;
      }
      const picks = row.action.choose === "timer"
        ? Cynosure.timerChoices(Chronos.timers) : [];
      if (picks.length > 1) {
        popup.pending = row.action;
        popup.choices = picks;
        popup.showPicker();
      } else if (row.action.confirm) {
        popup.pending = row.action;
        popup.showPicker();
        popup.sel = popup.pickerRows.length - 1;   // Back, not Confirm
      } else {
        popup.runAction(row.action);
      }
    } else {
      popup.runCommand(row.key, row.raw.startsWith(Cynosure.ICON_P) ? "Process" : "Terminal");
    }
  }

  // Not written to the history: a verb is not a command you typed, and it
  // is already a row of its own. `ipc` overrides the verb's own call, for a
  // choice made in the picker; the frecency still goes to the verb.
  function runAction(a, ipc) {
    if (!a.noBump) popup.bump(Cynosure.actionKey(a));
    popup.closeCynosure();
    Quickshell.execDetached(["sh", "-c", ipc ? "qs ipc call " + ipc
      : Cynosure.actionCommand(a, Quickshell.shellDir, Quickshell.env("XDG_SESSION_ID") || "")]);
  }

  function deleteSelected() {
    if (popup.mode !== "search") return;
    const row = popup.filtered[popup.sel];
    if (row && row.kind === "hist") {
      popup.histLines = Cynosure.deleteHistoryLine(popup.histLines, row.raw);
      popup.writeHistory();
      popup.rebuild();
    }
  }

  // Tab: a quick panel's row opens it, a name is completed into the field
  function tabRow() {
    if (popup.mode !== "search") { popup.moveSel(1); return; }
    const row = popup.filtered[popup.sel];
    if (!row) return;
    if (row.kind === "file") return;
    if (row.kind === "scoped" || (row.kind === "shell" && row.action.view)) {
      popup.confirm();
      return;
    }
    if (row.kind === "run") return;
    const kind = row.kind;
    const key = row.key;
    if (popup.chip) input.text = row.text; else popup.setLine(row.text);
    const idx = popup.filtered.findIndex((r) => r.kind === kind && r.key === key);
    if (idx >= 0) popup.sel = idx;
  }

  function showPicker() {
    popup.mode = "picker";
    popup.sel = 0;
    input.readOnly = true;
    popup.followSelection();
  }

  FocusRetry {
    id: focusRetry
    live: popup.shown && !popup.taken
    took: input.activeFocus
    onPlace: input.forceActiveFocus()
  }

  // ── SETTING AN ALIAS ──────────────────────────────────────────────────
  // The field becomes "Alias for Firefox" and the word: return keeps it (an
  // empty word takes the alias away), esc leaves it as it was. The line that
  // was typed comes back after.
  // the line is a word being set (an alias, a quick link), not a search
  readonly property bool editing: popup.mode === "alias" || popup.mode === "link" || popup.mode === "hotkey"
    || popup.mode === "clipname" || popup.mode === "snipkey" || popup.mode === "snipargs"
  property var aliasRow: null
  property string aliasNote: ""
  property string aliasWas: ""
  // "New quick link": the same one line, its chip "New quick link" and the
  // word then the address typed after it
  function askLink() {
    popup.aliasRow = null;
    popup.aliasNote = "";
    popup.aliasWas = popup.query;
    popup.mode = "link";
    input.readOnly = false;
    popup.setLine("");
    Qt.callLater(() => input.forceActiveFocus());
  }
  function saveLink() {
    const got = Cynosure.readLink(input.text);
    if (got.problem) { popup.aliasNote = got.problem; return; }
    popup.ownLinks = popup.ownLinks.filter((l) => l.word !== got.link.word).concat([got.link]);
    popup.writeLinks();
    popup.endAlias();
  }
  function askAlias(row) {
    popup.aliasRow = row;
    popup.aliasNote = "";
    popup.aliasWas = popup.query;
    popup.mode = "alias";
    input.readOnly = false;
    popup.setLine(row.alias || "");
    input.selectAll();
    Qt.callLater(() => input.forceActiveFocus());
  }
  // "Rename" on a clip: the same one line, its chip "Rename", the name
  // typed over; return keeps it, an empty line gives the clip its words back
  function askClipName(row) {
    popup.aliasRow = row;
    popup.aliasNote = "";
    popup.aliasWas = popup.query;
    popup.mode = "clipname";
    input.readOnly = false;
    popup.setLine(row.name || "");
    input.selectAll();
    Qt.callLater(() => input.forceActiveFocus());
  }
  // "Set keyword" on a snippet (2026-11-03): typed anywhere, it becomes
  // the snippet (expand.py, below); an empty line takes it away
  function askSnipKey(row) {
    popup.aliasRow = row;
    popup.aliasNote = "";
    popup.aliasWas = popup.query;
    popup.mode = "snipkey";
    input.readOnly = false;
    popup.setLine(row.keyword || "");
    input.selectAll();
    Qt.callLater(() => input.forceActiveFocus());
  }
  function saveSnipKey() {
    const got = Folio.setKeyword(popup.snipKeys, input.text, popup.aliasRow ? popup.aliasRow.path : "");
    if (got.problem) { popup.aliasNote = got.problem; return; }
    popup.snipKeys = got.keys;
    snipKeysFile.setText(JSON.stringify(got.keys, null, 2) + "\n");
    popup.endAlias();
    popup.takeClips();
  }
  // ── A SNIPPET'S {argument}s, ASKED (2026-11-04) ─────────────────────
  // one at a time on the line, its name the chip, its default typed and
  // selected; then what was asked for is done with the filled snippet:
  // "copy", "paste", or "type" (its keyword typed somewhere: erased, then
  // the snippet typed there once the panel has gone)
  property var argAsk: null
  function askSnipArgs(content, then, word) {
    const args = Folio.snippetArgs(content);
    if (args.length === 0) { popup.doSnippet(String(content || ""), then, word); return false; }
    if (!popup.shown) popup.openCynosure();
    popup.argAsk = { content: String(content || ""), args, at: 0, values: ({}), then, word: word || "" };
    popup.aliasRow = null;
    popup.aliasNote = "";
    popup.aliasWas = then === "type" ? "" : popup.query;
    popup.mode = "snipargs";
    input.readOnly = false;
    popup.setLine(args[0].def);
    input.selectAll();
    Qt.callLater(() => input.forceActiveFocus());
    return true;
  }
  function nextSnipArg() {
    const a = popup.argAsk;
    if (!a) { popup.endAlias(); return; }
    a.values[a.args[a.at].name] = input.text;
    if (a.at + 1 < a.args.length) {
      a.at++;
      popup.argAsk = Object.assign({}, a);
      popup.setLine(a.args[a.at].def);
      input.selectAll();
      return;
    }
    const filled = Folio.fillArgs(a.content, a.values);
    popup.argAsk = null;
    popup.endAlias();
    popup.doSnippet(filled, a.then, a.word);
  }
  function endSnipArgs() { popup.argAsk = null; }
  function doSnippet(content, then, word) {
    if (then === "paste") { popup.folio.pasteSnippet(content); return; }
    if (then === "copy") { popup.folio.takeSnippet(content); return; }
    // typed where its keyword was: once the panel has gone, focus is back there
    const job = { word: word || "", fromFile: false,
      command: ["sh", "-c", "printf '%s' \"$1\"; printf '\\036'; wl-paste -n -t text 2>/dev/null | head -c 100000",
        "cynosure", content] };
    if (popup.shown) { popup.typeJobs = popup.typeJobs.concat([job]); popup.closeCynosure(); typeLater.restart(); }
    else RunJob.queued(expandProc, job);
  }
  // typed once the panel has gone, in the order given
  property var typeJobs: []
  Timer {
    id: typeLater
    interval: Zenon.slow + 250
    onTriggered: { const jobs = popup.typeJobs; popup.typeJobs = []; for (const j of jobs) RunJob.queued(expandProc, j); }
  }
  function saveClipName() {
    if (popup.folio && popup.aliasRow) popup.folio.setName(popup.aliasRow.id, input.text);
    popup.endAlias();
  }
  function saveAlias() {
    const word = input.text.trim().toLowerCase();
    const problem = Cynosure.aliasProblem(word);
    if (problem !== "") { popup.aliasNote = problem; return; }
    // a word another row had moves to this one
    const others = {};
    for (const w in popup.aliases) if (w !== word) others[w] = popup.aliases[w];
    popup.aliases = word === "" ? Cynosure.dropAlias(popup.aliases, popup.aliasRow)
      : Cynosure.setAlias(others, word, popup.aliasRow);
    popup.writeAliases();
    popup.endAlias();
  }
  function endAlias() {
    popup.aliasRow = null;
    popup.aliasNote = "";
    popup.mode = "search";
    popup.setLine(popup.aliasWas);
    input.cursorPosition = input.text.length;
    popup.rebuild();
  }

  function backToSearch() {
    popup.pending = null;
    popup.choices = null;
    popup.mode = "search";
    popup.sel = 0;
    input.readOnly = false;
    popup.followSelection();
    Qt.callLater(() => input.forceActiveFocus());
  }

  function resetState() {
    popup.endHotkey();
    popup.altHeld = false;
    popup.actionsOpen = false;
    popup.lexiChip = -1;
    // read again next time: what is installed may have changed meanwhile
    popup.storeApps = [];
    popup.pkgFound = [];
    popup.folioLatched = false;
    popup.snippetAsked = false;
    popup.clipRows = [];
    popup.pwMode = false;
    popup.pwLatched = false;
    popup.pwPending = null;
    popup.glyphRows = [];
    popup.cellSel = 0;
    popup.opening = false;
    popup.fileRows = [];
    if (popup.finder) popup.finder.search("");
    openWith.close();
    popup.pending = null;
    popup.choices = null;
    popup.mode = "search";
    popup.query = "";
    popup.sel = 0;
    popup.setLine("");
    input.readOnly = false;
  }

  function openCynosure() {
    if (popup.shown && !popup.collapsing) return;
    rowFlash.cancel();
    popup.resetState();
    popup.compactOpen = false;
    popup.shown = true;
    popup.collapsing = false;
    if (popup.metis) popup.metis.start();
    histCat.running = false;
    histCat.running = true;
    scriptsProc.running = false;
    scriptsProc.running = true;
    // walked again on every open, as artemis' own panel did: 19ms for ~4k
    // entries, and no staleness to reason about
    if (popup.finder) popup.finder.reindex();
    popup.applyFilter();
    popup.playOpen();
    focusRetry.begin();
    if (popup.keptLine !== "" && Date.now() - popup.keptAt < Oracle.cynosureKeepLine * 1000) {
      popup.setLine(popup.keptLine);
      input.selectAll();
    }
  }
  property string keptLine: ""
  property real keptAt: 0

  // The list keeps what it showed until the panel has faded out, so the row
  // that was chosen is still under the cursor on the way down.
  function closeCynosure() {
    if (!popup.shown || popup.collapsing) return;
    // the line that led somewhere, kept for "history"
    // and for Keep the line (Oracle): brought back on an opening soon after
    popup.keptLine = popup.mode === "search" ? popup.query : "";
    popup.keptAt = Date.now();
    if (popup.mode === "search" && popup.query.trim() !== "" && Oracle.cynosureRemember) {
      // what was searched for, under its chip (Cynosure.pickedLine): the
      // chip in place or the line's own tag, else the kind of row picked
      const pick = popup.lastPick;
      const tag = popup.fieldTag && popup.fieldTag.text ? popup.fieldTag
        : pick ? { glyph: "", text: Cynosure.kindName(pick) } : null;
      const line = Cynosure.pickedLine(popup.query, popup.chip ? popup.chip.word : "", pick);
      popup.queries = Cynosure.addQuery(popup.queries, Cynosure.queryEntry(line, tag));
      writer.write(Cynosure.queriesPath(), Cynosure.serializeQueries(popup.queries));
    }
    // a view keeps what it has on screen first (metis' answer), then says
    // dismissed, which comes back here
    if (popup.pwMode && popup.calypso && !popup.calypso.closing) { popup.calypso.closePopup(); return; }
    // the calculator keeps the answer it was showing, as it always has
    if (popup.metis && popup.calcShown && !popup.metis.closing) { popup.metis.closePopup(); return; }
    popup.collapsing = true;
    popup.playClose();
  }
  onCloseFinished: {
    if (!popup.shown) popup.resetState();
    popup.runAfterClose();
  }

  function toggle() {
    if (popup.shown && !popup.collapsing) popup.closeCynosure();
    else popup.openCynosure();
  }

  // the answer card, when it is up, is row -1: above the first
  function moveSel(delta) {
    const len = popup.mode === "picker" ? popup.pickerRows.length : popup.filtered.length;
    const first = popup.mode === "search" && popup.cardUp ? -1 : 0;
    const n = len - first;
    if (n <= 0) return;
    popup.sel = ((popup.sel - first + delta) % n + n) % n + first;
    popup.followSelection();
  }

  function jumpSel(delta) {
    const len = popup.mode === "picker" ? popup.pickerRows.length : popup.filtered.length;
    if (len === 0) return;
    popup.sel = Math.max(0, Math.min(len - 1, popup.sel + delta));
    popup.followSelection();
  }

  // The keys the list answers, asked by the field BEFORE its own handling:
  // a TextInput would take Up and Down for nothing, and the list is what they
  // move. Left and Right stay the caret's.
  // ── THE ACTIONS PANEL (shift return) ──────────────────────────────────
  // Raycast's ⌘K: what the chosen row (or the calculator's card) can do,
  // in the suite's menu card (morpheus/MenuCore) over the panel's bottom
  // right. Up and down choose, return does it, esc or shift+return puts it
  // away. Shift+return opens it (user, 2026-11-01: not ctrl k).
  property bool actionsOpen: false
  property var actionRows: []
  property int actionSel: 0
  // the row the panel was opened on: kept, so a list that refreshes under
  // it does not change what the action is done to
  property var actionOn: null
  // something to say: a player, and the word's own recording (a definition
  // Wiktionary has none for offers no Say, user 2026-11-08) or a translation
  readonly property bool lexiCanSay: !!popup.lexi && popup.lexi.playerCmd !== ""
    && (popup.lexiMode === "dict" ? !!(popup.lexi.dictResult && popup.lexi.dictResult.audio)
                                  : !!(popup.lexi.cardTr && popup.lexi.cardTr.translation))
  readonly property var chosenRow: !popup.cardSel ? popup.current
    : popup.calcShown ? { kind: "calc" }
    : popup.lexiShown ? { kind: "lexi", mode: popup.lexiMode, more: !!popup.lexi.dictResult,
        swap: !!(popup.lexiTr && popup.lexiTr.source), say: popup.lexiCanSay }
    : { kind: "answer", weather: !!popup.wxAsk,
        calDay: popup.answer && popup.answer.kind === "cal" ? popup.answer.day || "" : "",
        kairos: popup.answer && popup.answer.kairos ? popup.answer.kairos : "" }
  // ── DRAGGED OUT ───────────────────────────────────────────────────────
  // A file, a clip, a picture, a snippet, an emoji or a link dragged from
  // the list into another app (artemis' and folio's way, brought here): for
  // as long as the drag is out, the panel lets go of the pointer (its input
  // region is nothing) and of its grab, so the drop is the other app's; a
  // copy dropped closes the panel. The card under the pointer is terminus'.
  property bool dragging: false
  // explicitly the whole surface when idle, explicitly nothing while
  // dragging: an unset mask read the wrong way leaves it click-through
  mask: Region { item: popup.dragging ? null : closeArea }
  Term.DragCard { id: dragCard }
  function dragPicture(label, glyph, then, thumb) {
    dragCard.label = label;
    dragCard.glyph = glyph;
    dragCard.ink = Zenon.accent;
    dragCard.thumb = thumb || "";
    dragCard.picture(then);
  }
  // offer `item`'s drag with `mime`, once its card is drawn
  function offerDrag(item, mime, label, glyph, thumb) {
    popup.dragPicture(label, glyph, (url) => {
      item.Drag.mimeData = mime;
      item.Drag.imageSource = url;
      item.Drag.active = true;
    }, thumb);
  }
  function startDrag(item, r) {
    popup.dragging = true;
    if (r.kind === "file")
      popup.offerDrag(item, { "text/uri-list": Strings.fileUrl(r.path.replace(/\/$/, "")) + "\r\n" }, r.label, r.glyph);
    else if (r.kind === "snip") popup.offerDrag(item, { "text/plain": String(r.content || "") }, r.label, r.glyph);
    else if (r.kind === "link") popup.offerDrag(item, { "text/uri-list": r.url + "\r\n", "text/plain": r.url }, r.label, r.glyph);
    else if (r.kind === "clip")
      // the clip itself, decoded (the row's is cliphist's folded preview)
      popup.folio.decodeText(r.id, (t) => {
        if (!popup.dragging) return;
        popup.offerDrag(item, { "text/plain": t !== "" ? t : String(r.label) }, r.label, r.glyph);
      });
    else popup.dragging = false;
  }
  function dragEnded(item, action) {
    item.Drag.active = false;
    popup.dragging = false;
    if (action === Qt.CopyAction) popup.closeCynosure();
  }

  // the chosen cell's item, which the cell cursor slides to
  property Item chosenCellItem: null
  function placeCellCursor() {
    const c = popup.current;
    const row = c && c.cells ? list.itemAtIndex(popup.sel) : null;
    popup.chosenCellItem = row && row.cellItem ? row.cellItem(Math.min(popup.cellSel, c.cells.length - 1)) : null;
  }
  onFilteredChanged: Qt.callLater(popup.placeCellCursor)
  // the cell chosen in a row of cells (a strip of emoji, a row of pictures)
  function chosenCell(r) {
    return r && r.cells ? r.cells[Math.min(popup.cellSel, r.cells.length - 1)] : null;
  }
  function openActions() {
    let r = popup.chosenRow;
    // a picture's actions are the chosen picture's
    if (r && r.kind === "pics") r = { kind: "clipimg", id: popup.chosenCell(r).id };
    // a font tile's are the chosen font's
    if (r && r.kind === "fonts") r = popup.chosenCell(r);
    // a capture's are the chosen capture's
    if (r && r.kind === "shots") {
      const c = popup.chosenCell(r);
      r = c ? { kind: "shot", path: c.path, video: c.video, label: c.name } : null;
    }
    const favAt = r ? popup.favorites.findIndex((f) => Cynosure.hotkeyTarget(f) === Cynosure.hotkeyTarget(r)) : -1;
    const rows = Cynosure.rowActions(r && Cynosure.HOTKEY_KINDS[r.kind]
      ? Object.assign({}, r, { hotkey: popup.chordWords(Cynosure.hotkeyOf(popup.hotkeys, r)),
          favorite: favAt >= 0, favAt, favCount: popup.favorites.length }) : r);
    if (rows.length === 0) return;
    // a file goes out through the suite's one Share menu (morpheus Share),
    // before Move to the trash
    if (r.kind === "file" && !r.isDir) {
      const path = r.path;
      const share = Share.items([path], false, 1).map((t) => ({ id: "fn", text: t.label, icon: t.glyph, hint: "", fn: t.act }));
      rows.splice(rows.length - 1, 0, ...share);
    }
    // a quick link: which browser it always opens in, after Open
    if (r.kind === "link" && /^https?:/i.test(r.url)) {
      const link = r;
      const pick = popup.browsers.filter((b) => b.id !== link.app).map((b) => ({ id: "fn", text: "Always open in " + b.name,
        icon: "\uF14C", hint: "", stay: true, fn: () => popup.setLinkApp(link, b.id, b.name) }));
      if (link.app) pick.push({ id: "fn", text: "Open in the default browser", icon: "\uF14C", hint: "", stay: true, fn: () => popup.setLinkApp(link, "", "") });
      if (pick.length > 1 || link.app) rows.splice(1, 0, ...pick);
    }
    popup.actionOn = r;
    popup.actionRows = rows;
    popup.actionSel = 0;
    popup.actionsOpen = true;
  }
  function closeActions() { popup.actionsOpen = false; }
  // a file moved to the trash: gone from the finder's list, said if it failed
  Process {
    id: trashProc
    property string path: ""
    stderr: StdioCollector { id: trashErr; waitForEnd: true }
    onExited: (code) => {
      if (code !== 0) {
        Quickshell.execDetached(["notify-send", "-a", "Cynosure", "--", "Not moved to the trash", trashErr.text.trim()]);
        return;
      }
      popup.fileRows = popup.fileRows.filter((f) => f.path !== trashProc.path);
      if (popup.shotsScoped || popup.recsScoped) popup.askCaptures();
      if (popup.finder) popup.finder.reindex();
      popup.applyFilter();
    }
  }
  function actionsKey(event) {
    const k = event.key;
    event.accepted = true;
    const shiftRet = (k === Qt.Key_Return || k === Qt.Key_Enter) && (event.modifiers & Qt.ShiftModifier);
    if (k === Qt.Key_Escape || shiftRet) { popup.closeActions(); return; }
    if (k === Qt.Key_Up) { popup.actionSel = (popup.actionSel + popup.actionRows.length - 1) % popup.actionRows.length; return; }
    if (k === Qt.Key_Down) { popup.actionSel = (popup.actionSel + 1) % popup.actionRows.length; return; }
    if (k === Qt.Key_Return || k === Qt.Key_Enter) { popup.doAction(popup.actionSel); return; }
    // anything else is not typed into the line while the panel is up
  }
  // a copy never closes Cynosure: you may want the next one too (user,
  // 2026-11-08). Pastes, opens and launches still close.
  function copyText(t) {
    Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "cynosure", String(t)]);
  }
  function doAction(i) {
    const act = popup.actionRows[i];
    const r = popup.actionOn;
    popup.closeActions();
    if (!act || !r) return;
    const m = popup.metis;
    if (act.id.startsWith("as:")) { popup.pasteAs(r, act.id.slice(3)); return; }
    if (act.id.startsWith("form:")) {
      const f = (r.forms || []).find((x) => "form:" + x[0] === act.id);
      if (f) popup.copyText(f[1]);
      return;
    }
    switch (act.id) {
    case "fn": act.fn(); if (!act.stay) popup.closeCynosure(); return;
    // taken out of the list (Oracle › Cynosure › Search keeps the hidden)
    case "hide":
      Oracle.set("cynosureHidden", Cynosure.withHidden(Oracle.cynosureHidden, Cynosure.hideId(r), r.label, true));
      return;
    case "fbUp": Oracle.set("cynosureFallbackList", Cynosure.fallbackMoved(Oracle.cynosureFallbackList, r.fbWord, -1)); return;
    case "fbDown": Oracle.set("cynosureFallbackList", Cynosure.fallbackMoved(Oracle.cynosureFallbackList, r.fbWord, 1)); return;
    case "fbOff": Oracle.set("cynosureFallbackList", Cynosure.fallbackSet(Oracle.cynosureFallbackList, r.fbWord, false)); return;
    case "addFav": popup.setFavorites(Cynosure.addFavorite(popup.favorites, r)); return;
    case "dropFav": popup.setFavorites(Cynosure.dropFavorite(popup.favorites, r)); return;
    case "favUp": popup.setFavorites(Cynosure.moveFavorite(popup.favorites, r, -1)); return;
    case "favDown": popup.setFavorites(Cynosure.moveFavorite(popup.favorites, r, 1)); return;
    case "trash":
      // gio's trash, as terminus' own delete: Tidy or the trash brings it back
      trashProc.path = r.path;
      trashProc.command = ["gio", "trash", "--", r.path];
      trashProc.running = true;
      return;
    case "taskOpen": popup.addTask(r, true); return;
    case "copyItem": popup.copyText(r.item.copy !== "" ? r.item.copy : r.item.title); return;
    case "copyLine": popup.copyText(r.text); return;
    case "copyPic":
      Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\"", "cynosure", r.path]);
      return;
    case "winLeft": popup.snapWindow(r.address, "left"); return;
    case "winRight": popup.snapWindow(r.address, "right"); return;
    case "winMax": popup.snapWindow(r.address, "max"); return;
    case "winNext": popup.snapWindow(r.address, "next"); return;
    case "openTerm":
      Quickshell.execDetached(["sh", "-c", Terminus.shellCommand(r.path, "")]);
      popup.closeCynosure();
      return;
    case "forceQuit": popup.endProcess(r, true); return;
    case "copyPid": popup.copyText(String(r.pid)); return;
    case "hermesOpen": popup.closeThen(() => Hermes.open(r.kind === "btdev" ? "bluetooth" : "network")); return;
    case "svcStart": popup.serviceDo(r, "start"); return;
    case "svcStop": popup.serviceDo(r, "stop"); return;
    case "svcRestart": popup.serviceDo(r, "restart"); return;
    case "svcLog": popup.closeThen(() => Quickshell.execDetached(["qs", "ipc", "call", "Hestia", "journal", r.unit])); return;
    case "copyBody": popup.copyText(r.body); return;
    case "dropNotif": Howler.forget(r.row); popup.applyFilter(); return;
    case "taskShow": popup.closeThen(() => { if (Clio.app) Clio.app.openTask(r.task.id, r.task.h); }); return;
    case "go":
      if (r.kind === "calc") m.takeShown(false);
      else if (r.kind === "answer") { popup.takeAnswer(); popup.closeCynosure(); }
      else if (r.kind === "lexi") popup.lexiCopy();
      else popup.confirm();
      return;
    case "setAlias": popup.askAlias(r); return;
    case "setHotkey": popup.askHotkey(r); return;
    case "dropHotkey": popup.dropHotkey(r); return;
    case "winHere": popup.windowDo(r.address, "here"); return;
    case "winFloat": popup.windowDo(r.address, "float"); return;
    case "winCenter": popup.windowDo(r.address, "center"); return;
    case "winFull": popup.windowDo(r.address, "full"); return;
    case "closeWin":
      Hyprland.dispatch(Hypr.closeWindow(Hypr.byAddress(r.address)));
      return;
    case "copyUrl": popup.copyText(r.url || r.uri); return;
    case "dropLink":
      popup.ownLinks = popup.ownLinks.filter((l) => l.word !== r.word);
      popup.writeLinks();
      popup.rebuild();
      return;
    case "dropAlias":
      popup.aliases = Cynosure.dropAlias(popup.aliases, r);
      popup.writeAliases();
      popup.rebuild();
      return;
    case "calOpen":
      Quickshell.execDetached(["qs", "ipc", "call", "Calendar", "day", r.calDay]);
      popup.closeCynosure();
      return;
    case "kairosOpen":
      Quickshell.execDetached(["qs", "ipc", "call", "Kairos", "open", r.kairos]);
      popup.closeCynosure();
      return;
    case "forecast":
      Quickshell.execDetached(["qs", "ipc", "call", "Chronos", "toggle"]);
      popup.closeCynosure();
      return;
    case "copyName":
      popup.copyText(r.kind === "glyphs" ? (r.nerd ? (r.cells[popup.cellSel] || {}).cls : (r.cells[popup.cellSel] || {}).name) || "" : r.kind === "hist" ? r.key : r.kind === "proc" ? r.args || r.name : r.label);
      return;
    case "copyPath": popup.copyText(r.path || (r.script ? r.script.path : "")); return;
    case "editScript":
      Quickshell.execDetached(["qs", "ipc", "call", "Plato", "open", r.script.path]);
      popup.closeCynosure();
      return;
    case "reveal":
      Quickshell.execDetached(["qs", "ipc", "call", "Terminus", "reveal", r.path]);
      popup.closeCynosure();
      return;
    case "openWith": openWith.ask(r.path); return;
    case "forget":
      if (r.kind === "hist") { popup.deleteSelected(); return; }
      delete popup.freqMap[r.key];
      popup.writeFreq();
      popup.rebuild();
      return;
    case "runTerminal": popup.runCommand(r.key, "Terminal"); return;
    case "runProcess": popup.runCommand(r.key, "Process"); return;
    case "keep": popup.folio.keepClip(r.id); return;
    case "rename": popup.askClipName(r); return;
    case "pin": popup.folio.togglePin(r.id, r.pinText); return;
    case "copyEmail": popup.copyText(r.email); return;
    case "copyPhone": popup.copyText(r.phone); return;
    case "snipKey": popup.askSnipKey(r); return;
    case "turn": popup.folio.toggleTurn(r.id); return;
    case "inTurn": popup.folio.pasteInTurn(); popup.closeCynosure(); return;
    case "drop":
      if (r.kind === "snip") popup.folio.dropSnippet(r.path); else popup.folio.dropClip(r.id);
      return;
    case "markUp":
      if (r.kind === "shot") { popup.closeThen(() => Quickshell.execDetached(["qs", "ipc", "call", "Picasso", "annotate", r.path])); return; }
      popup.folio.annotateClip(r.id);
      return;
    case "viewPic": popup.folio.viewClip(r.id); return;
    case "savePic": popup.folio.saveClip(r.id); return;
    case "openUrl": Strings.openLink(String(r.label).trim()); popup.closeCynosure(); return;
    case "copyFile":
      // as a file, not its path: pasted into terminus or a browser's upload
      Quickshell.execDetached(["sh", "-c", "printf 'file://%s\\n' \"$1\" | wl-copy -t text/uri-list", "cynosure", r.path]);
      return;
    case "edit": popup.folio.editSnippetAt(r.path, r.label, r.content); return;
    case "newSnippet": popup.runInline({ inline: "newSnippet" }); return;
    case "copyGlyph": {
      const ch = (r.cells[popup.cellSel] || {}).char || "";
      popup.noteGlyph(ch, r.nerd);
      popup.ideo.copyGlyph(ch);
      return;
    }
    case "copyCode": popup.copyText(Cynosure.codepoints((r.cells[popup.cellSel] || {}).char)); return;
    case "copyAnswer": m.takeShown(true); return;
    case "noteOpen": popup.saveNote(r.text, true); return;
    case "eventOpen": popup.addEvent(r, true); return;
    case "pasteSnip": popup.askSnipArgs(r.content, "paste"); return;
    case "pkgShow": popup.closeThen(() => Ceres.showPackage(r.label)); return;
    case "storeInstall":
      Ceres.install([r.pkg], "from Cynosure", () => {});
      Ceres.openWindow("store");
      popup.closeCynosure();
      return;
    case "lexiSay": popup.lexi.cardSpeak(popup.lexiMode); return;
    case "lexiMore": popup.lexi.cardMore(); return;
    case "lexiSwap": popup.lexiSwap(); return;
    case "copyQuestion": popup.copyText(m.query); return;
    case "tape": m.tapeToggleOpen(); return;
    case "explain":
      if (m.readings.length > 1) m.readingIdx = (m.readingIdx + 1) % m.readings.length;
      return;
    }
  }

  function fieldKey(event) {
    const k = event.key;
    // the actions panel has the keys while it is up
    if (popup.actionsOpen) { popup.actionsKey(event); return; }
    // waiting for a hotkey's chord: every key is the chord
    if (popup.mode === "hotkey") { popup.hotkeyKey(event); return; }
    // setting an alias: return keeps it, esc leaves it; the rest is typing
    if (popup.mode === "alias" || popup.mode === "link" || popup.mode === "clipname" || popup.mode === "snipkey"
        || popup.mode === "snipargs") {
      if (k === Qt.Key_Return || k === Qt.Key_Enter) {
        event.accepted = true;
        popup.mode === "link" ? popup.saveLink() : popup.mode === "clipname" ? popup.saveClipName()
          : popup.mode === "snipkey" ? popup.saveSnipKey() : popup.mode === "snipargs" ? popup.nextSnipArg()
          : popup.saveAlias();
      }
      else if (k === Qt.Key_Escape) { event.accepted = true; popup.endSnipArgs(); popup.endAlias(); }
      return;
    }
    if (k === Qt.Key_Alt) { popup.altHeld = true; return; }
    // alt 1–9: that row, at once (user, 2026-11-01: alt, not ctrl)
    if ((event.modifiers & Qt.AltModifier) && k >= Qt.Key_1 && k <= Qt.Key_9 && popup.mode === "search") {
      event.accepted = true;
      const n = k - Qt.Key_1;
      if (n < popup.filtered.length) { popup.sel = n; popup.altHeld = false; popup.confirm(); }
      return;
    }
    // what you searched before is "history …" (user, 2026-11-04: up for it
    // "is really messing things up"), so up and down are only the list's
    if ((k === Qt.Key_Return || k === Qt.Key_Enter) && (event.modifiers & Qt.ShiftModifier)
        && popup.mode === "search") {
      event.accepted = true;
      popup.openActions();
      return;
    }
    // ONE RULE FOR THE WHOLE PANEL (user, 2026-11-01): esc clears the line,
    // and on an empty one closes; backspace on an empty line goes back a step
    if (k === Qt.Key_Escape) {
      event.accepted = true;
      if (popup.mode === "picker") { popup.backToSearch(); popup.setLine(""); }
      // Esc: Closes (Oracle) skips the clearing. A chip outlasts the first
      // esc (user, 2026-11-04): the words go, then the chip, then the panel
      else if (input.text !== "" && Oracle.cynosureEsc !== "close") input.text = "";
      else if (popup.chip && Oracle.cynosureEsc !== "close") popup.chip = null;
      else if (popup.compactOpen) popup.compactOpen = false;
      else popup.closeCynosure();
      return;
    }
    // the picker's line is the verb that asked, kept: backspace there is
    // always back, not a letter off it
    if (k === Qt.Key_Backspace && (input.text === "" || popup.mode === "picker")) {
      event.accepted = true;
      if (popup.mode === "picker") popup.backToSearch();
      else if (popup.chip) popup.chip = null;
      return;
    }
    // the answer chosen: the calculator's own keys first (tab its chips,
    // return pastes, ctrl+return copies, ctrl+h its tape, up its history),
    // and down off the bottom of it into the list
    // a smart answer's card: return copies it; up stays, down into the list
    // the dictionary's or the translator's card: tab its chips, return
    // copies (or takes the chip), alt p says it, alt e more, alt s swaps
    if (popup.cardSel && popup.lexiShown && popup.lexiKey(event)) return;
    if (popup.cardSel && !popup.calcShown) {
      if (k === Qt.Key_Up || k === Qt.Key_Down) {
        event.accepted = true;
        if (k === Qt.Key_Down && popup.filtered.length > 0) { popup.sel = 0; popup.followSelection(); }
        return;
      }
      if (k === Qt.Key_Return || k === Qt.Key_Enter) {
        event.accepted = true;
        popup.takeAnswer();
        popup.closeCynosure();
        return;
      }
    }
    if (popup.cardSel && popup.calcShown) {
      const m = popup.metis;
      // up and down are the list's (the tape's while it is open): up stays
      // on the card, down goes on into the list
      if ((k === Qt.Key_Up || k === Qt.Key_Down) && !m.tapeMode) {
        event.accepted = true;
        if (k === Qt.Key_Down && popup.filtered.length > 0) { popup.sel = 0; popup.followSelection(); }
        return;
      }
      const caret = k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Home || k === Qt.Key_End;
      if (!caret) {
        m.handleKey(event);
        if (event.accepted) return;
      }
    }
    // the one-line confirm: its two answers sit side by side
    if ((k === Qt.Key_Left || k === Qt.Key_Right) && popup.confirmLine) {
      event.accepted = true;
      popup.moveSel(k === Qt.Key_Left ? -1 : 1);
      return;
    }
    if ((k === Qt.Key_Left || k === Qt.Key_Right) && popup.current && popup.current.cells) {
      event.accepted = true;
      popup.moveCell(k === Qt.Key_Left ? -1 : 1);
      return;
    }
    if (k === Qt.Key_Up) { event.accepted = true; popup.moveSel(-1); return; }
    if (k === Qt.Key_Down && popup.compactNow) { event.accepted = true; popup.compactOpen = true; popup.sel = 0; return; }
    if (k === Qt.Key_Down) { event.accepted = true; popup.moveSel(1); return; }
    if (k === Qt.Key_PageUp) { event.accepted = true; popup.jumpSel(-8); return; }
    if (k === Qt.Key_PageDown) { event.accepted = true; popup.jumpSel(8); return; }
    if (k === Qt.Key_Tab) { event.accepted = true; if (!popup.chipTab() && !popup.chipTurn(false)) popup.tabRow(); return; }
    if (k === Qt.Key_Backtab) { event.accepted = true; if (!popup.chipTurn(true)) popup.moveSel(-1); return; }
    if (k === Qt.Key_Return || k === Qt.Key_Enter) {
      event.accepted = true;
      if ((event.modifiers & Qt.AltModifier) && popup.mode === "search") {
        const q = popup.query.trim();
        if (q !== "") popup.runCommand(q, "Terminal");
      } else popup.confirm();
      return;
    }
    if (k === Qt.Key_Delete && popup.mode === "search" && popup.current
        && popup.current.kind === "hist") {
      event.accepted = true;
      popup.deleteSelected();
      return;
    }
    // folio's keys, on its rows: delete removes, shift+return marks up a
    // picture, ctrl+s keeps a clip as a snippet, ctrl+e edits a snippet,
    // ctrl+n writes a new one
    const c = popup.current;
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
    if (popup.folio && ctrl && k === Qt.Key_N && popup.mode === "search") {
      event.accepted = true;
      popup.folio.editSnippetAt("", "", "");
      return;
    }
    if (!popup.folio || !c) return;
    if (k === Qt.Key_Delete && c.kind === "clip") {
      event.accepted = true; popup.folio.dropClip(c.id);
    } else if (k === Qt.Key_Delete && c.kind === "pics") {
      event.accepted = true; popup.folio.dropClip(popup.chosenCell(c).id);
    } else if (k === Qt.Key_Delete && c.kind === "snip") {
      event.accepted = true; popup.folio.dropSnippet(c.path);
    } else if (ctrl && k === Qt.Key_S && c.kind === "clip") {
      event.accepted = true; popup.folio.keepClip(c.id);
    } else if (ctrl && k === Qt.Key_R && c.kind === "clip") {
      event.accepted = true; popup.askClipName(c);
    } else if (ctrl && k === Qt.Key_P && c.kind === "clip") {
      event.accepted = true; popup.folio.togglePin(c.id, c.pinText);
    } else if (ctrl && k === Qt.Key_Space && c.kind === "clip" && !c.gone) {
      event.accepted = true; popup.folio.toggleTurn(c.id);
    } else if (ctrl && (k === Qt.Key_Return || k === Qt.Key_Enter) && c.kind === "clip" && popup.folio.turn.length > 0) {
      event.accepted = true; popup.folio.pasteInTurn(); popup.closeCynosure();
    } else if (ctrl && k === Qt.Key_K && c.kind === "snip") {
      event.accepted = true; popup.askSnipKey(c);
    } else if (ctrl && k === Qt.Key_E && c.kind === "snip") {
      event.accepted = true; popup.folio.editSnippetAt(c.path, c.label, c.content);
    }
  }

  function hints() {
    if (popup.mode === "link") return [["return", "save"], ["esc", "cancel"]];
    if (popup.mode === "clipname")
      return [["return", input.text.trim() !== "" ? "save" : popup.aliasRow && popup.aliasRow.name ? "remove name" : "leave it"],
        ["esc", "cancel"]];
    if (popup.mode === "snipargs" && popup.argAsk)
      return [["return", popup.argAsk.at + 1 < popup.argAsk.args.length ? "next"
        : popup.argAsk.then === "copy" ? "copy" : popup.argAsk.then === "paste" ? "paste" : "type it"], ["esc", "cancel"]];
    if (popup.mode === "snipkey")
      return [["return", input.text.trim() !== "" ? "save" : popup.aliasRow && popup.aliasRow.keyword ? "remove keyword" : "leave it"],
        ["esc", "cancel"]];
    if (popup.mode === "hotkey") return [["super ctrl alt + key", "set"], ["esc", "cancel"]];
    if (popup.mode === "alias")
      return [["return", input.text.trim() !== "" ? "save"
                : popup.aliasRow && popup.aliasRow.alias ? "remove alias" : "leave it"], ["esc", "cancel"]];
    if (popup.mode === "picker")
      return [["return", "choose"], ["backspace", "back"], ["esc", "clear"]];
    if (popup.actionsOpen) return [["↑↓", "choose"], ["return", "do it"], ["esc", "back"]];
    // the dictionary's, passwords' or the snippet page's while one has the
    // field
    if (popup.folioEditing) return Folio.hintText("edit");
    if (popup.pwMode && popup.calypso) return popup.calypso.hints();
    // Raycast's strip: what return does, the actions panel, esc — the rest of
    // a row's keys are listed with their actions (shift return)
    const out = [];
    if (popup.cardSel && popup.calcShown) {
      out.push(["return", "paste"], ["tab", "units"]);
    } else if (popup.cardSel && popup.lexiShown) {
      if (popup.lexiChip >= 0 || !popup.lexiBare)
        out.push(["return", popup.lexiChip >= 0 ? (popup.lexiMode === "trans" && !popup.lexiBare ? "translate" : "look up") : "copy"]);
      if (popup.lexiChips.length && !popup.chipOffer) out.push(["tab", popup.lexiMode === "trans" && !popup.lexiBare ? "languages"
        : popup.lexiBare ? "recents" : "words"]);
    } else if (popup.cardSel) {
      out.push(["return", "copy"]);
    } else {
      const r = popup.current;
      if (r && r.cells) out.push(["←→", "choose"]);
      if (r) out.push(["return", Cynosure.verbOf(r)]);
    }
    if (popup.chosenRow) out.push(["shift return", "actions"]);
    // tab makes the word a chip: which one, said before it is pressed
    // (hint words are lowercase, as every strip's)
    if (popup.chipOffer) out.unshift(["tab", popup.chipOffer.chip.text.toLowerCase()]);
    else if (popup.chipNext) out.unshift(["tab", popup.chipNext.text.toLowerCase()]);
    if (!popup.chipOffer && popup.chip && input.text === "") out.push(["backspace", "remove chip"]);
    // what the next esc takes: the words, then the chip, then the panel
    const keeps = Oracle.cynosureEsc !== "close";
    out.push(["esc", keeps && input.text !== "" ? "clear" : keeps && popup.chip ? "remove chip" : "close"]);
    return out;
  }


  // Dim the screen behind (Oracle), wherever it opens: the panel is a hole
  // in it (morpheus/SheetDim), so the pill it may be and its glass are not
  // darkened with the rest
  SheetDim {
    width: popup.width
    height: popup.height
    strength: Oracle.cynosureDimStrength
    ink: Oracle.cynosureDim ? popup.contentFade : 0
    holeX: panel.x
    holeY: panel.y
    holeW: panel.width
    holeH: panel.height
    holeRadius: bgRoot.radius
  }

  // a press anywhere off the panel closes it
  MouseArea {
    id: closeArea
    anchors.fill: parent
    z: 0
    onClicked: popup.closeCynosure()
  }

  LayerPanel {
    id: panel
    host: popup
    ground: bgRoot
    width: Math.round(popup.liveWidth)
    height: popup.calcHeight()

    PanelGround {
      id: bgRoot
      color: Zenon.layerBg

      // everything the panel shows, in one item
      Item {
        id: stage
        anchors.fill: parent

      // rows scrolled off the top carry on under the field, frosted (see
      // morpheus/ScrollEdge); before the field, so the field draws over it
      ScrollEdge {
        view: list
        visible: !popup.confirmLine
        x: list.x
        width: list.width
        height: list.y
      }
      // and the ones still to come run on under the foot, sharp and fading:
      // the keys' pill frosts only what is behind it (ScrollEdge underPill)
      ScrollEdge {
        view: list
        visible: !popup.confirmLine
        below: true
        bar: hintStrip
        x: list.x
        y: hintStrip.y
        width: list.width
        height: hintStrip.height
      }

      // ------------------------------------------------------- field --
      Item {
        id: field
        // hidden while something has taken the field: what took it draws
        // its own line in this place
        visible: !popup.taken
        width: parent.width
        height: popup.confirmLine ? popup.confirmH : popup.fieldH

        // the confirm's red, the question's own ground only: on the one-line
        // strip it ends where the question does, and its two answers follow
        Rectangle {
          width: popup.confirmLine ? popup.questionW : parent.width
          height: parent.height
          color: popup.alarm ? Zenon.red : "transparent"
          Behavior on color { ColorAnimation { duration: Zenon.normal; easing.type: Zenon.ease } }
        }

        Text {
          id: fieldGlyph
          // in the pill instead, while there is one
          opacity: popup.pillShown ? 0 : 1
          x: Math.round((popup.fieldH - Zenon.px(22)) / 2) + popup.fieldInset
          width: Zenon.px(22)
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignHCenter
          text: popup.mode === "picker" && popup.pending && popup.pending.glyph
            ? popup.pending.glyph : popup.mode === "alias" ? "\uF02B" : popup.mode === "link" ? "\uF0C1"
            : popup.mode === "clipname" ? "\uF044"
            : popup.mode === "snipkey" ? "\uF11C"
            : popup.mode === "snipargs" ? "\uEB66"
            : popup.mode === "hotkey" ? "\uF11C"
            : popup.fieldTag && popup.fieldTag.glyph ? popup.fieldTag.glyph : ""
          color: popup.alarm ? Zenon.inkOnAccent : popup.mode === "picker" ? Zenon.white : Zenon.muted
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(popup.confirmLine ? 16 : 18)
        }

        TextInput {
          id: input
          objectName: "cynosureLine"
          // a pill starts where the glyph would be: the glyph is in it
          anchors.left: popup.pillShown ? fieldGlyph.left : fieldGlyph.right
          anchors.leftMargin: popup.pillShown ? 0 : 14
          anchors.right: popup.fieldTag && !popup.chip ? fieldTagLabel.left : queryClear.left
          anchors.rightMargin: 10
          height: parent.height
          // the question takes the field's place in the picker; the input
          // keeps the focus there, unseen, so the keys still arrive
          opacity: popup.mode === "search" || popup.editing ? 1 : 0
          // the word goes after "Alias for …" / "New quick link"
          leftPadding: popup.pillShown ? aliasFor.width + 12 : 0
          verticalAlignment: TextInput.AlignVCenter
          color: Zenon.white
          selectionColor: Zenon.selBg
          selectedTextColor: Zenon.white
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(popup.linePx)
          clip: true
          cursorVisible: activeFocus
          cursorDelegate: Caret {
            field: input
            active: input.activeFocus && (popup.mode === "search" || popup.editing && popup.mode !== "hotkey")
            thick: 3; low: 0.25; radius: 1
            color: Zenon.white
          }
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: (event) => popup.fieldKey(event)
          Keys.onReleased: (event) => { if (event.key === Qt.Key_Alt) popup.altHeld = false; }
          onTextChanged: {
            // the word being set as an alias is not a search
            if (popup.editing) { if (popup.mode !== "hotkey") popup.aliasNote = ""; return; }
            popup.query = popup.chipLine(input.text);
            if (!popup.feedingLine) Qt.callLater(popup.maybeEnterPw);
            // metis' line typing keeps its answer the chosen row
            if (!popup.cardUp) popup.sel = 0;
            popup.applyFilter();
            // a tick later: the hand-over may rewrite this very line ("=" → "calc ")
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.left: input.left
          anchors.verticalCenter: parent.verticalCenter
          visible: (popup.mode === "search" && !popup.chip || popup.editing) && input.text === ""
          anchors.leftMargin: popup.editing ? aliasFor.width + 12 : 0
          text: popup.mode === "alias" ? "A word, like ff"
            : popup.mode === "clipname" ? "A name for it"
            : popup.mode === "snipkey" ? "What you type for it anywhere, like ;sig"
            : popup.mode === "snipargs" && popup.argAsk ? "The snippet's " + popup.argAsk.args[popup.argAsk.at].name
            : popup.mode === "hotkey" ? "Press the keys, like Super+F"
            : popup.mode === "link" ? "A word, then the address with {q} for the words" : "Search apps and commands"
          color: Zenon.muted
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(popup.linePx)
        }

        Text {
          id: question
          textFormat: Text.PlainText
          anchors.left: input.left
          anchors.right: popup.confirmLine ? undefined : parent.right
          anchors.rightMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          visible: popup.mode === "picker"
          text: popup.choices ? "Which timer?"
            : popup.pending ? popup.pending.name + "?" : ""
          color: popup.alarm ? Zenon.inkOnAccent : Zenon.white
          font.family: Zenon.face
          font.weight: Zenon.titleWeight
          font.pixelSize: Zenon.px(popup.confirmLine ? 16 : 18)
          elide: Text.ElideRight
        }

        // the rest of a begun chip word, dim after what is typed ("lay" +
        // "out"): tab takes it (chipOffer)
        Text {
          textFormat: Text.PlainText
          visible: !!popup.chipOffer && popup.chipOffer.ghost !== "" && input.cursorPosition === input.text.length
          x: input.x + input.leftPadding + input.contentWidth
          anchors.verticalCenter: input.verticalCenter
          text: popup.chipOffer ? popup.chipOffer.ghost : ""
          color: Zenon.muted
          font: input.font
        }

        // "Alias for Firefox", ahead of the word being set
        // the field's glyph goes inside it (user, 2026-11-04)
        Rectangle {
          id: aliasFor
          visible: popup.pillShown
          anchors.left: input.left
          anchors.verticalCenter: parent.verticalCenter
          width: pillRow.implicitWidth + 16
          height: aliasForText.implicitHeight + 8
          radius: Zenon.menuRadius
          color: Zenon.menuHi
          Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6
            Text {
              visible: text !== ""
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: fieldGlyph.text
              color: Zenon.white
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(15)
            }
          Text {
            id: aliasForText
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: !popup.editing && popup.chip ? popup.chip.text
              : popup.mode === "link" ? "New quick link"
              : popup.mode === "clipname" ? "Rename"
              : popup.mode === "snipkey" ? "Keyword"
              : popup.mode === "snipargs" && popup.argAsk ? popup.argAsk.args[popup.argAsk.at].name
                + (popup.argAsk.args.length > 1 ? " \u00B7 " + (popup.argAsk.at + 1) + " of " + popup.argAsk.args.length : "")
              : popup.mode === "hotkey" && popup.hotkeyRow ? "Hotkey for " + (popup.hotkeyRow.label || popup.hotkeyRow.text || "")
              : popup.aliasRow ? "Alias for " + (popup.aliasRow.label || popup.aliasRow.text || "") : ""
            color: Zenon.white
            font.family: Zenon.face
            font.weight: Zenon.titleWeight
            font.pixelSize: Zenon.px(15)
          }
          }
        }

        // what the line is read as (fieldTag), at the right of it: the
        // heading the card or the list had, the same small capitals
        SectionLabel {
          id: fieldTagLabel
          // the chip says it already
          visible: !!popup.fieldTag && !popup.chip
          anchors.right: queryClear.left
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          text: popup.fieldTag ? popup.fieldTag.text : ""
        }

        // a click on the × empties the line, as esc does (Picasso's)
        ClearChip {
          id: queryClear
          anchors.right: parent.right
          anchors.rightMargin: Math.round((popup.fieldH - queryClear.height) / 2) + popup.fieldInset
          anchors.verticalCenter: parent.verticalCenter
          size: Zenon.px(15)
          shown: popup.mode === "search" && (input.text !== "" || !!popup.chip)
          onClicked: popup.setLine("")
        }

        // ── the confirm's two answers, on the question's line ──────────
        // the one sliding cursor (morpheus/CursorBand), under the answers
        CursorBand {
          repeater: answersRep
          index: popup.sel
          shown: popup.confirmLine
        }
        Row {
          id: answers
          x: popup.questionW
          height: parent.height
          visible: popup.confirmLine
          Repeater {
            id: answersRep
            model: popup.confirmLine ? popup.pickerRows : []
            delegate: Item {
              id: answer
              required property var modelData
              required property int index
              width: answerFace.implicitWidth + 28
              height: answers.height
              FlashOver { flash: rowFlash; index: answer.index }
              Row {
                id: answerFace
                anchors.centerIn: parent
                spacing: Zenon.px(10)
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: answer.modelData.glyph || ""
                  color: Zenon.white
                  font.family: Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(17)
                }
                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  text: answer.modelData.label || ""
                  color: Zenon.white
                  font.family: Zenon.face
                  font.weight: Zenon.titleWeight
                  font.pixelSize: Zenon.px(16)
                }
              }
              // one click chooses, two answer (user, 2026-11-01)
              MouseArea {
                anchors.fill: parent
                onClicked: popup.sel = answer.index
                onDoubleClicked: { popup.sel = answer.index; popup.confirm(); }
              }
            }
          }
        }

        Hairline {
          anchors.bottom: parent.bottom
          width: parent.width
          visible: !popup.confirmLine
        }
      }

      // ---------------------------------------------------- clipboard --
      // Folio, unseen; its snippet page drawn from the top while it is up
      Loader {
        id: folioLoader
        width: parent.width
        height: popup.folioEditing ? popup.folioH : 0
        visible: popup.folioEditing
        active: popup.folioLatched && popup.shown
        source: "folio/FolioView.qml"
        onLoaded: {
          const f = folioLoader.item;
          f.host = popup;
          f.embedded = true;
          f.dismissed.connect(() => popup.closeCynosure());
          f.start();
          popup.takeClips();
          if (popup.snippetAsked) { popup.snippetAsked = false; f.editSnippetAt("", "", ""); }
        }
      }

      // ------------------------------------------------------- glyphs --
      // Ideo, unseen: its sets are the strips' cells
      Loader {
        id: ideoLoader
        width: 0
        height: 0
        visible: false
        // made once a session and kept: the sets are read once (and the
        // first "fi" or "em" waited 85 ms on the making, every open)
        active: popup.ideoLatched
        source: "ideo/IdeoCore.qml"
        onLoaded: {
          ideoLoader.item.host = popup;
          popup.takeGlyphs();
        }
      }

      // ---------------------------------------------------- passwords --
      // Calypso's Quick Access, from the top while it has the field (pwMode)
      Loader {
        id: calypsoLoader
        width: parent.width
        height: popup.pwH
        visible: popup.pwMode
        active: popup.pwLatched && popup.shown
        source: "../calypso/CalypsoView.qml"
        onLoaded: {
          const c = calypsoLoader.item;
          c.mgr = popup.passwords;
          c.host = popup;
          c.embedded = true;
          c.dismissed.connect(() => popup.closeCynosure());
          c.backed.connect(() => popup.exitPw());
          popup.startPw();
        }
      }

      // ------------------------------------------------- dictionary --
      // Lexi, unseen: it asks, the card under the field shows (lexiAsk)
      Loader {
        id: lexiLoader
        width: 0
        height: 0
        visible: false
        active: popup.lexiLatched
        source: "lexi/LexiCore.qml"
        onLoaded: {
          lexiLoader.item.host = popup;
          popup.askLexi();
        }
      }

      // -------------------------------------------------- calculator --
      // Metis, under the field while the line is a sum: its heading, then
      // the calculator itself (embedded: the answer, chips, strips, tape).
      // Lit as the chosen row while sel is -1.
      Item {
        id: calcBox
        y: popup.fieldH
        width: parent.width
        height: popup.calcShown ? popup.cardTop + popup.metisH : 0
        visible: popup.calcShown
        clip: true
        Behavior on height { NumberAnimation { duration: Zenon.normal; easing.type: Zenon.ease } }

        // Metis' wash over the breath above it, so it meets the field's
        // rule as Lexi's does — only while the answer is the card's top
        Rectangle {
          id: metisBreath
          readonly property var m: metisLoader.item
          width: parent.width
          height: popup.cardTop
          visible: !!m && m.resultShown && !m.tapeMode && !m.showLine
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: metisBreath.m ? metisBreath.m.washColor : "transparent" }
            GradientStop { position: 1.0; color: "transparent" }
          }
        }

        // no band over a card when it is chosen (user, 2026-11-01): its
        // chips are what is picked in it, and they light themselves
        Loader {
          id: metisLoader
          y: popup.cardTop
          width: parent.width
          height: popup.metisH
          // kept too once made (the first digit of every open waited on
          // it); start() on each open puts it back to an empty line
          active: popup.calcLatched
          source: "metis/MetisView.qml"
          onLoaded: {
            const m = metisLoader.item;
            m.host = popup;
            m.embedded = true;
            m.dismissed.connect(() => popup.closeCynosure());
            m.start();
            m.setLine(popup.calcWanted ? popup.calcLine : "");
          }
        }
        // a press on the card's ground (not on a chip of it) chooses it
        MouseArea {
          anchors.fill: parent
          z: -1
          onClicked: popup.sel = -1
        }
      }

      // ------------------------------------------------ smart answer --
      // the answer to a line in plain words, its heading over it, lit as a
      // band while it is the chosen row; the weather in a card of its own
      Item {
        id: answerBox
        y: popup.fieldH + calcBox.height
        width: parent.width
        height: popup.answerBoxH
        visible: popup.answerShown
        clip: true
        Behavior on height { NumberAnimation { duration: Zenon.normal; easing.type: Zenon.ease } }

        Rectangle {
          id: answerBand
          y: popup.cardTop
          width: parent.width
          height: Math.max(0, parent.height - popup.cardTop)
          // no band when chosen: see the calculator's card
          color: "transparent"
          MouseArea {
            anchors.fill: parent
            onClicked: popup.sel = -1
            onDoubleClicked: { popup.takeAnswer(); popup.closeCynosure(); }
          }
        }

        // ── an answer: large, and what it is under it
        Column {
          visible: !popup.wxAsk
          anchors.horizontalCenter: parent.horizontalCenter
          y: popup.cardTop + (answerBand.height - height) / 2
          spacing: 6
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            // a color shows itself; the moon its phase
            Rectangle {
              visible: !!popup.answer && !!popup.answer.color
              anchors.verticalCenter: parent.verticalCenter
              width: Zenon.px(30)
              height: width
              radius: Zenon.menuRadius
              color: popup.answer && popup.answer.color ? popup.answer.color : "transparent"
              border.width: 1
              border.color: Zenon.border
            }
            Text {
              visible: !!popup.answer && !!popup.answer.glyph
              anchors.verticalCenter: parent.verticalCenter
              text: popup.answer && popup.answer.glyph ? popup.answer.glyph : ""
              color: Zenon.white
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(28)
            }
          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, answerBox.width - 40)
            elide: Text.ElideMiddle
            text: popup.answer ? popup.answer.big : ""
            color: Zenon.white
            font.family: Zenon.face
            font.weight: Zenon.titleWeight
            // a long answer (an address, filler text) smaller
            font.pixelSize: Zenon.px(popup.answer && popup.answer.big.length > 40 ? 16 : 28)
          }
          }
          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: popup.answer ? popup.answer.small : ""
            color: Zenon.accentMuted
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(14)
          }
          // an answer's facts, each its label and value
          Row {
            visible: popup.answerFacts
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 8
            spacing: Zenon.px(22)
            Repeater {
              model: popup.answerFacts ? popup.answer.facts : []
              delegate: Row {
                required property var modelData
                spacing: 7
                Text {
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: Zenon.accentMuted
                  font.family: Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(13)
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData.value
                  color: Zenon.white
                  font.family: Zenon.faceMono
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(13)
                }
              }
            }
          }
          // cpu and memory over the last while, as the bar's tooltips draw it
          Sparkline {
            id: answerGraph
            readonly property bool cpu: !!popup.answer && popup.answer.kind === "cpu"
            visible: popup.answerGraph
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(Zenon.px(420), answerBox.width - 80)
            height: Zenon.px(64)
            panel: true
            maxPoints: Sysmon.span
            values: answerGraph.cpu ? Sysmon.cpuHistory : Sysmon.memHistory
            peakFormat: (v) => Math.round(v) + "%"
            lineColor: answerGraph.cpu ? Sysmon.cpuInk : Sysmon.memInk
            fillColor: answerGraph.lineColor
            fillOpacity: 0.18
          }
          // a QR code, on its own light ground
          Rectangle {
            visible: popup.answerQr
            anchors.horizontalCenter: parent.horizontalCenter
            width: Zenon.px(200)
            height: width
            radius: Zenon.menuRadius
            // paper white in either theme: a camera reads dark on light
            color: Qt.rgba(1, 1, 1, 1)
            Image {
              anchors.fill: parent
              anchors.margins: Zenon.px(6)
              source: popup.answerQr ? "file://" + popup.answer.qr : ""
              cache: false
              smooth: false
              fillMode: Image.PreserveAspectFit
            }
          }
          // how full: the disk, the battery (red when it runs low)
          Meter {
            readonly property bool low: !!popup.answer && popup.answer.kind === "battery"
              && popup.answer.level <= 0.15 && popup.answer.small !== "Charging"
            visible: popup.answerMeter
            anchors.horizontalCenter: parent.horizontalCenter
            vertical: false
            value: popup.answerMeter ? popup.answer.level : 0
            accent: low ? Zenon.red : popup.answer && popup.answer.kind === "battery" ? Zenon.green : Sysmon.diskReadInk
            segCount: 30
            thickness: Zenon.px(8)
            segLength: Zenon.px(8)
            segGap: 2
          }
        }

        // ── the weather: now (or the day asked about), and the days after
        Item {
          id: wxCard
          visible: !!popup.wxAsk && !!popup.wx
          y: popup.cardTop
          width: parent.width
          height: answerBand.height
          readonly property var w: popup.wx
          readonly property var d: popup.wxDay
          readonly property bool now: !!w && w.offset === 0 && !!w.current
          readonly property int code: now ? w.current.code : d ? d.code : 0
          function t(c) { return Weather.fmt(c) + "°"; }
          // the conditions' own graphic, as the calculator and the
          // dictionary have theirs: a wash in their color (Wx.tone) from the
          // field's rule down, and their glyph large and faint behind
          readonly property color tone: Zenon[Wx.tone(code, now ? w.current.isDay : true)]
          Rectangle {
            y: -popup.cardTop
            width: parent.width
            height: parent.height + popup.cardTop
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 0.5; color: Zenon.alpha(wxCard.tone, 0.10) }
              GradientStop { position: 1.0; color: "transparent" }
            }
          }
          Text {
            anchors.right: parent.right
            anchors.rightMargin: -Zenon.px(14)
            anchors.verticalCenter: parent.verticalCenter
            text: Wx.glyph(wxCard.code, wxCard.now ? wxCard.w.current.isDay : true)
            color: wxCard.tone
            opacity: 0.08
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(170)
          }

          Row {
            id: wxNow
            x: 24
            y: 14
            spacing: 18
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: Wx.glyph(parent.parent.code, parent.parent.now ? parent.parent.w.current.isDay : true)
              color: Zenon.white
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(44)
            }
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: parent.parent.now ? parent.parent.t(parent.parent.w.current.temp)
                : parent.parent.d ? parent.parent.t(parent.parent.d.hi) : ""
              color: Zenon.white
              font.family: Zenon.face
              font.weight: Zenon.titleWeight
              font.pixelSize: Zenon.px(38)
            }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 3
              Text {
                textFormat: Text.PlainText
                text: Wx.label(parent.parent.parent.code)
                color: Zenon.white
                font.family: Zenon.face
                font.weight: Zenon.titleWeight
                font.pixelSize: Zenon.px(16)
              }
              Text {
                textFormat: Text.PlainText
                text: parent.parent.parent.w ? parent.parent.parent.w.name + " · " + popup.dayName(parent.parent.parent.w.offset) : ""
                color: Zenon.accentMuted
                font.family: Zenon.face
                font.weight: Zenon.weight
                font.pixelSize: Zenon.px(14)
              }
            }
          }

          // the facts on the right: what was asked about first
          Column {
            anchors.right: parent.right
            anchors.rightMargin: 24
            y: 16
            spacing: 4
            readonly property var box: parent
            Repeater {
              model: {
                const b = parent.box;
                const w = b.w, d = b.d;
                if (!w) return [];
                const out = [];
                const add = (txt) => { if (txt) out.push(txt); };
                const sun = d ? "Sunrise " + Wx.hhmm(d.sunrise) + " · Sunset " + Wx.hhmm(d.sunset) : "";
                const rain = d && d.pop !== undefined && d.pop !== null ? "Rain " + d.pop + "%" : "";
                const hl = d ? "High " + b.t(d.hi) + " · Low " + b.t(d.lo) : "";
                const cur = b.now ? w.current : null;
                const wind = cur ? "Wind " + Math.round(cur.wind) + " km/h " + Wx.windDir(cur.windDeg) : "";
                const more = cur ? "Feels " + b.t(cur.feels) + " · Humidity " + cur.humidity + "%" : "";
                if (w.focus === "sun") { add(sun); add(hl); add(rain); }
                else if (w.focus === "rain") { add(rain); add(hl); add(more); }
                else if (w.focus === "wind") { add(wind); add(hl); add(more); }
                else { add(hl); add(rain); add(more); add(wind); }
                return out.slice(0, 3);
              }
              delegate: Text {
                required property var modelData
                anchors.right: parent.right
                textFormat: Text.PlainText
                text: modelData
                color: Zenon.keyInk
                font.family: Zenon.face
                font.weight: Zenon.weight
                font.pixelSize: Zenon.px(14)
              }
            }
          }

          // the days after the one shown
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            spacing: 26
            readonly property var box: parent
            Repeater {
              model: parent.box.w && parent.box.w.days
                ? parent.box.w.days.slice(parent.box.w.offset + 1, parent.box.w.offset + 6) : []
              delegate: Column {
                id: dayCol
                required property var modelData
                required property int index
                readonly property var box: parent.box
                spacing: 2
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: popup.dayName(dayCol.box.w.offset + 1 + dayCol.index).slice(0, 3)
                  color: Zenon.accentMuted
                  font.family: Zenon.face
                  font.weight: Zenon.titleWeight
                  font.pixelSize: Zenon.px(12)
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Wx.glyph(dayCol.modelData.code, true)
                  color: Zenon.white
                  font.family: Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(18)
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: dayCol.box.t(dayCol.modelData.hi) + " " + dayCol.box.t(dayCol.modelData.lo)
                  color: Zenon.keyInk
                  font.family: Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(12)
                }
              }
            }
          }
        }
      }

      // ------------------------------------------- dictionary, translate --
      // Lexi's answer as the calculator shows its own (user, 2026-11-01):
      // a heading, a wash of color, the reading over a large answer, and
      // chips under — words for the dictionary, languages for the translator
      Item {
        id: lexiBox
        y: popup.fieldH + calcBox.height + answerBox.height
        width: parent.width
        height: popup.lexiBoxH
        visible: popup.lexiShown
        clip: true
        Behavior on height { NumberAnimation { duration: Zenon.normal; easing.type: Zenon.ease } }

        readonly property var lx: popup.lexi
        readonly property bool dict: popup.lexiMode === "dict"
        readonly property var res: lexiBox.lx && lexiBox.dict ? lexiBox.lx.dictResult : null
        readonly property var tr: popup.lexiTr
        readonly property bool loading: !!lexiBox.lx && (lexiBox.dict ? lexiBox.lx.dictLoading : !!(lexiBox.tr && lexiBox.tr.pending))
        readonly property bool failed: !!lexiBox.lx && (lexiBox.dict
          ? lexiBox.lx.dictError !== "" || lexiBox.lx.dictSuggest.length > 0 : !!(lexiBox.tr && lexiBox.tr.error))
        readonly property color ink: lexiBox.dict ? Zenon.accent : Zenon.magenta


        Item {
          id: lexiCard
          y: popup.cardTop
          width: parent.width
          height: lexiCard.want
          // the words, the senses under them, and a row of chips
          // room above and below (user, 2026-11-04: "everything looks
          // squished together")
          readonly property int want: Math.ceil(lexiCol.implicitHeight) + Zenon.px(22) * 2
            + (popup.lexiChips.length > 0 ? lexiChipRow.height : 0)

          // up over the breath too, so the wash meets the field's rule
          Rectangle {
            y: -popup.cardTop
            width: parent.width
            height: parent.height + popup.cardTop
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 0.5; color: Zenon.alpha(lexiBox.ink, 0.08) }
              GradientStop { position: 1.0; color: "transparent" }
            }
          }

          Column {
            id: lexiCol
            y: Zenon.px(22)
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 64
            spacing: Zenon.px(6)

            // how it was read: the sound and the parts of speech, or which
            // language into which — after an ear when the word has its own
            // recording to say (md-ear_hearing, user 2026-11-08; alt p)
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Zenon.px(8)
              visible: readLine.text !== ""
              // a chip, pressed to hear it — alt p's twin (user, 2026-11-09);
              // a rounded square in the card's ink, ClearChip's press
              Rectangle {
                id: hearMark
                visible: lexiBox.dict && popup.lexiCanSay
                anchors.verticalCenter: parent.verticalCenter
                // as tall as the reading line beside it, a few pixels over,
                // so the two sit on one middle (user, 2026-11-09)
                implicitWidth: readLine.implicitHeight + Zenon.px(6)
                width: implicitWidth
                height: width
                radius: Zenon.radiusControl
                color: hearPress.pressed ? Zenon.pressFill
                  : Zenon.alpha(lexiBox.ink, hearPress.containsMouse ? 0.24 : 0.14)
                Behavior on color { ColorAnimation { duration: Zenon.fast } }
                Text {
                  id: hearGlyph
                  anchors.centerIn: parent
                  text: "\u{F07C5}"
                  color: lexiBox.ink
                  opacity: hearPress.pressed ? Zenon.pressDim : 1
                  font.family: Zenon.glyphFace
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(14)
                }
                MouseArea {
                  id: hearPress
                  // a little past the chip: it is small
                  anchors.fill: parent
                  anchors.margins: -4
                  hoverEnabled: true
                  onClicked: popup.lexi.cardSpeak(popup.lexiMode)
                }
              }
              Text {
                id: readLine
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, lexiCol.width - (hearMark.visible ? hearMark.implicitWidth + Zenon.px(8) : 0))
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.StyledText
                elide: Text.ElideRight
                text: {
                  const x = lexiBox.lx;
                  if (!x || popup.lexiBare) return "";
                  if (lexiBox.dict) {
                    const r = lexiBox.res;
                    if (!r || lexiBox.failed) return "";
                    const bits = [];
                    if (r.ipa) bits.push(Strings.escapeHtml(r.ipa));
                    if (r.pos.length) bits.push(Strings.escapeHtml(r.pos.map((p) => p.name.toLowerCase()).join(", ")));
                    if (r.corrected) bits.push('<font color="' + Zenon.keyInk + '">\u21BA ' + Strings.escapeHtml(x.dictAskedAs) + '</font>');
                    if (popup.lexiAsk.lang) bits.push(Strings.escapeHtml(popup.lexiAsk.lang.en));
                    return bits.join("  \u00B7  ");
                  }
                  const t = lexiBox.tr;
                  if (!t) return "";
                  const from = t.from || t.source;
                  return (from ? Strings.escapeHtml(Lexicon.langEnName(from)) : "Detected")
                    + '<font color="' + lexiBox.ink + '">  \u2192  </font>'
                    + '<font color="' + Zenon.white + '">' + Strings.escapeHtml(Lexicon.langEnName(t.to)) + '</font>';
                }
                color: Zenon.accentMuted
                font.family: Zenon.face
                font.weight: Zenon.titleWeight
                font.pixelSize: Zenon.px(14)
              }
            }

            // the word, or the translation: large, the way an answer is
            Text {
              // nothing typed yet: no title, only the line under (user)
              visible: !popup.lexiBare
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              wrapMode: Text.Wrap
              maximumLineCount: lexiBox.dict ? 1 : 3
              elide: Text.ElideRight
              opacity: lexiBox.loading ? 0.45 : 1
              Behavior on opacity { NumberAnimation { duration: Zenon.normal } }
              text: {
                const x = lexiBox.lx;
                if (!x) return "";
                if (popup.lexiBare) return "";
                if (lexiBox.dict) {
                  if (x.dictError !== "") return x.dictErrorWord !== "" ? "No entry for \u201C" + x.dictErrorWord + "\u201D" : "No answer";
                  if (x.dictSuggest.length) return x.offerLabel.charAt(0).toUpperCase() + x.offerLabel.slice(1);
                  return lexiBox.res ? lexiBox.res.title : "\u2026";
                }
                const t = lexiBox.tr;
                if (!t) return "\u2026";
                if (t.error) return "No translation";
                return t.translation || "\u2026";
              }
              // a word in the card's ink; a translation plain (user, 2026-11-01)
              color: lexiBox.failed ? Zenon.red : lexiBox.dict ? lexiBox.ink : Zenon.white
              font.family: Zenon.face
              font.weight: Zenon.titleWeight
              // the prompts and the misses at metis' "Can't read" size, an
              // answer large (user, 2026-11-01)
              font.pixelSize: Zenon.px(popup.lexiBare || lexiBox.failed ? 19
                : lexiBox.dict ? 26 : String(text).length < 40 ? 21 : 18)
            }

            // nothing typed yet: what to type, led by the book's or the
            // translator's glyph in the same quiet grey, and no title over
            // it (user, 2026-11-01)
            Row {
              visible: popup.lexiBare
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: 14
              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: lexiBox.dict ? "\uF02D" : "\uF1AB"
                color: Zenon.accentMuted
                font.family: Zenon.face
                font.weight: Zenon.weight
                font.pixelSize: Zenon.px(16)
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: lexiBox.dict ? "Type the word, or \u201C\u2026 in french\u201D to read another language"
                  : "Type the words, then \u201Cin\u201D and a language: tr good morning in german"
                color: Zenon.accentMuted
                font.family: Zenon.face
                font.weight: Zenon.weight
                font.pixelSize: Zenon.px(14)
              }
            }
            // under the answer, quietly: the romanization, or what went wrong
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              visible: text !== ""
              wrapMode: Text.Wrap
              text: popup.lexiBare ? ""
                // how to say it, where the answer is in another script
                : !lexiBox.dict && lexiBox.tr && lexiBox.tr.roman
                  && /[^\u0000-\u024F\s]/.test(lexiBox.tr.translation || "") ? lexiBox.tr.roman
                : lexiBox.dict && lexiBox.lx && lexiBox.lx.dictError !== "" && lexiBox.lx.dictErrorWord === "" ? lexiBox.lx.dictError
                : ""
              color: Zenon.accentMuted
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(14)
            }

            // the senses: the first few, all of them on alt e. Each part of
            // speech a group with room over it, its senses apart and in
            // lines a reader's length, not the card's
            Column {
              id: senses
              width: parent.width
              spacing: Zenon.px(6)
              topPadding: Zenon.px(8)
              visible: lexiBox.dict && !!lexiBox.res && !lexiBox.failed && !popup.lexiBare
              // a reader's length at the typed line's size, about as many
              // letters to a line as before
              readonly property int lineW: Math.min(senses.width, Zenon.px(popup.linePx) * 32)
              Repeater {
                model: lexiBox.dict && lexiBox.lx ? lexiBox.lx.dictRows.filter((row) => row.kind === "pos" || row.kind === "def")
                  .slice(0, lexiBox.lx.expanded ? 14 : 5) : []
                delegate: Text {
                  required property var modelData
                  required property int index
                  readonly property bool head: modelData.kind === "pos"
                  x: Math.round((senses.width - width) / 2)
                  width: senses.lineW
                  topPadding: head && index > 0 ? Zenon.px(10) : 0
                  // centered under the word, as the card's every line is (user)
                  horizontalAlignment: Text.AlignHCenter
                  textFormat: Text.StyledText
                  wrapMode: Text.Wrap
                  maximumLineCount: 3
                  elide: Text.ElideRight
                  lineHeight: head ? 1 : 1.25
                  text: head ? modelData.text.toLowerCase() : modelData.text
                  color: head ? lexiBox.ink : Zenon.white
                  font.family: Zenon.face
                  font.weight: head ? Zenon.titleWeight : 500
                  font.italic: head
                  // the senses at the typed line's size; the part of speech
                  // over them two under it, as it was
                  font.pixelSize: Zenon.px(head ? popup.linePx - 2 : popup.linePx)
                }
              }
            }
          }

          // the chips: synonyms or near misses, languages, or the recents
          Item {
            id: lexiChipRow
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: parent.width
            height: Zenon.px(40)
            visible: popup.lexiChips.length > 0
            MetisDir.ChipStrip {
              id: lexiStrip
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              Repeater {
                id: lexiChipRep
                model: popup.lexiChips
                delegate: MetisDir.MetisChip {
                  required property var modelData
                  required property int index
                  order: index
                  sel: popup.cardSel && index === popup.lexiChip
                  label: modelData.label
                  sub: modelData.sub || ""
                  glyph: modelData.glyph || ""
                  onClicked: popup.lexiTakeChip(index)
                }
              }
            }
          }

          // a press on the card's ground chooses it
          MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: popup.sel = -1
          }
        }
      }

      // --------------------------------------------------- detail pane --
      // what the chosen file, clip, picture, snippet or glyph is: a preview,
      // and the facts about it under (Raycast's detail, terminus' Info)
      Item {
        id: pane
        visible: popup.paneOn
        x: list.width
        y: list.y
        width: parent.width - list.width
        height: list.height
        clip: true
        readonly property var d: popup.detail

        Rectangle { width: 1; height: parent.height; color: Zenon.border }

        Item {
          id: look
          x: 18
          y: 14
          width: parent.width - 36
          // what the facts leave: their heading and a line each, under it
          height: Math.max(80, parent.height - 14 - 10 - 34 - 8
            - (pane.d && pane.d.facts ? pane.d.facts.length + 1 : 1) * (Zenon.px(24) + 6))

          Image {
            id: lookImage
            anchors.fill: parent
            visible: !!pane.d && !!pane.d.image
            source: pane.d && pane.d.image ? pane.d.image : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            // the size it really is, for the facts
            onStatusChanged: if (status === Image.Ready) popup.picSize = sourceSize.width + " × " + sourceSize.height
          }
          Text {
            anchors.centerIn: parent
            visible: !!pane.d && !!pane.d.glyph
            text: pane.d && pane.d.glyph ? pane.d.glyph : ""
            color: Zenon.white
            font.family: pane.d && pane.d.nerd ? "Symbols Nerd Font" : "Noto Color Emoji"
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(96)
          }
          // "in …": the matching line lit under the text, where the text laid
          // it out (a line over it may wrap)
          Rectangle {
            id: hitBand
            visible: lookRich.visible && !!pane.d && !!pane.d.hitAt && height > 0
            x: -6
            width: parent.width + 12
            radius: Zenon.rad(4)
            color: Zenon.menuHi
            function place() {
              const h = pane.d ? pane.d.hitAt : null;
              if (!h) { hitBand.height = 0; return; }
              const a = lookRich.positionToRectangle(h[0]), b = lookRich.positionToRectangle(h[1]);
              hitBand.y = a.y - 1;
              hitBand.height = b.y + b.height - a.y + 2;
            }
          }
          // a file's own text, in the colors terminus' preview wears. A
          // TextEdit for positionToRectangle (hitBand), never enabled: it
          // takes no clicks, keys or cursor
          TextEdit {
            id: lookRich
            anchors.fill: parent
            enabled: false
            readOnly: true
            visible: !!pane.d && !!pane.d.rich
            textFormat: TextEdit.RichText
            text: pane.d && pane.d.rich ? pane.d.rich : ""
            color: Zenon.white
            font.family: Zenon.faceCode
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(14)
            clip: true
            wrapMode: TextEdit.NoWrap
            onTextChanged: Qt.callLater(hitBand.place)
            onWidthChanged: Qt.callLater(hitBand.place)
          }
          Text {
            anchors.fill: parent
            visible: !!pane.d && !pane.d.rich && pane.d.text !== undefined && pane.d.text !== ""
            textFormat: Text.PlainText
            text: pane.d && pane.d.text ? pane.d.text : ""
            color: Zenon.white
            font.family: pane.d && pane.d.mono ? Zenon.faceCode : Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(pane.d && pane.d.mono ? 14 : 15)
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            clip: true
          }
          // a picked color: itself, large
          Rectangle {
            anchors.centerIn: parent
            visible: !!pane.d && !!pane.d.swatch
            width: Math.min(parent.width, parent.height, Zenon.px(180))
            height: width
            radius: Zenon.dialogRadius
            color: pane.d && pane.d.swatch ? pane.d.swatch : "transparent"
            border.width: 1
            border.color: Zenon.border
          }
          // nothing to show it with: its glyph, large and quiet
          Text {
            anchors.centerIn: parent
            visible: !!pane.d && !pane.d.image && !pane.d.glyph && !pane.d.rich && !pane.d.text && !pane.d.busy && !pane.d.swatch
            text: pane.d && pane.d.icon ? pane.d.icon : ""
            color: Zenon.muted
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(64)
          }
          Working {
            anchors.centerIn: parent
            running: popup.paneOn && !!pane.d && !!pane.d.busy
            dot: 6
            gap: 6
          }
        }

        Rectangle {
          id: factsRule
          x: 18
          y: look.y + look.height + 10
          width: parent.width - 36
          height: 1
          color: Zenon.border
        }
        SectionLabel {
          x: 18
          y: factsRule.y + 12
          text: "Information"
        }
        Column {
          x: 18
          y: factsRule.y + 34
          width: parent.width - 36
          spacing: 6
          Repeater {
            model: pane.d && pane.d.facts ? pane.d.facts.concat(popup.picSize !== "" && pane.d.image
              && pane.d.kind === "pics" ? [["Size", popup.picSize]] : []) : []
            delegate: Item {
              id: fact
              required property var modelData
              width: parent.width
              height: Zenon.px(24)
              Text {
                id: factKey
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: fact.modelData[0]
                color: Zenon.accentMuted
                font.family: Zenon.face
                font.weight: Zenon.weight
                font.pixelSize: Zenon.px(15)
              }
              Text {
                textFormat: Text.PlainText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - factKey.implicitWidth - 16)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideMiddle
                text: fact.modelData[1]
                color: Zenon.keyInk
                font.family: Zenon.face
                font.weight: Zenon.weight
                font.pixelSize: Zenon.px(15)
              }
            }
          }
        }
      }

      // -------------------------------------------------------- list --
      ListView {
        id: list
        // compact's field alone has no room under it: a list left there
        // (the chosen row scrolled into view) drew over the field
        visible: !popup.confirmLine && !popup.editing && !popup.compactNow
        // Finder's rubber band and the smooth wheel notch, one rule for the
        // whole shell — see morpheus/Elastic.qml
        ElasticScroll { view: list }
        // the chosen row slides (morpheus/CursorBand), flush to both sides
        // not on a row of cells (pictures, emoji): the chosen cell's ring is
        // the cursor there (user, 2026-11-01)
        CursorBand { follows: list; index: popup.sel
                     shown: list.count > 0 && !(popup.current && popup.current.cells) }
        // and on a row of cells the one cursor slides between the cells
        // themselves, across a row and from row to row (user, 2026-11-01)
        CursorBand {
          follows: list
          item: popup.chosenCellItem
          shown: !!popup.chosenCellItem
          insetX: 4
          insetY: 4
          radius: Zenon.menuRadius
        }
        y: popup.topH + calcBox.height + answerBox.height + lexiBox.height
        // the detail pane takes the right of it in a list of one kind
        // a glyph's pane is one character and its facts: a narrow column,
        // the strips their full width (user, 2026-11-01)
        width: !popup.paneOn ? parent.width
          : popup.glyphsScoped ? parent.width - Zenon.px(280) : Math.round(parent.width * 0.52)
        height: Math.max(0, popup.rootH - Zenon.hintBarH - y)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: popup.mode === "picker" ? popup.pickerRows : popup.filtered
        cacheBuffer: 600
        // a new list's rows made from the last one's, not built from nothing
        // (user, 2026-11-02: snappier)
        reuseItems: true

        section.property: "section"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
          required property string section
          width: list.width
          // the field says it already (fieldTag): not again over the list
          readonly property bool said: section === "" || (!!popup.fieldTag && section === popup.fieldTag.text)
          height: said ? 0 : popup.sectionH
          // the list sets a heading's own `visible`: the label is what hides,
          // or it draws over the row before at height 0 (nf, em, 11-01)
          SectionLabel {
            visible: !parent.said
            x: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: parent.section
          }
        }

        delegate: Item {
          id: row
          required property var modelData
          required property int index
          readonly property var r: modelData
          // a name, read through the query's underline, for the rows that
          // are a thing found; a sentence of the shell's own for the rest
          readonly property bool marked: r.kind === "app" || r.kind === "shell" || r.kind === "hist"
          // a picture on the clipboard: its thumbnail in the glyph's place,
          // on a row tall enough to see it
          readonly property bool isPic: r.kind === "clipimg"
          readonly property bool isStrip: r.kind === "glyphs"
          readonly property bool isGrid: r.kind === "pics" || r.kind === "shots" || r.kind === "fonts"
          // the item of cell i, for the sliding cell cursor
          function cellItem(i) {
            return row.isGrid ? picRep.itemAt(i) : row.isStrip ? glyphRep.itemAt(i) : null;
          }
          readonly property bool chosen: row.index === popup.sel
          width: list.width
          height: row.isPic ? popup.rowH * 2 : row.isStrip ? popup.glyphRowH
            : row.isGrid ? popup.picRowH : popup.rowH

          // a row of the pictures' grid: each a thumbnail and when it came,
          // the chosen one ringed in the accent
          Row {
            visible: row.isGrid
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
              id: picRep
              model: row.isGrid ? row.r.cells : []
              delegate: Item {
                id: picCell
                required property var modelData
                required property int index
                width: Math.floor((list.width - 28) / popup.picsPer)
                height: popup.picRowH
                // a font's tile: its name written in itself on a quiet ground
                readonly property bool font: picCell.modelData.kind === "font"
                Rectangle {
                  visible: picCell.font
                  anchors.fill: parent
                  anchors.margins: 4
                  radius: Zenon.menuRadius
                  color: Zenon.wash(0.04)
                }
                Text {
                  visible: picCell.font
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  anchors.verticalCenterOffset: -8
                  width: parent.width - 28
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                  maximumLineCount: 2
                  wrapMode: Text.Wrap
                  text: picCell.font ? picCell.modelData.family : ""
                  color: Zenon.white
                  font.family: picCell.font ? picCell.modelData.face : Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(24)
                }
                // the chosen cell lights before it acts, in the cursor's box
                FlashOver {
                  flash: rowFlash
                  index: row.index
                  anchors.margins: 4
                  radius: Zenon.menuRadius
                  visible: picCell.index === popup.cellSel && !!flash && index === flash.at && flash.ink > 0
                }
                // the picture itself, written out as a file to carry
                Drag.active: false
                Drag.source: picCell
                Drag.keys: ["text/uri-list"]
                Drag.supportedActions: Qt.CopyAction
                Drag.dragType: Drag.Automatic
                Drag.hotSpot.x: 16
                Drag.hotSpot.y: 19
                Drag.onDragFinished: function(dropAction) { popup.dragEnded(picCell, dropAction); }
                DragHandler {
                  target: null
                  onActiveChanged: {
                    if (!active) return;
                    popup.dragging = true;
                    // a font is its first file
                    if (picCell.font) {
                      const ff = picCell.modelData.files[0] || "";
                      if (ff === "") { popup.dragging = false; return; }
                      popup.offerDrag(picCell, { "text/uri-list": Strings.fileUrl(ff) + "\r\n" },
                        Terminus.basename(ff), "\uF031", "");
                      return;
                    }
                    // a capture is a file already
                    if (picCell.modelData.path) {
                      const f = picCell.modelData.path;
                      popup.offerDrag(picCell, { "text/uri-list": Strings.fileUrl(f) + "\r\n" },
                        Terminus.basename(f), picCell.modelData.video ? "\u{F0567}" : "\uF03E",
                        picCell.modelData.thumb ? "file://" + picCell.modelData.thumb : "");
                      return;
                    }
                    popup.folio.dragDecode(picCell.modelData.id, (file) => {
                      if (file === "") { popup.dragging = false; return; }
                      popup.offerDrag(picCell, { "text/uri-list": Strings.fileUrl(file) + "\r\n" },
                        Terminus.basename(file), "\uF03E", picCell.modelData.thumb ? "file://" + picCell.modelData.thumb : "");
                    });
                  }
                }
                Image {
                  id: picThumb
                  visible: !picCell.font
                  anchors.top: parent.top
                  anchors.topMargin: 10
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: parent.width - 20
                  height: parent.height - 40
                  source: picCell.modelData.thumb ? "file://" + picCell.modelData.thumb : ""
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  cache: false
                }
                // not made yet: the picture glyph in its place
                Text {
                  anchors.centerIn: picThumb
                  visible: !picCell.font && picThumb.status !== Image.Ready
                  text: picCell.modelData.video ? "\u{F0567}" : "\uF03E"
                  color: Zenon.muted
                  font.family: Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(28)
                }
                Text {
                  textFormat: Text.PlainText
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: 9
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: Math.min(implicitWidth, parent.width - 16)
                  elide: Text.ElideRight
                  // a font says what it is (its styles), a picture when it came
                  text: picCell.font ? picCell.modelData.sub : picCell.modelData.stamp
                  color: Zenon.accentMuted
                  font.family: Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(12)
                }
                MouseArea {
                  anchors.fill: parent
                  // one click chooses it, two use it, a right click opens
                  // its actions (user, 2026-11-01)
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  onClicked: (mouse) => {
                    popup.sel = row.index;
                    popup.cellSel = picCell.index;
                    if (mouse.button === Qt.RightButton) Qt.callLater(popup.openActions);
                  }
                  onDoubleClicked: (mouse) => {
                    if (mouse.button !== Qt.LeftButton) return;
                    popup.sel = row.index;
                    popup.cellSel = picCell.index;
                    popup.confirm();
                  }
                }
              }
            }
          }

          // a strip of emoji or glyphs, the chosen cell ringed in the accent
          Row {
            visible: row.isStrip
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
              id: glyphRep
              model: row.isStrip ? row.r.cells : []
              delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: Zenon.px(52)
                height: popup.glyphRowH
                // the chosen cell lights before it acts, in the cursor's box
                FlashOver {
                  flash: rowFlash
                  index: row.index
                  anchors.margins: 4
                  radius: Zenon.menuRadius
                  visible: cell.index === popup.cellSel && !!flash && index === flash.at && flash.ink > 0
                }
                // the glyph as text, into whatever takes it
                Drag.active: false
                Drag.source: cell
                Drag.supportedActions: Qt.CopyAction
                Drag.dragType: Drag.Automatic
                Drag.hotSpot.x: 16
                Drag.hotSpot.y: 19
                Drag.onDragFinished: function(dropAction) { popup.dragEnded(cell, dropAction); }
                DragHandler {
                  target: null
                  onActiveChanged: {
                    if (!active) return;
                    popup.dragging = true;
                    popup.offerDrag(cell, { "text/plain": cell.modelData.char }, cell.modelData.name || cell.modelData.char, cell.modelData.char);
                  }
                }
                Text {
                  anchors.centerIn: parent
                  text: cell.modelData.char
                  color: Zenon.white
                  font.family: row.r.nerd ? "Symbols Nerd Font" : "Noto Color Emoji"
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(row.r.nerd ? 26 : 24)
                }
                MouseArea {
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  onClicked: (mouse) => {
                    popup.sel = row.index;
                    popup.cellSel = cell.index;
                    if (mouse.button === Qt.RightButton) Qt.callLater(popup.openActions);
                  }
                  onDoubleClicked: (mouse) => {
                    if (mouse.button !== Qt.LeftButton) return;
                    popup.sel = row.index;
                    popup.cellSel = cell.index;
                    popup.confirm();
                  }
                }
              }
            }
          }

          // dragged out to another app (startDrag): not a row of cells,
          // whose cells drag themselves
          Drag.active: false
          Drag.source: row
          Drag.supportedActions: Qt.CopyAction
          Drag.dragType: Drag.Automatic
          Drag.hotSpot.x: 16
          Drag.hotSpot.y: 19
          Drag.onDragFinished: function(dropAction) { popup.dragEnded(row, dropAction); }
          DragHandler {
            target: null
            enabled: ["file", "clip", "snip", "link"].indexOf(row.r.kind) >= 0
            onActiveChanged: if (active) popup.startDrag(row, row.r)
          }

          // the whole row lights before it acts — but not a row of cells,
          // where only the chosen cell does (below, in the cell)
          FlashOver {
            flash: rowFlash
            index: row.index
            visible: !row.r.cells && !!flash && index === flash.at && flash.ink > 0
          }

          // ── every row: glyph, name, its second line, and on the
          // right what kind of thing it is, or the word that reaches it
          Image {
            id: thumb
            visible: row.isPic
            x: 20
            width: row.isPic ? popup.rowH * 2 - 12 : 0
            height: width
            anchors.verticalCenter: parent.verticalCenter
            source: row.isPic && row.r.thumb ? "file://" + row.r.thumb : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
          }
          Text {
            id: glyph
            visible: !row.isPic && !row.isStrip && !row.isGrid
            x: 20
            width: Zenon.px(22)
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: row.r.glyph || ""
            // a script's list can name its own glyph: never markup (11-09)
            textFormat: Text.PlainText
            // a picked color's swatch wears the color itself; the theme
            // worn now is dimmed (user, 2026-11-07)
            color: row.r.worn ? Zenon.accentMuted : row.r.ink || Zenon.white
            font.family: Zenon.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(17)
          }

          Row {
            visible: !row.isStrip && !row.isGrid
            anchors.left: row.isPic ? thumb.right : glyph.right
            anchors.leftMargin: 14
            anchors.right: tail.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: Zenon.px(10)
            clip: true

            // a search's chip, as the field shows it (history)
            Rectangle {
              visible: !!row.r.chipTag
              anchors.verticalCenter: parent.verticalCenter
              width: histChip.implicitWidth + 16
              height: histChipText.implicitHeight + 6
              radius: Zenon.menuRadius
              color: Zenon.menuHi
              Row {
                id: histChip
                anchors.centerIn: parent
                spacing: 6
                Text {
                  visible: text !== ""
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: row.r.chipTag ? row.r.chipTag.glyph || "" : ""
                  color: Zenon.white
                  font.family: Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(13)
                }
                Text {
                  id: histChipText
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: row.r.chipTag ? row.r.chipTag.text : ""
                  color: Zenon.white
                  font.family: Zenon.face
                  font.weight: Zenon.titleWeight
                  font.pixelSize: Zenon.px(13)
                }
              }
            }

            Text {
              id: label
              anchors.verticalCenter: parent.verticalCenter
              text: row.marked ? Cynosure.highlight(row.r.label, popup.query)
                : Strings.escapeHtml(row.r.label || "")
              textFormat: Text.StyledText
              color: row.r.worn ? Zenon.accentMuted : Zenon.white
              // a font's row is drawn in the font itself
              font.family: row.r.face || Zenon.face
              font.weight: Zenon.titleWeight
              font.pixelSize: Zenon.px(15)
            }
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              visible: text !== ""
              text: row.r.sub || ""
              color: Zenon.accentMuted
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(14)
            }
          }

          Row {
            id: tail
            // beside the detail pane a strip's name is the pane's to say
            visible: !row.isGrid && !(row.isStrip && popup.paneOn)
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: Zenon.px(10)
            // a theme's inks (ThemeInks), as Oracle's Theme list has them
            Loader {
              id: rowInks
              anchors.verticalCenter: parent.verticalCenter
              active: !!row.r.inks
              visible: active
              opacity: row.r.worn ? 0.45 : 1
              source: Qt.resolvedUrl("../morpheus/ThemeInks.qml")
              Binding {
                target: rowInks.item
                when: rowInks.status === Loader.Ready
                property: "colors"
                value: row.r.inks || null
              }
            }
            // the word that opens it straight from the field: "cb invoice"
            KeyCap {
              anchors.verticalCenter: parent.verticalCenter
              // your alias for it, or a panel's own word
              visible: !!row.r.alias || !!row.r.cap || (row.r.kind === "shell" && !!(row.r.action && row.r.action.alias))
              label: row.r.alias ? row.r.alias : row.r.cap ? row.r.cap : row.r.action && row.r.action.alias ? row.r.action.alias : ""
            }
            // the row's keys on ONE cap, as a hint writes them (user,
            // 2026-11-01: a cap per key read as several shortcuts): with alt
            // held the first nine say "alt 1"…; otherwise the hotkey you gave
            // the row, "super shift f"
            KeyCap {
              anchors.verticalCenter: parent.verticalCenter
              readonly property bool numbered: popup.altHeld && row.index < 9 && !row.isStrip && !row.isGrid
              label: numbered ? "alt " + (row.index + 1)
                : Cynosure.HOTKEY_KINDS[row.r.kind] ? popup.chordWords(Cynosure.hotkeyOf(popup.hotkeys, row.r)) : ""
            }
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              visible: row.r.kind !== "pick"
              // a strip says the chosen cell's name, while it is chosen
              width: row.isStrip ? Math.min(implicitWidth, popup.panelWidth - 40 - popup.glyphsPer * Zenon.px(52)) : implicitWidth
              elide: Text.ElideRight
              // with alt held, the first nine say the number that opens them
              text: row.isStrip
                ? (row.chosen && row.r.cells[popup.cellSel] ? row.r.cells[popup.cellSel].name : Cynosure.kindName(row.r))
                : Cynosure.kindName(row.r)
              color: Zenon.accentMuted
              font.family: Zenon.face
              font.weight: Zenon.weight
              font.pixelSize: Zenon.px(13)
            }
          }

          MouseArea {
            anchors.fill: parent
            // a strip's cells take their own presses
            enabled: !row.isStrip && !row.isGrid
            // one click chooses the row, two do what return does, a right
            // click opens its actions (shift return's menu)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
              popup.sel = row.index;
              if (mouse.button === Qt.RightButton) Qt.callLater(popup.openActions);
            }
            onDoubleClicked: (mouse) => {
              if (mouse.button !== Qt.LeftButton) return;
              popup.sel = row.index;
              popup.confirm();
            }
          }
        }

        ScrollRail {
          target: list
          parent: list
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
        }
      }

      // ---------------------------------------------------- the keys --
      // morpheus/HintBar, as every strip: what the keys do to the chosen
      // row (which says what it is on its own right end)
      HintBar {
        id: hintStrip
        visible: !popup.confirmLine && !popup.compactNow
        y: popup.rootH - Zenon.hintBarH
        width: parent.width
        rows: popup.hints()
        // folio's word for a moment ("Kept as …", "Saved")
        note: popup.aliasNote !== "" ? popup.aliasNote : popup.folio ? popup.folio.note : ""
      }
      }

      // the actions panel, over the bottom right as Raycast has it; a press
      // anywhere else in the panel puts it away
      MouseArea {
        anchors.fill: parent
        z: 59
        visible: popup.actionsOpen
        onClicked: popup.closeActions()
      }

    }
  }

  // ── THE ACTIONS CARD ──────────────────────────────────────────────────
  // Its own overlay surface (morpheus/CardMenu, as terminus' menus became):
  // drawn inside the panel, a long list was cut off at the panel's top
  // (user, 2026-11-03). Still over the panel's bottom right, standing on the
  // strip of keys, and free to rise past the panel's edge; hyprland's layer
  // blur frosts it as every menu. The keys stay the panel's (actionsKey).
  CardMenu {
    id: actionsMenu
    screen: popup.screen
    fit: true
    open: popup.actionsOpen
    at: Qt.point(panel.x + panel.width - 8 - actionsMenu.cardW,
                 panel.y + panel.height - Zenon.hintBarH - 4
                   - (actionsMenu.implicitHeight - Zenon.menuShadowPad * 2))
    activeIndex: popup.actionSel
    model: popup.actionRows.map((a) => ({ text: a.text, icon: a.icon, hint: a.hint }))
    onChosen: (i) => popup.doAction(i)
    onHovered: (i) => popup.actionSel = i
  }

  Timer {
    id: appPoll
    interval: 50
    repeat: true
    running: true
    onTriggered: {
      const vals = DesktopEntries.applications.values;
      if (vals && vals.length > 0) {
        popup.refreshApps();
        appPoll.stop();
      }
    }
  }

  Component.onCompleted: {
    DesktopEntries.applicationsChanged.connect(() => popup.refreshApps());
    histCat.running = true;
    freqCat.running = true;
    picksCat.running = true;
    // and your words, links and searches: never asked for before, so a
    // restart came back without them (2026-11-01)
    aliasCat.running = true;
    linkCat.running = true;
    queriesCat.running = true;
    glyphsCat.running = true;
    hotkeysCat.running = true;
    favoritesCat.running = true;
  }
}
