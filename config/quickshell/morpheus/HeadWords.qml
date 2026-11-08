// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// AN APP'S NAME OVER A LINE OF HOW IT IS DOING, at the left of its head: Control
// Hub, System Journal, Screen Time and Tidy each drew this by hand. `room`
// caps the line when something stands to its right (0 is no cap).

import QtQuick

Column {
  id: words
  property string title: ""
  property string status: ""
  property color statusInk: Zenon.accentMuted
  property real room: 0

  x: 20
  anchors.verticalCenter: parent.verticalCenter
  spacing: 1
  Text {
    textFormat: Text.PlainText
    text: words.title
    color: Zenon.ink
    font.family: Zenon.face
    font.weight: Zenon.titleWeight
    font.pixelSize: Zenon.px(17)
  }
  Text {
    textFormat: Text.PlainText
    width: words.room > 0 ? words.room : implicitWidth
    elide: Text.ElideRight
    text: words.status
    color: words.statusInk
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(12)
  }
}
