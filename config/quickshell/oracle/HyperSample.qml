// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// HyperSample — THE HYPER KEY, DRAWN (2026-11-03, user: "so the user can
// quickly identify that caps lock is no ordinary key"). Shortcuts' head: a
// keyboard's left and bottom rows with the key Hyper took lit in the
// accent and named Hyper, and under it the four it holds. Off, the keys
// are all plain and the line says so.
import QtQuick
import "../morpheus"

Item {
  id: sample

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  readonly property string taken: Oracle.hyperKey
  readonly property real u: Math.min(Zenon.px(40), (width - Zenon.px(48)) / 15.5)

  // [label, width in keys, id]: the id is the one hyperKey names
  readonly property var rows: [
    [["Tab", 1.5, ""], ["Q", 1, ""], ["W", 1, ""], ["E", 1, ""], ["R", 1, ""], ["T", 1, ""], ["Y", 1, ""], ["U", 1, ""],
     ["I", 1, ""], ["O", 1, ""], ["P", 1, ""], ["[", 1, ""], ["]", 1, ""], ["\\", 1.5, ""]],
    [["Caps Lock", 1.75, "caps"], ["A", 1, ""], ["S", 1, ""], ["D", 1, ""], ["F", 1, ""], ["G", 1, ""], ["H", 1, ""],
     ["J", 1, ""], ["K", 1, ""], ["L", 1, ""], [";", 1, ""], ["'", 1, ""], ["Return", 2.25, ""]],
    [["Ctrl", 1.25, ""], ["Super", 1.25, ""], ["Alt", 1.25, ""], ["", 6.25, ""], ["Alt", 1.25, ""],
     ["Menu", 1.25, "menu"], ["Ctrl", 1.5, "rctrl"]]
  ]

  Column {
    anchors.centerIn: parent
    spacing: Zenon.px(12)

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Zenon.px(4)
      Repeater {
        model: sample.rows
        Row {
          id: keyRow
          required property var modelData
          spacing: Zenon.px(4)
          Repeater {
            model: keyRow.modelData
            Rectangle {
              id: cap
              required property var modelData
              readonly property bool lit: cap.modelData[2] !== "" && cap.modelData[2] === sample.taken
              width: Math.round(sample.u * cap.modelData[1] - Zenon.px(4))
              height: Math.round(sample.u - Zenon.px(4))
              radius: Zenon.rad(6)
              color: cap.lit ? sample.highlight : Zenon.alpha(sample.fgColor, 0.06)
              border.width: 1
              border.color: cap.lit ? sample.highlight : Zenon.alpha(sample.fgColor, 0.14)
              Behavior on color { ColorAnimation { duration: Zenon.fast } }
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: cap.lit ? "Hyper" : cap.modelData[0]
                color: cap.lit ? Zenon.inkOnAccent : sample.dimColor
                font.family: sample.face
                font.weight: cap.lit ? Zenon.titleWeight : 500
                font.pixelSize: Zenon.px(cap.lit ? 13 : 11)
              }
            }
          }
        }
      }
    }

    // what it holds, as caps, or that there is none
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Zenon.px(6)
      visible: sample.taken !== "off"
      Repeater {
        model: ["Ctrl", "+", "Alt", "+", "Shift", "+", "Super"]
        Rectangle {
          id: mod
          required property string modelData
          readonly property bool plus: mod.modelData === "+"
          width: mod.plus ? plusText.implicitWidth : modText.implicitWidth + Zenon.px(16)
          height: Zenon.px(24)
          radius: Zenon.rad(5)
          color: mod.plus ? "transparent" : Zenon.alpha(sample.highlight, 0.16)
          Text {
            id: modText
            visible: !mod.plus
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: mod.modelData
            color: sample.fgColor
            font.family: sample.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(12)
          }
          Text {
            id: plusText
            visible: mod.plus
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "+"
            color: sample.dimColor
            font.family: sample.face
            font.weight: Zenon.weight
            font.pixelSize: Zenon.px(12)
          }
        }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: sample.taken === "off"
      textFormat: Text.PlainText
      text: "No hyper key: every key is its usual self"
      color: sample.dimColor
      font.family: sample.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(12)
    }
  }
}
