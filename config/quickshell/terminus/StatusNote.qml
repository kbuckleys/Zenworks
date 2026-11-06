// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE WHOLE OF A MESSAGE THE STATUS PILL HAD TO CUT. The pill is capped at a
// share of the listing and elides; this stands over it while the pointer is
// on it, the same text wrapped to a readable measure, in the pill's own tone.
// A click on the words copies them (the holder's job — see StatusPill).
//
//     StatusNote { parent: window.contentItem; z: 60
//       anchorItem: words; text: …; bad: …; open: hovered && cut }
//
// Placed from the words each time it opens, centered over them and kept
// inside the window — the pill sits at the window's foot, so it opens upward.

import QtQuick
import "../morpheus"

Item {
  id: note

  property Item anchorItem: null
  property string text: ""
  property bool bad: false
  property bool open: false
  readonly property color tone: note.bad ? Zenon.red : Zenon.sand

  width: Math.min(460, (parent ? parent.width : 460) - 24)
  height: card.height
  visible: card.opacity > 0.01

  function place() {
    if (!note.anchorItem || !note.parent) return;
    const p = note.anchorItem.mapToItem(note.parent, note.anchorItem.width / 2, 0);
    note.x = Math.round(Math.max(12, Math.min(p.x - note.width / 2, note.parent.width - note.width - 12)));
    note.y = Math.round(p.y - note.height - 10);
  }
  onOpenChanged: if (note.open) note.place()
  onHeightChanged: if (note.open) note.place()

  Rectangle {
    id: card
    width: note.width
    height: words.implicitHeight + 20
    radius: Zenon.windowRadius
    color: Zenon.black
    border.width: 1
    border.color: Qt.rgba(note.tone.r, note.tone.g, note.tone.b, 0.45)
    opacity: note.open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }
    transform: Translate {
      y: note.open ? 0 : 4
      Behavior on y { NumberAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }
    }

    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: Qt.rgba(note.tone.r, note.tone.g, note.tone.b, 0.08)
    }

    Text {
      textFormat: Text.PlainText
      id: words
      x: 12
      y: 10
      width: card.width - 24
      text: note.text
      wrapMode: Text.WrapAtWordBoundaryOrAnywhere
      color: note.tone
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(13)
      lineHeight: 1.15
    }
  }
}
