// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE SETUP ASSISTANT'S TIME ZONE — Time & date's own map (WorldMap, in
// its picking mode) over a searched list of zone.tab's cities. Picked, it
// is kept for the end, with the language (SetupAssistant.applySystem).

import QtQuick
import "../../morpheus"
import ".."

Item {
  id: step
  // the assistant; not `asst`, which shadowed its id and bound to itself
  property var setup: null

  readonly property string worn: step.setup.pickZone !== "" ? step.setup.pickZone : Oracle.timedate.zone
  function pick(z) { step.setup.pickZone = z === Oracle.timedate.zone ? "" : z; }

  Rectangle {
    id: mapBox
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Math.round(step.height * 0.36)
    radius: Zenon.radiusControl
    color: Zenon.wash(0.03)
    border.width: 1
    border.color: Zenon.border
    clip: true
    WorldMap {
      anchors.fill: parent
      anchors.margins: 1
      picking: true
      chosen: step.worn
      onPicked: (z) => step.pick(z)
    }
  }

  PickList {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: mapBox.bottom
    anchors.topMargin: 14
    anchors.bottom: note.top
    anchors.bottomMargin: 12
    focus: true
    placeholder: "Search cities and regions"
    model: Oracle.zones.map((z) => ({ value: z.zone, label: z.city, sub: z.region }))
    current: step.worn
    onPicked: (v) => step.pick(v)
    Component.onCompleted: forceActiveFocus()
  }

  Text {
    id: note
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    wrapMode: Text.Wrap
    text: step.setup.pickZone !== "" ? "Set when you get started, with your password."
      : Oracle.timedate.zone !== "" ? "Now " + Oracle.timedate.zone.replace(/_/g, " ") + "." : ""
    color: Zenon.soft
    font.family: Zenon.face
    font.weight: Zenon.weight
    font.pixelSize: Zenon.px(13)
  }
}
