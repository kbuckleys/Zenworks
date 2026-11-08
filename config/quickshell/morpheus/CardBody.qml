// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE CARD ITSELF — rows, flash and shadow — without the surface it stands on.
//
// CardMenu puts it on a layer surface, placed in screen coordinates, which is
// right for a menu opened on the desktop or out of the pill. CardPopup puts
// it on an xdg-popup hung off a window, which is the only way a window can
// open a card: a client is never told where its own window is, and the
// compositor places a popup for it. One card, so the two look and behave
// exactly alike; see CardMenu for the row format.
import QtQuick
import "."
import "clip"

Item {
  id: root

  property var model: []
  // `still`: the rows do not scroll at all — no wheel, no elastic pull —
  // for a card that shows every row (CardMenu's `whole`; clio's sticky
  // menu, user 2026-10-17)
  property bool still: false
  // the room around the card for its shadow; the card is inset by it
  property int pad: Zenon.menuShadowPad
  property real shade: 1
  property bool hinged: false
  property bool onRight: false
  property string squareEdge: ""

  // ── A DROPDOWN'S LIST: ONE SURFACE WITH ITS BUTTON ───────────────────
  // `joinEdge` ("top" or "bottom") is the card's edge laid against a
  // dropdown's face (morpheus/DropFace) — no gap, the card's hairline on the
  // face's, so the face reads as the menu's header (user, 2026-11-04). The
  // corners there are square for as far as the face covers them
  // (`joinSpan`, its width from the card's left edge) and the rest wear the
  // face's own radius (`joinRadius`), so only the outer ends are round. It
  // unrolls out of that edge rather than growing from a corner, and casts no
  // shadow back over the face.
  property string joinEdge: ""
  property real joinSpan: 0
  property real joinRadius: Zenon.radiusControl
  readonly property bool joined: root.joinEdge !== ""
  // drawn inside a window rather than on a surface of its own: nothing
  // behind it can be blurred, so a dropdown's frost is laid solid
  property bool inWindow: false
  // the face covers the card's whole width: both corners on that edge square
  readonly property bool joinAll: root.joinSpan >= bg.width - 1

  signal chosen(int index)

  readonly property alias card: bg

  function rowHeight(m) {
    return (m && m.isSeparator) ? Zenon.menuSepHeight : Zenon.menuRowHeight;
  }

  // The flash a row gives when it is clicked (morpheus/ChosenFlash), and the
  // reason the card outlives the click: the action runs at the END of it.

  RoundClip {
    id: bg
    anchors.fill: parent
    anchors.margins: root.pad
    // Grows out of its own top-left corner rather than appearing at full
    // size, so the card unfolds FROM the thing it belongs to.
    transformOrigin: Item.TopLeft
    // a dropdown's list unrolls out of its face (joinEdge), in height only
    scale: root.joined ? 1 : Zenon.menuScale(root.shade)
    transform: Scale {
      origin.y: root.joinEdge === "bottom" ? bg.height : 0
      yScale: root.joined ? Zenon.menuUnfold(root.shade) : 1
    }
    opacity: root.shade
    // Opaque, like terminus' card: a menu sits ON what is behind it, not in
    // it, and a translucent ground let the background read through the rows.
    // A dropdown's list is frosted as a sheet is (Zenon.dropFrost): on its
    // own surface Hyprland blurs what is behind; drawn inside a window
    // (`inWindow`, BulkDrop) the same glass is laid solid instead.
    color: !root.joined ? Zenon.menuBg
         : root.inWindow ? Zenon.dropFrostSolid : Zenon.dropFrost
    border.color: Zenon.border
    border.width: 1
    // a dropdown's list wears its face's radius: one outline, one rounding
    radius: root.joined ? root.joinRadius : Zenon.menuRadius
    // Square where it meets its parent, round everywhere else — so a submenu
    // reads as hinged off the row that opened it rather than as a second card
    // that happens to be touching. Only when there IS a parent: a root card
    // opened at a pointer keeps all four corners. A dropdown's list is square
    // where its face sits on it: the left always (it hangs from the face's
    // left), the right too when the face spans the card.
    topLeftRadius:     (root.hinged &&  root.onRight) || root.squareEdge === "top"
                       || root.joinEdge === "top" ? 0 : bg.radius
    bottomLeftRadius:  (root.hinged &&  root.onRight) || root.squareEdge === "bottom"
                       || root.joinEdge === "bottom" ? 0 : bg.radius
    topRightRadius:    (root.hinged && !root.onRight) || root.squareEdge === "top"
                       || (root.joinEdge === "top" && root.joinAll) ? 0 : bg.radius
    bottomRightRadius: (root.hinged && !root.onRight) || root.squareEdge === "bottom"
                       || (root.joinEdge === "bottom" && root.joinAll) ? 0 : bg.radius

    // ── TALLER THAN THE CARD, IT SCROLLS ───────────────────────────────
    // The card is capped at Zenon.menuMaxHeight by whichever surface holds
    // it, and the rows past that are reached with the wheel or two fingers,
    // on the shell's one feel (morpheus Elastic). Not dragged: a press on a
    // row is a choice, and a menu that scrolled under it would be a menu
    // that picked the wrong row. A card that fits does not move at all.
    // EDGE TO EDGE, ALL FOUR SIDES. The rows run flush to the card's 1px
    // border, so the highlight is a band across the menu rather than a pill
    // floating in it (user, 2026-10-10), and the first and last rows touch
    // the top and bottom edges with the card's own round clip cutting the
    // band's corners — folio's cursor, in every menu (user, 2026-10-17).
    // The labels keep their place by their own margins below.
    Flickable {
      id: flick
      anchors.fill: parent
      contentWidth: width
      contentHeight: col.height
      interactive: false
      boundsBehavior: Flickable.StopAtBounds
      clip: true

      ElasticScroll { view: flick; enabled: !root.still }

      Column {
        id: col
        width: flick.width
        spacing: 0

        Repeater {
          id: rowsRep
          model: root.model

          delegate: Item {
            id: row
            // the flash, for a row chosen by key rather than by click (fire)
            Connections {
              target: root
              function onFireAt(i) { if (i === row.index) flash.fire(root.firedThen); }
            }
            required property var modelData
            required property int index
            width: flick.width
            height: root.rowHeight(row.modelData)

            readonly property bool sep: row.modelData.isSeparator || false
            // a branch: flagged by the owner (hasChildren), or carrying its own
            // rows for CardPopup to open beside it (children)
            readonly property bool branch: (row.modelData.hasChildren || false) || !!row.modelData.children
            readonly property bool on: row.modelData.enabled !== false && !row.sep
            // ONE INK FOR EVERY ROW (user, 2026-11-04): no red Trash, no red
            // Empty trash. A row tinted for what it MEANS is gone; only a row
            // that stands for a color shows it, on its glyph (`iconInk`: a
            // tag, a sticky's hue). `danger` is still accepted and ignored.
            // `markDim`: the current choice dimmed instead of ticked
            // (Oracle's Theme list, user 2026-11-07, as Cynosure's)
            readonly property bool dimmed: !!row.modelData.markDim && !!row.modelData.mark
            readonly property color ink: !row.on || row.dimmed ? Zenon.accentMuted : Zenon.white
            // Lit by the pointer, OR because the card it opened is still up.
            // A branch you are standing inside is still the row you came from,
            // and the pointer has by then moved off it onto the child.
            readonly property bool lit: row.on
              && (hover.containsMouse || row.index === root.activeIndex)

            // Square: the first and last rows sit in the card's round
            // corners and the card's clip (RoundClip, inside the border)
            // rounds them, as folio's panel rounds its cursor.
            Rectangle {
              anchors.fill: parent
              color: row.lit ? Zenon.menuHi : "transparent"
            }

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              // EDGE TO EDGE — a separator in a menu spans the whole card, as
              // every menu's does; the row already runs border to border.
              height: 1
              color: Zenon.border
              visible: row.sep
            }

            Item {
              anchors.fill: parent
              // where they were when the column was inset by menuCardPad
              anchors.leftMargin: 12 + Zenon.menuCardPad
              anchors.rightMargin: 10 + Zenon.menuCardPad
              visible: !row.sep

              // A row's mark is EITHER a glyph or an image, never both. Most of
              // this shell's menus draw icons from the font, but a tray menu's
              // come from the application as image URLs, and an application's
              // own icon is not something a font can stand in for.
              Item {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                height: 16
                visible: icon.glyph !== "" || icon.src !== "" || icon.swatch !== null
                readonly property string glyph: row.modelData.icon || ""
                readonly property string src: row.modelData.image || ""
                // or a theme's swatch, [ground, ink, accent] (see Swatch)
                readonly property var swatch: row.modelData.swatch || null
                width: icon.swatch !== null ? sw.width : 16

                Swatch {
                  id: sw
                  visible: icon.swatch !== null
                  anchors.verticalCenter: parent.verticalCenter
                  colors: icon.swatch
                  opacity: row.on ? 1 : 0.45
                }

                Text {
                  anchors.fill: parent
                  visible: icon.glyph !== ""
                  text: icon.glyph
                  // a row may tint its glyph (`iconInk`): a color's swatch
                  color: row.modelData.iconInk && row.on ? row.modelData.iconInk : row.ink
                  font.family: Zenon.face
                  font.weight: Zenon.weight
                  font.pixelSize: Zenon.px(15)
                  verticalAlignment: Text.AlignVCenter
                  horizontalAlignment: Text.AlignHCenter
                }

                Image {
                  anchors.fill: parent
                  visible: icon.glyph === "" && icon.src !== ""
                  source: icon.src
                  sourceSize.width: 16
                  sourceSize.height: 16
                  // An application's icon is its own; dimming it for a disabled
                  // row is the only thing done to it.
                  opacity: row.on ? 1 : 0.45
                }
              }

              Text {
                textFormat: Text.PlainText
                anchors.left: icon.visible ? icon.right : parent.left
                anchors.leftMargin: icon.visible ? Zenon.menuIconGap : 0
                anchors.right: inksBar.left
                anchors.rightMargin: inksBar.width > 0 ? 12 : keyHint.width > 0 ? 12 : (tail.width > 0 ? 8 : 0)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
                text: row.modelData.text || ""
                elide: Text.ElideRight
                color: row.ink
                font.family: Zenon.face
                // a row may be set in a weight of its own (`weight`): a font
                // weight's menu shows each in itself
                font.weight: row.modelData.weight || Zenon.weight
                font.pixelSize: Zenon.px(16)
              }

              // A row's `hint`: the keys that do the same thing, at the right
              // edge — so a menu teaches the keyboard as it is used (plato's
              // context menu). On a key cap, as every key the shell shows
              // is (user, 2026-11-01: "keybinds need chips").
              // a theme's inks (`inks`, Ora.themeInksFor), at the right
              Loader {
                id: inksBar
                anchors.right: keyHint.left
                anchors.rightMargin: width > 0 ? (keyHint.width > 0 ? 8 : (tail.width > 0 ? 10 : 0)) : 0
                anchors.verticalCenter: parent.verticalCenter
                active: !!row.modelData.inks
                source: Qt.resolvedUrl("ThemeInks.qml")
                opacity: row.on && !row.dimmed ? 1 : 0.45
              }
              Binding {
                target: inksBar.item
                when: inksBar.status === Loader.Ready
                property: "colors"
                value: row.modelData.inks || null
              }
              KeyCap {
                id: keyHint
                anchors.right: tail.left
                anchors.rightMargin: tail.width > 0 && width > 0 ? 8 : 0
                anchors.verticalCenter: parent.verticalCenter
                width: label === "" ? 0 : implicitWidth
                fontSize: 12
                label: row.modelData.hint || ""
              }

              // The chevron on a row that has children, or the tick on one that
              // reports a current choice. Never both — a row is a branch or an
              // answer, and one that looked like both would be lying about one.
              Text {
                id: tail
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                // COLLAPSES when it has nothing to show. A row with neither a
                // chevron nor a tick was still reserving 24px for one, so the
                // longest label in a card was elided by a column that was not
                // there — and the only fix available to a caller was to guess a
                // wider card. A plain row now gets that width back.
                width: tail.text === "" ? 0 : 16
                height: 16
                text: row.branch ? ""
                  : ((row.modelData.mark || false) && !row.modelData.markDim ? "" : "")
                // Three answers, not two. A TICK is a state and keeps its
                // accent; a CHEVRON is punctuation belonging to the label beside
                // it and takes the label's own white. Muted was lumping the
                // chevron in with "nothing here", which is what made it look
                // like a disabled row. A branch that IS off (icarus' Recent
                // with nothing learned yet) dims it with its label (user,
                // 2026-10-25).
                color: (row.modelData.mark || false) ? Zenon.accent
                  : (row.branch ? (row.on ? Zenon.white : Zenon.accentMuted)
                    : Zenon.accentMuted)
                font.family: Zenon.face
                font.weight: Zenon.weight
                // The chevron matches the label it punctuates, which is 16.
                // The tick stays smaller: it is a state sitting in the margin,
                // not part of the sentence.
                font.pixelSize: Zenon.px((row.modelData.mark || false) ? 13 : 16)
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
              }
            }

            ChosenFlash { id: flash }

            MouseArea {
              id: hover
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              enabled: row.on && !flash.running
              onEntered: root.hovered(row.index)
              // ONLY A POINTER THAT LEFT. Disabling a hovered MouseArea makes
              // Qt report an exit too — and the flash disables this one for its
              // whole length. So confirming an armed row ("Empty trash", second
              // click) reported the pointer as gone, the owner disarmed it, and
              // the flash then ended in `chosen` on a row that was no longer
              // armed: it armed again instead of acting, every time.
              onExited: if (hover.enabled) root.unhovered(row.index)
              // A row that ASKS does not flash. The flash is the reply to an
              // action, and a row that opens a question has not done anything
              // yet — the question is the reply. Everything else flashes, and
              // the action runs at the end of it.
              onClicked: (event) => {
                if (event.button === Qt.RightButton) {
                  // No flash: a right click on a row is a second question about
                  // it, not the row doing its job.
                  root.secondary(row.index);
                  return;
                }
                // a branch only opens its card — nothing done, nothing to flash
                if ((row.modelData.asks || false) || row.branch) root.chosen(row.index);
                else flash.fire(() => root.chosen(row.index));
              }
            }
          }
        }
      }
    }

    // NO SCROLLBAR (user, 2026-11-04: "it's a menu"): a long card scrolls
    // by the wheel and the cursor keys alone, its rows' own ElasticScroll
  }

  // A ROW CHOSEN BY KEY flashes as a clicked one does, then `then` runs —
  // for a host that walks the rows with the keyboard (terminus' DropAsk).
  // (`then` waits in a property: a signal's var argument is a copy, and
  // a function does not survive being one)
  signal fireAt(int i)
  property var firedThen: null
  function fire(i, then) {
    const t = then || null;
    root.firedThen = () => { root.firedThen = null; if (t) t(); };
    if (i >= 0 && i < rowsRep.count) root.fireAt(i);
    else root.firedThen();
  }

  // A ROW WALKED TO BY KEY is scrolled into the card, as a ListView's
  // Contain would (terminus' BulkDrop arrows down a clamped list).
  function showRow(i) {
    const rows = root.model || [];
    let y = 0;
    for (let k = 0; k < i && k < rows.length; ++k) y += root.rowHeight(rows[k]);
    const h = root.rowHeight(rows[i]);
    if (y < flick.contentY) flick.contentY = y;
    else if (y + h > flick.contentY + flick.height) flick.contentY = y + h - flick.height;
  }

  // How far the rows are scrolled, for a host placing a submenu against one.
  readonly property real scrollY: flick.contentY

  // ── OPENED ON ITS ANSWER ──────────────────────────────────────────────
  // A card that reports a current choice (a row with `mark`) opens with that
  // row in the middle, not at the top of the list: a dropdown of keyboard
  // layouts opens on yours. A card with no mark, or one that fits, opens at
  // its top. The host calls this as it opens the card.
  function reveal() {
    const rows = root.model || [];
    // measured from the rows, not from the column: a Column lays itself out
    // at the next polish, and rows handed over this same turn are not in its
    // height yet — the card would think it fitted and open at the top
    let y = 0, at = -1;
    for (let i = 0; i < rows.length; ++i) {
      if (at < 0 && rows[i] && rows[i].mark) at = y;
      y += root.rowHeight(rows[i]);
    }
    const room = Math.max(0, y - flick.height);
    flick.contentY = at < 0 ? 0
      : Math.max(0, Math.min(room, at - (flick.height - Zenon.menuRowHeight) / 2));
  }

  // A row was pointed at. Separate from `chosen` because a branch opens on
  // hover and acts on click, and only the owner knows which rows are branches.
  signal hovered(int index)
  // And pointed away from — which is how an armed row disarms, so it cannot
  // sit primed waiting for a stray click later.
  signal unhovered(int index)

  // A row was RIGHT-clicked. Some rows carry two answers — icarus' trash row
  // opens the directory on a left click and its own card on a right one — and a
  // menu that swallowed the second button made that impossible to express.
  // Owners that have nothing to say to it simply do not connect it.
  signal secondary(int index)

  // The row whose own card is currently open, which stays lit while you are
  // inside that card. The owner knows which row that is; this card cannot,
  // because the child is a separate window. -1 for none. Both icarus' desktop
  // menu and terminus' context menu have always done this; a CardMenu that
  // did not was the one menu on the desktop whose parent row went dark the
  // moment its child appeared.
  property int activeIndex: -1

  // THE FALLOFF HAS TO FIT THE ROOM. The defaults add up to menuShadowPad;
  // CardPopup leaves only 36px around its card, and the gradient was cut off
  // partway down — a hard-edged dark box around the menu rather than a
  // shadow fading out. Scaled to the pad instead, as terminus' menu does, so
  // the last of the blur lands on the last pixel of the surface.
  readonly property real shadowScale: Math.min(1, root.pad / Zenon.menuShadowPad)

  // A DROPDOWN'S LIST CASTS NOTHING BACK OVER ITS FACE: the face is the
  // menu's header, and a shadow across it would read as a second card laid
  // on top of the first. The face's footprint (its width, everything past
  // the joined edge) is punched out of the shadow like the card's own;
  // beside it the shadow falls as it always did, as the whole thing's.
  MenuShadow {
    panel: bg
    cornerRadius: bg.radius
    alsoHole: root.joinEdge === "top" ? Qt.rect(0, -root.pad, root.joinSpan, root.pad)
            : root.joinEdge === "bottom" ? Qt.rect(0, bg.height, root.joinSpan, root.pad)
            : Qt.rect(0, 0, 0, 0)
    visible: Zenon.menuShadows
    reach: root.pad
    grow: Math.round(Zenon.menuShadowGrow * root.shadowScale)
    softness: Math.round(Zenon.menuShadowBlur * root.shadowScale)
    drop: Math.round(Zenon.menuShadowDrop * root.shadowScale)
    opacity: root.shade
    transformOrigin: Item.TopLeft
    scale: bg.scale
    // unrolled with the card, from its joined edge
    transform: Scale {
      origin.y: root.joinEdge === "bottom" ? bg.height : 0
      yScale: root.joined ? Zenon.menuUnfold(root.shade) : 1
    }
  }
}
