// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ── THE SURFACE QUICK LOOK LIVES ON ──────────────────────────────────
// Not a child of the window. terminus is an xdg-toplevel, so anything
// inside it is clipped to whatever height the compositor gave the window —
// and a preview that has to fit inside a short window is not a preview.
//
// So the overlay gets its own layer-shell surface, the size of the monitor
// the window happens to be on. Two properties make that safe:
//
//   keyboardFocus None  — the layer never asks for the keyboard, so focus
//     stays on the toplevel underneath and Escape / h / l / j / k go on
//     being handled by the window's own Keys handler, unmoved.
//   exclusionMode Ignore — it is a modal overlay for a few seconds, not
//     furniture. Reserving space would shove every tiled window aside.
//
// It is mapped only while the overlay is on screen, opacity included, so
// the closing fade finishes before the surface goes away.
// ── THE DROP QUESTION, ON A SURFACE NOTHING CAN COVER ─────────────────
// See dropUris for why this is a layer and not a popup. Everything else
// about it follows the context menu: same ground, same radius, same row
// height, and it grows out of the pointer the way that card does.
//
// Its own file since 2026-10-08, out of TerminusWindow.qml (the split).
// `term` is the terminus window; window items it uses are read as
// term.<id>Ref (the window's aliases).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../morpheus"

PanelWindow {
  id: dropAsk
  // the terminus window (`term`, never `root` — see terminus-split notes)
  property var term: null
  property var rows: []
  property bool open: false
  property real cx: 0
  property real cy: 0
  property int at: 0

  // ── AS EVERY MENU ARRIVES, CHOOSES AND LEAVES ─────────────────────
  // The card is drawn here, on this surface, and not by CardMenu: a card
  // on a surface of its own has to stack above this one to be clicked,
  // and when it did not, the click fell to the catcher below and the drop
  // was abandoned without a word. The card itself is CardBody, as
  // CardMenu's is (2026-11-04; it was a hand-drawn copy): the shade here
  // fades and grows it in and out.
  property real shade: 0
  onOpenChanged: dropAsk.shade = dropAsk.open ? 1 : 0
  Behavior on shade {
    NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic }
  }
  // Keyboard of its OWN, unlike quick look's layer which leaves the keys
  // to the window behind it. The window behind this one may be buried —
  // that is the whole reason this surface exists — so it cannot be the
  // thing listening.
  WlrLayershell.keyboardFocus: dropAsk.open
    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "terminus-dropmenu"
  exclusionMode: ExclusionMode.Ignore
  // kept up through the fade out, so the card is seen to go — and taking
  // no input while it does, or a click just after answering would land on
  // a menu that is already leaving
  visible: dropAsk.open || dropAsk.shade > 0.01
  mask: dropAsk.open ? null : dropNoInput
  Region { id: dropNoInput }
  screen: term.screen
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }

  // ── WHERE THE POINTER IS, ASKED OF THE COMPOSITOR ─────────────────
  // A Wayland client is not told where its own toplevel sits, so there is
  // no arithmetic here that can turn a point inside the window into a
  // point on the screen — Item.mapToGlobal answers as though the window
  // were at the origin, which is how the card ended up over whichever
  // window happened to be at that offset instead of over the drop.
  //
  // Zenon.winOrigin solves this for a LAYER, by reading the anchors and
  // margins it was placed with. A toplevel has neither.
  //
  // hyprctl does know, and costs 5ms measured — which is nothing against
  // a menu that opens after a drop, and is paid once per drop rather than
  // per frame.
  function show(list) {
    dropAsk.rows = list || [];
    dropAsk.at = 0;
    cursorProc.running = false;
    cursorProc.running = true;
  }

  // Fallback: the middle of the screen. Better than a card at a
  // meaningless offset if hyprctl ever fails to answer.
  function place(gx, gy) {
    const sx = term.screen ? term.screen.x : 0;
    const sy = term.screen ? term.screen.y : 0;
    const okX = !isNaN(gx), okY = !isNaN(gy);
    dropAsk.cx = okX ? gx - sx : dropAsk.width / 2;
    dropAsk.cy = okY ? gy - sy : dropAsk.height / 2;
    dropAsk.open = true;
    // ASK FOR THE KEYBOARD AND KEEP ASKING. A bare forceActiveFocus on
    // the frame a surface is made visible is dropped — it has not been
    // mapped yet — which is the same trap the window itself documents
    // beside focusClaim. One shot here for the common case, and a few
    // more behind it for the frame the compositor is still catching up.
    dropKeys.forceActiveFocus();
    dropClaim.begin();
  }

  Process {
    id: cursorProc
    command: ["hyprctl", "cursorpos"]
    stdout: StdioCollector {
      id: cursorOut
      waitForEnd: true
      onStreamFinished: {
        // "739, 1429"
        const p = String(cursorOut.text || "").trim().split(",");
        dropAsk.place(Number(p[0]), Number(p[1]));
      }
    }
  }

  FocusRetry {
    id: dropClaim
    interval: 16
    checkFirst: true
    live: dropAsk.open
    took: dropKeys.activeFocus
    onPlace: {
      dropKeys.forceActiveFocus();
    }
  }

  function dismiss() {
    dropAsk.open = false;
    // Abort, Escape or a click away: nothing landed, so the branches the
    // drag opened go now. A turn later, because a chosen row's act runs
    // just AFTER this — see act() — and Copy or Move starts
    // springGrace instead.
    Qt.callLater(() => { if (!term.springGraceRef.running) term.springShut(term.springHeld); });
    // The rows stay until the next show: the card fades out, and emptying
    // them under it would collapse it mid-fade.
    // The listing gets the keyboard back, the way every sheet here ends.
    term.takeFocus();
  }

  // By key, the row flashes (CardBody's flash), then it acts; by click,
  // CardBody flashes it itself and says `chosen`.
  property bool acting: false
  function choose(i) {
    if (dropAsk.acting || !dropAsk.open) return;
    const r = dropAsk.rows[i];
    if (!r || r.sep) return;
    dropAsk.at = i;
    dropAsk.acting = true;
    dropCard.fire(i, () => dropAsk.act(i));
  }
  function act(i) {
    dropAsk.acting = false;
    // once only: a click's flash and a Return's can both end here (audit
    // 11-04: Copy then Move both ran); the first one closes the card
    if (!dropAsk.open) return;
    const r = dropAsk.rows[i];
    dropAsk.dismiss();
    if (r && r.act) r.act();
  }

  // Skips the rule when walking, so the ring is the three verbs.
  function step(n) {
    const list = dropAsk.rows;
    if (list.length === 0) return;
    let i = dropAsk.at;
    for (let guard = 0; guard < list.length; ++guard) {
      i = (i + n + list.length) % list.length;
      if (!list[i].sep) { dropAsk.at = i; return; }
    }
  }

  // Click away to abort, the way the menu it replaced did.
  MouseArea {
    anchors.fill: parent
    onClicked: dropAsk.dismiss()
  }

  FocusScope {
    id: dropKeys
    anchors.fill: parent
    focus: true
    Keys.onPressed: (event) => {
      event.accepted = true;
      if (event.key === Qt.Key_Escape) { dropAsk.dismiss(); return; }
      if (event.key === Qt.Key_Down || event.text === "j") { dropAsk.step(1); return; }
      if (event.key === Qt.Key_Up || event.text === "k") { dropAsk.step(-1); return; }
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        dropAsk.choose(dropAsk.at); return;
      }
    }

    // THE CARD IS THE SHARED ONE (morpheus/CardBody, 2026-11-04): its
    // rows, band, flash and shadow, on this surface — only the surface and
    // the keys are this file's (why a surface of its own: see the head)
    CardBody {
      id: dropCard
      readonly property real cardH: dropAsk.rows.reduce((h, r) => h + (r.sep ? Zenon.menuSepHeight : Zenon.menuRowHeight), 0) + 2
      pad: Zenon.menuShadowPad
      width: Zenon.menuWidth + 2 * pad
      height: cardH + 2 * pad
      // Clamped to the screen, because a card that opened near the right
      // or bottom edge would otherwise hang off it — the compositor does
      // this for a popup and does not for a layer's contents.
      x: Math.round(Math.min(Math.max(8, dropAsk.cx), dropAsk.width - Zenon.menuWidth - 8)) - pad
      y: Math.round(Math.min(Math.max(8, dropAsk.cy), dropAsk.height - cardH - 8)) - pad
      still: true
      shade: dropAsk.shade
      model: dropAsk.rows.map((r) => r.sep ? { isSeparator: true } : { text: r.label || "" })
      activeIndex: dropAsk.at
      onHovered: (i) => dropAsk.at = i
      onChosen: (i) => dropAsk.act(i)
    }
  }
}
