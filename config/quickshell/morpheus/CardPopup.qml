// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE CARD, FOR A WINDOW. CardMenu stands on a layer surface placed in
// screen coordinates — which a window cannot supply, because a wayland client
// is never told where its own window is. An xdg-popup can be placed by
// something it DOES know: a point inside its own window. So this hangs the same
// card (CardBody) off that point, and the compositor puts it on screen,
// flipping it up or sliding it sideways when there is no room below.
//
//     CardPopup {
//       window: myWindow
//       at: chip.mapToItem(null, 0, chip.height + 4)   // window coordinates
//       open: …; model: […]; onChosen: …
//     }
//
// The row format is CardMenu's, and one more: a row with `children` opens
// them in a card of their own beside it, on hover — see MenuCore's BRANCHES.
//
// A DROPDOWN: `attach: face` (a morpheus/DropFace) instead of `at`. The card
// then hangs from the face's bottom edge with no gap, its hairline on the
// face's, at least as wide as the face — one surface, the face its header —
// and unrolls out of it (CardBody's joinEdge). With no room below, the
// compositor flips it ABOVE the face, laid on the face's top edge the same
// way. `joined` says which ("below", "above", "" closed) for the face to
// square its own corners: `joined: menu.attach === face ? menu.joined : ""`.
//
// THE SURFACE ONLY. The menu itself — sizing, fade, branches, the card — is
// morpheus/MenuCore (2026-10-18), so any other surface can hang the same core.
import QtQuick
import Quickshell
import "."

PopupWindow {
  id: root

  // the window it hangs off, and where in it: the card's top-left
  property var window: null
  property point at: Qt.point(0, 0)
  // or the dropdown face it hangs from — see the header
  property DropFace attach: null
  readonly property bool attached: root.attach !== null && root.parentCard === null
  // the face, in the window's coordinates; measured again as it opens or
  // moves to another face (one card is often shared by every dropdown in a
  // window, oracle's is)
  // — where it WILL be: a face widens to the menu as it opens (DropFace),
  // and the card hangs from the end of that, not from a frame of it
  readonly property rect joinRect: {
    root.open;
    const a = root.attach;
    if (!a) return Qt.rect(0, 0, 0, 0);
    a.x; a.y; a.width; a.height;
    const w = a.targetWidth;
    // through its parent: the face's own lift (DropFace) is drawn, not placed
    const p = a.parent ? a.parent.mapToItem(null, a.x, a.y) : a.mapToItem(null, 0, 0);
    const x = a.growLeft ? p.x + a.width - w : p.x;
    return Qt.rect(Math.round(x), Math.round(p.y), Math.round(w), Math.round(a.height));
  }
  // WHERE THE COMPOSITOR PUT IT. A client asks for a popup below and the
  // compositor flips it above when the screen runs out; the only word of
  // that is where the popup's window ended up against its parent's. Above
  // the face's middle is above the face.
  // (Read in a function, never in a binding: the backing windows are not
  // notifiable properties, and the live log says so.)
  property bool flipped: false
  property var placedWin: null
  function checkFlip() {
    if (!root.attached || !root.visible) { root.flipped = false; return; }
    const me = root._backingWindow;
    const up = root.window ? root.window._backingWindow : null;
    root.placedWin = me || null;
    root.flipped = !!(me && up)
      && me.y - up.y + root.pad < root.joinRect.y + root.joinRect.height / 2;
  }
  onVisibleChanged: root.checkFlip()
  onJoinRectChanged: Qt.callLater(root.checkFlip)
  Connections {
    target: root.placedWin
    ignoreUnknownSignals: true
    function onYChanged() { root.checkFlip(); }
  }
  // which side of its face the list is showing on, while it is showing
  readonly property string joined: root.attached && core.showing
    ? (root.flipped ? "above" : "below") : ""

  property alias model: core.model
  property alias open: core.open
  property alias cardWidth: core.cardWidth
  // as wide as its longest row (cardWidth is then ignored; see Zenon.menuMinWidth)
  property alias fit: core.fit
  property alias activeIndex: core.activeIndex
  readonly property alias pad: core.pad
  readonly property alias cardW: core.cardW
  // what its rows alone want — a dropdown face widens to this as it opens
  readonly property alias fitW: core.fitW
  readonly property alias contentH: core.contentH
  readonly property alias shade: core.shade
  readonly property alias branch: core.branch
  readonly property alias child: core.child

  signal chosen(int index)
  signal hovered(int index)
  signal unhovered(int index)
  signal secondary(int index)
  // a row picked in a branch's card
  signal subChosen(int branch, int index)

  // A key pressed while the card's own surface has the keyboard. Whether a
  // popup or the window under it gets the keys is the compositor's call, so
  // a holder that wants a key on a row (oracle: Delete on a theme) listens
  // here as well as on its own window. Opt in with `takeKeys`.
  property bool takeKeys: false
  signal keyPressed(var event)
  Item {
    focus: root.takeKeys
    Keys.onPressed: (event) => root.keyPressed(event)
  }

  // set on a branch's card: the card it hangs off, and how far down that
  // card the row is
  property var parentCard: null
  property real hingeY: 0

  function rowY(i) { return core.rowY(i); }
  function openBranch(i) { core.openBranch(i); }
  function closeBranch() { core.closeBranch(); }

  visible: root.window !== null && core.showing
  color: "transparent"
  implicitWidth: core.implicitWidth
  implicitHeight: core.implicitHeight

  anchor {
    window: root.window
    // a rect the size of the padding box, so the CARD's corner lands on the
    // point and the shadow's room is taken out of the way on either side.
    // A branch's card: the parent card at its row, NARROWED by this
    // surface's own inset at both ends, so the CARD lands flush against the
    // parent card on whichever side it opens. Shifted rather than narrowed,
    // it was flush on the right only: flipped left (FlipX mirrors the rect's
    // edges) a sticky's Color card stood two insets, 72px, off its menu
    // (user, 2026-11-02 — icarus never showed it: it hinges in code).
    //
    // A dropdown's: a rect whose TOP puts the card's top on the face's
    // bottom hairline (one pixel up, so the two hairlines are one) and whose
    // BOTTOM puts the card's bottom on the face's top hairline — so a flip
    // lands it above the face exactly as it would have hung below. Slid
    // sideways, never flipped sideways: it hangs from the face's left.
    rect.x: root.parentCard ? root.parentCard.pad + root.pad
          : root.attached ? root.joinRect.x - root.pad : Math.round(root.at.x) - root.pad
    rect.y: root.parentCard ? root.parentCard.pad + root.hingeY - root.pad
          : root.attached ? root.joinRect.y + root.joinRect.height - 1 - root.pad
          : Math.round(root.at.y) - root.pad
    rect.width: root.parentCard ? Math.max(1, root.parentCard.cardW - 2 * root.pad) : 2 * root.pad
    rect.height: root.parentCard ? 1
               : root.attached ? Math.max(1, 2 * root.pad + 2 - root.joinRect.height)
               : 2 * root.pad
    edges: root.parentCard ? (Edges.Right | Edges.Top) : (Edges.Left | Edges.Top)
    gravity: Edges.Right | Edges.Bottom
    // flip and slide, never resize: a list that fits by losing its bottom
    // rows is not fitting
    adjustment: root.parentCard ? (PopupAdjustment.FlipX | PopupAdjustment.SlideY)
              : root.attached ? (PopupAdjustment.FlipY | PopupAdjustment.SlideX | PopupAdjustment.SlideY)
                              : (PopupAdjustment.Flip | PopupAdjustment.Slide)
  }

  MenuCore {
    id: core
    anchors.fill: parent
    // a dropdown's list: as wide as its face at least, laid against it
    minWidth: root.attached ? root.joinRect.width : 0
    joinEdge: root.joined === "below" ? "top" : root.joined === "above" ? "bottom" : ""
    joinSpan: root.joinRect.width
    joinRadius: root.attach ? root.attach.radius : Zenon.radiusControl
    // a branch's card: another CardPopup, its own surface, hinged on the row
    // as terminus' submenu is — anchored to THIS surface across the card's
    // width, so FlipX mirrors it to the card's left where the screen runs out
    makeBranch: (rows, from, hingeY) => {
      const c = Qt.createComponent("CardPopup.qml");
      return c.status === Component.Ready
        ? c.createObject(root, { window: root, parentCard: root, hingeY: hingeY, fit: true,
                                 cardWidth: core.cardWidth, model: rows })
        : null;
    }
    onChosen: (i) => root.chosen(i)
    onHovered: (i) => root.hovered(i)
    onUnhovered: (i) => root.unhovered(i)
    onSecondary: (i) => root.secondary(i)
    onSubChosen: (b, i) => root.subChosen(b, i)
  }
}
