// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE HINT STRIP — the bar at a window's or a panel's foot that the keys
// (HintRow) stand on: its height, its frosted ground, its hairline, and
// where the keys sit. It was ceres' foot; every other window and panel drew
// its own, at 22, 26, 28, 32, 34 or 40 px on one of two grounds (user,
// 2026-10-19: "make all hint bars follow the same properties as ceres'
// hint bar, bar height included. consolidate"). One file now, ceres
// included.
//
//     HintBar { rows: popup.hints() }
//
//     HintBar {                          // buttons at the right end
//       rows: win.hintRows
//       DialogButton { label: "Install"; … }
//     }
//
//     HintBar {                          // a word before the keys
//       rows: …
//       leading: Text { text: query; … }
//     }
//
// The keys (with whatever stands before them) are centered, and start at
// the left the moment buttons stand at the right end, so keys and buttons
// read as the two ends of one strip rather than a row shifting off-center.
// What does not fit is dropped from the END of the list (HintRow.maxWidth),
// which is why every holder lists the keys you need most first.
//
// `note`, when set, takes the keys' place for a moment: "copied", "saved".
//
// `floating` (2026-11-03, Raycast's foot; every strip since the same day,
// user: "worth a try"): no strip — the keys stand in a pill at the right
// end, over whatever runs on behind it, rounded as a row or an inner panel
// is (Zenon.windowRadius, from Oracle's Corner rounding: pillRadius, the
// bar's, stood out against everything round it, user 2026-11-04). Only the pill is
// glass: `frostSource` is what is under it, blurred in its shape. A
// ScrollEdge whose `bar` is this sets it itself, and turns from frost to a
// plain fade (morpheus/ScrollEdge, underPill). `floating: false` is the
// old strip.

import QtQuick
import "."

Item {
  id: bar
  property var rows: []
  // a word for a moment, over the keys (they fade out under it)
  property string note: ""
  property color noteInk: Zenon.accentKey
  // the hairline along the top edge, where the strip meets what it is under
  property bool rule: true
  property color ground: Zenon.hintFrostBg
  property bool floating: true
  property Item frostSource: null
  // WHAT IT FLOATS OVER, FOUND (user, 2026-11-04: "this is a shared helper,
  // why do i have to specify the same set of properties in every single
  // implementation?"): with no ScrollEdge to hand it a source, the pill
  // frosts the topmost sibling stacked under it that it overlaps (the
  // page, the list, the window's ground). ScrollEdges are passed over: they
  // hand themselves in through frostSource, which wins.
  readonly property Item frostUnder: {
    const p = bar.parent;
    if (!bar.floating || !p) return null;
    const kids = p.children;
    const me = Array.prototype.indexOf.call(kids, bar);
    const px = bar.x + bar.pillX, py = bar.y, pw = bar.pillW, ph = bar.height;
    let best = null, bestZ = -Infinity, bestI = -1;
    for (let i = 0; i < kids.length; ++i) {
      const k = kids[i];
      if (!k || k === bar || !k.visible || k.opacity <= 0 || k.width <= 0 || k.height <= 0) continue;
      if (k.underPill !== undefined) continue;
      // input only (a MouseArea, an InputShield, a DropArea) draws nothing
      // to frost (audit 11-04)
      if (k.acceptedButtons !== undefined || (k.containsDrag !== undefined && k.keys !== undefined)) continue;
      // stacked under the bar: a lower z, or the same z and declared before
      if (k.z > bar.z || (k.z === bar.z && i > me)) continue;
      if (k.x >= px + pw || k.x + k.width <= px || k.y >= py + ph || k.y + k.height <= py) continue;
      if (k.z > bestZ || (k.z === bestZ && i > bestI)) { best = k; bestZ = k.z; bestI = i; }
    }
    return best;
  }
  readonly property Item frostFrom: bar.frostSource || bar.frostUnder
  // the pill's gap to the holder's edges, the same below and to the right,
  // and from the buttons beside it
  readonly property int pillInset: 5
  readonly property int trailGap: 12
  // THE KEYS' GAP TO THE PILL'S RIM, one number on every side (user,
  // 2026-11-05: the chips "aren't perfectly aligned with the pill's
  // border"): the pill is the keys' height plus this twice, on whole pixels
  // — the old 30 px pill round 21 px caps put them 4.5 in, and the half
  // rounded one way for the pill and the other for the keys. Measured from
  // a CAP, not the row: the words stand taller than the caps, and the row's
  // height left them 2 px from the rim. The caps keep their own rounding
  // (concentric squared them off, user same day). A word ends the row, and a
  // word needs more air than a box, so the right end has 6 more; a note
  // (all words) keeps the 14 it always had, and a word that STARTS the row
  // (a holder's `leading`) gets the same 6 at the left.
  readonly property int capH: Zenon.px(13) + 8
  readonly property int pad: Math.max(2, Math.floor((Zenon.hintBarH - 2 * bar.pillInset - bar.capH) / 2))
  readonly property int padL: bar.note !== "" ? 14 : lead.width > 0 ? bar.pad + 6 : bar.pad
  readonly property int padR: bar.note !== "" ? 14 : bar.pad + 6
  // the pill in the middle of the foot rather than at its right end (a
  // settings sheet's, Argus'). In a sheet it always is (user, 2026-11-09):
  // a HintBar anywhere inside a morpheus Sheet finds it once it is built.
  property bool centered: bar.inSheet
  property bool inSheet: false
  Component.onCompleted: {
    for (let p = bar.parent; p; p = p.parent) {
      if (p instanceof Sheet) { bar.inSheet = true; return; }
    }
  }
  // keys that do not fit go onto more lines, centered in the pill, rather
  // than behind "?" (terminus' which-key strip, where the list IS the point)
  property bool wrap: false
  // the solid floor under the pill's glass, so nothing sharp reads through
  // it (Frost's base): the holder's own ground
  property color frostBase: Zenon.layerBg
  // the buttons at the right end: a holder's children land here
  default property alias trailing: trail.data
  // something before the keys at the left (terminus' sheets put the query)
  property alias leading: lead.data
  // over the whole strip, the keys' place taken (ideo's format chooser)
  property alias overlay: over.data
  readonly property alias hintRow: hints
  // how wide the keys want to be, all of them shown (a panel sizing itself
  // to its strip reads this)
  readonly property real needW: hints.implicitWidth + 32 + (bar.floating ? 2 * bar.pad + 6 : 0)
    + (lead.width > 0 ? lead.width + bar.leadGap : 0) + (trail.width > 0 ? trail.width + 36 : 0)

  implicitHeight: bar.wrap && bar.floating
    ? Math.max(Zenon.hintBarH, wrapCol.implicitHeight + 2 * bar.pad + 2 * bar.pillInset) : Zenon.hintBarH
  height: implicitHeight

  // see-through: lists rise out of it (the views' ScrollEdges)
  Rectangle { anchors.fill: parent; color: bar.ground; visible: !bar.floating }
  Hairline {
    visible: bar.rule && !bar.floating
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
  }

  // CENTERED AS ONE GROUP — what stands before the keys and the keys —
  // unless something stands at the right end, when they start at the left
  // so the two ends read as one strip (user, 2026-10-19: center the hints
  // in terminus' sheets and plato's settings, which put a word first)
  readonly property bool flanked: trail.width > 0
  // the gap is between the word and the keys: with no keys there is nothing
  // to stand apart from, and it read as uneven padding (user, 2026-11-07)
  readonly property int leadGap: hints.width > 0 ? 16 : 0
  readonly property real groupW: (lead.width > 0 ? lead.width + bar.leadGap : 0) + hints.width

  // ── THE PILL'S PLACE, floating ─────────────────────────────────────────
  // its right edge leaves the buttons their room; the keys stand `pad` in
  readonly property real pillRight: bar.width - bar.pillInset - (trail.width > 0 ? trail.width + bar.trailGap : 0)
  // whole pixels, so its left edge is too and the first cap stands `pad` in
  readonly property real pillW: Math.ceil((bar.note !== "" ? noteText.implicitWidth : bar.wrap ? bar.wrapW : bar.groupW) + bar.padL + bar.padR)
  readonly property real pillX: bar.centered
    ? Math.min(Math.round((bar.width - bar.pillW) / 2), bar.pillRight - bar.pillW)
    : bar.pillRight - bar.pillW
  readonly property real floatX: bar.pillX + bar.padL

  // the wrapped lines: the keys broken greedily, in their order, on the
  // widths HintRow measured
  readonly property var lines: {
    if (!bar.wrap) return [];
    const ws = hints.widths, rs = bar.rows || [];
    // the keys' pads, not the note's: a note must not re-wrap the lines
    const room = bar.width - 2 * bar.pillInset - 2 * bar.pad - 6 - (trail.width > 0 ? trail.width + bar.trailGap : 0);
    const out = [];
    let cur = [], w = 0;
    for (let i = 0; i < rs.length; ++i) {
      const ew = ws[i] || 0;
      if (cur.length > 0 && w + hints.spacing + ew > room) { out.push({ rows: cur, w }); cur = []; w = 0; }
      w += (cur.length > 0 ? hints.spacing : 0) + ew;
      cur.push(rs[i]);
    }
    if (cur.length > 0) out.push({ rows: cur, w });
    return out;
  }
  readonly property real wrapW: bar.lines.reduce((m, l) => Math.max(m, l.w), 0)

  // the pill the keys stand in, floating (or the note while it shows)
  Rectangle {
    id: pill
    visible: bar.floating && (bar.groupW > 0 || bar.note !== "" || bar.lines.length > 0)
    width: bar.pillW
    height: bar.wrap ? bar.height - 2 * bar.pillInset : bar.capH + 2 * bar.pad
    x: bar.pillX
    y: Math.round((bar.height - height) / 2)
    radius: Zenon.windowRadius
    color: bar.ground
    border.width: 1
    border.color: Zenon.border
    Behavior on width { NumberAnimation { duration: Zenon.fast; easing.type: Zenon.ease } }
    Frost {
      anchors.fill: parent
      z: -1
      source: bar.frostFrom
      active: !!bar.frostFrom && Zenon.scrollFrost
      radius: pill.radius
      base: bar.frostBase
    }
  }
  Row {
    id: lead
    x: bar.floating ? Math.max(16, Math.round(bar.floatX))
      : bar.flanked ? 16 : Math.max(16, Math.round((bar.width - bar.groupW) / 2))
    y: Math.round((bar.height - height) / 2)
    spacing: 8
  }

  HintRow {
    id: hints
    rows: bar.rows
    // the caps' top on the pill's pad, whole pixels, however tall the words
    y: bar.floating ? pill.y + bar.pad - (height - bar.capH) / 2 : Math.round((bar.height - height) / 2)
    x: lead.width > 0 ? lead.x + lead.width + 16
      : bar.floating ? Math.max(16, Math.round(bar.floatX))
      : (bar.flanked ? 16 : Math.round((bar.width - width) / 2))
    // never below 0: -1 is HintRow's "unset, show them all", so buttons
    // wider than what was left used to bring every hint back under them
    // (Delphi's Repositories, user 2026-10-25). Wrapping, it is only the
    // ruler the lines are measured on: all shown, unseen.
    maxWidth: bar.wrap ? -1 : Math.max(0, bar.width - 32 - (bar.floating ? 2 * bar.pad + 6 : 0)
      - (lead.width > 0 ? lead.width + 16 : 0)
      - (trail.width > 0 ? trail.width + 12 + 24 : 0))
    opacity: bar.wrap ? 0 : bar.note !== "" ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Zenon.fast } }
  }

  Column {
    id: wrapCol
    visible: bar.wrap && bar.floating
    x: Math.round(bar.floatX)
    width: bar.wrapW
    y: Math.round((bar.height - height) / 2)
    spacing: 6
    opacity: bar.note !== "" ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Zenon.fast } }
    Repeater {
      model: bar.lines
      delegate: HintRow {
        required property var modelData
        anchors.horizontalCenter: parent.horizontalCenter
        rows: modelData.rows
      }
    }
  }

  Text {
    id: noteText
    // floating, in the pill
    anchors.horizontalCenter: bar.floating ? undefined : parent.horizontalCenter
    y: Math.round((bar.height - height) / 2)
    x: Math.round(bar.floatX)
    visible: opacity > 0.01
    opacity: bar.note !== "" ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Zenon.fast } }
    textFormat: Text.PlainText
    text: bar.note
    color: bar.noteInk
    font.family: Zenon.face
    font.weight: Zenon.titleWeight
    font.pixelSize: Zenon.px(15)
  }

  // the buttons' own glass, floating: each on the holder's floor, frosted
  // from what is under it as the pill is, so none is see-through
  Item {
    x: trail.x
    y: trail.y
    width: trail.width
    height: trail.height
    visible: bar.floating
    Repeater {
      model: bar.floating ? trail.children : []
      delegate: Item {
        id: btnGlass
        required property var modelData
        readonly property real r: btnGlass.modelData.radius !== undefined ? btnGlass.modelData.radius : Zenon.windowRadius
        x: btnGlass.modelData.x
        y: btnGlass.modelData.y
        width: btnGlass.modelData.width
        height: btnGlass.modelData.height
        visible: btnGlass.modelData.visible
        Rectangle {
          anchors.fill: parent
          radius: btnGlass.r
          color: bar.frostBase
          visible: !btnFrost.on
        }
        Frost {
          id: btnFrost
          anchors.fill: parent
          source: bar.frostFrom
          active: !!bar.frostFrom && Zenon.scrollFrost
          radius: btnGlass.r
          base: bar.frostBase
        }
      }
    }
  }

  Row {
    id: trail
    anchors.right: parent.right
    anchors.rightMargin: bar.floating ? bar.pillInset : 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8
  }

  Item {
    id: over
    anchors.fill: parent
  }
}
