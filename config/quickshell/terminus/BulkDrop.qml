// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ── one switch in the settings panel ────────────────────────────────────
// A name, the key that does the same thing, and the state as something you
// can click. Its own component because four of these written out by hand is
// four chances for one to drift from the other three.
// ── a preference you DO rather than one you set ─────────────────────────
// PrefRow's shape — the same height, the same hover, the same label — so the
// panel stays one list. What differs is the right-hand end: a switch says
// "this is how things are" and would be a lie here, because nothing stays
// on afterwards. A verb says what will happen, and a count beside it says
// how much there is to happen to, which is also how you know whether the row
// is worth pressing at all.
// A CHOICE on the batch-rename card, shown as the answer with the rest put
// away. A dropdown and not another row of chips: these options are
// EXCLUSIVE and each one hides the others' controls, so a shape that shows
// one answer is telling the truth where six lit-or-unlit chips would be
// claiming they could all be on at once.
//
// Shared: terminus' batch-rename card and collection editor, and picasso's
// rename of several pictures. `host` is the window, or the card, holding
// the one open dropdown (bulkOpenDrop) and the wheel's step (wheelStep).

import QtQuick
import "../morpheus"

Item {
  id: drop
  // open, over the dropdowns after it in a row (its header widens)
  z: drop.joined !== "" ? 1 : 0
  // whoever keeps the one open dropdown — see the header
  property var host: null
  // [[value, label], ...] rather than two parallel lists, so a row cannot
  // go out of step with its own label.
  property var options: []
  property string value: ""
  property bool expanded: false
  signal picked(string v)

  // WHERE THE LIST ACTUALLY LIVES. A list hanging under a 28px chip is
  // entirely outside its own parent's bounds, and Qt Quick will RENDER a
  // child out there while refusing to hit-test it — so the menu drew
  // perfectly and not one row in it could be clicked. Reparented into a
  // layer that spans the card, where every row sits inside its parent and
  // the mouse can find it.
  property Item overlay: null
  property real listX: 0
  property real listY: 0
  property real listH: 0
  // the list hangs above the chip rather than below it (no room below)
  property bool up: false
  // ONE SURFACE WITH THE CHIP (morpheus DropFace, 2026-11-04): the list
  // unrolls out of the chip's edge and folds back into it, and the chip
  // stays joined until it has
  property real shade: drop.expanded ? 1 : 0
  Behavior on shade { NumberAnimation { duration: Zenon.menuFade; easing.type: Easing.OutCubic } }
  readonly property string joined: drop.shade > 0.01 ? (drop.up ? "above" : "below") : ""

  // THE SAME CONTRACT A FIELD OFFERS. The card owns the tab ring and hands
  // focus round it by calling claim() and asking focused — a control that
  // cannot answer those is one the keyboard has to skip, and the mode
  // picker is the first thing in the row.
  readonly property bool focused: drop.activeFocus
  signal tabbed()
  signal backTabbed()
  function claim() { drop.forceActiveFocus(); }

  // Which row the KEYBOARD is on, as opposed to which one is chosen.
  // Only meaningful while open, and reset to the chosen row each time it
  // opens so arrowing starts from where you already are.
  property int cursor: 0
  function indexOfValue() {
    for (let i = 0; i < drop.options.length; ++i)
      if (drop.options[i][0] === drop.value) return i;
    return 0;
  }
  function choose(i) {
    if (i < 0 || i >= drop.options.length) return;
    drop.expanded = false;
    drop.picked(drop.options[i][0]);
  }

  Keys.onPressed: (e) => {
    // Tab LEAVES, and closes on the way out: a list left hanging over the
    // card while the caret is three controls away is a menu nobody owns.
    if (e.key === Qt.Key_Tab) {
      e.accepted = true; drop.expanded = false; drop.tabbed(); return;
    }
    if (e.key === Qt.Key_Backtab) {
      e.accepted = true; drop.expanded = false; drop.backTabbed(); return;
    }
    // Escape closes the LIST if one is open, and is left alone otherwise
    // so it still reaches the card and shuts that.
    if (e.key === Qt.Key_Escape) {
      if (!drop.expanded) return;
      e.accepted = true; drop.expanded = false; return;
    }
    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter
        || e.key === Qt.Key_Space) {
      e.accepted = true;
      if (drop.expanded) drop.choose(drop.cursor);
      else { drop.cursor = drop.indexOfValue(); drop.expanded = true; }
      return;
    }
    if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
      e.accepted = true;
      const step = e.key === Qt.Key_Down ? 1 : -1;
      if (!drop.expanded) {
        // Closed, an arrow OPENS it rather than silently changing the
        // value underneath you — the same thing every other list in this
        // window does with a first keypress.
        drop.cursor = drop.indexOfValue();
        drop.expanded = true;
        return;
      }
      drop.cursor = Math.max(0, Math.min(drop.options.length - 1,
                                         drop.cursor + step));
      return;
    }
  }

  // Recomputed when it opens, not bound: mapToItem is a function call and
  // a binding around one does not re-run when the geometry under it moves.
  // A dropdown does not move while it is open, so once is enough.
  // ── WHERE IT FITS, NOT JUST WHERE IT BELONGS ───────────────────────
  // A card sized by its own content is often shorter than a list of nine
  // options, and a list that simply hung downwards from the last rule ran
  // off the bottom of the card and was cut in half by the clip. So the
  // space is measured and the list goes wherever there is more of it —
  // and when neither side has enough, it takes what there is and scrolls.
  function reposition() {
    const rowH = Zenon.menuRowHeight;
    const want = drop.options.length * rowH + 2;   // + the border
    if (!drop.overlay) {
      drop.listX = 0;
      drop.listY = drop.height - 1;
      drop.listH = want;
      drop.up = false;
      return;
    }
    const pt = drop.mapToItem(drop.overlay, 0, 0);
    const below = drop.overlay.height - (pt.y + drop.height) - 6;
    const above = pt.y - 6;
    drop.listX = pt.x;
    // Downwards by preference — that is where a menu is looked for — and
    // upwards only when down genuinely has less room. Flush either way, the
    // list's hairline on the chip's: one outline (DropFace).
    if (want <= below || below >= above) {
      drop.listH = Math.min(want, Math.max(rowH + 2, below));
      drop.listY = pt.y + drop.height - 1;
      drop.up = false;
    } else {
      drop.listH = Math.min(want, Math.max(rowH + 2, above));
      drop.listY = pt.y - drop.listH + 1;
      drop.up = true;
    }
  }

  onExpandedChanged: {
      if (!drop.host) return;
    if (drop.expanded) { drop.reposition(); drop.host.bulkOpenDrop = drop; }
    else if (drop.host.bulkOpenDrop === drop) drop.host.bulkOpenDrop = null;
  }

  Connections {
    target: drop.host
    ignoreUnknownSignals: true
    function onBulkOpenDropChanged() {
      if (drop.host.bulkOpenDrop !== drop) drop.expanded = false;
    }
  }

  readonly property string label: {
    for (let i = 0; i < drop.options.length; ++i)
      if (drop.options[i][0] === drop.value) return drop.options[i][1];
    return "";
  }
  // AS WIDE AS ITS CHOICE (user, 2026-11-05), and as its list while that
  // is out — the chip widens rightwards over what is beside it, and the
  // control keeps its closed width, so nothing beside it moves
  implicitWidth: dropChip.restWidth
  // Grows with the text it carries, so a card that wants larger type
  // does not end up with larger words in a chip sized for smaller ones.
  property int textSize: 13
  implicitHeight: Math.max(28, drop.textSize + 15)

  // what the closed chip shows, measured for its width (DropFace)
  TextMetrics {
    id: labelMetric
    text: drop.label
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: drop.textSize
  }

  // the list's header while it is out: one surface (DropFace)
  DropFace {
    id: dropChip
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    radius: Zenon.windowRadius
    joined: drop.joined
    leftInset: 9
    contentWidth: labelMetric.advanceWidth
    menuWidth: listFit.cardW
    // PRESSED, DARKENED as every button in the suite (user, 2026-10-17)
    pressed: dropPress.pressed
    restColor: Zenon.alpha(Zenon.white, 0.05)
    lit: drop.activeFocus
    chevronInk: Zenon.white
    chevronSize: drop.textSize - 2

    Text {
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.leftMargin: dropChip.inset
      anchors.verticalCenter: parent.verticalCenter
      text: drop.label
      color: Zenon.white
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.pixelSize: drop.textSize
    }
  }
  MouseArea {
    id: dropPress
    // the open header is wider than the closed chip: all of it takes the
    // press, and it stands over the next dropdown in a row (audit 11-05)
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Math.max(parent.width, dropChip.width)
    onClicked: {
      drop.claim();
      if (!drop.expanded) drop.cursor = drop.indexOfValue();
      drop.expanded = !drop.expanded;
    }
  }

  // The list. Parented to the drop and drawn with a z of its own, which
  // is why patRow lifts its whole self while one is open — see there.
  // THE SUITE'S MENU CARD (morpheus/CardBody, 2026-11-04): it was a hand
  // list with its own band, rounded end rows and a hover tint. The chosen
  // option carries the card's tick, as every dropdown's does.
  // the one measure every card fits by (MenuFit)
  MenuFit { id: listFit; model: dropList.model; again: drop.expanded }
  CardBody {
    id: dropList
    visible: drop.shade > 0.01
    shade: drop.shade
    // laid against the chip, the chip its header
    joinEdge: drop.up ? "bottom" : "top"
    // inside the window: its frost laid solid (Zenon.dropFrostSolid)
    inWindow: true
    joinSpan: dropChip.targetWidth
    joinRadius: dropChip.radius
    parent: drop.overlay ? drop.overlay : drop
    z: 100
    pad: 12
    x: drop.listX - pad
    y: drop.listY - pad
    // the chip's open width, which is the list's own (DropFace.menuWidth)
    width: Math.max(dropChip.restWidth, listFit.cardW) + 2 * pad
    height: drop.listH + 2 * pad
    model: drop.options.map((o) => ({ text: String(o[1]), mark: o[0] === drop.value ? "\u2713" : "" }))
    activeIndex: drop.cursor
    onHovered: (i) => drop.cursor = i
    onChosen: (i) => drop.choose(i)
  }
  onCursorChanged: if (drop.expanded) dropList.showRow(drop.cursor)
}
