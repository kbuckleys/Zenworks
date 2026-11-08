// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A QUESTION ACROSS THE TOP OF ORACLE — a tinted strip that opens while
// `asked`, its words on the left and two answers on the right, the second
// the one it leans to (tinted and ringed in the accent). Over every section,
// not only the one that asked: it stands until it is answered.
//
// Was written out twice in OracleWindow ("Keep these display settings?" and
// "Turn Hyper off?"), the same 70 lines (2026-11-08).

import QtQuick
import "../morpheus"

Rectangle {
  id: qb
  property bool asked: false
  property string text: ""
  // [first, second]: the second is the one it leans to
  property var choices: ["", ""]
  // the window's own colors and face
  property color ink: Zenon.yellow
  property color highlight: Zenon.accent
  property color fg: Zenon.ink
  property string face: Zenon.face
  // 0 for the first answer, 1 for the second
  signal chose(int i)

  height: qb.asked ? 52 : 0
  visible: height > 0
  clip: true
  color: Qt.rgba(qb.ink.r, qb.ink.g, qb.ink.b, 0.10)
  Behavior on height { NumberAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }

  Hairline {
    anchors.bottom: parent.bottom
    width: parent.width
  }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: 24
    anchors.right: btns.left
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: qb.text
    color: qb.ink
    font.family: qb.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(15)
  }

  Row {
    id: btns
    anchors.right: parent.right
    anchors.rightMargin: 20
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    Repeater {
      model: qb.choices
      Rectangle {
        id: b
        required property string modelData
        required property int index
        readonly property bool lean: b.index === 1
        width: bText.implicitWidth + 28
        height: 28
        radius: Zenon.radiusControl
        color: bMa.pressed
          ? Qt.rgba(qb.highlight.r, qb.highlight.g, qb.highlight.b, 0.25)
          : b.lean ? Qt.rgba(qb.highlight.r, qb.highlight.g, qb.highlight.b, 0.14)
          : Zenon.wash(0.06)
        border.width: 1
        border.color: b.lean ? qb.highlight : Zenon.border

        Text {
          id: bText
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: b.modelData
          color: qb.fg
          font.family: qb.face
          font.weight: Zenon.weight
          font.pixelSize: Zenon.px(14)
        }

        MouseArea {
          id: bMa
          anchors.fill: parent
          onClicked: qb.chose(b.index)
        }
      }
    }
  }
}
