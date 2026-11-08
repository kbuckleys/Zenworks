// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//

//
// Shared, as BulkDrop is.

import QtQuick
import "../morpheus"

FocusScope {
  id: fld
  property string ghost: ""
  // the ground is a child now, so this is a FocusScope: forceActiveFocus and
  // activeFocus on the field mean the input, as they would on a bare TextInput
  property alias color: ground.color
  property alias radius: ground.radius
  property alias border: ground.border
  // ── A SEARCH'S PARTS (morpheus/SearchBox, 2026-11-07) ─────────────
  // `lens`: a glyph before the text. `keyHook`: function(event), seen before
  // anything else here, to leave accepted. `keysTo`: items that hear every
  // key first, as Keys.forwardTo. `refocusOnClear`: the × hands the keys back.
  property string lens: ""
  property var keyHook: null
  property var keysTo: []
  property bool refocusOnClear: false
  // the input itself, for whatever this does not pass on
  readonly property alias input: fldIn
  readonly property alias selectedText: fldIn.selectedText
  function selectAll() { fldIn.selectAll(); }
  // what the × takes at the right end, for something laid beside it
  readonly property real chipRoom: clearChip.visible ? clearChip.width + 12 : 8
  readonly property real leadRoom: fld.lens !== "" ? lensMark.x + lensMark.width + 9 : 8
  // As BulkDrop has one — the two sit side by side in a row and have to
  // agree about how big the type is.
  property int textSize: 14
  property alias text: fldIn.text
  // Which end gives way when the text is wider than the field and the field
  // is not being typed in. A path keeps its tail, so a path field says Left.
  property int elide: Text.ElideRight
  signal accepted()
  // ── A CHIP TO CLEAR IT (user, 2026-10-11) ─────────────────────────
  // For a search or a filter: a small round × inside the field's right
  // end, there while it holds text. Pressed, the text goes and `cleared`
  // tells the holder — one that searches on Return searches again on it.
  property bool clearable: false
  // ── A SECRET, OR CODE (calypso's editor, 2026-10-12) ──────────────
  // `masked`: drawn as dots, as a password field is, until the holder
  // shows it; `mono`: in the monospaced face (a key, a code).
  property bool masked: false
  property bool mono: false
  // room kept clear at the right end for something laid over the field
  // (ConnectSheet's kind words) — typed text and the ghost stop short of it
  property int trailRoom: 0
  // A field holding a secret hands its copies to the holder instead of the
  // clipboard: calypso's go out marked sensitive, so the clipboard history
  // never keeps them (user, 2026-10-12). function(text) or null.
  property var copyHook: null
  readonly property string family: fld.mono ? Zenon.faceMono : Zenon.face
  signal cleared()
  function clear() {
    fldIn.text = "";
    fld.cleared();
    if (fld.refocusOnClear) fldIn.forceActiveFocus();
  }
  // Where Tab goes from here. The card owns the ring — a field should not
  // know what is next to it.
  signal tabbed()
  signal backTabbed()

  function claim() { fldIn.forceActiveFocus(); fldIn.selectAll(); }
  // A secret refused: the lock screen's shake (morpheus' Shake).
  function shake() { shakeT.run(); }
  transform: Shake { id: shakeT; reach: 7 }

  // WHETHER IT ACTUALLY HAS THE KEYBOARD. The retry that opens the card has
  // to ask the field, not the scope around it: activeFocus propagates up a
  // FocusScope, so a scope that got focus while the claim inside it was
  // dropped looks exactly like success from the outside.
  readonly property alias focused: fldIn.activeFocus

  height: Math.max(26, fld.textSize + 12)
  Rectangle {
    id: ground
    anchors.fill: parent
    radius: Zenon.radiusControl
    color: Zenon.alpha(Zenon.white, 0.05)
    border.width: 1
    border.color: Zenon.border
    Behavior on border.color { ColorAnimation { duration: Zenon.fast } }
  }

  // Declared FIRST, so the input above it still gets the clicks that place
  // its own caret. This one only catches the padding either side of the
  // text, which is otherwise a strip of field that does not focus it.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.IBeamCursor
    onClicked: fldIn.forceActiveFocus()
  }

  Text {
    id: lensMark
    visible: fld.lens !== ""
    x: 13
    anchors.verticalCenter: parent.verticalCenter
    text: fld.lens
    color: Zenon.accentMuted
    textFormat: Text.PlainText
    font.family: Zenon.glyphFace
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(13)
  }

  Text {
    anchors.fill: parent
    anchors.leftMargin: fld.leadRoom
    anchors.rightMargin: fld.chipRoom + fld.trailRoom
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    elide: Text.ElideRight
    visible: fldIn.text === ""
    text: fld.ghost
    color: Zenon.accentMuted
    font.family: fld.family
    font.weight: Zenon.weight
    font.pixelSize: fld.textSize
  }

  // ── AT REST, A LONG VALUE IS SHORTENED, NOT CUT ───────────────────
  // A TextInput wider than itself scrolls to its caret and clips wherever
  // that leaves it — the search sheet's "~/.config/quickshell/terminus"
  // came out as "’.config/…", the last sliver of the slash reading as a
  // stray apostrophe. Unfocused and overflowing, the field shows this
  // elided copy instead; a click hands it back to the input, which shows
  // the whole thing for editing.
  readonly property bool overflows: fldIn.contentWidth > fldIn.width
  Text {
    textFormat: Text.PlainText
    anchors.fill: fldIn
    verticalAlignment: Text.AlignVCenter
    visible: fld.overflows && !fldIn.activeFocus
    text: fld.masked ? "\u2022".repeat(fldIn.text.length) : fldIn.text
    elide: fld.elide
    color: Zenon.ink
    font.family: fld.family
    font.weight: Zenon.weight
    font.pixelSize: fld.textSize
  }

  TextInput {
    id: fldIn
    focus: true
    opacity: fld.overflows && !fldIn.activeFocus ? 0 : 1

    cursorDelegate: Caret { field: fldIn }
    anchors.fill: parent
    anchors.leftMargin: fld.leadRoom
    anchors.rightMargin: fld.chipRoom + fld.trailRoom
    verticalAlignment: Text.AlignVCenter
    // masked, its own echo stays for the caret and the selection to sit on
    // but is drawn clear: SecretDots below are what shows
    color: fld.masked ? "transparent" : Zenon.ink
    selectionColor: Zenon.selBg
    selectedTextColor: fld.masked ? "transparent" : Zenon.white
    font.family: fld.family
    font.weight: Zenon.weight
    font.pixelSize: fld.textSize
    echoMode: fld.masked ? TextInput.Password : TextInput.Normal
    passwordCharacter: "\u2022"
    clip: true

    // ── THE LOCK SCREEN'S DOTS (2026-10-31) ─────────────────────────
    // morpheus' SecretDots over the echo, one bullet per character in the
    // field's own face and size with no spacing, so each lands where the
    // echo's would: the caret and a selection still line up. Placed off
    // character 0, which follows the input's own scroll as the caret moves.
    SecretDots {
      visible: fld.masked
      count: fld.masked ? fldIn.text.length : 0
      glyph: "\u2022"
      ink: Zenon.ink
      family: fld.family
      size: fld.textSize
      spacing: 0
      // swell from the start of the text, so it grows away from the caret
      transformOrigin: Item.Left
      x: { fldIn.cursorRectangle; fldIn.text; fldIn.width; return fldIn.positionToRectangle(0).x; }
      y: Math.round((fldIn.height - height) / 2)
    }
    // Tab has to be caught here: a TextInput otherwise hands it to the
    // scene's own focus chain, which in a card full of list delegates lands
    // somewhere arbitrary. Return is here too and not in Keys.onReturnPressed:
    // Qt runs a key's own handler BEFORE onPressed, and accepted there, the
    // hook would never see it.
    Keys.forwardTo: fld.keysTo
    Keys.onPressed: (e) => {
      if (fld.keyHook) { fld.keyHook(e); if (e.accepted) return; }
      if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { e.accepted = true; fld.accepted(); return; }
      if (e.key === Qt.Key_Tab) { e.accepted = true; fld.tabbed(); return; }
      if (e.key === Qt.Key_Backtab) { e.accepted = true; fld.backTabbed(); return; }
      if (fld.copyHook && (e.matches(StandardKey.Copy) || e.matches(StandardKey.Cut))) {
        e.accepted = true;
        const t = fldIn.selectedText !== "" ? fldIn.selectedText : fldIn.text;
        if (t !== "") fld.copyHook(t);
        if (e.matches(StandardKey.Cut) && fldIn.selectedText !== "") fldIn.remove(fldIn.selectionStart, fldIn.selectionEnd);
        return;
      }
    }
  }
  ClearChip {
    id: clearChip
    size: fld.textSize
    shown: fld.clearable && fldIn.text !== ""
    anchors.right: parent.right
    anchors.rightMargin: Math.round((fld.height - height) / 2)
    anchors.verticalCenter: parent.verticalCenter
    onClicked: fld.clear()
  }
  // focused for typing: terminus' held ring (user, 2026-10-11 — every
  // text field wears it, its own border staying neutral)
  HeldRing { anchors.fill: parent; radius: fld.radius; z: 10; on: fldIn.activeFocus }
}
