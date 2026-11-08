// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// HELDRING — the thing a menu was asked of, outlined while that menu is
// open. Not the cursor: a right click is a question about a row, so which
// row the card is about has to be seen at a glance, beside wherever the
// cursor happens to be. It began on terminus' disk rows (SideRow) and the
// user asked for it everywhere a right click opens a menu (2026-10-09):
// terminus' rows and tiles, picasso's gallery, icarus' entries, clio's notes.
//
//     HeldRing { anchors.fill: parent; anchors.margins: 4; on: menuAt === row }
//
// Laid over the row as a sibling of what it draws, so it reads on top of the
// row's own fill and cursor bar. Placement is the caller's.
//
// A MIDDLE CLICK WEARS IT TOO (user, 2026-11-07), as the sight that it landed:
// a new tab opens out of view, a mark goes without a word. Hand it the row's
// MouseArea and the ring is up from the press until a moment past the release:
//
//     HeldRing { anchors.fill: parent; middleOf: rowMouse }
//
// A row answering through a TapHandler calls flash() from its tap instead.

import QtQuick
import "../morpheus"

Rectangle {
  id: held
  property bool on: false
  property var middleOf: null

  readonly property bool middleDown: !!held.middleOf
    && (held.middleOf.pressedButtons & Qt.MiddleButton) !== 0
  function flash() { linger.restart(); }
  onMiddleDownChanged: if (!held.middleDown) linger.restart()

  radius: Zenon.radiusControl
  // hollow: only the ring (user, 2026-10-09 — no tint inside it)
  color: "transparent"
  border.width: 2   // user, 2026-10-09
  border.color: Zenon.alpha(Zenon.accent, 0.6)

  opacity: held.on || held.middleDown || linger.running ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { NumberAnimation { duration: Zenon.fast; easing.type: Easing.OutCubic } }

  Timer { id: linger; interval: Zenon.hoverLeave }
}
