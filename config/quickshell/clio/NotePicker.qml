// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A NOTE TO LINK TO — Apple's ">>": typed in a note, this comes up with
// every other note, searched as you type; the one chosen goes in as a link
// (clio:note/<id>) that opens it.

import QtQuick
import "../morpheus"
import "notes.js" as N

Item {
  id: np
  property var win: null
  property bool shown: false
  signal picked(var note)
  signal closed()
  property int sel: 0
  readonly property var found: !np.shown || !np.win ? []
    : N.shelve(np.win.mgr.notes, { shelf: "all" }, pickField.text, "modified", np.win.mgr.folders)
        .filter((n) => n.id !== np.win.selId).slice(0, 60)
  onFoundChanged: np.sel = 0
  onShownChanged: if (np.shown) { pickField.text = ""; Qt.callLater(() => pickField.forceActiveFocus()); }

  function key(e) {
    if (e.key === Qt.Key_Down) { np.sel = Math.min(np.found.length - 1, np.sel + 1); list.positionViewAtIndex(np.sel, ListView.Contain); return true; }
    if (e.key === Qt.Key_Up) { np.sel = Math.max(0, np.sel - 1); list.positionViewAtIndex(np.sel, ListView.Contain); return true; }
    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (np.found[np.sel]) np.picked(np.found[np.sel]); return true; }
    if (e.key === Qt.Key_Escape) { np.closed(); return true; }
    return false;
  }

  Text {
    id: title
    x: 20
    y: 16
    text: "\u{F0339}  Link to a note"
    color: Zenon.ink
    font.family: Zenon.face
    font.weight: Zenon.titleWeight
    font.pixelSize: Zenon.px(17)
  }
  SearchBox {
    id: pickField
    x: 20
    anchors.top: title.bottom
    anchors.topMargin: 12
    width: parent.width - 40
    ghost: "Search notes"
    keyHook: (e) => { if (np.key(e)) e.accepted = true; }
  }
  ListView {
    id: list
    anchors.top: pickField.bottom
    anchors.topMargin: 10
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 12
    x: 12
    width: parent.width - 24
    clip: true
    model: np.found
    delegate: Rectangle {
      required property var modelData
      required property int index
      width: list.width
      height: 38
      radius: Zenon.windowRadius
      color: index === np.sel ? np.win.hiFill : "transparent"
      Text {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 24
        elide: Text.ElideRight
        text: N.escape(N.titleOf(modelData)) + "   " + "<font color=\"" + Zenon.accentMuted + "\">" + N.escape(np.win.folderName(modelData.folder)) + "</font>"
        textFormat: Text.StyledText
        color: Zenon.ink
        font.family: Zenon.face
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(14)
      }
      MouseArea { anchors.fill: parent; onClicked: np.picked(modelData) }
    }
    EmptyState { anchors.centerIn: parent; visible: list.count === 0; filtered: pickField.text !== ""; text: "No other notes" }
  }
  ElasticScroll { anchors.fill: list; view: list }
  Scrollbar { flick: list; anchors.right: parent.right; anchors.top: list.top; anchors.bottom: list.bottom }
}
