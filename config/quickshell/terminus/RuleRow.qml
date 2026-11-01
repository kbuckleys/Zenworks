// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// ONE RULE: what it asks about, how, and what for — Finder's criteria row.
// Out of CollEditSheet's rule list (2026-11-01) so the search bar's own
// criteria rows (SearchBar, user: "match the finder's smart folder toolbars,
// search should have no sheets") are the same row and not a second one.
//
// It says what changed (set) and leaves the rule list to its owner: the
// sheet keeps a ListModel of the draft, the bar writes into the tab's spec.

import QtQuick
import "../morpheus"
import "collections.js" as Coll

Item {
  id: ruleRow
  property var host: null
  property int textSize: 16
  property string kind: ""
  property string op: ""
  property string value: ""
  // the left and right air, the sheet's 16 by default
  property int inset: 16
  property int rowH: 44
  // the trailing controls: the sheet's remove mark unless the owner hands
  // in its own (SearchBar's − and +, as Finder's)
  property Component trailing: null

  signal edited(string field, string v)
  signal drop()
  signal tabbed(var ctl, int dir)
  signal accepted()

  // What this row offers the ring. The value stop is whichever control the
  // row is actually showing — a hidden one cannot take focus, and tabbing
  // into it would look like Tab being swallowed.
  readonly property var kindCtl: kindDrop
  readonly property var opCtl: opDrop
  readonly property var valCtl: ruleRow.kind === "kind" ? valueDrop : valueField
  height: ruleRow.rowH
  // Lifted while one of its own dropdowns is open — z orders an item among
  // its SIBLINGS, and the rows below are this row's siblings.
  z: (kindDrop.expanded || opDrop.expanded || valueDrop.expanded) ? 60 : 0

  BulkDrop {
    id: kindDrop
    host: ruleRow.host
    textSize: ruleRow.textSize
    overlay: ruleRow.host ? ruleRow.host.dropLayerRef : null
    anchors.left: parent.left
    anchors.leftMargin: ruleRow.inset
    anchors.verticalCenter: parent.verticalCenter
    options: {
      const out = [];
      for (let i = 0; i < Coll.KINDS.length; ++i)
        out.push([Coll.KINDS[i].kind, Coll.KINDS[i].label]);
      return out;
    }
    value: ruleRow.kind
    onPicked: (v) => ruleRow.edited("kind", v)
    onTabbed: ruleRow.tabbed(kindDrop, 1)
    onBackTabbed: ruleRow.tabbed(kindDrop, -1)
  }

  BulkDrop {
    id: opDrop
    host: ruleRow.host
    textSize: ruleRow.textSize
    overlay: ruleRow.host ? ruleRow.host.dropLayerRef : null
    anchors.left: kindDrop.right
    anchors.leftMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    options: {
      const ops = Coll.opsFor(ruleRow.kind);
      const out = [];
      for (let i = 0; i < ops.length; ++i) out.push([ops[i], ops[i]]);
      return out;
    }
    value: ruleRow.op
    onPicked: (v) => ruleRow.edited("op", v)
    onTabbed: ruleRow.tabbed(opDrop, 1)
    onBackTabbed: ruleRow.tabbed(opDrop, -1)
  }

  // The Kind row picks from a list; everything else is typed. Two controls
  // in one slot rather than a third column that is empty five rows out of six.
  BulkDrop {
    id: valueDrop
    host: ruleRow.host
    textSize: ruleRow.textSize
    overlay: ruleRow.host ? ruleRow.host.dropLayerRef : null
    visible: ruleRow.kind === "kind"
    anchors.left: opDrop.right
    anchors.leftMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    options: {
      const out = [["", "—"]];
      for (let i = 0; i < Coll.FILE_KINDS.length; ++i)
        out.push([Coll.FILE_KINDS[i].name,
                  Coll.FILE_KINDS[i].label || Coll.FILE_KINDS[i].name]);
      return out;
    }
    value: ruleRow.value
    onPicked: (v) => ruleRow.edited("value", v)
    onTabbed: ruleRow.tabbed(valueDrop, 1)
    onBackTabbed: ruleRow.tabbed(valueDrop, -1)
  }

  BulkField {
    id: valueField
    textSize: ruleRow.textSize
    visible: ruleRow.kind !== "kind"
    anchors.left: opDrop.right
    anchors.leftMargin: 8
    anchors.right: ruleRow.trailing ? trailSlot.left : ruleDrop.left
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    ghost: {
      const k = ruleRow.kind;
      if (k === "size") return "10m";
      if (k === "date") return "7d";
      if (k === "tag") return "a tag name";
      if (k === "content") return "text to find inside";
      return "text";
    }
    // Written back on every keystroke rather than on accept: whatever is
    // bound to the rule (the sheet's Save, the bar's re-run) would otherwise
    // wait for a Return in a field you had already filled in.
    onTextChanged: if (valueField.text !== ruleRow.value) ruleRow.edited("value", valueField.text)
    onTabbed: ruleRow.tabbed(valueField, 1)
    onBackTabbed: ruleRow.tabbed(valueField, -1)
    onAccepted: ruleRow.accepted()
    // Seeded once. The row is edited in place, so this runs when the row is
    // CREATED and never again — which is what stops the seed and the
    // write-back chasing each other.
    Component.onCompleted: valueField.text = ruleRow.value
    // except when the kind changes: the owner empties the value, and the
    // field went on showing the old words over an empty rule (audit
    // 2026-10-28d)
    Connections {
      target: ruleRow
      function onKindChanged() { if (valueField.text !== ruleRow.value) valueField.text = ruleRow.value; }
    }
  }

  Loader {
    id: trailSlot
    anchors.right: parent.right
    anchors.rightMargin: ruleRow.inset
    anchors.verticalCenter: parent.verticalCenter
    sourceComponent: ruleRow.trailing
  }
  Text {
    id: ruleDrop
    visible: !ruleRow.trailing
    anchors.right: parent.right
    anchors.rightMargin: ruleRow.inset
    anchors.verticalCenter: parent.verticalCenter
    text: ""
    color: Zenon.accentMuted
    opacity: ruleDropPress.pressed ? Zenon.pressDim : 1
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(14)

    MouseArea {
      id: ruleDropPress
      anchors.fill: parent
      anchors.margins: -6
      onClicked: ruleRow.drop()
    }
  }
}
