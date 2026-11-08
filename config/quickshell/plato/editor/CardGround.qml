// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A floating card's ground in Plato: the status bar's lists, the path card,
// completion and hover cards, at a full-strength hairline.

import QtQuick
import "../../morpheus"

Rectangle {
  anchors.fill: parent
  radius: Zenon.windowRadius
  color: Zenon.alpha(Zenon.card, 0.97)
  border.width: 1
  border.color: Zenon.alpha(Zenon.border, 0.9)
}
