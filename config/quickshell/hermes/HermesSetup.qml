// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A piece Hermes needs and this machine has not got: what it is, what
// setting it up does, and the one button that does it (through Ceres).
// Without an `action` it only says why, for hardware that is not there.

import QtQuick
import "../morpheus"
import "../terminus"

Column {
  id: s

  property string glyph: ""
  property string title: ""
  property string body: ""
  property string action: ""
  // a second, plain answer beside the first ("Turn off Bluetooth")
  property string action2: ""
  property bool busy: false
  // the second action under way: it says so, not the first (audit 11-08:
  // "Look again" read "Setting up…" while Bluetooth was being turned off)
  property bool busy2: false
  property string busyText2: "Working…"
  property color ink: Zenon.accent
  signal go()
  signal go2()

  spacing: 10

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    text: s.glyph
    color: s.action !== "" ? s.ink : Zenon.accentMuted
    font.family: Zenon.glyphFace
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(40)
  }
  Text {
    textFormat: Text.PlainText
    anchors.horizontalCenter: parent.horizontalCenter
    text: s.title
    color: Zenon.ink
    font.family: Zenon.face
    font.weight: Zenon.titleWeight
    font.pixelSize: Zenon.px(18)
  }
  EmptyState {
    width: Math.min(parent.width, 520)
    anchors.horizontalCenter: parent.horizontalCenter
    text: s.body
    visible: s.body !== ""
  }
  Item { width: 1; height: 4; visible: s.action !== "" }
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Zenon.buttonGap
    visible: s.action !== ""
    DialogButton {
      visible: s.action2 !== ""
      label: s.busy2 ? s.busyText2 : s.action2
      ready: !s.busy && !s.busy2
      onClicked: s.go2()
    }
    BusyButton {
      label: s.action
      primary: true
      busy: s.busy
      ready: !s.busy2
      busyText: "Setting up…"
      onClicked: s.go()
    }
  }
}
