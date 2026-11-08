// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A CALENDAR'S « ‹ › » — one month or one year along. Chronos' popup, its
// window and Clio's journal each had their own, in three sizes and two grays.
// `compact` is for a small month grid.

import QtQuick

Item {
  id: chev
  property string glyph: ""
  property bool compact: false
  signal activated()

  width: chev.compact ? 20 : 24
  height: chev.compact ? 28 : 34
  Text {
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: chev.glyph
    color: press.pressed ? Zenon.accent : Zenon.accentMuted
    font.family: Zenon.face
    font.weight: Zenon.titleWeight
    font.pixelSize: Zenon.px(chev.compact ? 16 : 17)
  }
  MouseArea { id: press; anchors.fill: parent; onClicked: chev.activated() }
}
