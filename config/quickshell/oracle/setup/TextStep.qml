// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SETUP ASSISTANT'S TEXT SIZE — Oracle's Font size (Zenon.px, the
// suite's text everywhere), in four steps rather than a number. The card
// itself is the sample: it grows and shrinks with the pick. Any size from
// 12 to 24 is Oracle's Fonts row.

import QtQuick
import "../../morpheus"
import ".."
import "../../terminus" as Term

Item {
  id: sizeStep
  // the assistant; not `asst`, which shadowed its id and bound to itself
  property var setup: null

  readonly property var sizes: [["14", "Small"], ["16", "Standard"], ["18", "Large"], ["20", "Larger"]]
  readonly property string now: String(Oracle.fontSize)

  Column {
    width: parent.width
    spacing: 22

    Term.Segments {
      anchors.horizontalCenter: parent.horizontalCenter
      options: sizeStep.sizes
      current: sizeStep.now
      onChose: (v) => Oracle.set("fontSize", parseInt(v, 10))
    }

    Text {
      width: parent.width
      wrapMode: Text.Wrap
      horizontalAlignment: Text.AlignHCenter
      visible: !sizeStep.sizes.some((s) => s[0] === sizeStep.now)
      text: "Now " + sizeStep.now + ", set in Oracle."
      color: Zenon.soft
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(13)
    }

    // a few lines as the suite sets them, at the size picked
    Rectangle {
      width: parent.width
      height: sample.implicitHeight + 36
      radius: Zenon.radiusCard
      color: Zenon.wash(0.04)
      border.width: 1
      border.color: Zenon.border
      Column {
        id: sample
        x: 18
        y: 18
        width: parent.width - 36
        spacing: 6
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "A heading reads like this"
          color: Zenon.white
          font.family: Zenon.face
          font.weight: Zenon.titleWeight
          font.pixelSize: Zenon.px(18)
        }
        Text {
          width: parent.width
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
          text: "And the words under it like this: menus, lists, settings and notifications all follow the size you pick."
          color: Zenon.soft
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(15)
        }
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "A small note, like a time or a path"
          color: Zenon.accentMuted
          font.family: Zenon.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(13)
        }
      }
    }
  }
}
