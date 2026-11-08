// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A THEME'S INKS, IN ONE BAR (user, 2026-11-07): its eight colors flowing
// into each other, as About this computer's bar has them, with no border
// and no frame of the theme's ground (the light mark beside the name says
// which side it is). At the right of a theme's row in Oracle's Theme list
// and in Cynosure's "theme" list. `colors` is Ora.themeInksFor's: [ground,
// red, sand, yellow, green, accent, blue, magenta, pink]; the ground is not
// drawn. Loaded by URL (Qt.resolvedUrl), so a running shell takes it
// without a restart.

import QtQuick

Rectangle {
  id: ti
  property var colors: null
  readonly property var c: ti.colors && ti.colors.length === 9 ? ti.colors : null
  function at(i) { return ti.c ? ti.c[i] : "transparent"; }
  implicitWidth: 92
  implicitHeight: 14
  width: implicitWidth
  height: implicitHeight
  radius: Zenon.rad(3)
  gradient: Gradient {
    orientation: Gradient.Horizontal
    GradientStop { position: 0 / 7; color: ti.at(1) }
    GradientStop { position: 1 / 7; color: ti.at(2) }
    GradientStop { position: 2 / 7; color: ti.at(3) }
    GradientStop { position: 3 / 7; color: ti.at(4) }
    GradientStop { position: 4 / 7; color: ti.at(5) }
    GradientStop { position: 5 / 7; color: ti.at(6) }
    GradientStop { position: 6 / 7; color: ti.at(7) }
    GradientStop { position: 7 / 7; color: ti.at(8) }
  }
}
