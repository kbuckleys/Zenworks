// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A KEEP CHIP — ClearChip's disc with a ✓, for a quiet "save this" beside
// an AddChip (user, 2026-11-02: terminus' search bar had a lit Save button
// that stood out; "just make it a chip with a checkmark"). Drawn, as the
// × and the chevron are: a glyph centers by its line box, not its ink.

import QtQuick
import "."

Rectangle {
  id: chip
  property real size: 14
  property bool shown: true
  // false: dimmed and deaf, a save with nothing to save yet
  property bool ready: true
  property bool held: false
  property color ink: Zenon.ink
  readonly property bool down: press.pressed || chip.held
  signal clicked()

  visible: chip.shown
  width: Math.round(chip.size * 1.05)
  height: width
  radius: width / 2
  color: chip.down ? Zenon.pressFill : Zenon.alpha(Zenon.ink, 0.16)
  opacity: chip.ready ? 1 : Zenon.disabledDim

  // the two arms meet at the foot; the pair centered on the disc
  Item {
    id: mark
    anchors.fill: parent
    readonly property real thick: Math.max(1.5, chip.size / 10)
    readonly property real a: chip.size * 0.24     // the short arm
    readonly property real b: chip.size * 0.48     // the long arm
    readonly property real r2: Math.SQRT2
    // the foot, placed so the whole mark's box sits on the middle
    readonly property real fx: width / 2 - (mark.b - mark.a) / (2 * mark.r2)
    readonly property real fy: height / 2 + mark.b / (2 * mark.r2)
    Repeater {
      // [length, rotation, sign of its run along x]
      model: [[mark.a, 45, -1], [mark.b, -45, 1]]
      Rectangle {
        required property var modelData
        width: modelData[0] + mark.thick / 2
        height: mark.thick
        radius: height / 2
        antialiasing: true
        rotation: modelData[1]
        x: mark.fx + modelData[2] * modelData[0] / (2 * mark.r2) - width / 2
        y: mark.fy - modelData[0] / (2 * mark.r2) - height / 2
        color: chip.ink
        opacity: chip.down ? Zenon.pressDim : 0.8
      }
    }
  }
  MouseArea {
    id: press
    enabled: chip.ready
    // a little past the chip: it is small
    anchors.fill: parent
    anchors.margins: -4
    onClicked: chip.clicked()
  }
}
