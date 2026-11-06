// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// WHAT THE LAST ACTION HAD TO SAY, floating at the listing's foot (user,
// 2026-11-07: out of the path bar, which it kept from the crumbs). The suite's
// foot pill (morpheus/HintBar), mid-foot: the words where a holder's query
// stands, and the undo on offer as a key. Nothing here takes the pointer but
// the words and the key, so the rows around it stay clickable.
//
//     StatusPill { term: root; parent: root.contentItem; z: 59; … }
//
// The color says which kind of news it is: red for refused or failed, sand for
// an ordinary note.

import QtQuick
import "../morpheus"

HintBar {
  id: pill
  property var term: null

  // ── IT KEEPS THE WORDS WHILE IT GOES ────────────────────────────────
  // Clearing the status has to leave something to fade: `shown` holds the
  // last message until the fade is over, and `shownBad` its color, which
  // clearing the status resets. The window writes both (onStatusChanged).
  property string shown: ""
  property bool shownBad: false
  readonly property color tone: pill.shownBad ? Zenon.red : Zenon.sand

  // ── NEVER WIDER THAN THE LISTING CAN GIVE ───────────────────────────
  // A message is as long as whatever failed made it: capped, elided, and the
  // whole of it one hover away (StatusNote).
  readonly property real cap: Math.max(160, pill.width * 0.6)
  readonly property bool cut: words.implicitWidth > pill.cap
  readonly property bool hovering: wordsMa.containsMouse
  readonly property Item wordsItem: words

  // The offer, held through the fade as the words are.
  readonly property bool undoOn: pill.term.undoOffer && pill.term.undoLabel !== ""
  property string undoHeld: ""
  onUndoOnChanged: if (pill.undoOn) pill.undoHeld = pill.term.undoLabel

  centered: true
  frostSource: pill.term.chromeRef.bodyBox
  rows: pill.undoHeld !== "" && (pill.undoOn || pill.term.status === "")
    ? [["u", pill.undoOn ? pill.term.undoLabel : pill.undoHeld]] : []

  // ── IT ARRIVES AND IT LEAVES ────────────────────────────────────────
  // Twice the slowest of the motion tokens, deliberately: every other
  // transition in this window answers something you just did, and this one
  // happens on its own while you are reading something else. The going IS
  // the notice; at 170 ms it is over before it has been seen.
  opacity: pill.term.status !== "" || pill.undoOn ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { NumberAnimation { duration: Zenon.slow * 2; easing.type: Zenon.ease } }
  onOpacityChanged: if (pill.opacity === 0) pill.undoHeld = ""

  leading: Text {
    id: words
    anchors.verticalCenter: parent.verticalCenter
    visible: pill.shown !== ""
    width: Math.min(implicitWidth, pill.cap)
    elide: Text.ElideRight
    textFormat: Text.PlainText
    // ONLY the status: a fallback that never emptied could never fade out
    text: pill.shown
    color: pill.tone
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(14)
    opacity: pill.term.status !== "" ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Zenon.slow * 2; easing.type: Zenon.ease } }
    onOpacityChanged: if (words.opacity === 0) pill.shown = ""

    MouseArea {
      id: wordsMa
      anchors.fill: parent
      hoverEnabled: true
      // Held while you read; let go and it counts down afresh.
      onContainsMouseChanged: {
        if (wordsMa.containsMouse) pill.term.statusClearRef.stop();
        else pill.term.armStatusClear();
      }
      onClicked: pill.term.copyText(pill.shown, "message copied")
    }
  }

  // the key is a thing to press as well as a thing to read
  overlay: MouseArea {
    x: pill.hintRow.x
    y: 0
    width: pill.hintRow.width
    height: pill.height
    enabled: pill.undoOn
    visible: pill.undoOn
    onClicked: pill.term.undo()
  }
}
