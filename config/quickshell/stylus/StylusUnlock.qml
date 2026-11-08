// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// UNLOCKING AN ENCRYPTED VOLUME, IN A SHEET — its passphrase, once; what
// is inside is mounted as soon as it opens. The passphrase goes to forge.py
// on stdin (never an argument) and the field is cleared as it is sent; a
// wrong one says so here and leaves the sheet up for another try.
//
//     Sheet { cardH: body.implicitHeight
//       StylusUnlock { id: body; width: parent.width; win: sw } }

import QtQuick
import "../morpheus"
import "../terminus"
import "stylus.js" as S

FocusScope {
  id: body

  property var win: null

  function reset() {
    pass.text = "";
    Qt.callLater(() => pass.claim());
  }
  function go() {
    if (pass.text === "" || !body.win || body.win.asking) return;
    const p = pass.text;
    pass.text = "";
    body.win.unlock(p);
  }

  // A refused passphrase shakes the field, as the lock screen does. Asked
  // on the answer's edge, not off the reason: two refusals in a row say the
  // same thing, and the reason is written just after `asking` drops.
  Connections {
    target: body.win
    ignoreUnknownSignals: true
    function onAskingChanged() {
      if (body.win.asking) return;
      Qt.callLater(() => { if (body.win && body.win.unlockOpen && body.win.unlockWhy !== "") pass.shake(); });
    }
  }

  implicitHeight: col.implicitHeight + 2 * 24

  Column {
    id: col
    x: 24
    y: 24
    width: parent.width - 48
    spacing: 14

    Row {
      spacing: 10
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F033E}"
        color: Zenon.accent
        font.family: Zenon.glyphFace
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(18)
      }
      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: "Unlock " + S.partName(body.win ? body.win.vol : null)
        color: Zenon.ink
        font.family: Zenon.face
        font.weight: Zenon.titleWeight
        font.pixelSize: Zenon.px(17)
      }
    }

    BulkField {
      id: pass
      width: parent.width
      masked: true
      ghost: "Passphrase"
      onAccepted: body.go()
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      wrapMode: Text.Wrap
      text: body.win && body.win.unlockWhy !== "" ? body.win.unlockWhy : "What is inside is mounted once it opens"
      color: body.win && body.win.unlockWhy !== "" ? Zenon.red : Zenon.accentSoft
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(13)
    }

    Row {
      anchors.right: parent.right
      spacing: Zenon.buttonGap
      DialogButton { label: "Cancel"; ink: Zenon.accentMuted; onClicked: body.win.closeUnlock() }
      BusyButton {
        label: "Unlock"
        primary: true
        ink: Zenon.accent
        ready: pass.text !== ""
        busy: !!body.win && body.win.asking
        busyText: "Unlocking…"
        onClicked: body.go()
      }
    }
  }

  Keys.onEscapePressed: body.win.closeUnlock()
}
