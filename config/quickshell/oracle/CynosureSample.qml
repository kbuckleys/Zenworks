// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// CynosureSample — CYNOSURE ON A SCREEN (2026-11-03): Look & place's head.
// A screen with the bar's pill on its edge and the panel where Opens puts
// it, as wide and as tall as Width and Rows make it, the shade behind it
// when Dim is on; with Compact, the field alone. Out of the bar, the pill IS the panel, so the pill is
// drawn as it: grown, on its own edge.
import QtQuick
import "../morpheus"
import "../morpheus/place.js" as Place

Item {
  id: sample

  // the panel's palette, handed in rather than reached for
  property string face: Zenon.face
  property color fgColor: Zenon.white
  property color dimColor: Zenon.accentMuted
  property color highlight: Zenon.accent

  // the screen, 16:9, as large as the band allows
  readonly property real sh: height - Zenon.px(36)
  readonly property real sw: Math.min(width - Zenon.px(48), sh * 16 / 9)
  // a 1920×1080 screen drawn this size
  readonly property real k: sample.sw / 1920

  Rectangle {
    id: screen
    anchors.centerIn: parent
    width: sample.sw
    height: sample.sw * 9 / 16
    radius: Zenon.rad(8)
    color: Zenon.alpha(sample.fgColor, 0.05)
    border.width: 1
    border.color: Zenon.alpha(sample.fgColor, 0.16)
    clip: true

    // the shade
    Rectangle {
      anchors.fill: parent
      color: Zenon.shade(Oracle.cynosureDim ? Oracle.cynosureDimStrength : 0)
      Behavior on color { ColorAnimation { duration: Zenon.fast } }
    }

    // the bar's pill, unless the panel is it
    Rectangle {
      visible: Oracle.cynosurePlace !== "bar"
      anchors.horizontalCenter: parent.horizontalCenter
      y: Zenon.barTop ? Zenon.px(4) : parent.height - height - Zenon.px(4)
      width: parent.width * 0.42
      height: Math.max(Zenon.px(6), 36 * sample.k)
      radius: height / 2
      color: Zenon.alpha(sample.fgColor, 0.18)
    }

    // the panel
    Rectangle {
      id: panel
      readonly property real pad: Zenon.px(4)
      readonly property real fieldH: 40 * sample.k
      // compact: the field alone, as it opens on an empty line
      readonly property real rowsH: Oracle.cynosureCompact ? 0 : Oracle.cynosureRows * 40 * sample.k
      readonly property real footH: Oracle.cynosureCompact ? 0 : 40 * sample.k
      anchors.horizontalCenter: parent.horizontalCenter
      width: Oracle.cynosureWidth * sample.k
      height: panel.fieldH + panel.rowsH + panel.footH
      y: Place.placeTop(Oracle.cynosurePlace, Zenon.barTop, parent.height, panel.height, panel.height, panel.pad,
        Math.max(Zenon.px(6), 36 * sample.k) + Zenon.px(4))
      radius: Zenon.rad(8)
      color: Zenon.layerBg
      border.width: 1
      border.color: Zenon.alpha(sample.highlight, 0.6)
      Behavior on y { NumberAnimation { duration: Zenon.slow; easing.type: Zenon.ease } }
      Behavior on width { NumberAnimation { duration: Zenon.slow; easing.type: Zenon.ease } }
      Behavior on height { NumberAnimation { duration: Zenon.slow; easing.type: Zenon.ease } }

      // the field
      Rectangle {
        x: Zenon.px(6)
        y: panel.fieldH * 0.32
        width: panel.width * 0.4
        height: Math.max(2, panel.fieldH * 0.36)
        radius: height / 2
        color: Zenon.alpha(sample.fgColor, 0.5)
      }
      // the rows
      Repeater {
        model: Oracle.cynosureCompact ? 0 : Oracle.cynosureRows
        Rectangle {
          required property int index
          x: Zenon.px(6)
          y: panel.fieldH + index * 40 * sample.k + 40 * sample.k * 0.35
          width: (index === 0 ? panel.width - Zenon.px(12) : panel.width * (0.3 + 0.35 * ((index * 37) % 10) / 10))
          height: Math.max(2, 40 * sample.k * 0.3)
          radius: height / 2
          color: index === 0 ? Zenon.alpha(sample.highlight, 0.45) : Zenon.alpha(sample.fgColor, 0.16)
        }
      }
    }
  }
}
