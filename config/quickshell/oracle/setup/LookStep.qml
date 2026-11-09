// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// MAKE IT YOURS — the first start's card before the assistant (2026-10-25),
// now its Look step: dark or light, an accent, a background. Each is
// Oracle's own setting, set the moment it is picked, so the desktop behind
// changes as you choose; Oracle's Appearance sections hold them afterwards.
//
//   Theme       Zenon dark, Zenon light, or Follow Background
//   Accent      the theme's own, or one of its other hues
//   Background  the Zenworks one stays unless a picture is chosen in
//               Picasso (the card steps aside and comes back after)

import QtQuick
import "../../morpheus"
import "../../picasso"
import ".."
// qualified, for Segments alone: oracle and terminus import each other
import "../../terminus" as Term

Item {
  id: step
  // the assistant; not `asst`, which shadowed its id and bound to itself
  property var setup: null

  // the accents on offer: the worn theme's own hues, so each reads on it
  readonly property var hues: ["cyan", "blue", "green", "magenta", "pink", "yellow", "sand", "red"]
  function hex(c) { return String(c).slice(0, 7); }
  readonly property string accentNow: Oracle.accentColor

  Column {
    id: body
    width: parent.width
    spacing: 18

    SectionLabel { anchors.horizontalCenter: parent.horizontalCenter; text: "Theme" }
    Term.Segments {
      anchors.horizontalCenter: parent.horizontalCenter
      options: [["zenon", "Dark"], ["zenon-light", "Light"], ["follow", "Follow background"]]
      current: Oracle.theme
      onChose: (v) => Oracle.set("theme", v)
    }

    SectionLabel { anchors.horizontalCenter: parent.horizontalCenter; text: "Accent" }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 10
      Repeater {
        model: step.hues
        delegate: Rectangle {
          id: sw
          required property var modelData
          required property int index
          // the first is the theme's own: no color of its own laid over
          readonly property bool own: sw.index === 0
          readonly property bool on: sw.own ? step.accentNow === "" : step.accentNow === step.hex(Zenon[sw.modelData])
          width: Zenon.px(15) * 2
          height: width
          radius: width / 2
          // the theme's own as the theme has it, not the accent worn now
          // ("cyan" is the worn one, your own included: picked blue, the
          // first swatch went blue too; audit 2026-11-08)
          color: sw.own ? Zenon.themeAccent : Zenon[sw.modelData]
          border.width: sw.on ? 3 : 1
          border.color: sw.on ? Zenon.ink : Zenon.border
          MouseArea {
            anchors.fill: parent
            onClicked: Oracle.set("accentColor", sw.own ? "" : step.hex(Zenon[sw.modelData]))
          }
        }
      }
    }

    SectionLabel { anchors.horizontalCenter: parent.horizontalCenter; text: "Background" }
    // the words, then the button under them: side by side they ran
    // past the card on a narrow (portrait) screen (user, 2026-10-25)
    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 10
      Text {
        width: body.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: "The Zenworks one, until you choose another."
        color: Zenon.soft
        font.family: Zenon.face
        font.weight: Zenon.weight
        font.pixelSize: Zenon.px(14)
      }
      DialogButton {
        anchors.horizontalCenter: parent.horizontalCenter
        label: "Choose a picture…"
        ink: Zenon.accent
        onClicked: step.setup.visit(() => Picasso.popupShown, ["Picasso", "toggle"])
      }
    }
  }
}
