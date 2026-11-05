// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SETUP ASSISTANT'S KEYBOARD — Oracle's Input rows (input:kb_layout,
// input:kb_variant), set as they are picked: no password, and the line at
// the foot types with the new layout at once. A layout picked starts its
// variant over at Standard. More layouts, and the switch key, are Oracle's
// Keyboard section.

import QtQuick
import "../../morpheus"
import "../../terminus" as T
import ".."
import "../oracle.js" as Ora

Item {
  id: step
  // the assistant; not `asst`, which shadowed its id and bound to itself
  property var setup: null

  readonly property string layout: String(Oracle.get("input:kb_layout") || "us").split(",")[0].trim() || "us"
  readonly property string variant: String(Oracle.get("input:kb_variant") || "").split(",")[0].trim()

  Row {
    id: lists
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: tryBox.top
    anchors.bottomMargin: 14
    spacing: 14

    PickList {
      id: layouts
      width: (lists.width - lists.spacing) * 0.58
      height: lists.height
      focus: true
      placeholder: "Search layouts"
      model: (Oracle.xkb.layouts || []).map((l) => ({ value: l.value, label: String(l.label).split(" · ")[0], sub: l.value }))
      current: step.layout
      onPicked: (v) => {
        if (v === step.layout) return;
        Oracle.set("input:kb_layout", v);
        Oracle.set("input:kb_variant", "");
      }
      Component.onCompleted: forceActiveFocus()
    }
    PickList {
      width: (lists.width - lists.spacing) * 0.42
      height: lists.height
      placeholder: "Variants"
      model: Ora.variantOptions(Oracle.xkb, step.layout).map((v) => ({ value: v.value, label: v.label }))
      current: step.variant
      onPicked: (v) => Oracle.set("input:kb_variant", v)
    }
  }

  // a line to type in, with what was just picked
  Rectangle {
    id: tryBox
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Zenon.px(15) * 2.4
    radius: Zenon.radiusControl
    color: Zenon.wash(0.06)
    border.width: 1
    border.color: Zenon.border
    TextInput {
      id: tryIn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 12
      anchors.verticalCenter: parent.verticalCenter
      color: Zenon.white
      selectionColor: Zenon.accentMuted
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(15)
      clip: true
      cursorDelegate: Caret { field: tryIn }
      Keys.onEscapePressed: (e) => { if (tryIn.text !== "") { tryIn.text = ""; e.accepted = true; } else e.accepted = false; }
    }
    Text {
      anchors.left: tryIn.left
      anchors.verticalCenter: parent.verticalCenter
      visible: tryIn.text === ""
      text: "Type here to try it"
      color: Zenon.muted
      font.family: Zenon.face
      font.weight: Zenon.weight
      font.pixelSize: Zenon.px(15)
    }
    MouseArea { anchors.fill: parent; onClicked: tryIn.forceActiveFocus() }
    // the suite's focus ring on a boxed field
    T.HeldRing { anchors.fill: parent; radius: parent.radius; z: 10; on: tryIn.activeFocus }
  }
}
