// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
// A divider that eases away with the group it separates, so an empty side of
// the bar never leaves a seam floating against the pill edge.

import QtQuick
import "."

Collapsible {
  id: slot
  openWidth: rule.implicitWidth
  // the rule's strength, its room kept (a frameless bar, 0: shell.qml)
  property real ink: 1
  Divider { id: rule; anchors.centerIn: parent; opacity: slot.ink }
}
