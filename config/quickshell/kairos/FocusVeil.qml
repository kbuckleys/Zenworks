// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// FocusVeil — AN APP SET ASIDE FOR A FOCUS SESSION (2026-11-03): while one
// on the session's list is in front (Kairos.blocking), its screen is
// covered, the keys taken, and a card says so, with five minutes of it or
// the session's end. Going to another window (a workspace, the switcher)
// takes the veil away; the app is never closed or moved.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../morpheus"
import "../oracle"
import "kairos.js" as K

PanelWindow {
  id: veil
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "kairos-focus"
  WlrLayershell.keyboardFocus: veil.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  anchors { left: true; right: true; top: true; bottom: true }
  color: "transparent"
  visible: Kairos.blocking && !Kairos.locked
  onVisibleChanged: if (veil.visible) veil.screen = Oracle.focusedScreen()

  readonly property string app: Kairos.current !== "" ? Kairos.nameOf(Kairos.current) : ""

  Rectangle {
    anchors.fill: parent
    color: Zenon.shade(0.82)
  }
  Item {
    anchors.fill: parent
    focus: true
    Keys.onPressed: (e) => {
      e.accepted = true;
      if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) Kairos.letIn(Kairos.current, 5);
    }
  }
  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.max(Zenon.px(380), col.implicitWidth + Zenon.px(56))
    height: col.implicitHeight + Zenon.px(48)
    radius: Zenon.dialogRadius
    color: Zenon.layerBg
    border.width: 1
    border.color: Zenon.border
    Column {
      id: col
      anchors.centerIn: parent
      spacing: Zenon.px(10)
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Kairos.glyphOf(Kairos.current)
        color: Zenon.muted
        font.family: Zenon.face
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(40)
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: veil.app + " is set aside"
        color: Zenon.white
        font.family: Zenon.face
        font.weight: Zenon.titleWeight
        font.pixelSize: Zenon.px(20)
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Kairos.focus ? Kairos.focus.label + " · " + K.leftWords(Kairos.focus.until - Kairos.clock) : ""
        color: Zenon.muted
        font.family: Zenon.face
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(14)
      }
      Item { width: 1; height: Zenon.px(6) }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Zenon.buttonGap
        DialogButton { label: "End focus"; onClicked: Kairos.endFocus(false) }
        DialogButton { label: "Five more minutes"; primary: true; onClicked: Kairos.letIn(Kairos.current, 5) }
      }
    }
  }
}
