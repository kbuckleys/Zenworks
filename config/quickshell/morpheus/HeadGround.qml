// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A WINDOW HEAD'S GROUND — the head's fill and the hairline under it, the
// two lines every app's head began with (dedupe, 2026-11-07).
//
//     Item { height: Zenon.toolbarH; HeadGround {} … }

import QtQuick

Item {
  anchors.fill: parent
  Rectangle { anchors.fill: parent; color: Zenon.headBg }
  Hairline { anchors.bottom: parent.bottom; width: parent.width }
}
