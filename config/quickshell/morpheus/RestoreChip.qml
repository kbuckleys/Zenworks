// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A SETTING'S RESTORE DEFAULT MARK — beside the name of a setting that has
// moved off its default (user, 2026-11-07: the one glyph, U+F17B1, in one
// place). Oracle's rows and Plato's settings sheet both wear it:
//
//     RestoreChip { visible: row.changed
//                   ink: Zenon.yellow
//                   height: label.height
//                   onClicked: settings.reset(key) }
//
// A hover tip belongs to the caller: `area` is the MouseArea to read
// containsMouse from and to place the tip against.

import QtQuick

Item {
  id: chip
  // the "changed" ink of the row it sits in; pressed, it goes to the text ink
  property color ink: Zenon.yellow
  // the mark itself, for a button that says the same thing in words
  readonly property string glyph: "\u{F17B1}"
  readonly property alias area: press
  signal clicked()

  implicitWidth: mark.implicitWidth + 8
  implicitHeight: mark.implicitHeight

  Rectangle {
    anchors.centerIn: parent
    width: parent.width + 4
    height: width
    radius: Zenon.windowRadius
    color: press.pressed ? Zenon.pressWash(0.12) : "transparent"
  }
  Text {
    id: mark
    anchors.centerIn: parent
    text: chip.glyph
    color: press.pressed ? Zenon.ink : chip.ink
    textFormat: Text.PlainText
    font.family: Zenon.glyphMono
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(15)
  }
  MouseArea {
    id: press
    anchors.fill: parent
    anchors.margins: -3
    hoverEnabled: true
    onClicked: chip.clicked()
  }
}
