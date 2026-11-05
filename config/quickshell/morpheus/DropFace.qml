// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// A DROPDOWN'S BUTTON — the face the closed control shows, and the HEADER of
// the open menu. Pressed, the list does not appear as a second card under a
// gap: it unrolls out of this face's edge and the two read as ONE surface
// (user, 2026-11-04: "visually truly a dropdown menu, not just a button that
// spawns a menu"). So while its list is showing this face wears the card's
// ground and hairline, squares the corners where the list meets it, turns
// its chevron over — and WIDENS TO THE MENU, so face and list are one width.
// Closed, it is as wide as its current choice and no wider (user,
// 2026-11-05). The list's half is CardBody's `joinEdge`, set by CardPopup's
// `attach` (a window's dropdown) or by hand (terminus BulkDrop).
//
//     DropFace {
//       joined: myPopup.attach === face ? myPopup.joined : ""
//       menuWidth: myPopup.attach === face ? myPopup.fitW : 0
//       contentWidth: label.implicitWidth      // what the closed face shows
//       growLeft: true                         // when anchored by its right
//       pressed: ma.pressed
//       // content: a label anchored to `chevron.left`
//     }
//
// `joined` is where the list hangs: "below", "above", or "" (closed). It
// stays set until the list has finished folding away, so the face does not
// round or narrow while the card is still against it. Leave `width` unset:
// the face sizes itself (implicitWidth).
import QtQuick
import "."

Rectangle {
  id: face

  property string joined: ""
  property bool pressed: false
  // the closed look: an owner's own wash, press and focus ring
  property color restColor: Zenon.wash(0.06)
  property color pressColor: Zenon.pressFill
  property bool lit: false
  property color litBorder: Zenon.accent
  property color chevronInk: Zenon.accentMuted
  property int chevronSize: 11
  readonly property alias chevron: chev
  readonly property bool open: face.joined !== ""

  // ── ITS WIDTH ─────────────────────────────────────────────────────────
  // Closed: what it shows (`contentWidth`, from its left inset to the end of
  // its label) plus the chevron and the insets round it. Open: the menu's
  // (`menuWidth`, CardPopup.fitW), so the two are one width; never narrower
  // than closed. `growLeft`: the face is held by its right edge and widens
  // leftwards — the card then hangs from where its left edge WILL be.
  property real contentWidth: 0
  property real leftInset: 10
  // ── THE ROWS' INSETS, OPEN ────────────────────────────────────────────
  // Open, the header's label starts where every row's does and its chevron
  // stands in the rows' tick column (CardBody: 12 + menuCardPad in from the
  // left, a 16px tail 10 + menuCardPad in from the right) — user,
  // 2026-11-05. Owners anchor their first piece at `inset`, not a number.
  property real openness: face.open ? 1 : 0
  Behavior on openness { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
  readonly property real rowInset: 12 + Zenon.menuCardPad
  readonly property real inset: face.leftInset + (face.rowInset - face.leftInset) * face.openness
  readonly property real chevronRest: 9
  readonly property real chevronOpen: 10 + Zenon.menuCardPad + (16 - chev.implicitWidth) / 2
  property real menuWidth: 0
  property bool growLeft: false
  property real floorWidth: 0
  readonly property real restWidth: Math.ceil(Math.max(face.floorWidth,
    face.leftInset + face.contentWidth + 6 + chev.implicitWidth + face.chevronRest))
  readonly property real targetWidth: face.open ? Math.max(face.restWidth, face.menuWidth) : face.restWidth
  implicitWidth: face.targetWidth
  Behavior on implicitWidth { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }

  // ── AS TALL AS A ROW, OPEN ────────────────────────────────────────────
  // A 26px face over 30px rows read as a short first row (user,
  // 2026-11-05). Open, the header stands a menu row tall: it grows AWAY
  // from the list, so the seam does not move and the card stays where it
  // hangs, and its content is carried with it so the label stays centered
  // in the taller header. Drawn, not laid out: the row it sits in, and the
  // place CardPopup measures it at, are untouched (see joinRect).
  readonly property real extra: Math.max(0, Zenon.menuRowHeight - face.height)
  property string lastJoin: "below"
  onJoinedChanged: if (face.joined !== "") face.lastJoin = face.joined
  property real lift: face.open ? face.extra : 0
  Behavior on lift { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
  readonly property int liftSign: face.lastJoin === "above" ? 1 : -1
  transform: Translate { y: face.liftSign * face.lift / 2 }

  radius: Zenon.radiusControl
  // the edge the list hangs from is square, as a hinged submenu's is
  topLeftRadius: face.joined === "above" ? 0 : face.radius
  topRightRadius: face.joined === "above" ? 0 : face.radius
  bottomLeftRadius: face.joined === "below" ? 0 : face.radius
  bottomRightRadius: face.joined === "below" ? 0 : face.radius
  color: face.pressed ? face.pressColor : face.restColor
  border.width: 1
  border.color: face.lit ? face.litBorder : Zenon.border
  Behavior on color { ColorAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }
  Behavior on border.color { ColorAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }

  // OPEN, THE LIST'S OWN FROST AND HAIRLINE: one outline round both.
  // Laid OVER the closed look and faded, never the face's color tweened into
  // it — a dark glass and a white wash met halfway as a light gray, and the
  // face flashed every time its list folded away (user, 2026-11-05).
  Rectangle {
    // the taller header: its far edge out by the lift, the seam where it was
    x: 0
    width: parent.width
    y: -face.lift / 2
    height: parent.height + face.lift
    radius: face.radius
    topLeftRadius: face.topLeftRadius
    topRightRadius: face.topRightRadius
    bottomLeftRadius: face.bottomLeftRadius
    bottomRightRadius: face.bottomRightRadius
    // the list's frost, laid solid: drawn inside the window, nothing under
    // the header can be blurred, and the row's own text must not show
    // through it sharp (Zenon.dropFrostSolid)
    color: Zenon.dropFrostSolid
    border.width: 1
    border.color: Zenon.border
    opacity: face.open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
  }

  // the one mark that says this opens rather than cycles; turned over while
  // the list is out, pointing the way it folds back
  Text {
    id: chev
    anchors.right: parent.right
    anchors.rightMargin: face.chevronRest + (face.chevronOpen - face.chevronRest) * face.openness
    anchors.verticalCenter: parent.verticalCenter
    // a chevron, written as an escape: the glyph itself was lost once already
    text: ""
    color: face.chevronInk
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(face.chevronSize)
    rotation: face.open ? 180 : 0
    Behavior on rotation { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
  }
}
